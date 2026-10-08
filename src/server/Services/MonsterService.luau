--!strict
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("AetherDungeon"):WaitForChild("Shared")
local DungeonConfig = require(Shared:WaitForChild("DungeonConfig"))
local MonsterConfig = require(Shared:WaitForChild("MonsterConfig"))
local MonsterHealthService = require(script.Parent:WaitForChild("MonsterHealthService"))

local MonsterService = {}
MonsterService.__index = MonsterService

local UP = Vector3.new(0, 1, 0)
local ZERO = Vector3.zero

local function createPart(model: Model, name: string, size: Vector3, transform: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = transform
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = name == "Body" or name == "Head"
	part.CastShadow = material ~= Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	end
	part.Parent = model
	return part
end

local function strut(model: Model, name: string, a: Vector3, b: Vector3, color: Color3)
	return createPart(model, name, Vector3.new(0.42, (a - b).Magnitude, 0.42),
		CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(math.pi / 2, 0, 0), color, Enum.Material.Slate)
end

local function makeModel(state: any): Model
	local zone = DungeonConfig.Zones[state.ZoneId]
	local accent: Color3 = zone.AccentColor
	local stone = accent:Lerp(Color3.fromRGB(42, 47, 60), 0.72)
	local trim = accent:Lerp(Color3.fromRGB(175, 171, 161), 0.52)
	local model = Instance.new("Model")
	model.Name = state.Config.Name
	local at = CFrame.new(state.Position)
	local root = createPart(model, "Root", Vector3.new(2, 2, 2), at, stone, Enum.Material.SmoothPlastic)
	root.Transparency = 1
	root.CastShadow = false
	model.PrimaryPart = root
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local zoneId = state.ZoneId
	if zoneId == 5 then
		createPart(model, "Body", Vector3.new(4.8, 2.8, 5.3), at, stone, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		createPart(model, "Head", Vector3.new(2.8, 2.1, 2.5), at * CFrame.new(0, 0.15, -2.7), trim, Enum.Material.Slate, Enum.PartType.Ball)
		for side = -1, 1, 2 do
			for leg = 1, 4 do
				local start = state.Position + Vector3.new(side * 1.6, -0.15, (leg - 2.5) * 1.2)
				local joint = state.Position + Vector3.new(side * 4.2, 0.1, (leg - 2.5) * 1.8)
				local foot = state.Position + Vector3.new(side * 5, -3.1, (leg - 2.5) * 2)
				strut(model, "LegUpper", start, joint, stone)
				strut(model, "LegLower", joint, foot, trim)
			end
			createPart(model, "Eye", Vector3.new(0.7, 0.7, 0.4), at * CFrame.new(side * 0.7, 0.55, -3.8), accent, Enum.Material.Neon, Enum.PartType.Ball)
		end
	elseif zoneId == 9 then
		createPart(model, "Body", Vector3.new(4.2, 3, 3), at * CFrame.Angles(0, 0, math.pi / 2), trim, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		createPart(model, "Head", Vector3.new(6.6, 2.2, 6.6), at * CFrame.new(0, 2.8, 0), accent:Lerp(stone, 0.3), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		createPart(model, "CapUnderside", Vector3.new(0.35, 5.8, 5.8), at * CFrame.new(0, 2.3, 0) * CFrame.Angles(0, 0, math.pi / 2), trim, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		for side = -1, 1, 2 do
			createPart(model, "Foot", Vector3.new(1.6, 1.1, 2), at * CFrame.new(side * 1.1, -2.5, -0.3), stone, Enum.Material.SmoothPlastic)
			createPart(model, "Eye", Vector3.new(0.45, 0.65, 0.25), at * CFrame.new(side * 0.62, 0.6, -1.45), accent, Enum.Material.Neon)
			createPart(model, "Spore", Vector3.new(1.3, 0.4, 1.3), at * CFrame.new(side * 1.6, 3.7, -0.6), trim, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	else
		local isGoblin = zoneId == 3
		local bodyColor = if isGoblin then Color3.fromRGB(99, 129, 70) else stone
		local bodyMaterial = if zoneId >= 16 and zoneId <= 18 then Enum.Material.Ice else Enum.Material.Slate
		createPart(model, "Body", Vector3.new(3.8, 3.8, 2.6), at, bodyColor, bodyMaterial)
		createPart(model, "Chestplate", Vector3.new(3.2, 2.2, 0.5), at * CFrame.new(0, 0.3, -1.5), trim, Enum.Material.Metal)
		createPart(model, "Core", Vector3.new(0.75, 1.4, 0.25), at * CFrame.new(0, 0.4, -1.82), accent, Enum.Material.Neon)
		createPart(model, "Head", Vector3.new(2.6, 2.25, 2.5), at * CFrame.new(0, 2.9, 0), bodyColor, bodyMaterial)
		createPart(model, "Brow", Vector3.new(3.1, 0.5, 2.8), at * CFrame.new(0, 3.7, 0), trim, Enum.Material.Slate)
		for side = -1, 1, 2 do
			createPart(model, "Shoulder", Vector3.new(1.6, 1.6, 2.5), at * CFrame.new(side * 2.55, 1.1, 0) * CFrame.Angles(0, 0, side * -0.14), trim, Enum.Material.Slate)
			createPart(model, "Arm", Vector3.new(1.35, 2.1, 1.5), at * CFrame.new(side * 2.5, -0.75, 0), bodyColor, bodyMaterial)
			createPart(model, "Foot", Vector3.new(1.6, 1.2, 2.25), at * CFrame.new(side * 1.02, -2.65, -0.35), trim, Enum.Material.Slate)
			createPart(model, "Eye", Vector3.new(0.7, 0.35, 0.18), at * CFrame.new(side * 0.65, 3, -1.32), accent, Enum.Material.Neon)
		end
		if isGoblin then
			for side = -1, 1, 2 do
				createPart(model, "Ear", Vector3.new(1.35, 0.75, 0.65), at * CFrame.new(side * 1.8, 3, 0) * CFrame.Angles(0, 0, side * 0.35), bodyColor, Enum.Material.SmoothPlastic)
			end
		elseif zoneId >= 16 and zoneId <= 20 then
			for side = -1, 1, 2 do
				createPart(model, "CrystalSpire", Vector3.new(0.8, 3.8, 0.8), at * CFrame.new(side * 2.1, 2.6, 0.5) * CFrame.Angles(0.2, 0, side * -0.45), accent, Enum.Material.Glass)
			end
		elseif zoneId >= 21 and zoneId <= 25 then
			createPart(model, "ForgeCrown", Vector3.new(3.7, 0.6, 3.3), at * CFrame.new(0, 4.3, 0), stone, Enum.Material.Metal)
			for side = -1, 1, 2 do
				createPart(model, "FurnaceVent", Vector3.new(0.28, 1.65, 1.6), at * CFrame.new(side * 1.94, -0.15, 0), accent, Enum.Material.Neon)
			end
		elseif zoneId >= 26 then
			for crown = 1, 3 do
				createPart(model, "VoidCrown", Vector3.new(0.6, 1.6 + (crown % 2) * 0.7, 0.7), at * CFrame.new((crown - 2) * 1.15, 4.75, 0), accent:Lerp(stone, 0.3), Enum.Material.Glass)
			end
		elseif zoneId == 6 or zoneId == 7 then
			createPart(model, "Helmet", Vector3.new(3, 0.65, 2.9), at * CFrame.new(0, 4.15, 0), Color3.fromRGB(132, 96, 61), Enum.Material.CorrodedMetal)
			createPart(model, "HelmetLamp", Vector3.new(0.8, 0.8, 0.3), at * CFrame.new(0, 4.05, -1.6), accent, Enum.Material.Neon, Enum.PartType.Ball)
		end
	end

	model:SetAttribute("MonsterId", state.Id)
	model:SetAttribute("ZoneId", state.ZoneId)
	model:SetAttribute("SlotId", state.SlotId)
	model:SetAttribute("HP", state.HP)
	model:SetAttribute("MaxHP", state.MaxHP)
	model:SetAttribute("DisplayName", state.Config.Name)
	return model
end

local function getLivingRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root, humanoid
	end
	return nil, nil
end

function MonsterService.new(world: any, progression: any, damage: any, remotes: any)
	assert(not Workspace:FindFirstChild("AetherMonsters"), "MonsterService is already running; destroy it before restarting")
	local folder = Instance.new("Folder")
	folder.Name = "AetherMonsters"
	folder.Parent = Workspace
	local died = Instance.new("BindableEvent")
	died.Name = "MonsterDied"
	local self: any = setmetatable({
		_world = world,
		_progression = progression,
		_damage = damage,
		_remotes = remotes,
		_folder = folder,
		_health = MonsterHealthService.new(),
		_states = {},
		_zones = {},
		_destroyed = false,
		MonsterDied = died,
	}, MonsterService)

	-- State tables are cheap; models/AI exist only for occupied zones. A sleeping
	-- encounter retains HP and per-slot identity instead of granting free resets.
	for zoneId = 1, DungeonConfig.ZoneCount do
		local positions = DungeonConfig.GetSpawnPositions(zoneId)
		assert(#positions == 5, "Every zone requires exactly five regular monster slots")
		local states = {}
		for slotId, position in positions do
			local config = MonsterConfig.Get(zoneId)
			local id = string.format("zone:%02d:slot:%d", zoneId, slotId)
			local state = {
				Id = id,
				ZoneId = zoneId,
				SlotId = slotId,
				Config = config,
				MaxHP = config.MaxHP,
				HP = config.MaxHP,
				Alive = true,
				Active = false,
				Contributors = {},
				Position = position,
				SpawnPosition = position,
				Model = nil,
				NextAttackAt = 0,
				RespawnAt = 0,
				Generation = 1,
			}
			self._states[id] = state
			table.insert(states, state)
		end
		self._zones[zoneId] = states
	end
	self._leavingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		for _, state in self._states do
			state.Contributors[player.UserId] = nil
		end
	end)
	damage:SetMonsterService(self)
	return self
end

function MonsterService:GetMonster(monsterId: string): any
	return self._states[monsterId]
end

function MonsterService:GetStates(): { [string]: any }
	return self._states
end

function MonsterService:_spawn(state: any)
	state.Position = state.SpawnPosition
	state.NextAttackAt = os.clock() + 0.9
	local model = makeModel(state)
	state.Model = model
	model.Parent = self._folder
	CollectionService:AddTag(model, "AetherMonster")
end

function MonsterService:_removeModel(state: any)
	if state.Model then
		CollectionService:RemoveTag(state.Model, "AetherMonster")
		state.Model:Destroy()
		state.Model = nil
	end
end

function MonsterService:ApplyDamage(state: any, amount: number, attacker: Player): (number, boolean)
	if self._destroyed or self._states[state.Id] ~= state or not state.Active then
		return 0, false
	end
	local applied, killed = self._health:ApplyDamage(state, amount, attacker)
	if not killed then
		return applied, false
	end

	-- ApplyDamage marks Alive=false before any external hook; another hit cannot
	-- duplicate this death. Only actual living contributors at this frontier earn
	-- encounter credit. RegisterKill additionally deduplicates the five slot IDs.
	state.RespawnAt = os.clock() + state.Config.RespawnSeconds
	local eligibleContributors = {}
	for userId, contribution in state.Contributors do
		local player = Players:GetPlayerByUserId(userId)
		if not player or contribution <= 0 or not self._progression:IsLoaded(player) then
			continue
		end
		local root = getLivingRoot(player)
		if root and self._progression:ValidatePosition(player)
			and self._progression:GetCurrentZone(player) == state.ZoneId
			and self._progression:GetHighest(player) == state.ZoneId then
			table.insert(eligibleContributors, { UserId = userId, Damage = contribution })
			local ok, reason = pcall(function()
				self._progression:RegisterKill(player, state.ZoneId, state.SlotId)
			end)
			if not ok then
				warn("[AetherDungeon] Encounter credit failed: " .. tostring(reason))
			end
		end
	end
	self.MonsterDied:Fire({
		MonsterId = state.Id,
		ZoneId = state.ZoneId,
		SlotId = state.SlotId,
		Generation = state.Generation,
		Position = state.Position,
		MaxHP = state.MaxHP,
		Contributors = eligibleContributors,
		KillerUserId = attacker.UserId,
	})
	self:_removeModel(state)
	return applied, true
end

function MonsterService:_move(state: any, direction: Vector3, dt: number, exclusions: { Instance })
	local horizontal = Vector3.new(direction.X, 0, direction.Z)
	local distance = horizontal.Magnitude
	if distance < 0.15 then
		return
	end
	local step = math.min(state.Config.MoveSpeed * dt, distance)
	local unit = horizontal.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions
	params.RespectCanCollide = true
	local offset = unit * step
	if Workspace:Raycast(state.Position + UP, unit * (step + 2), params) then
		-- A small perpendicular slide handles pillars without an expensive
		-- PathfindingService request for every creature on every scheduler tick.
		local side = Vector3.new(-unit.Z, 0, unit.X) * (if state.SlotId % 2 == 0 then 1 else -1)
		offset = side * step
		if Workspace:Raycast(state.Position + UP, side * (step + 2), params) then
			return
		end
	end
	local nextPosition = state.Position + offset
	if DungeonConfig.GetZoneAt(nextPosition) ~= state.ZoneId then
		return
	end
	state.Position = nextPosition
	if state.Model then
		state.Model:PivotTo(CFrame.lookAt(nextPosition, nextPosition + unit))
	end
end

function MonsterService:_stepMonster(state: any, candidates: { Player }, dt: number, now: number, exclusions: { Instance })
	local target: Player? = nil
	local targetRoot: BasePart? = nil
	local targetHumanoid: Humanoid? = nil
	local nearest = state.Config.AggroDistance
	for _, player in candidates do
		local root, humanoid = getLivingRoot(player)
		if root then
			local distance = (root.Position - state.Position).Magnitude
			if distance < nearest and (root.Position - state.SpawnPosition).Magnitude < state.Config.AggroDistance * 1.8 then
				nearest = distance
				target = player
				targetRoot = root
				targetHumanoid = humanoid
			end
		end
	end
	if not target or not targetRoot or not targetHumanoid then
		self:_move(state, state.SpawnPosition - state.Position, dt, exclusions)
		return
	end
	if nearest > state.Config.AttackRange then
		local toTarget = targetRoot.Position - state.Position
		local horizontal = Vector3.new(toTarget.X, 0, toTarget.Z)
		if horizontal.Magnitude > 0 then
			local approach = horizontal.Unit * math.max(0, horizontal.Magnitude - state.Config.AttackRange * 0.8)
			self:_move(state, approach, dt, exclusions)
		end
	elseif now >= state.NextAttackAt then
		-- Revalidate access synchronously at attack time, just like player damage.
		if not self._progression:ValidatePosition(target) or self._progression:GetCurrentZone(target) ~= state.ZoneId then
			return
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = exclusions
		params.RespectCanCollide = true
		local origin = state.Position + UP
		if Workspace:Raycast(origin, targetRoot.Position + UP - origin, params) then
			return
		end
		state.NextAttackAt = now + state.Config.AttackCooldown
		-- Deliberately modest player damage; it never scales with monster MaxHP.
		targetHumanoid:TakeDamage(state.Config.AttackDamage)
	end
end

-- Called by ONE shared server scheduler, normally every 0.15 seconds. No
-- per-monster connections, coroutines, or per-frame idle animation loops.
function MonsterService:Step(dt: number, activeZones: { [number]: boolean })
	if self._destroyed then
		return
	end
	local now = os.clock()
	local boundedDt = math.clamp(dt, 0, 0.4)
	local playersByZone: { [number]: { Player } } = {}
	local exclusions: { Instance } = { self._folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclusions, player.Character)
		end
		if self._progression:IsLoaded(player) then
			local zoneId = self._progression:GetCurrentZone(player)
			if zoneId and activeZones[zoneId] and zoneId <= self._progression:GetHighest(player) then
				if not playersByZone[zoneId] then
					playersByZone[zoneId] = {}
				end
				table.insert(playersByZone[zoneId], player)
			end
		end
	end

	for zoneId, states in self._zones do
		local active = activeZones[zoneId] == true
		for _, state in states do
			state.Active = active
			if not active then
				self:_removeModel(state)
				continue
			end
			if not state.Alive then
				if now < state.RespawnAt then
					continue
				end
				self._health:Reset(state)
				state.Generation += 1
			end
			if not state.Model then
				self:_spawn(state)
			end
			self:_stepMonster(state, playersByZone[zoneId] or {}, boundedDt, now, exclusions)
		end
	end
end

function MonsterService:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._leavingConnection:Disconnect()
	for _, state in self._states do
		self:_removeModel(state)
	end
	self.MonsterDied:Destroy()
	self._folder:Destroy()
	table.clear(self._states)
	table.clear(self._zones)
end

return MonsterService
