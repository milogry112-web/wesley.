-- Runs the real services in Lune with deterministic clock, task, player and
-- DataStore doubles. These are logic regression tests, not a Roblox network,
-- physics, character, DataStore-backend or Studio playtest.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3, CFrame, Enum = roblox.Vector3, roblox.CFrame, roblox.Enum

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in value do result[key] = copy(item) end
	return result
end

local function scheduler()
	local clock = { now = 0, sequence = 0, queue = {} }
	local function enqueue(thread, when)
		clock.sequence += 1
		table.insert(clock.queue, { thread = thread, at = when, sequence = clock.sequence })
	end
	clock.task = {
		spawn = function(callback, ...)
			local arguments = table.pack(...)
			local thread = coroutine.create(function() callback(table.unpack(arguments, 1, arguments.n)) end)
			enqueue(thread, clock.now)
			return thread
		end,
		wait = function(delay) return coroutine.yield(delay or 0.03) end,
	}
	function clock:step()
		if #self.queue == 0 then return false end
		table.sort(self.queue, function(a, b)
			return a.at < b.at or (a.at == b.at and a.sequence < b.sequence)
		end)
		local entry = table.remove(self.queue, 1)
		self.now = math.max(self.now, entry.at)
		local ok, delay = coroutine.resume(entry.thread)
		assert(ok, tostring(delay))
		if coroutine.status(entry.thread) ~= "dead" then enqueue(entry.thread, self.now + delay) end
		return true
	end
	function clock:run()
		local iterations = 0
		while self:step() do
			iterations += 1
			assert(iterations < 3000, "A service task did not settle")
		end
	end
	function clock:call(callback)
		local result
		self.task.spawn(function() result = callback() end)
		self:run()
		return result
	end
	return clock
end

local function fixture(studio)
	local clock = scheduler()
	local messages, warnings, closeCallbacks = {}, {}, {}
	local store = { values = {}, getCalls = 0, updateCalls = 0, writes = 0, getFailures = 0, updateFailures = 0, updateDelay = 0 }
	function store:GetAsync(key)
		self.getCalls += 1
		if self.getFailure then error(self.getFailure) end
		if self.getFailures > 0 then self.getFailures -= 1; error("Transient read failure") end
		return copy(self.values[key])
	end
	function store:UpdateAsync(key, callback)
		self.updateCalls += 1
		if self.updateFailures > 0 then self.updateFailures -= 1; error("Transient write failure") end
		if self.updateDelay > 0 then clock.task.wait(self.updateDelay) end
		local value = callback(copy(self.values[key]))
		if value ~= nil then
			self.writes += 1
			self.values[key] = copy(value)
		end
		return copy(value)
	end
	local players = {}
	local environment = table.clone(roblox)
	environment.task = clock.task
	environment.os = { clock = function() return clock.now end, time = function() return 1_800_000_000 end }
	environment.Random = { new = function() return { NextNumber = function() return 0 end } end }
	environment.warn = function(message) table.insert(warnings, message) end
	local function load(path)
		return luau.load(fs.readFile(path), { environment = environment, debugName = path })()
	end
	local config = load("src/shared/DungeonConfig.luau")
	local rules = load("src/shared/ProgressionRules.luau")
	local shared = { DungeonConfig = config, ProgressionRules = rules }
	local aether = { Shared = shared }
	local replicated = { AetherDungeon = aether }
	for _, folder in { shared, aether, replicated } do
		folder.WaitForChild = function(self, name) return self[name] end
	end
	local dataStores = {
		GetDataStore = function() return store end,
		GetRequestBudgetForRequestType = function() return 100 end,
	}
	local services = {
		Players = players, ReplicatedStorage = replicated,
		DataStoreService = dataStores, RunService = { IsStudio = function() return studio == true end },
	}
	environment.game = {
		GetService = function(_, name) assert(services[name], name); return services[name] end,
		BindToClose = function(_, callback) table.insert(closeCallbacks, callback) end,
	}
	environment.require = function(module) return module end
	local Data = load("src/server/Services/ProgressionDataService.luau")
	local Progression = load("src/server/Services/ProgressionService.luau")
	local remotes = {}
	for _, name in { "State", "Notify" } do
		remotes[name] = { FireClient = function(_, player, payload)
			table.insert(messages, { remote = name, player = player, payload = copy(payload) })
		end }
	end
	local data = Data.new()
	local progression = Progression.new(remotes, data)
	local result = { clock = clock, store = store, data = data, progression = progression, warnings = warnings, messages = messages, closeCallbacks = closeCallbacks }
	function result:player(userId)
		local callbacks = {}
		local player = { UserId = userId, Parent = players }
		player.CharacterAdded = { Connect = function(_, callback)
			callbacks[callback] = true
			return { Disconnect = function() callbacks[callback] = nil end }
		end }
		local root = {
			Position = Vector3.new(0, 5, -95), CFrame = CFrame.new(0, 5, -95),
			AssemblyLinearVelocity = Vector3.zero, AssemblyAngularVelocity = Vector3.zero,
			IsA = function(_, class) return class == "BasePart" end,
		}
		local humanoid = { Health = 100, FloorMaterial = Enum.Material.Slate }
		local character = {
			Parent = {},
			WaitForChild = function(_, name) return if name == "HumanoidRootPart" then root else nil end,
			FindFirstChildOfClass = function(_, class) return if class == "Humanoid" then humanoid else nil end,
			GetDescendants = function() return { root } end,
			PivotTo = function(_, frame) root.Position = frame.Position; root.CFrame = frame end,
		}
		root.Parent = character
		player.Character = character
		player.TestRoot, player.TestHumanoid = root, humanoid
		player.TestCharacterCallbacks = callbacks
		return player
	end
	function result:add(userId)
		local player = self:player(userId)
		self.progression:AddPlayer(player)
		self.clock:run()
		return player
	end
	function result:place(player, position)
		player.TestRoot.Position = position
		player.TestRoot.CFrame = CFrame.new(position)
	end
	function result:walk(player, targetZ)
		while math.abs(player.TestRoot.Position.Z - targetZ) > 0.01 do
			local delta = math.clamp(targetZ - player.TestRoot.Position.Z, -16, 16)
			self.clock.now += 0.25
			self:place(player, player.TestRoot.Position + Vector3.new(0, 0, delta))
			assert(self.progression:ValidatePosition(player), "A normal grounded walk was rejected")
		end
	end
	return result
