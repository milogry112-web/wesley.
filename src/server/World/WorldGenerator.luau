--!strict
local Workspace = game:GetService("Workspace")
local Hub = require(script.Parent.SpawnHubGenerator)
local Zones = require(script.Parent.DungeonZoneGenerator)
local LightingController = require(script.Parent.LightingController)

local WorldGenerator = {}
local OWNED = "GeneratedByEternalForge"

function WorldGenerator.Generate(config: any)
	local previous = Workspace:FindFirstChild("AetherWorld")
	assert(not previous or previous:GetAttribute(OWNED) == true,
		"An unrelated AetherWorld already exists; refusing to replace user content")
	local root = Instance.new("Model")
	root.Name = "AetherWorld"
	root:SetAttribute(OWNED, true)
	root:SetAttribute("GeneratorVersion", 1)
	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = root
	-- Assemble off-tree. Failure keeps the previous generated world intact.
	local ok, failure = xpcall(function()
		Hub.Generate(config, root)
		for id = 1, config.ZoneCount do
			Zones.Generate(config, zones, id)
			if id % 3 == 0 then task.wait() end
		end
		Zones.GenerateBossReserve(config, root)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "DawnrestSpawn"
		spawn.Size = Vector3.new(12, 0.2, 12)
		spawn.CFrame = CFrame.new(config.HubSpawn.X, 0.15, config.HubSpawn.Z)
		spawn.Anchored = true
		spawn.CanCollide = false
		spawn.CanTouch = false
		spawn.CanQuery = false
		spawn.Transparency = 1
		spawn.Neutral = true
		spawn.Duration = 2
		spawn.Parent = root
	end, debug.traceback)
	if not ok then
		root:Destroy()
		error(failure)
	end
	local count = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then count += 1 end
	end
	root:SetAttribute("StaticPartCount", count)
	root:SetAttribute("ZoneCount", config.ZoneCount)
	if previous then previous:Destroy() end
	root.Parent = Workspace
	LightingController.Apply()
	return { Root = root, Zones = zones, Spawn = config.GetSafeCFrame(0), PartCount = count }
end

return WorldGenerator
