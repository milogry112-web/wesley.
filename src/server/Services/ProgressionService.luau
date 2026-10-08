--!nonstrict
-- Gates are visual, noncolliding objects. Access is enforced for each player
-- here, independently of every other player's unlocks and client UI state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("AetherDungeon"):WaitForChild("Shared"):WaitForChild("DungeonConfig"))
local Rules = require(ReplicatedStorage.AetherDungeon.Shared.ProgressionRules)

local REQUIRED_KILLS = 5
local VALIDATION_INTERVAL = 0.1
local AUTOSAVE_INTERVAL = 30
local ALLOWED_MOVE_SPEED = 72 -- Generous network tolerance; standard avatar speed is 16.
local MOVEMENT_BURST = 36 -- Bounds teleport distance even after a long idle period.
local MIN_Y, MAX_Y = -12, 95

local ProgressionService = {}
ProgressionService.__index = ProgressionService

local function finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

function ProgressionService.new(remotes: Folder, dataService)
	return setmetatable({
		_remotes = remotes,
		_data = dataService,
		_players = {},
		_accumulator = 0,
		_autosave = 0,
		_destroyed = false,
	}, ProgressionService)
end

function ProgressionService:_notify(player: Player, title: string, body: string, kind: string)
	if player.Parent == Players then
		self._remotes.Notify:FireClient(player, { Title = title, Body = body, Kind = kind })
	end
end

function ProgressionService:_resetCharacter(player: Player, character: Model)
	local state = self._players[player]
	if not state then
		return
	end
	state.character = character
	state.root = nil
	state.current = 0
	state.lastPosition = nil
	state.lastSafe = Config.GetSafeCFrame(0)
	state.lastObserved = os.clock()
	state.moveBudget = MOVEMENT_BURST
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root or not root:IsA("BasePart") or self._players[player] ~= state or state.character ~= character then
			return
		end
		-- Spawn and respawn always return to the village. This is not a dungeon
		-- travel mechanism; forward travel is exclusively normal avatar walking.
		character:PivotTo(Config.GetSafeCFrame(0))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		state.root = root
		state.lastPosition = root.Position
		state.lastSafe = root.CFrame
		state.lastObserved = os.clock()
		self:PushState(player)
	end)
end

function ProgressionService:AddPlayer(player: Player)
	if self._players[player] or self._destroyed then
		return
	end
	local state = {
		highest = 1,
		completed = false,
		slots = Rules.NewEncounter(),
		current = 0,
		loaded = false,
		character = nil,
		root = nil,
		lastPosition = nil,
		lastSafe = Config.GetSafeCFrame(0),
		lastObserved = os.clock(),
		moveBudget = MOVEMENT_BURST,
		nextGateNotice = 0,
		lastDataStatus = "Loading",
		lastSaveWritable = false,
		characterConnection = nil,
	}
	self._players[player] = state
	state.characterConnection = player.CharacterAdded:Connect(function(character)
		self:_resetCharacter(player, character)
	end)
	if player.Character then
		self:_resetCharacter(player, player.Character)
	end
	self:PushState(player)
	task.spawn(function()
		local profile = self._data:Load(player)
		if self._players[player] ~= state or self._destroyed then
			self._data:RemovePlayer(player)
			return
		end
		state.highest = profile.HighestUnlocked
		state.completed = profile.Completed
		state.loaded = true
		if state.completed then
			for slot = 1, REQUIRED_KILLS do
				state.slots[slot] = true
			end
		end
		state.lastDataStatus = profile.DataStatus
		state.lastSaveWritable = profile.Writable
		self:PushState(player)
		if not profile.Writable then
			self:_notify(player, "SESSION PROGRESS ONLY", "Saved progress could not be loaded. You can play, but progress in this session will not be saved. Rejoin when data access is available.", "Warning")
		end
	end)
end

function ProgressionService:GetHighest(player: Player): number
	local state = self._players[player]
	return if state then state.highest else 1
end

function ProgressionService:GetCurrentZone(player: Player): number
	local state = self._players[player]
	return if state then state.current else 0
end

function ProgressionService:IsLoaded(player: Player): boolean
	local state = self._players[player]
	return state ~= nil and state.loaded
end

function ProgressionService:GetSnapshot(player: Player)
	local state = self._players[player]
	if not state then
		return nil
	end
	local kills = Rules.Count(state.slots)
	if state.current > 0 and state.current < state.highest then
		kills = REQUIRED_KILLS
	end
	return {
		CurrentZone = state.current,
		HighestUnlocked = state.highest,
		Kills = kills,
		Required = REQUIRED_KILLS,
		Completed = state.completed,
		DataStatus = self._data:GetStatus(player),
		SaveWritable = self._data:IsWritable(player),
	}
end

function ProgressionService:PushState(player: Player)
	local snapshot = self:GetSnapshot(player)
	if snapshot and player.Parent == Players then
		self._remotes.State:FireClient(player, snapshot)
	end
end

function ProgressionService:_correct(player: Player, state, reason: string)
	local root = state.root
	local character = state.character
	if root and character and character.Parent then
		character:PivotTo(state.lastSafe)
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") then
				part.AssemblyLinearVelocity = Vector3.zero
				part.AssemblyAngularVelocity = Vector3.zero
			end
		end
		state.lastPosition = root.Position
		state.lastObserved = os.clock()
		state.moveBudget = MOVEMENT_BURST
		state.current = Config.GetZoneAt(root.Position) or 0
	end
	if os.clock() >= state.nextGateNotice then
		state.nextGateNotice = os.clock() + 3
		self:_notify(player, "PATH SEALED", reason, "Warning")
	end
	self:PushState(player)