end

local passed = 0
local function test(name, callback)
	local ok, failure = pcall(callback)
	assert(ok, name .. ": " .. tostring(failure))
	passed += 1
	print("PASS: " .. name)
end

test("failed profile reads never write a default or later training unlock", function()
	local f = fixture()
	f.store.getFailure = "Service temporarily unavailable"
	local player = f:add(101)
	assert(f.store.getCalls == 4 and f.progression:IsLoaded(player))
	assert(not f.data:IsWritable(player) and f.data:GetStatus(player) == "SaveFailed")
	f:walk(player, 25)
	for slot = 1, 5 do assert(f.progression:RegisterKill(player, 1, slot)) end
	assert(f.progression:GetHighest(player) == 2)
	f.progression:RemovePlayer(player)
	f.clock:run()
	assert(f.store.updateCalls == 0 and f.store.writes == 0)
end)

test("disabled Studio APIs visibly create a nonpersistent session", function()
	local f = fixture(true)
	f.store.getFailure = "Studio access to APIs is not allowed"
	local player = f:add(102)
	assert(f.store.getCalls == 1 and f.data:GetStatus(player) == "SessionOnly")
	assert(not f.data:IsWritable(player) and f.store.updateCalls == 0)
	local warned = false
	for _, message in f.messages do
		if message.remote == "Notify" and message.payload.Title == "SESSION PROGRESS ONLY" then warned = true end
	end
	assert(warned)
end)

test("transient loading and saving failures retry before reporting success", function()
	local f = fixture()
	f.store.getFailures = 2
	local player = f:add(103)
	assert(f.store.getCalls == 3 and f.data:GetStatus(player) == "Saved")
	f.store.updateFailures = 2
	f.data:QueueSave(player, 5, false)
	assert(f.data:GetStatus(player) == "Saving")
	f.clock:run()
	assert(f.store.updateCalls == 3 and f.store.writes == 1)
	assert(f.store.values.player_103.HighestUnlocked == 5 and f.data:GetStatus(player) == "Saved")
end)

