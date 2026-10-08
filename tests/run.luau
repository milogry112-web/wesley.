-- Tests execute the production modules with the official Luau VM.
-- No Roblox engine, DataStore, rendering, networking, or physics is simulated here.
local Health = require("../src/server/Services/MonsterHealthService")
local Monsters = require("../src/shared/MonsterConfig")
local Numbers = require("../src/shared/NumberFormatter")
local Progression = require("../src/shared/ProgressionRules")

local passed = 0
local function test(name: string, callback: () -> ())
	local ok, message = pcall(callback)
	assert(ok, name .. ": " .. tostring(message))
	passed += 1
	print("PASS: " .. name)
end

local function state(maxHP: number)
	local value = { HP = 0, MaxHP = maxHP, Alive = false, Contributors = {} }
	Health.new():Reset(value)
	return value
end

test("server health reset restores a full encounter", function()
	local monster = state(20)
	assert(monster.HP == 20 and monster.Alive and next(monster.Contributors) == nil)
end)

test("damage clamps to remaining health and credits only applied damage", function()
	local monster = state(20)
	local health = Health.new()
	local first, firstDeath = health:ApplyDamage(monster, 7, { UserId = 101 })
	local last, lastDeath = health:ApplyDamage(monster, 100, { UserId = 202 })
	assert(first == 7 and not firstDeath)
	assert(last == 13 and lastDeath and monster.HP == 0 and not monster.Alive)
	assert(monster.Contributors[101] == 7 and monster.Contributors[202] == 13)
end)

test("a dead encounter cannot emit another death or award contribution", function()
	local monster = state(5)
	local health = Health.new()
	health:ApplyDamage(monster, 5, { UserId = 1 })
	local applied, killed = health:ApplyDamage(monster, 5, { UserId = 2 })
	assert(applied == 0 and not killed and monster.Contributors[2] == nil)
end)

test("nonfinite and nonpositive damage cannot corrupt monster health", function()
	local health = Health.new()
	for _, damage in { 0, -1, math.huge, -math.huge, 0 / 0 } do
		local monster = state(100)
		local applied, killed = health:ApplyDamage(monster, damage, { UserId = 1 })
		assert(applied == 0 and not killed and monster.HP == 100)
		assert(next(monster.Contributors) == nil)
	end
end)

test("invalid maximum health is rejected when creating an encounter", function()
	for _, maxHP in { 0, -1, math.huge, 0 / 0 } do
		assert(not pcall(state, maxHP))
	end
end)

test("800Qa health accepts meaningful quadrillion-scale server damage", function()
	local monster = state(800e15)
	local applied, killed = Health.new():ApplyDamage(monster, 200e15, { UserId = 1 })
	assert(applied == 200e15 and monster.HP == 600e15 and not killed)
end)

test("sub-ULP hits at 800Qa award no phantom damage or contribution", function()
	local monster = state(800e15)
	local applied, killed = Health.new():ApplyDamage(monster, 1, { UserId = 1 })
	assert(applied == 0 and not killed and monster.HP == 800e15)
	assert(next(monster.Contributors) == nil)
end)

test("respawning clears old contributors", function()
	local monster = state(100)
	local health = Health.new()
	health:ApplyDamage(monster, 100, { UserId = 1 })
	health:Reset(monster)
	assert(monster.Alive and monster.HP == 100 and next(monster.Contributors) == nil)
end)

