--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local packageRoot = ReplicatedStorage:WaitForChild("AetherDungeon")
local Shared = packageRoot:WaitForChild("Shared")
local DungeonConfig = require(Shared:WaitForChild("DungeonConfig"))
local MonsterConfig = require(Shared:WaitForChild("MonsterConfig"))
local Services = script.Parent:WaitForChild("Services")
local WorldGenerator = require(script.Parent.World.WorldGenerator)
local ProgressionDataService = require(Services.ProgressionDataService)
local ProgressionService = require(Services.ProgressionService)
local DamageService = require(Services.DamageService)
local MonsterService = require(Services.MonsterService)
local ZoneActivationService = require(Services.ZoneActivationService)
local Runtime = require(script.Parent.Runtime)

local function ensure(parent: Instance, className: string, name: string): any
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA(className), name .. " has the wrong class")
		return existing
	end
	local object = Instance.new(className)
	object.Name = name
	object.Parent = parent
	return object
end

local remotesFolder = ensure(packageRoot, "Folder", "Remotes")
local remotes: any = {}
for _, name in { "Attack", "State", "Notify", "RequestState", "DamageFeedback" } do
	remotes[name] = ensure(remotesFolder, "RemoteEvent", name)
end

-- Wait for solid spawn ground before the first character is loaded.
local autoLoads = Players.CharacterAutoLoads
Players.CharacterAutoLoads = false
local ok, result = xpcall(function()
	return WorldGenerator.Generate(DungeonConfig)
end, debug.traceback)
if not ok then
	Players.CharacterAutoLoads = autoLoads
	error("Eternal Forge world generation failed: " .. tostring(result))
end
local world = result

local data = ProgressionDataService.new()
local progression = ProgressionService.new(remotes, data)
local damage = DamageService.new(progression, remotes)
local monsters = MonsterService.new(world, progression, damage, remotes)
damage:SetMonsterService(monsters)
local activation = ZoneActivationService.new(progression)

local joining: {[Player]: boolean} = {}
local requestTimes: {[Player]: number} = {}
local characterConnections: {[Player]: {RBXScriptConnection}} = {}
local loadingCharacters: {[Player]: boolean} = {}
local connections = {}
local closed = false
-- Own both initial spawning and death respawning. Keeping engine auto-spawning
-- disabled prevents an automatic load racing an explicit LoadCharacterAsync.
local function loadCharacter(player: Player)
	if closed or player.Parent ~= Players or loadingCharacters[player] then return end
	loadingCharacters[player] = true
	task.spawn(function()
		for attempt = 1, 3 do
			if closed or player.Parent ~= Players then break end
			local loaded, failure = pcall(function() player:LoadCharacterAsync() end)
			if loaded then break end
			warn("[Eternal Forge] Character load failed: " .. tostring(failure))
			if attempt < 3 then task.wait(2) end
		end
		loadingCharacters[player] = nil
	end)
end
local function watchCharacter(player: Player, character: Model)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		local owned = characterConnections[player]
		if not owned or not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= character then return end
		if owned[2] then owned[2]:Disconnect() end
		owned[2] = humanoid.Died:Once(function()
			task.delay(Players.RespawnTime, function()
				if joining[player] and (player.Character == character or player.Character == nil) then
					loadCharacter(player)
				end
			end)
		end)
	end)
end
local function addPlayer(player: Player)
	if joining[player] then return end
	joining[player] = true
	progression:AddPlayer(player)
	characterConnections[player] = { player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end) }
	if player.Character then watchCharacter(player, player.Character) else loadCharacter(player) end
end
table.insert(connections, Players.PlayerAdded:Connect(addPlayer))
table.insert(connections, Players.PlayerRemoving:Connect(function(player)
	requestTimes[player] = nil
	joining[player] = nil
	local owned = characterConnections[player]
	if owned then for _, connection in owned do connection:Disconnect() end end
	characterConnections[player] = nil
	progression:RemovePlayer(player)
end))
table.insert(connections, remotes.RequestState.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (requestTimes[player] or -math.huge) < 1 then return end
	requestTimes[player] = now
	progression:PushState(player)
end))
for _, player in Players:GetPlayers() do addPlayer(player) end

-- ONE shared simulation scheduler; no loop/Heartbeat per enemy or static prop.
-- Time budget never catches up a lag spike with an unbounded burst of ticks.
local elapsed = 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
	if closed then return end
	elapsed += dt
	if elapsed < MonsterConfig.AITick then return end
	local step = math.min(elapsed, 0.4)
	elapsed = 0
	progression:Step(step)
	local active = activation:Step(step)
	monsters:Step(step, active)
end))

Runtime.Register({
	World = world,
	Progression = progression,
	Data = data,
	Damage = damage,
	Monsters = monsters,
	Activation = activation,
})

-- Data service owns its bounded BindToClose save flush. Stop simulation here.
game:BindToClose(function()
	closed = true
	for _, connection in connections do connection:Disconnect() end
	for _, owned in characterConnections do
		for _, connection in owned do connection:Disconnect() end
	end
	damage:Destroy()
	activation:Destroy()
	monsters:Destroy()
end)

print("[Eternal Forge] Ready: 30 connected zones; five slots per active zone; server-authoritative training combat.")