test("UpdateAsync merges another server's newer unlock and completion", function()
	local f = fixture()
	local player = f:add(104)
	f.store.values.player_104 = { SchemaVersion = 1, HighestUnlocked = 30, Completed = true }
	f.data:QueueSave(player, 2, false)
	f.clock:run()
	local saved = f.store.values.player_104
	assert(saved.HighestUnlocked == 30 and saved.Completed and saved.SchemaVersion == 1)
end)

test("progress earned while an older save yields is saved in a second pass", function()
	local f = fixture()
	local player = f:add(105)
	f.store.updateDelay = 1
	f.data:QueueSave(player, 2, false)
	assert(f.clock:step())
	f.data:QueueSave(player, 3, false)
	f.clock:run()
	assert(f.store.writes == 2 and f.store.values.player_105.HighestUnlocked == 3)
	assert(f.data:GetStatus(player) == "Saved")
end)

test("a fast rejoin preserves unsaved local progress and separate sessions", function()
	local f = fixture()
	local oldPlayer = f:add(106)
	f.store.updateDelay = 2
	f.data:QueueSave(oldPlayer, 9, false)
	assert(f.clock:step())
	f.progression:RemovePlayer(oldPlayer)
	local newPlayer = f:add(106)
	assert(newPlayer ~= oldPlayer and f.progression:GetHighest(newPlayer) == 9)
	assert(f.store.values.player_106.HighestUnlocked == 9)
	assert(f.data:GetStatus(newPlayer) == "Saved")
end)

test("future schema profiles are read-only and never replaced", function()
	local f = fixture()
	f.store.values.player_107 = { SchemaVersion = 2, HighestUnlocked = 20, Completed = false, FutureField = true }
	local player = f:add(107)
	f.data:QueueSave(player, 30, true)
	f.clock:run()
	assert(not f.data:IsWritable(player) and f.store.updateCalls == 0)
	assert(f.store.values.player_107.FutureField and f.store.values.player_107.HighestUnlocked == 20)
	local other = f:add(108)
	f.store.values.player_108 = { SchemaVersion = 2, HighestUnlocked = 25 }
	f.data:QueueSave(other, 2, false)
	f.clock:run()
	assert(f.store.writes == 0 and not f.data:IsWritable(other))
	assert(f.store.values.player_108.HighestUnlocked == 25)
end)

test("sanitization clamps malformed fields and never invents final completion", function()
	local f = fixture()
	f.store.values.player_109 = { SchemaVersion = 1, HighestUnlocked = 5.8, Completed = true }
	local player = f:add(109)
	local snapshot = f.progression:GetSnapshot(player)
	assert(snapshot.HighestUnlocked == 5 and not snapshot.Completed)
	f.store.values.player_110 = { SchemaVersion = 1, HighestUnlocked = math.huge, Completed = true }
	assert(f.progression:GetHighest(f:add(110)) == 1)
end)

test("personal gates admit an unlocked player while stopping their companion", function()
	local f = fixture()
	f.store.values.player_201 = { SchemaVersion = 1, HighestUnlocked = 2 }
	local unlocked, locked = f:add(201), f:add(202)
	f:walk(unlocked, 195)
	f:walk(locked, 170)
	f.clock.now += 0.4
	f:place(locked, Vector3.new(0, 5, 190))
	assert(not f.progression:ValidatePosition(locked))
	assert(locked.TestRoot.Position.Z == 170 and f.progression:GetCurrentZone(locked) == 1)
	assert(f.progression:GetCurrentZone(unlocked) == 2 and unlocked.TestRoot.Position.Z == 195)
	assert(locked.TestRoot.AssemblyLinearVelocity == Vector3.zero)
	-- The same service permits normal backward walking through earlier zones.
	f:walk(unlocked, 30)
	assert(f.progression:GetCurrentZone(unlocked) == 1)
end)

