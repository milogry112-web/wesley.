-- Production server modules executed with controlled service boundaries.
-- These checks verify decisions; they do not simulate Roblox replication/physics.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local passed = 0
local function test(name, callback)
	local ok, message = pcall(callback)
	assert(ok, name .. ": " .. tostring(message))
	passed += 1
	print("PASS: " .. name)
end

local function signal()
	local result = { Connected = false }
	function result:Connect(callback)
		self.Callback = callback
		self.Connected = true
		return { Disconnect = function() self.Connected = false end }
	end
	return result
end

local MonsterConfig = luau.load(fs.readFile("src/shared/MonsterConfig.luau"))()
local function context()
	local ctx = { Now = 100, Loaded = true, ValidPosition = true, Highest = 1, Zone = 1, BlockedRay = false, Hits = 0 }
	local players = { PlayerRemoving = signal() }
	local shared = { WaitForChild = function(_, name) return name end }
	local package = { WaitForChild = function() return shared end }
	local replicated = { WaitForChild = function() return package end }
	local workspace = { Raycast = function() return if ctx.BlockedRay then {} else nil end }
	local services = { Players = players, ReplicatedStorage = replicated, Workspace = workspace }
	local game = { GetService = function(_, name) return assert(services[name], "Unexpected service " .. name) end }
	ctx.Root = { Position = Vector3.new(0, 4, 20), IsA = function(_, class) return class == "BasePart" end }
	ctx.Humanoid = { Health = 100 }
	local character = {
		FindFirstChildOfClass = function() return ctx.Humanoid end,
		FindFirstChild = function() return ctx.Root end,
	}
	ctx.Player = { UserId = 10, Parent = players, Character = character }
	ctx.Players = { ctx.Player }
	players.GetPlayers = function() return ctx.Players end
	ctx.Progression = {
		IsLoaded = function() return ctx.Loaded end,
		ValidatePosition = function() return ctx.ValidPosition end,
		GetHighest = function(_, player) return player.Highest or ctx.Highest end,
		GetCurrentZone = function(_, player) return player.Zone or ctx.Zone end,
	}
	ctx.Monster = { Id = "zone:01:slot:1", ZoneId = 1, Alive = true, Active = true,
		Model = { Parent = workspace }, Position = Vector3.new(0, 4, 25) }
	ctx.Monsters = {
		GetMonster = function(_, id) return if id == ctx.Monster.Id then ctx.Monster else nil end,
		ApplyDamage = function(_, _, amount, player)
			assert(player == ctx.Player)
			ctx.Hits += 1
			ctx.LastDamage = amount
			return amount, false
		end,
	}
	ctx.Remotes = { Attack = { OnServerEvent = signal() },
		DamageFeedback = { FireClient = function(_, player, result) ctx.Feedback = result end } }
	local environment = {
		game = game, Vector3 = Vector3, Enum = roblox.Enum,
		Random = { new = function() return { NextNumber = function() return 0.5 end } end },
		RaycastParams = { new = function() return {} end },
		os = { clock = function() return ctx.Now end },
		require = function(name)
			if name == "MonsterConfig" then return MonsterConfig end
			if name == "DungeonConfig" then return { ZoneCount = 30 } end
			error("Unexpected module " .. tostring(name))
		end,
	}
	ctx.Damage = luau.load(fs.readFile("src/server/Services/DamageService.luau"), { environment = environment })()
	ctx.Activation = luau.load(fs.readFile("src/server/Services/ZoneActivationService.luau"), { environment = environment })()
	ctx.Service = ctx.Damage.new(ctx.Progression, ctx.Remotes)
	ctx.Service:SetMonsterService(ctx.Monsters)
	return ctx
end

test("a client damage argument is ignored; damage comes from the server provider", function()
	local c = context()
	c.Remotes.Attack.OnServerEvent.Callback(c.Player, c.Monster.Id, 800e15)
	assert(c.Hits == 1 and math.abs(c.LastDamage - 1.7) < 1e-12)
	assert(c.Feedback.Amount == c.LastDamage)
end)

test("invalid target types, oversized IDs, and missing monsters never deal damage", function()
	local c = context()
	for _, id in { 1, {}, true, string.rep("x", 81), "nonexistent" } do
		c.Now += 1
		assert(not c.Service:Attack(c.Player, id))
	end
	assert(c.Hits == 0)
end)

