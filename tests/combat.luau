-- Real MonsterService/health modules and real Roblox datatypes/instance trees.
-- Engine scheduling, raycasts, players and BindableEvent delivery are controlled
-- boundaries here. This is not a rendering, replication or Studio physics test.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local passed = 0

local function test(name, callback)
	local ok, reason = pcall(callback)
	assert(ok, name .. ": " .. tostring(reason))
	passed += 1
	print("PASS: " .. name)
end

local function signal()
	local callbacks = {}
	local result = {}
	function result:Connect(callback)
		callbacks[callback] = true
		return { Disconnect = function() callbacks[callback] = nil end }
	end
	function result:Fire(...)
		for callback in callbacks do callback(...) end
	end
	return result
end

-- Lune implements Instance storage; supply only the absent engine model pivot.
roblox.implementMethod("Model", "PivotTo", function(model, transform)
	local delta = transform * model.PrimaryPart.CFrame:Inverse()
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then part.CFrame = delta * part.CFrame end
	end
end)

local contexts = {}
roblox.implementMethod("Workspace", "Raycast", function(workspace, _origin, _direction, _parameters)
	return if contexts[workspace].BlockedRay then {} else nil
end)

local configs = {
	DungeonConfig = luau.load(fs.readFile("src/shared/DungeonConfig.luau"), {
		environment = { Vector3 = Vector3, Color3 = roblox.Color3, CFrame = CFrame },
	})(),
	MonsterConfig = luau.load(fs.readFile("src/shared/MonsterConfig.luau"))(),
	MonsterHealthService = luau.load(fs.readFile("src/server/Services/MonsterHealthService.luau"))(),
}

local function context()
	local ctx = { Now = 100, BlockedRay = false, Players = {}, Credits = {}, Tags = {}, Deaths = {} }
	ctx.Workspace = roblox.Instance.new("Workspace")
	contexts[ctx.Workspace] = ctx
	local players = { PlayerRemoving = signal() }
	function players:GetPlayers() return ctx.Players end
	function players:GetPlayerByUserId(userId)
		for _, player in ctx.Players do
			if player.UserId == userId then return player end
		end
		return nil
	end
	local shared = { WaitForChild = function(_, name) return name end }
	local replicated = { WaitForChild = function() return { WaitForChild = function() return shared end } end }
	local collection = {
		AddTag = function(_, model, tag) assert(tag == "AetherMonster"); ctx.Tags[model] = true end,
		RemoveTag = function(_, model, tag) assert(tag == "AetherMonster"); ctx.Tags[model] = nil end,
	}
	local services = { Players = players, Workspace = ctx.Workspace, ReplicatedStorage = replicated, CollectionService = collection }
	local environment = {
		game = { GetService = function(_, name) return assert(services[name], name) end },
		script = { Parent = shared },
		Vector3 = Vector3, CFrame = CFrame, Color3 = roblox.Color3, Enum = roblox.Enum,
		RaycastParams = { new = function() return {} end },
		os = { clock = function() return ctx.Now end },
		require = function(name) return assert(configs[name], name) end,
		Instance = {
			new = function(className)
				if className ~= "BindableEvent" then return roblox.Instance.new(className) end
				local event = { Event = signal() }
				function event:Fire(payload) table.insert(ctx.Deaths, payload); self.Event:Fire(payload) end
				function event:Destroy() self.Destroyed = true end
				return event
			end,
		},
	}
	ctx.Progression = {
		IsLoaded = function(_, player) return player.Loaded end,
		ValidatePosition = function(_, player) return player.ValidPosition end,
		GetCurrentZone = function(_, player) return player.Zone end,
		GetHighest = function(_, player) return player.Highest end,
		RegisterKill = function(_, player, zoneId, slotId)
			table.insert(ctx.Credits, { UserId = player.UserId, ZoneId = zoneId, SlotId = slotId })
		end,
	}
	ctx.Damage = { SetMonsterService = function(_, service) ctx.BoundService = service end }
	ctx.MonsterService = luau.load(fs.readFile("src/server/Services/MonsterService.luau"), { environment = environment })()
	ctx.Service = ctx.MonsterService.new({}, ctx.Progression, ctx.Damage, {})
	function ctx:AddPlayer(userId, zone, position)
		local root = { Position = position, IsA = function(_, class) return class == "BasePart" end }
		local humanoid = { Health = 100, DamageTaken = 0 }
		function humanoid:TakeDamage(amount) self.Health -= amount; self.DamageTaken += amount end
		local player = {
			UserId = userId, Parent = players, Zone = zone, Highest = zone, Loaded = true, ValidPosition = true,
			Root = root, Humanoid = humanoid,
			Character = { FindFirstChild = function() return root end, FindFirstChildOfClass = function() return humanoid end },
		}
		table.insert(self.Players, player)
		return player
	end
	function ctx:Close()
		self.Service:Destroy()
		contexts[self.Workspace] = nil
		self.Workspace:Destroy()
	end
	return ctx
