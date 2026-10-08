--!nonstrict
-- Only durable unlocks are saved. In-progress encounter slots intentionally reset
-- on reconnect; they are never accepted from a client.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local SCHEMA_VERSION = 1
local ZONE_COUNT = 30
local SAVE_ATTEMPTS = 4
local STORE_NAME = "AetherDungeon_Progression_v1"

local ProgressionDataService = {}
ProgressionDataService.__index = ProgressionDataService

local function finite(value): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- UpdateAsync also sanitizes its current value, preventing an old server's stale
-- snapshot from lowering progress written by a newer server.
local function sanitize(value)
	if value == nil then
		return { HighestUnlocked = 1, Completed = false }
	end
	if type(value) ~= "table" then
		return nil, "The stored profile is not a table."
	end
	local version = value.SchemaVersion
	if version ~= nil and (not finite(version) or version > SCHEMA_VERSION or version < 1) then
		return nil, "The stored profile uses an unsupported schema."
	end
	local highest = if finite(value.HighestUnlocked) then math.clamp(math.floor(value.HighestUnlocked), 1, ZONE_COUNT) else 1
	return { HighestUnlocked = highest, Completed = value.Completed == true and highest == ZONE_COUNT }
end

local function unavailableInStudio(message): boolean
	if not RunService:IsStudio() then
		return false
	end
	local lower = string.lower(tostring(message))
	return string.find(lower, "studio", 1, true) ~= nil
		or string.find(lower, "publish", 1, true) ~= nil
		or string.find(lower, "403", 1, true) ~= nil
		or string.find(lower, "accessnotallowed", 1, true) ~= nil
end

function ProgressionDataService.new()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	local self = setmetatable({
		_store = if ok then result else nil,
		_startupFailure = if ok then nil else tostring(result),
		_records = {}, -- Player instances distinguish a fast rejoin from its retiring session.
		_known = {},
		_closing = false,
		_destroyed = false,
		_shutdownDeadline = nil,
		_random = Random.new(),
	}, ProgressionDataService)
	game:BindToClose(function()
		self:_close()
	end)
	return self
end

function ProgressionDataService:_timeRemaining(): number
	return if self._shutdownDeadline then self._shutdownDeadline - os.clock() else math.huge
end

function ProgressionDataService:_waitForBudget(requestType): boolean
	local deadline = os.clock() + math.min(4, self:_timeRemaining())
	repeat
		local ok, budget = pcall(function()
			return DataStoreService:GetRequestBudgetForRequestType(requestType)
		end)
		if ok and budget > 0 then
			return true
		end
		if os.clock() >= deadline or self._destroyed then
			return false
		end
		task.wait(0.25)
	until false
end

function ProgressionDataService:_retryDelay(attempt: number)
	local delay = math.min(2 ^ (attempt - 1) + self._random:NextNumber(0, 0.4), self:_timeRemaining())
	if delay > 0 then
		task.wait(delay)
	end
end

function ProgressionDataService:_remember(record)
	local previous = self._known[record.player.UserId]
	self._known[record.player.UserId] = {
		HighestUnlocked = math.max(record.highest, if previous then previous.HighestUnlocked else 1),
		Completed = record.completed or (previous ~= nil and previous.Completed),
	}
end

function ProgressionDataService:Load(player: Player)
	local existing = self._records[player]
	if existing then
		-- The owning progression service calls Load once. Avoid a second request if
		-- another server subsystem happens to ask after the first one has completed.
		while existing.loading and not self._destroyed do
			task.wait(0.05)
		end
		return { HighestUnlocked = existing.highest, Completed = existing.completed, DataStatus = existing.status, Writable = existing.writable }
	end
	local record = {
		player = player,
		key = "player_" .. tostring(player.UserId),
		highest = 1,
		completed = false,
		status = "Loading",
		writable = false,
		loading = true,
		dirty = false,
		busy = false,
		retired = false,
	}
	self._records[player] = record
	local profile, failure = nil, self._startupFailure
	local sessionOnly = self._store == nil and RunService:IsStudio()
	if self._store then
		for attempt = 1, SAVE_ATTEMPTS do
			if self._closing or self._destroyed then
				failure = "The server is shutting down."
				break
			end
			local ok, result
			if self:_waitForBudget(Enum.DataStoreRequestType.GetAsync) then
				ok, result = pcall(function()
					return self._store:GetAsync(record.key)
				end)
			else
				ok, result = false, "DataStore request budget is unavailable."
			end
			if ok then
				profile, failure = sanitize(result)
				break
			end
			failure = tostring(result)
			if unavailableInStudio(failure) then
				sessionOnly = true
				break
			end
			if attempt < SAVE_ATTEMPTS then
				self:_retryDelay(attempt)
			end
		end
	end
	if profile then
		local known = self._known[player.UserId]
		record.highest = math.max(profile.HighestUnlocked, if known then known.HighestUnlocked else 1)
		record.completed = profile.Completed or (known ~= nil and known.Completed)
		record.writable = true
		record.status = "Saved"
		record.dirty = record.highest > profile.HighestUnlocked or record.completed ~= profile.Completed
		self:_remember(record)
	else
		-- A failed read MUST NOT create a writable default profile. Retrying writes
		-- from this session could destroy the user's real progression.
		record.status = if sessionOnly then "SessionOnly" else "SaveFailed"
		record.writable = false
		warn("[AetherDungeon] Progression is read-only for user " .. tostring(player.UserId) .. ": " .. tostring(failure))
	end
	record.loading = false
	if record.dirty then
		self:_startSave(record)
	elseif record.retired then
		self._records[player] = nil
	end
	return { HighestUnlocked = record.highest, Completed = record.completed, DataStatus = record.status, Writable = record.writable }
