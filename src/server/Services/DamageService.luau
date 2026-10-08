--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("AetherDungeon"):WaitForChild("Shared")
local DungeonConfig = require(Shared:WaitForChild("DungeonConfig"))
local MonsterConfig = require(Shared:WaitForChild("MonsterConfig"))

local DamageService = {}
DamageService.__index = DamageService

export type WeaponStats = {
	Damage: number,
	Cooldown: number,
	Range: number,
	CritChance: number?,
	CritMultiplier: number?,
}

local function positiveFinite(value: any): boolean
	return typeof(value) == "number" and value > 0 and value < math.huge and value == value
end

local function finitePosition(position: Vector3): boolean
	return position.X == position.X and math.abs(position.X) < math.huge
		and position.Y == position.Y and math.abs(position.Y) < math.huge
		and position.Z == position.Z and math.abs(position.Z) < math.huge
end

function DamageService.new(progression: any, remotes: any)
	local self: any = setmetatable({
		_progression = progression,
		_remotes = remotes,
		_monsters = nil,
		_nextAttack = {},
		_nextRequest = {},
		_rng = Random.new(),
		_destroyed = false,
		_weaponProvider = nil,
	}, DamageService)

	-- This is an explicit temporary training weapon, not an inventory system.
	-- Server-owned progression sets its power so every frontier is testable.
	self._weaponProvider = function(player: Player, _monster: any): WeaponStats
		local highest = math.clamp(progression:GetHighest(player), 1, DungeonConfig.ZoneCount)
		return {
			Damage = MonsterConfig.Get(highest).MaxHP * 0.34,
			Cooldown = 0.65,
			Range = 16,
			CritChance = 0,
			CritMultiplier = 1,
		}
	end
	self._attackConnection = remotes.Attack.OnServerEvent:Connect(function(player: Player, targetId: any)
		self:Attack(player, targetId)
	end)
	self._leavingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		self._nextAttack[player.UserId] = nil
		self._nextRequest[player.UserId] = nil
	end)
	return self
end

function DamageService:SetMonsterService(monsters: any)
	self._monsters = monsters
end

-- Only server scripts can install a provider. Read server inventory/upgrade
-- records here; a client must never choose these values or a weapon definition.
function DamageService:SetWeaponProvider(provider: (Player, any) -> WeaponStats)
	assert(typeof(provider) == "function", "Expected a server weapon provider")
	self._weaponProvider = provider
end

function DamageService:Attack(player: Player, targetId: any): boolean
	if self._destroyed or not self._monsters or player.Parent ~= Players then
		return false
	end
	if typeof(targetId) ~= "string" or #targetId > 80 then
		return false
	end

	local now = os.clock()
	local userId = player.UserId
	if now < (self._nextRequest[userId] or 0) or now < (self._nextAttack[userId] or 0) then
		return false
	end
	-- Rate-limit invalid targets as well as accepted strikes before expensive work.
	self._nextRequest[userId] = now + 0.08

	local progression = self._progression
	if not progression:IsLoaded(player) or not progression:ValidatePosition(player) then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false
	end
	if not finitePosition(root.Position) then
		return false
	end

	local monster = self._monsters:GetMonster(targetId)
	if not monster or not monster.Alive or not monster.Active or not monster.Model or not monster.Model.Parent then
		return false
	end
	if progression:GetCurrentZone(player) ~= monster.ZoneId or progression:GetHighest(player) < monster.ZoneId then
		return false
	end

	local ok, weapon = pcall(self._weaponProvider, player, monster)
	if not ok or typeof(weapon) ~= "table" or not positiveFinite(weapon.Damage)
		or not positiveFinite(weapon.Cooldown) or not positiveFinite(weapon.Range) then
		return false
	end
	if (root.Position - monster.Position).Magnitude > weapon.Range then
		return false
	end

	local origin = root.Position + Vector3.new(0, 1, 0)
	local targetPosition = monster.Position + Vector3.new(0, 1, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character, monster.Model }
	raycastParams.RespectCanCollide = true
	if Workspace:Raycast(origin, targetPosition - origin, raycastParams) then
		return false
	end

	local amount = weapon.Damage
	local critical = false
	local chance = weapon.CritChance or 0
	local multiplier = weapon.CritMultiplier or 1
	if typeof(chance) ~= "number" or chance ~= chance or chance < 0 or chance > 1
		or not positiveFinite(multiplier) then
		return false
	end
	if chance > 0 and self._rng:NextNumber() < chance then
		amount *= multiplier
		critical = true
	end
	if not positiveFinite(amount) then
		return false
	end

	-- There is deliberately no low damage cap: future Qa/Qi weapons stay valid.
	self._nextAttack[userId] = now + weapon.Cooldown
	local applied, killed = self._monsters:ApplyDamage(monster, amount, player)
	if applied <= 0 then
		return false
	end
	if self._remotes.DamageFeedback then
		self._remotes.DamageFeedback:FireClient(player, {
			MonsterId = monster.Id,
			Position = targetPosition,
			Amount = applied,
			Killed = killed,
			Critical = critical,
		})
	end
	return true
end

function DamageService:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._attackConnection:Disconnect()
	self._leavingConnection:Disconnect()
	table.clear(self._nextAttack)
	table.clear(self._nextRequest)
	self._monsters = nil
end

return DamageService
