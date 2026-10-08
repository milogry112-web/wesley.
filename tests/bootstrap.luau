-- Actual Bootstrap startup/respawn/scheduler decisions with service boundaries
-- stubbed. Real service logic, generated geometry and UI have separate suites.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local function signal()
	local listeners = {}
	local event = {}
	function event:Connect(callback)
		listeners[callback] = true
		return { Disconnect = function() listeners[callback] = nil end }
	end
	function event:Once(callback)
		local connection
		connection = self:Connect(function(...) connection:Disconnect(); callback(...) end)
		return connection
	end
	function event:Fire(...)
		for callback in table.clone(listeners) do callback(...) end
	end
	return event
end
local delayed, shutdowns, registered = {}, {}, nil
local playerList = {}
local players = { CharacterAutoLoads = true, RespawnTime = 5, PlayerAdded = signal(), PlayerRemoving = signal() }
function players:GetPlayers() return playerList end
local heartbeat = signal()
local function makePlayer()
	local p = { Parent = players, Character = nil, CharacterAdded = signal(), Loads = 0 }
	function p:LoadCharacterAsync()
		assert(not players.CharacterAutoLoads, "Two character spawn owners enabled")
		self.Loads += 1
		local humanoid = { Died = signal(), IsA = function(_, class) return class == "Humanoid" end }
		self.Character = { WaitForChild = function(_, name) assert(name == "Humanoid"); return humanoid end, Humanoid = humanoid }
		self.CharacterAdded:Fire(self.Character)
	end
	return p
end
local first = makePlayer()
table.insert(playerList, first)
local counters = { Progression = 0, Monsters = 0, Activation = 0, World = 0 }
local progression = {
	AddPlayer = function() end, RemovePlayer = function() end, PushState = function() end,
	Step = function() counters.Progression += 1 end,
}
local damage = { SetMonsterService = function() end, Destroy = function() end }
local monsters = { Step = function() counters.Monsters += 1 end, Destroy = function() end }
local activation = { Step = function() counters.Activation += 1; return {} end, Destroy = function() end }
local modules = {
	ProgressionDataService = { new = function() return {} end },
	ProgressionService = { new = function() return progression end },
	DamageService = { new = function() return damage end },
	MonsterService = { new = function() return monsters end },
	ZoneActivationService = { new = function() return activation end },
}
local shared = { DungeonConfig = {}, MonsterConfig = { AITick = 0.15 } }
function shared:WaitForChild(name) return assert(self[name]) end
local package = { WaitForChild = function(_, name) assert(name == "Shared"); return shared end, FindFirstChild = function() return nil end }
local parent = { Services = modules, Runtime = { Register = function(value) registered = value end }, World = { WorldGenerator = { Generate = function()
	assert(not players.CharacterAutoLoads)
	counters.World += 1
	return {}
end } } }
function parent:WaitForChild(name) return assert(self[name]) end
local env = {
	game = { GetService = function(_, name)
		if name == "Players" then return players end
		if name == "ReplicatedStorage" then return { WaitForChild = function() return package end } end
		if name == "RunService" then return { Heartbeat = heartbeat } end
		error(name)
	end, BindToClose = function(_, callback) table.insert(shutdowns, callback) end },
	script = { Parent = parent }, require = function(module) return module end,
	Instance = { new = function(class)
		return { IsA = function(_, name) return name == class end, FindFirstChild = function() return nil end, OnServerEvent = signal() }
	end },
	task = { spawn = function(callback) callback() end, wait = function() end,
		delay = function(time, callback) table.insert(delayed, { time = time, callback = callback }) end },
}
luau.load(fs.readFile("src/server/Bootstrap.server.luau"), { environment = env })()
local passed = 0
local function test(name, callback)
	local ok, reason = pcall(callback)
	assert(ok, name .. ": " .. tostring(reason))
	passed += 1
	print("PASS: " .. name)
end
test("bootstrap prepares world once before one explicit initial character load", function()
	assert(counters.World == 1 and first.Loads == 1 and not players.CharacterAutoLoads)
	assert(registered and registered.Progression == progression and registered.Monsters == monsters)
end)
test("death queues one respawn and binds the replacement character", function()
	local dead = first.Character
	dead.Humanoid.Died:Fire()
	dead.Humanoid.Died:Fire()
	assert(#delayed == 1 and delayed[1].time == 5)
	table.remove(delayed, 1).callback()
	assert(first.Loads == 2 and first.Character ~= dead)
	first.Character.Humanoid.Died:Fire()
	assert(#delayed == 1)
end)
test("leaving cancels a pending respawn and a later player gets one initial load", function()
	players.PlayerRemoving:Fire(first)
	first.Parent = nil
	table.remove(delayed, 1).callback()
	assert(first.Loads == 2)
	local newcomer = makePlayer()
	players.PlayerAdded:Fire(newcomer)
	assert(newcomer.Loads == 1)
end)
test("one bounded scheduler ticks all services and closes cleanly", function()
	heartbeat:Fire(0.1)
	assert(counters.Monsters == 0)
	heartbeat:Fire(0.1)
	assert(counters.Monsters == 1 and counters.Progression == 1 and counters.Activation == 1)
	heartbeat:Fire(10)
	assert(counters.Monsters == 2)
	for _, close in shutdowns do close() end
	heartbeat:Fire(1)
	assert(counters.Monsters == 2)
end)
print(string.format("%d bootstrap lifecycle tests passed (service boundaries stubbed)", passed))