end

function ProgressionDataService:_startSave(record)
	if record.busy or record.loading or not record.writable or not record.dirty or self._destroyed then
		return
	end
	record.busy = true
	record.status = "Saving"
	task.spawn(function()
		while record.dirty and record.writable and not self._destroyed do
			local targetHighest, targetCompleted = record.highest, record.completed
			local saved, failure = nil, nil
			for attempt = 1, SAVE_ATTEMPTS do
				if self:_timeRemaining() <= 0 then
					failure = "Server shutdown save deadline reached."
					break
				end
				local unsupported = nil
				local ok, result
				if self:_waitForBudget(Enum.DataStoreRequestType.UpdateAsync) then
					ok, result = pcall(function()
						return self._store:UpdateAsync(record.key, function(previous)
							local clean, reason = sanitize(previous)
							if not clean then
								unsupported = reason
								return nil
							end
							local highest = math.max(clean.HighestUnlocked, targetHighest)
							return {
								SchemaVersion = SCHEMA_VERSION,
								HighestUnlocked = highest,
								Completed = highest == ZONE_COUNT and (clean.Completed or targetCompleted),
								UpdatedAt = os.time(),
							}
						end)
					end)
				else
					ok, result = false, "DataStore request budget is unavailable."
				end
				if unsupported then
					record.writable = false
					failure = unsupported
					break
				end
				if ok and result ~= nil then
					saved, failure = sanitize(result)
					if saved then
						break
					end
				else
					failure = tostring(result)
				end
				if attempt < SAVE_ATTEMPTS then
					self:_retryDelay(attempt)
				end
			end
			if not saved then
				record.status = "SaveFailed"
				warn("[AetherDungeon] Save deferred for user " .. tostring(record.player.UserId) .. ": " .. tostring(failure))
				break
			end
			-- Keep progress earned while UpdateAsync yielded; its next iteration saves
			-- the new snapshot. A successful older save must not clear a newer edit.
			record.dirty = record.highest > saved.HighestUnlocked or (record.completed and not saved.Completed)
			record.highest = math.max(record.highest, saved.HighestUnlocked)
			record.completed = record.completed or saved.Completed
			self:_remember(record)
			record.status = if record.dirty then "Saving" else "Saved"
		end
		record.busy = false
		if record.retired and (not record.dirty or not record.writable) then
			self._records[record.player] = nil
		end
	end)
end

function ProgressionDataService:QueueSave(player: Player, highest: number, completed: boolean)
	local record = self._records[player]
	if not record or record.loading or not record.writable or not finite(highest) then
		return
	end
	highest = math.clamp(math.floor(highest), 1, ZONE_COUNT)
	local nextHighest = math.max(record.highest, highest)
	local nextCompleted = record.completed or (completed == true and nextHighest == ZONE_COUNT)
	if nextHighest ~= record.highest or nextCompleted ~= record.completed then
		record.highest, record.completed = nextHighest, nextCompleted
		record.dirty = true
		self:_remember(record)
	end
	self:_startSave(record)
end

function ProgressionDataService:GetStatus(player: Player): string
	local record = self._records[player]
	return if record then record.status else "Loading"
end

function ProgressionDataService:IsWritable(player: Player): boolean
	local record = self._records[player]
	return record ~= nil and record.writable
end

function ProgressionDataService:RetryPending()
	for _, record in self._records do
		self:_startSave(record)
	end
end

function ProgressionDataService:RemovePlayer(player: Player)
	local record = self._records[player]
	if not record then
		return
	end
	record.retired = true
	if not record.loading and not record.busy and (not record.dirty or not record.writable) then
		self._records[player] = nil
	else
		self:_startSave(record)
	end
end

function ProgressionDataService:_close()
	if self._closing or self._destroyed then
		return
	end
	self._closing = true
	self._shutdownDeadline = os.clock() + 25
	self:RetryPending()
	repeat
		local pending = 0
		for _, record in self._records do
			if record.writable and (record.dirty or record.busy) then
				pending += 1
			end
		end
		if pending == 0 then
			break
		end
		if self:_timeRemaining() <= 0 then
			warn("[AetherDungeon] Shutdown finished with " .. tostring(pending) .. " unsaved progression profile(s).")
			break
		end
		task.wait(0.1)
	until false
	self._destroyed = true
end

function ProgressionDataService:Destroy()
	self:_close()
end

return ProgressionDataService
