-- Executes the production static generators using Lune's Roblox instance model.
-- No rendering/physics is simulated. Random is a deterministic test substitute;
-- Roblox's own seeded Random takes over when Bootstrap rebuilds during Play.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

return function(place)
	local document = place or roblox.Instance.new("DataModel")
	local function service(class)
		local found = document:FindFirstChildOfClass(class)
		if found then return found end
		local item = roblox.Instance.new(class)
		item.Name = class
		item.Parent = document
		return item
	end
	local workspace, lighting = service("Workspace"), service("Lighting")
	local env = table.clone(roblox)
	local modules = {}
	local cache = {}
	for _, name in { "DecorationGenerator", "SpawnHubGenerator", "DungeonZoneGenerator", "LightingController", "WorldGenerator" } do
		modules[name] = "src/server/World/" .. name .. ".luau"
	end
	local tags = {}
	env.game = { GetService = function(_, name)
		if name == "Workspace" then return workspace end
		if name == "Lighting" then return lighting end
		if name == "CollectionService" then return { AddTag = function(_, object, tag)
			object:AddTag(tag)
			tags[object] = tag
		end } end
		error("Unhandled service: " .. name)
	end }
	env.workspace = workspace
	env.task = { wait = function() return 0 end }
	env.Random = { new = function(seed)
		local value = seed or 1
		local rng = {}
		function rng:NextNumber(low, high)
			value = (value * 48271) % 2147483647
			local fraction = value / 2147483647
			return (low or 0) + fraction * ((high or 1) - (low or 0))
		end
		function rng:NextInteger(low, high)
			return math.floor(self:NextNumber(low, high + 1))
		end
		return rng
	end }
	env.require = function(path)
		if cache[path] then return cache[path] end
		local moduleEnv = table.clone(env)
		moduleEnv.script = { Parent = modules }
		local value = luau.load(fs.readFile(path), { environment = moduleEnv, debugName = path })()
		cache[path] = value
		return value
	end
	local config = env.require("src/shared/DungeonConfig.luau")
	local generator = env.require(modules.WorldGenerator)
	return { Document = document, Workspace = workspace, Lighting = lighting, Config = config,
		Generate = function() return generator.Generate(config) end }
end
