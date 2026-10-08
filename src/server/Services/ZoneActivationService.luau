--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("AetherDungeon"):WaitForChild("Shared")
local DungeonConfig = require(Shared:WaitForChild("DungeonConfig"))
local MonsterConfig = require(Shared:WaitForChild("MonsterConfig"))

local ZoneActivationService = {}
ZoneActivationService.__index = ZoneActivationService

-- Retain a zone briefly through short exits, death, and streaming transitions.
-- Activity is the union of every eligible player's occupied zone.
local INACTIVITY_GRACE_SECONDS = MonsterConfig.ActivationGraceSeconds

function ZoneActivationService.new(progression: any)
	local self: any = setmetatable({
		_progression = progression,
		_lastOccupied = {},
		_active = {},
		_destroyed = false,
	}, ZoneActivationService)
	return self
end

function ZoneActivationService:Step(_dt: number): { [number]: boolean }
	if self._destroyed then
		return {}
	end
	local now = os.clock()
	local progression = self._progression
	for _, player in Players:GetPlayers() do
		if not progression:IsLoaded(player) or not progression:ValidatePosition(player) then
			continue
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local zoneId = progression:GetCurrentZone(player)
		if humanoid and humanoid.Health > 0 and zoneId and zoneId >= 1 and zoneId <= DungeonConfig.ZoneCount
			and zoneId <= progression:GetHighest(player) then
			self._lastOccupied[zoneId] = now
		end
	end
	table.clear(self._active)
	for zoneId, occupiedAt in self._lastOccupied do
		if now - occupiedAt <= INACTIVITY_GRACE_SECONDS then
			self._active[zoneId] = true
		else
			self._lastOccupied[zoneId] = nil
		end
	end
	return self._active
end

function ZoneActivationService:Destroy()
	self._destroyed = true
	table.clear(self._active)
	table.clear(self._lastOccupied)
end

return ZoneActivationService
