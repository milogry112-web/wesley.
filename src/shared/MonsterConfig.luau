--!strict
-- Single source of truth. These are NUMBER values, using English short scale.
-- Luau uses IEEE-754 doubles: values/damage above 2^53 do not have unit precision.
-- 800Qa = 8e17 = 800,000,000,000,000,000 (NOT 800Qi).
local MonsterConfig = {}

MonsterConfig.HP = table.freeze({
	5, 20, 100, 500, 2e3, 1e5,
	1e6, 5e6, 2e7, 1e8, 5e8, 9e8,
	1e9, 5e9, 2e10, 1e11, 5e11, 9e11,
	1e12, 5e12, 2e13, 1e14, 5e14, 9e14,
	1e15, 5e15, 2e16, 1e17, 4e17, 8e17,
})

local names = {
	"Oathbound Sentinel", "Rootbound Revenant", "Scrapfang Raider", "Sepulchral Guard", "Silkfang Stalker",
	"Deepdelve Golem", "Corroded Automaton", "Riverstone Warden", "Sporecap Shambler", "Prismback Guardian",
	"Runebound Custodian", "Bloomfallen Knight", "Gilded Scarab", "Inkbound Specter", "Sanctuary Protector",
	"Rimeclaw Beast", "Frostguard Captain", "Diamondice Construct", "Thundercoil Sentinel", "Starfallen Watcher",
	"Cinderveil Wanderer", "Crucible Construct", "Obsidian Ravager", "Ember Legionnaire", "Thronefire Guardian",
	"Duskroot Horror", "Hollowcourt Specter", "Voidglass Stalker", "Abyssal Custodian", "Eternal Forgekeeper",
}

MonsterConfig.SlotsPerZone = 5
MonsterConfig.AITick = 0.15
MonsterConfig.ActivationGraceSeconds = 12
MonsterConfig.DefaultRespawnSeconds = 12

function MonsterConfig.Get(id: number)
	assert(id % 1 == 0 and id >= 1 and id <= #MonsterConfig.HP, "Invalid dungeon ID")
	return {
		MaxHP = MonsterConfig.HP[id],
		Name = names[id],
		MoveSpeed = 8 + math.min(id, 20) * 0.12,
		AggroDistance = 38,
		AttackRange = 6,
		AttackDamage = 7 + math.floor(id / 4),
		AttackCooldown = 1.5,
		RespawnSeconds = MonsterConfig.DefaultRespawnSeconds,
	}
end

return table.freeze(MonsterConfig)