test("synchronous validation rejects side routes, high flight and long teleports", function()
	local f = fixture()
	f.store.values.player_203 = { SchemaVersion = 1, HighestUnlocked = 3 }
	local player = f:add(203)
	f:walk(player, 30)
	for _, point in {
		Vector3.new(1000, 5, 600), -- beyond locked gate while outside all geometry
		Vector3.new(0, 150, 35), -- same unlocked zone, but above playable volume
		Vector3.new(0, 5, 205), -- huge jump into a previously unlocked zone
		Vector3.new(0, -30, 40), -- below the world
	} do
		f.clock.now += 10 -- Idle time does not accumulate an unlimited teleport budget.
		f:place(player, point)
		assert(not f.progression:ValidatePosition(player))
		assert(player.TestRoot.Position.Z == 30 and player.TestRoot.Position.Y == 5)
	end
	f:place(player, Vector3.new(0, 5, 380))
	assert(not f.progression:RegisterKill(player, 3, 1), "Combat must reject a forged position before the scheduler runs")
	assert(f.progression:GetSnapshot(player).Kills == 5)
end)

test("unloaded players cannot receive encounter credit", function()
	local f = fixture()
	f.store.getFailures = 2
	local player = f:player(204)
	f.progression:AddPlayer(player)
	assert(f.clock:step()) -- Character setup.
	assert(f.clock:step()) -- Load suspends at first retry.
	assert(not f.progression:IsLoaded(player))
	f:walk(player, 20)
	assert(not f.progression:RegisterKill(player, 1, 1))
	f.clock:run()
	assert(f.progression:IsLoaded(player) and f.progression:RegisterKill(player, 1, 1))
end)

test("the actual service advances a walking player through thirty encounters", function()
	local f = fixture()
	local player, companion = f:add(205), f:add(206)
	for zone = 1, 30 do
		f:walk(player, (zone - 1) * 180 + 25)
		for slot = 1, 5 do assert(f.progression:RegisterKill(player, zone, slot)) end
		f.clock:run()
		assert(f.progression:GetHighest(player) == math.min(zone + 1, 30))
		assert(f.progression:GetHighest(companion) == 1)
	end
	local snapshot = f.progression:GetSnapshot(player)
	assert(snapshot.Completed and snapshot.HighestUnlocked == 30 and snapshot.Kills == 5)
	assert(f.store.values.player_205.Completed and f.store.values.player_205.HighestUnlocked == 30)
	assert(not f.progression:RegisterKill(player, 30, 1))
	f:walk(player, 5510) -- Reserved boss annex belongs to zone thirty.
	assert(f.progression:GetCurrentZone(player) == 30)
	local completionCount = 0
	for _, message in f.messages do
		if message.remote == "Notify" and message.payload.Kind == "Complete" then completionCount += 1 end
	end
	assert(completionCount == 1)
end)

test("failed saves stay dirty and a later autosave retries them", function()
	local f = fixture()
	local player = f:add(207)
	f.store.updateFailures = 4
	f.data:QueueSave(player, 4, false)
	f.clock:run()
	assert(f.data:GetStatus(player) == "SaveFailed" and f.store.writes == 0)
	f.progression:Step(30)
	f.clock:run()
	assert(f.data:GetStatus(player) == "Saved" and f.store.values.player_207.HighestUnlocked == 4)
end)

test("shutdown saves all pending players within a bounded wait", function()
	local f = fixture()
	local alice, bob = f:add(208), f:add(209)
	f.store.updateDelay = 1
	f.data:QueueSave(alice, 7, false)
	f.data:QueueSave(bob, 8, false)
	local started = f.clock.now
	f.clock:call(f.closeCallbacks[1])
	assert(f.store.values.player_208.HighestUnlocked == 7 and f.store.values.player_209.HighestUnlocked == 8)
	assert(f.clock.now - started <= 25.5)
	local broken = fixture()
	local player = broken:add(210)
	broken.store.updateFailures = 100
	broken.data:QueueSave(player, 2, false)
	local failedStarted = broken.clock.now
	broken.clock:call(broken.closeCallbacks[1])
	assert(broken.clock.now - failedStarted <= 25.5 and broken.store.writes == 0)
	assert(broken.data:GetStatus(player) == "SaveFailed")
end)

print(string.format("%d service logic tests passed (Roblox engine playtesting still required)", passed))
