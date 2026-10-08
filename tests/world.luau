-- Real generated Roblox instance geometry under Lune; no rendered visual claim.
local roblox = require("@lune/roblox")
local fixture = require("../tools/world-fixture")()
local config = fixture.Config
local world = fixture.Generate()
local passed = 0
local function test(name, callback)
	local ok, failure = pcall(callback)
	assert(ok, name .. ": " .. tostring(failure))
	passed += 1
	print("PASS: " .. name)
end

test("thirty authored zones and exactly 150 regular spawn markers generate", function()
	assert(#world.Zones:GetChildren() == 30)
	local themes, layouts = {}, {}
	for id = 1, 30 do
		local zone = world.Zones:FindFirstChild(string.format("Zone%02d", id))
		assert(zone and zone:GetAttribute("ZoneId") == id)
		assert(#zone.Spawns:GetChildren() == 5)
		assert(not themes[zone:GetAttribute("Theme")] and not layouts[zone:GetAttribute("Layout")])
		themes[zone:GetAttribute("Theme")] = true
		layouts[zone:GetAttribute("Layout")] = true
		for slot, position in config.GetSpawnPositions(id) do
			local marker = zone.Spawns:FindFirstChild(tostring(slot))
			assert((marker.CFrame.Position - position).Magnitude < 0.001)
			assert(marker:GetAttribute("SlotId") == slot and not marker.CanCollide)
		end
	end
end)

local solids = {}
for _, part in world.Root:GetDescendants() do
	if part:IsA("BasePart") and part.CanCollide then table.insert(solids, part) end
end

local function intersectsBox(part, position, radius, halfHeight)
	local localPoint = part.CFrame:PointToObjectSpace(position)
	-- Generated collidable floors/walls are axis-aligned (hub floors turn only90deg).
	return math.abs(localPoint.X) < part.Size.X / 2 + radius
		and math.abs(localPoint.Z) < part.Size.Z / 2 + radius
		and math.abs(localPoint.Y) < part.Size.Y / 2 + halfHeight
end

test("continuous walkable floor reaches all30zones and the final arena", function()
	for z = -95, config.BossArenaEnd - 5, 3 do
		local position = roblox.Vector3.new(0, 3.3, z)
		local supported = false
		for _, part in solids do
			assert(not intersectsBox(part, position, 1.5, 2.8), "Path blocked by " .. part.Name .. " at Z=" .. z)
			if intersectsBox(part, roblox.Vector3.new(0, -0.1, z), 0, 0) then supported = true end
		end
		assert(supported, "Missing ground at Z=" .. z)
	end
end)

test("all encounter markers have clear reachable crosswise access", function()
	for id = 1, 30 do
		for _, position in config.GetSpawnPositions(id) do
			for x = math.min(0, position.X), math.max(0, position.X), 3 do
				for _, part in solids do
					assert(not intersectsBox(part, roblox.Vector3.new(x, 3.3, position.Z), 1.5, 2.8), "Blocked spawn route in zone " .. id)
				end
			end
		end
	end
end)

test("gates stay noncolliding and tagged for independent local presentation", function()
	for _, zone in world.Zones:GetChildren() do
		local gate = zone.ExitGate
		assert(gate:GetAttribute("ZoneId") == zone:GetAttribute("ZoneId"))
		assert(gate:HasTag("AetherGate"))
		assert(gate.Barrier:GetAttribute("GateBarrier") and not gate.Barrier.CanCollide)
	end
end)

test("static geometry is anchored with limited lights and no active decoration scripts", function()
	local parts, lights, particles = 0, 0, 0
	for _, object in world.Root:GetDescendants() do
		if object:IsA("BasePart") then
			parts += 1
			assert(object.Anchored and not object.CanTouch)
			if not object.CanCollide then assert(not object.CanQuery) end
		elseif object:IsA("Light") then lights += 1
		elseif object:IsA("ParticleEmitter") then particles += 1
		end
		assert(not object:IsA("BaseScript"), "Static world contains an active script")
	end
	assert(parts < 12000, "Exceeded12k static part budget")
	assert(lights <= 16, "Exceeded16 real lights")
	assert(particles <= 6, "Exceeded6 particle emitters")
	print(string.format("WORLD BUDGET: %d anchored parts, %d lights, %d emitters", parts, lights, particles))
end)

test("hub spawn and final boss reserve are accessible and correctly classified", function()
	assert(config.GetZoneAt(config.HubSpawn) == 0)
	assert(config.GetZoneAt(roblox.Vector3.new(0, 5, 5520)) == 30)
	assert(world.Root.FutureBossArena:GetAttribute("ReservedForFutureBoss") == true)
	assert(world.Root:FindFirstChild("DawnrestSpawn"):IsA("SpawnLocation"))
	assert(config.GetZoneAt(roblox.Vector3.new(500, 0, 900)) == nil)
end)

test("rerunning world generation replaces only owned geometry without duplicates", function()
	local foreign = roblox.Instance.new("Model")
	foreign.Name = "KeepUserAssets"
	foreign.Parent = fixture.Workspace
	local previousCount = #world.Root:GetDescendants()
	local effects = #fixture.Lighting:GetChildren()
	local nextWorld = fixture.Generate()
	assert(#nextWorld.Root:GetDescendants() == previousCount)
	assert(#fixture.Lighting:GetChildren() == effects)
	assert(foreign.Parent == fixture.Workspace)
	local roots = 0
	for _, child in fixture.Workspace:GetChildren() do
		if child.Name == "AetherWorld" then roots += 1 end
	end
	assert(roots == 1)
end)

print(string.format("%d actual-generator geometry tests passed (no Roblox physics/rendering)", passed))
