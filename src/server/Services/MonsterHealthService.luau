--!strict
-- Authoritative health is a Luau double, never Humanoid.Health. At the top of
-- the progression small sub-ULP hits cannot change HP; applied damage is always
-- the representable change, so an ineffective hit never earns contribution.
local MonsterHealthService = {}
MonsterHealthService.__index = MonsterHealthService

export type HealthState = {
	HP: number,
	MaxHP: number,
	Alive: boolean,
	Contributors: { [number]: number },
	Model: Model?,
}

local function positiveFinite(value: any): boolean
	return typeof(value) == "number" and value > 0 and value < math.huge and value == value
end

function MonsterHealthService.new()
	return setmetatable({}, MonsterHealthService)
end

function MonsterHealthService:Reset(state: HealthState)
	assert(positiveFinite(state.MaxHP), "Monster MaxHP must be positive and finite")
	state.HP = state.MaxHP
	state.Alive = true
	state.Contributors = {}
	if state.Model then
		state.Model:SetAttribute("HP", state.HP)
		state.Model:SetAttribute("MaxHP", state.MaxHP)
	end
end

function MonsterHealthService:ApplyDamage(state: HealthState, amount: number, contributor: Player?): (number, boolean)
	if not state.Alive or not positiveFinite(amount) then
		return 0, false
	end

	local oldHP = state.HP
	local newHP = if amount >= oldHP then 0 else math.max(0, oldHP - amount)
	local applied = oldHP - newHP
	if applied <= 0 then
		return 0, false
	end

	state.HP = newHP
	state.Alive = newHP > 0
	if contributor then
		local userId = contributor.UserId
		state.Contributors[userId] = math.min(state.MaxHP, (state.Contributors[userId] or 0) + applied)
	end
	if state.Model then
		state.Model:SetAttribute("HP", newHP)
	end
	return applied, not state.Alive
end

return MonsterHealthService