end

-- Call immediately before accepting combat as well as from the shared scheduler.
-- This closes the window between a forged position and the next periodic check.
function ProgressionService:ValidatePosition(player: Player): boolean
	local state = self._players[player]
	if not state or not state.root or not state.character or state.character ~= player.Character then
		return false
	end
	local root = state.root
	local humanoid = state.character:FindFirstChildOfClass("Humanoid")
	if not root.Parent or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local position = root.Position
	if not finite(position.X) or not finite(position.Y) or not finite(position.Z) then
		self:_correct(player, state, "Stay on the dungeon path.")
		return false
	end
	local forwardLimit = if state.highest == Config.ZoneCount then (Config.BossArenaEnd or Config.ZoneCount * Config.ZoneLength) else state.highest * Config.ZoneLength
	-- The raw forward bound is tested regardless of horizontal position or height:
	-- climbing or walking around the outside cannot bypass a personal unlock.
	local zone = Config.GetZoneAt(position)
	if position.Z >= forwardLimit or zone == nil or zone > state.highest or position.Y < MIN_Y or position.Y > MAX_Y then
		local message = if position.Z >= forwardLimit or (zone and zone > state.highest)
			then "Defeat all five different guardians in dungeon " .. tostring(state.highest) .. " to open the next path."
			else "Return to the marked village and dungeon paths."
		self:_correct(player, state, message)
		return false
	end
	local now = os.clock()
	state.moveBudget = math.min(MOVEMENT_BURST, state.moveBudget + math.max(0, now - state.lastObserved) * ALLOWED_MOVE_SPEED)
	state.lastObserved = now
	if state.lastPosition then
		local travelled = (position - state.lastPosition).Magnitude
		if travelled > state.moveBudget then
			self:_correct(player, state, "Walk between the dungeon gates to continue your journey.")
			return false
		end
		state.moveBudget -= travelled
	end
	state.lastPosition = position
	-- Only grounded samples replace the recovery point; falling into scenery or
	-- presenting a midair position does not become the next safe destination.
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		state.lastSafe = root.CFrame
	end
	if state.current ~= zone then
		state.current = zone
		self:PushState(player)
	end
	return true
end

function ProgressionService:RegisterKill(player: Player, zoneId: number, slotId: number): boolean
	local state = self._players[player]
	if not state or not state.loaded or state.completed or zoneId ~= state.highest
		or type(slotId) ~= "number" or slotId % 1 ~= 0 or slotId < 1 or slotId > REQUIRED_KILLS then
		return false
	end
	if not self:ValidatePosition(player) or state.current ~= zoneId or state.slots[slotId] then
		return false
	end
	local previousHighest = state.highest
	local previousCompleted = state.completed
	local nextHighest, nextCompleted, changed = Rules.RecordKill(state.slots, zoneId, slotId, state.highest, state.completed)
	if not changed then
		return false
	end
	state.highest, state.completed = nextHighest, nextCompleted
	if nextHighest ~= previousHighest or nextCompleted ~= previousCompleted then
		if nextHighest > previousHighest then
			state.slots = Rules.NewEncounter()
			self:_notify(player, "DUNGEON " .. tostring(state.highest) .. " UNLOCKED", "All five guardians defeated. Walk through the next gate to continue.", "Unlock")
		else
			self:_notify(player, "ETERNAL FORGE COMPLETE", "You conquered all 30 dungeons. The legendary forge awaits your next adventure.", "Complete")
		end
		self._data:QueueSave(player, state.highest, state.completed)
	end
	self:PushState(player)
	return true
end

function ProgressionService:Step(dt: number)
	if self._destroyed then
		return
	end
	self._accumulator += dt
	self._autosave += dt
	if self._accumulator >= VALIDATION_INTERVAL then
		self._accumulator %= VALIDATION_INTERVAL
		for player, state in self._players do
			self:ValidatePosition(player)
			local status = self._data:GetStatus(player)
			local writable = self._data:IsWritable(player)
			if status ~= state.lastDataStatus or writable ~= state.lastSaveWritable then
				state.lastDataStatus = status
				state.lastSaveWritable = writable
				self:PushState(player)
				if status == "SaveFailed" and state.loaded and self._data:IsWritable(player) then
					self:_notify(player, "SAVE RETRY PENDING", "Progress is available on this server. Saving failed; we will retry automatically.", "Warning")
				end
			end
		end
	end
	if self._autosave >= AUTOSAVE_INTERVAL then
		self._autosave %= AUTOSAVE_INTERVAL
		self._data:RetryPending()
	end
end

function ProgressionService:RemovePlayer(player: Player)
	local state = self._players[player]
	if state then
		if state.characterConnection then
			state.characterConnection:Disconnect()
		end
		if state.loaded then
			self._data:QueueSave(player, state.highest, state.completed)
		end
		self._players[player] = nil
	end
	self._data:RemovePlayer(player)
end

function ProgressionService:Destroy()
	self._destroyed = true
	local players = {}
	for player in self._players do
		table.insert(players, player)
	end
	for _, player in players do
		self:RemovePlayer(player)
	end
end

return ProgressionService