test("all thirty monster HP values match the design specification", function()
	local expected = {
		5, 20, 100, 500, 2000, 100000,
		1000000, 5000000, 20000000, 100000000, 500000000, 900000000,
		1000000000, 5000000000, 20000000000, 100000000000, 500000000000, 900000000000,
		1000000000000, 5000000000000, 20000000000000, 100000000000000, 500000000000000, 900000000000000,
		1000000000000000, 5000000000000000, 20000000000000000, 100000000000000000, 400000000000000000, 800000000000000000,
	}
	assert(#Monsters.HP == 30 and Monsters.SlotsPerZone == 5)
	for id, hp in expected do
		assert(type(Monsters.HP[id]) == "number" and Monsters.HP[id] == hp, "Wrong HP in zone " .. id)
		assert(Monsters.Get(id).MaxHP == hp)
	end
end)

test("monster settings reject nonexisting or fractional zones", function()
	for _, id in { 0, -1, 1.5, 31, math.huge, 0 / 0 } do
		assert(not pcall(Monsters.Get, id))
	end
end)

test("short-scale display includes Qa and Qi without confusing magnitude", function()
	local cases = {
		{ 0, "0" }, { 5, "5" }, { 1000, "1K" }, { 1500, "1.5K" }, { -1500, "-1.5K" },
		{ 1e6, "1M" }, { 1e9, "1B" }, { 1e12, "1T" }, { 1e15, "1Qa" },
		{ 800e15, "800Qa" }, { 1e18, "1Qi" }, { 999960, "1M" },
	}
	for _, case in cases do
		assert(Numbers.Format(case[1]) == case[2], tostring(case[1]))
	end
	assert(Numbers.Format(math.huge) == "—" and Numbers.Format(0 / 0) == "—")
end)

test("health bar ratio handles huge values and invalid inputs safely", function()
	assert(Numbers.Ratio(400e15, 800e15) == 0.5)
	assert(Numbers.Ratio(-10, 100) == 0 and Numbers.Ratio(200, 100) == 1)
	assert(Numbers.Ratio(5, 0) == 0 and Numbers.Ratio(0 / 0, 5) == 0)
	assert(Numbers.Ratio(math.huge, 5) == 0)
end)

test("five unique frontier slots unlock exactly the next zone", function()
	local encounter = Progression.NewEncounter()
	for slot = 1, 5 do
		local highest, completed, changed = Progression.RecordKill(encounter, 1, slot, 1, false)
		assert(changed and not completed)
		assert(highest == (if slot == 5 then 2 else 1))
		assert(Progression.Count(encounter) == slot)
	end
end)

test("repeat kills cannot replace the other four required encounter slots", function()
	local encounter = Progression.NewEncounter()
	Progression.RecordKill(encounter, 1, 1, 1, false)
	for _ = 1, 20 do
		local highest, _, changed = Progression.RecordKill(encounter, 1, 1, 1, false)
		assert(highest == 1 and not changed)
	end
	assert(Progression.Count(encounter) == 1)
end)

test("kills in old or locked zones cannot advance the frontier", function()
	local encounter = Progression.NewEncounter()
	for _, zone in { 1, 3, 30 } do
		local highest, _, changed = Progression.RecordKill(encounter, zone, 1, 2, false)
		assert(highest == 2 and not changed)
	end
	for _, slot in { 0, -1, 1.5, 6, math.huge, 0 / 0 } do
		local _, _, changed = Progression.RecordKill(encounter, 2, slot, 2, false)
		assert(not changed)
	end
	assert(Progression.Count(encounter) == 0)
end)

test("players keep independent encounter progress", function()
	local alice, bob = Progression.NewEncounter(), Progression.NewEncounter()
	for slot = 1, 5 do Progression.RecordKill(alice, 1, slot, 1, false) end
	assert(Progression.Count(alice) == 5 and Progression.Count(bob) == 0)
	local highest = Progression.RecordKill(bob, 1, 1, 1, false)
	assert(highest == 1 and Progression.Count(bob) == 1)
end)

test("a full thirty-zone journey completes without unlocking zone thirty-one", function()
	local highest, completed = 1, false
	for zone = 1, 30 do
		local encounter = Progression.NewEncounter()
		for slot = 1, 5 do
			highest, completed = Progression.RecordKill(encounter, zone, slot, highest, completed)
		end
		assert(highest == math.min(zone + 1, 30))
		assert(completed == (zone == 30))
	end
	local encounter = Progression.NewEncounter()
	local newHighest, stillComplete, changed = Progression.RecordKill(encounter, 30, 1, highest, completed)
	assert(newHighest == 30 and stillComplete and not changed and Progression.Count(encounter) == 0)
end)

assert(passed > 0, "Refusing a zero-test pass")
print(string.format("%d production-module tests passed", passed))