test("authoritative position validation runs before monster attacks", function()
	local c = context()
	c.ValidPosition = false
	assert(not c.Service:Attack(c.Player, c.Monster.Id) and c.Hits == 0)
	c.ValidPosition = true
	c.Loaded = false
	c.Now += 1
	assert(not c.Service:Attack(c.Player, c.Monster.Id) and c.Hits == 0)
end)

test("locked and different-zone targets reject a hit even when spatially close", function()
	local c = context()
	c.Monster.ZoneId = 2
	assert(not c.Service:Attack(c.Player, c.Monster.Id))
	c.Zone = 2
	c.Now += 1
	assert(not c.Service:Attack(c.Player, c.Monster.Id))
	assert(c.Hits == 0)
end)

test("server weapon range and collidable line-of-sight block impossible hits", function()
	local c = context()
	c.Monster.Position = Vector3.new(0, 4, 100)
	assert(not c.Service:Attack(c.Player, c.Monster.Id))
	c.Monster.Position = Vector3.new(0, 4, 25)
	c.BlockedRay = true
	c.Now += 1
	assert(not c.Service:Attack(c.Player, c.Monster.Id) and c.Hits == 0)
end)

test("accepted attacks enforce the server cooldown", function()
	local c = context()
	assert(c.Service:Attack(c.Player, c.Monster.Id))
	c.Now += 0.1
	assert(not c.Service:Attack(c.Player, c.Monster.Id) and c.Hits == 1)
	c.Now += 0.6
	assert(c.Service:Attack(c.Player, c.Monster.Id) and c.Hits == 2)
end)

test("future server weapons support quadrillions without a low hardcoded cap", function()
	local c = context()
	c.Service:SetWeaponProvider(function()
		return { Damage = 200e15, Range = 20, Cooldown = 0.5, CritChance = 1, CritMultiplier = 2 }
	end)
	assert(c.Service:Attack(c.Player, c.Monster.Id))
	assert(c.LastDamage == 400e15 and c.Feedback.Critical)
end)

test("invalid or failed server weapon providers cannot corrupt damage", function()
	for _, damage in { 0, -1, math.huge, 0 / 0 } do
		local c = context()
		c.Service:SetWeaponProvider(function() return { Damage = damage, Range = 20, Cooldown = 1 } end)
		assert(not c.Service:Attack(c.Player, c.Monster.Id) and c.Hits == 0)
	end
	local c = context()
	c.Service:SetWeaponProvider(function() error("equipment not loaded") end)
	assert(not c.Service:Attack(c.Player, c.Monster.Id) and c.Hits == 0)
end)

test("destroying damage service disconnects listeners and rejects later requests", function()
	local c = context()
	c.Service:Destroy()
	c.Service:Destroy()
	assert(not c.Remotes.Attack.OnServerEvent.Connected)
	assert(not c.Service:Attack(c.Player, c.Monster.Id) and c.Hits == 0)
end)

test("zone activation is the union of every eligible living player", function()
	local c = context()
	local bob = { UserId = 20, Zone = 2, Highest = 2, Character = c.Player.Character }
	table.insert(c.Players, bob)
	local activation = c.Activation.new(c.Progression)
	local active = activation:Step(0.15)
	assert(active[1] and active[2])
	c.Players = { bob }
	c.Now += 13
	active = activation:Step(0.15)
	assert(not active[1] and active[2], "Alice leaving must not despawn Bob's encounter")
	c.Players = {}
	c.Now += 5
	assert(activation:Step(0.15)[2], "Grace period should retain recently occupied zones")
	c.Now += 8
	assert(next(activation:Step(0.15)) == nil)
end)

test("dead players and players claiming locked zones do not activate simulation", function()
	local c = context()
	local activation = c.Activation.new(c.Progression)
	c.Zone = 2
	assert(next(activation:Step(0.15)) == nil)
	c.Zone = 1
	c.Humanoid.Health = 0
	assert(next(activation:Step(0.15)) == nil)
end)

print(string.format("%d production server decision tests passed (service boundaries stubbed)", passed))