end

test("all 150 authoritative slots exist without any inactive monster models", function()
	local c = context()
	local slots = 0
	for _, state in c.Service:GetStates() do
		slots += 1
		assert(not state.Active and state.Alive and state.Model == nil)
	end
	assert(slots == 150 and c.BoundService == c.Service)
	c.Service:Step(0.15, {})
	assert(#c.Workspace.AetherMonsters:GetChildren() == 0)
	c:Close()
end)

test("each active zone generates exactly five complete custom-health models", function()
	local c = context()
	c.Service:Step(0.15, { [1] = true, [5] = true, [9] = true })
	assert(#c.Workspace.AetherMonsters:GetChildren() == 15)
	for _, state in c.Service:GetStates() do
		if not state.Active then assert(not state.Model); continue end
		local model = state.Model
		assert(model and model.PrimaryPart.Name == "Root" and model:FindFirstChild("Head"))
		assert(model:GetAttribute("HP") == configs.MonsterConfig.HP[state.ZoneId])
		assert(model:GetAttribute("MonsterId") == state.Id and model:GetAttribute("SlotId") == state.SlotId)
		assert(model.ModelStreamingMode == roblox.Enum.ModelStreamingMode.Atomic and c.Tags[model])
		assert(not model:FindFirstChildOfClass("Humanoid"))
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then assert(part.Anchored and not part.CanCollide and not part.CanTouch) end
		end
	end
	c:Close()
end)

test("every themed monster can construct and zone 30 retains numeric 800Qa HP", function()
	local c = context()
	local active = {}
	for id = 1, 30 do active[id] = true end
	c.Service:Step(0.15, active)
	assert(#c.Workspace.AetherMonsters:GetChildren() == 150)
	local final = c.Service:GetMonster("zone:30:slot:5")
	assert(final.HP == 800e15, "Authoritative maximum HP must retain its configured double")
	-- Lune 0.10.1 coerces integer-like Instance attributes to Int32 and overflows
	-- this value. Roblox stores number attributes as doubles. Large replicated
	-- attribute precision must therefore be tested in Studio; production health
	-- arithmetic above executes unmodified and retains the full configured value.
	assert(type(final.Model:GetAttribute("MaxHP")) == "number")
	c:Close()
end)

test("a zone can sleep without losing HP or disturbing another player's active zone", function()
	local c = context()
	local alice = c:AddPlayer(1, 1, Vector3.new(-30, 4, 46))
	c.Service:Step(0.15, { [1] = true, [2] = true })
	local state = c.Service:GetMonster("zone:01:slot:1")
	assert(c.Service:ApplyDamage(state, 1, alice) == 1)
	c.Service:Step(0.15, { [2] = true })
	assert(not state.Model and not state.Active and state.HP == 4 and state.Contributors[1] == 1)
	assert(#c.Workspace.AetherMonsters:GetChildren() == 5)
	c.Service:Step(0.15, { [1] = true, [2] = true })
	assert(state.Model and state.HP == 4 and state.Model:GetAttribute("HP") == 4)
	assert(#c.Workspace.AetherMonsters:GetChildren() == 10)
	c:Close()
end)

test("one death emits one loot hook and credits both actual eligible contributors only", function()
	local c = context()
	local alice = c:AddPlayer(1, 1, Vector3.new(-30, 4, 46))
	local bob = c:AddPlayer(2, 1, Vector3.new(-28, 4, 46))
	c:AddPlayer(3, 1, Vector3.new(-27, 4, 46))
	c.Service:Step(0.15, { [1] = true })
	local state = c.Service:GetMonster("zone:01:slot:1")
	c.Service:ApplyDamage(state, 1, alice)
	local amount, killed = c.Service:ApplyDamage(state, 100, bob)
	assert(amount == 4 and killed and not state.Model and not state.Alive)
	assert(#c.Deaths == 1 and #c.Credits == 2 and #c.Deaths[1].Contributors == 2)
	local actualUsers = {}
	for _, credit in c.Credits do actualUsers[credit.UserId] = true end
	assert(actualUsers[1] and actualUsers[2] and not actualUsers[3])
	assert(c.Deaths[1].SlotId == 1 and c.Deaths[1].Generation == 1)
	local duplicate = c.Service:ApplyDamage(state, 100, alice)
	assert(duplicate == 0 and #c.Deaths == 1 and #c.Credits == 2)
	c:Close()
end)

test("dead, absent, and no-longer-eligible contributors cannot receive encounter credit", function()
	for _, invalidate in {
		function(player) player.Humanoid.Health = 0 end,
		function(player) player.Zone = 2 end,
		function(player) player.Highest = 2 end,
		function(player) player.ValidPosition = false end,
		function(player) player.Loaded = false end,
	} do
		local c = context()
		local alice = c:AddPlayer(1, 1, Vector3.new(-30, 4, 46))
		local bob = c:AddPlayer(2, 1, Vector3.new(-28, 4, 46))
		c.Service:Step(0.15, { [1] = true })
		local state = c.Service:GetMonster("zone:01:slot:1")
		c.Service:ApplyDamage(state, 1, alice)
		invalidate(alice)
		c.Service:ApplyDamage(state, 100, bob)
		assert(#c.Credits == 1 and c.Credits[1].UserId == 2)
		c:Close()
	end
end)

test("respawn waits for its deadline then resets health, contributors and generation", function()
	local c = context()
	local alice = c:AddPlayer(1, 1, Vector3.new(-30, 4, 46))
	c.Service:Step(0.15, { [1] = true })
	local state = c.Service:GetMonster("zone:01:slot:1")
	c.Service:ApplyDamage(state, 5, alice)
	c.Service:Step(0.15, { [1] = true })
	assert(#c.Workspace.AetherMonsters:GetChildren() == 4 and not state.Alive)
	c.Now += configs.MonsterConfig.DefaultRespawnSeconds
	c.Service:Step(0.15, { [1] = true })
	assert(#c.Workspace.AetherMonsters:GetChildren() == 5 and state.Alive and state.HP == 5)
	assert(state.Generation == 2 and next(state.Contributors) == nil and #c.Deaths == 1)
	c:Close()
end)

test("monster melee respects startup timing, line of sight and synchronous access validation", function()
	local c = context()
	local player = c:AddPlayer(1, 1, Vector3.new(-30, 4, 46))
	c.Service:Step(0.15, { [1] = true })
	assert(player.Humanoid.DamageTaken == 0)
	c.Now += 1
	c.BlockedRay = true
	c.Service:Step(0.15, { [1] = true })
	assert(player.Humanoid.DamageTaken == 0)
	c.BlockedRay = false
	player.ValidPosition = false
	c.Service:Step(0.15, { [1] = true })
	assert(player.Humanoid.DamageTaken == 0)
	player.ValidPosition = true
	c.Service:Step(0.15, { [1] = true })
	assert(player.Humanoid.DamageTaken == configs.MonsterConfig.Get(1).AttackDamage)
	c.Service:Step(0.15, { [1] = true })
	assert(player.Humanoid.DamageTaken == configs.MonsterConfig.Get(1).AttackDamage)
	c:Close()
end)

test("server-controlled chase stays on the zone floor and obeys world blockers", function()
	local c = context()
	c:AddPlayer(1, 1, Vector3.new(-15, 12, 42))
	c.Service:Step(0.15, { [1] = true })
	local state = c.Service:GetMonster("zone:01:slot:1")
	assert(state.Position.Y == state.SpawnPosition.Y)
	assert(state.Position.X > state.SpawnPosition.X)
	assert(configs.DungeonConfig.GetZoneAt(state.Position) == state.ZoneId)
	local before = state.Position
	c.BlockedRay = true
	c.Service:Step(0.15, { [1] = true })
	assert(state.Position == before)
	c:Close()
end)

test("destroy cleans tagged models and allows one clean replacement service", function()
	local c = context()
	c.Service:Step(0.15, { [1] = true })
	assert(not pcall(c.MonsterService.new, {}, c.Progression, c.Damage, {}), "Duplicate service must not duplicate models")
	c.Service:Destroy()
	c.Service:Destroy()
	assert(not c.Workspace:FindFirstChild("AetherMonsters") and next(c.Tags) == nil)
	c.Service = c.MonsterService.new({}, c.Progression, c.Damage, {})
	c.Service:Step(0.15, { [1] = true })
	assert(#c.Workspace.AetherMonsters:GetChildren() == 5)
	c:Close()
end)

print(string.format("%d production monster lifecycle tests passed (engine boundaries stubbed)", passed))
