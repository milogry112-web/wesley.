--!strict
-- World coordinates: +Z is always forward. All walkable ground has its top at Y=0.
local Config = {}
Config.ZoneLength = 180
Config.ZoneWidth = 128
Config.ZoneCount = 30
Config.BossArenaEnd = 5570
Config.HubSpawn = Vector3.new(0, 5, -95)

-- Each recipe has a unique architecture/layout, not just a different palette.
-- id, title, environmental story, theme/recipe, layout, floor RGB, wall RGB, accent RGB, height
local records = {
	{ "Forgotten Entrance", "The old oath still guards these stones.", "Entrance", "Processional", {77,83,79}, {97,109,103}, {242,176,91}, 30 },
	{ "Mossy Catacombs", "Roots have found the names we forgot.", "Catacombs", "RootGalleries", {54,72,67}, {65,91,78}, {138,210,122}, 25 },
	{ "Goblin Hideout", "A stolen caravan became a crooked kingdom.", "Goblin", "RaiderCamp", {89,74,53}, {96,86,65}, {228,143,66}, 34 },
	{ "Ancient Crypt", "Five empty tombs. Five broken promises.", "Crypt", "SepulchralAisles", {78,74,89}, {103,100,116}, {188,169,229}, 38 },
	{ "Spider Nest", "The lanterns went out one by one.", "Spider", "SilkenGrotto", {59,57,68}, {76,68,83}, {163,204,156}, 28 },
	{ "Abandoned Mine", "The last cart never reached daylight.", "Mine", "RailJunction", {87,75,63}, {103,89,71}, {235,182,103}, 28 },
	{ "Rusty Machinery", "A sleeping engine remembers its makers.", "Machinery", "EngineTrench", {78,81,84}, {107,79,62}, {215,157,91}, 40 },
	{ "Underground River", "Follow the water beneath the mountain.", "River", "Aqueduct", {56,87,100}, {76,109,116}, {107,211,222}, 34 },
	{ "Fungal Cavern", "An entire sky grows beneath your feet.", "Fungal", "SporeGarden", {58,69,79}, {70,91,91}, {149,205,220}, 40 },
	{ "Crystal Mine", "Listen: every shard carries a note.", "Crystal", "PrismVault", {69,84,105}, {81,103,128}, {111,199,246}, 44 },
	{ "Forgotten Temple", "The circle awaits its missing sun.", "Temple", "RuneColonnade", {100,99,86}, {132,130,112}, {111,222,207}, 42 },
	{ "Overgrown Ruins", "Life has claimed the fallen watchtower.", "Ruins", "BrokenCourtyard", {81,96,78}, {104,119,93}, {175,211,120}, 32 },
	{ "Sandstone Tomb", "A golden river once ran through this hall.", "Sandstone", "SunkenObelisks", {156,126,83}, {187,154,102}, {249,209,116}, 42 },
	{ "Cursed Library", "Some stories refuse to end.", "Library", "ForbiddenStacks", {72,60,76}, {103,77,97}, {203,145,222}, 38 },
	{ "Ancient Sanctuary", "A quiet light survives the centuries.", "Sanctuary", "RadiantChoir", {128,126,109}, {170,165,142}, {246,221,158}, 50 },
	{ "Frost Cavern", "Footsteps fade beneath the blue silence.", "Frost", "GlacialCrevasse", {134,160,177}, {139,184,207}, {177,231,248}, 32 },
	{ "Frozen Fortress", "Winter still holds the northern wall.", "Fortress", "BattlementMarch", {101,130,153}, {133,165,184}, {150,219,243}, 44 },
	{ "Ice Palace", "A crown suspended in a frozen dawn.", "IcePalace", "MirrorCourt", {141,182,195}, {169,206,217}, {198,243,250}, 54 },
	{ "Storm Temple", "The bells ring without a wind.", "Storm", "ConductorHall", {70,83,110}, {89,106,140}, {136,192,251}, 50 },
	{ "Celestial Ruins", "Fragments of a sky that fell to earth.", "Celestial", "AstralOrbits", {91,92,119}, {128,127,155}, {234,214,161}, 60 },
	{ "Ashen Tunnels", "Here the mountain first learned to burn.", "Ash", "CinderGalleries", {61,58,57}, {80,72,68}, {220,148,106}, 30 },
	{ "Magma Forges", "The great hammers have gone silent.", "Magma", "FoundryBays", {78,63,59}, {97,74,62}, {242,164,89}, 48 },
	{ "Volcanic Core", "The heart of the mountain is awake.", "Volcanic", "ObsidianRift", {48,47,55}, {64,56,63}, {252,125,70}, 48 },
	{ "Infernal Citadel", "Stand before the banners of the ember court.", "Citadel", "EmberRamparts", {71,51,57}, {104,58,65}, {232,127,101}, 54 },
	{ "Lava Throne", "An empty throne. An unspent fury.", "Throne", "SovereignSteps", {81,59,61}, {115,73,67}, {251,178,95}, 60 },
	{ "Shadow Forest", "No sun has ever touched these leaves.", "Shadow", "TwistedGrove", {52,49,65}, {67,60,87}, {171,138,220}, 44 },
	{ "Haunted Castle", "The court dances on, unseen.", "Haunted", "GothicGallery", {67,68,83}, {87,85,112}, {164,209,217}, 56 },
	{ "Void Corridors", "The walls remember a different world.", "Void", "FracturedPassage", {40,43,62}, {62,66,94}, {153,147,244}, 48 },
	{ "Abyssal Palace", "Even the stars fall silent at these doors.", "Abyssal", "MonolithCourt", {49,47,66}, {80,70,105}, {191,148,233}, 64 },
	{ "Eternal Forge", "Bring the dawn back to the heart of creation.", "Eternal", "WorldheartBasilica", {76,69,85}, {110,99,129}, {249,208,131}, 72 },
}

Config.Zones = {}
for id, record in records do
	Config.Zones[id] = table.freeze({
		Id = id, Name = record[1], Subtitle = record[2], Theme = record[3], Layout = record[4],
		FloorColor = Color3.fromRGB(table.unpack(record[5])),
		WallColor = Color3.fromRGB(table.unpack(record[6])),
		AccentColor = Color3.fromRGB(table.unpack(record[7])), CeilingHeight = record[8],
	})
end
table.freeze(Config.Zones)

function Config.GetZoneAt(position: Vector3): number?
	if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z then return nil end
	if math.abs(position.X) > Config.ZoneWidth / 2 then return nil end
	if position.Z >= -185 and position.Z < 0 then return 0 end
	if position.Z < 0 or position.Z > Config.BossArenaEnd then return nil end
	return math.min(30, math.floor(position.Z / Config.ZoneLength) + 1)
end

function Config.GetSpawnPositions(id: number): {Vector3}
	assert(id % 1 == 0 and id >= 1 and id <= Config.ZoneCount, "Invalid zone ID")
	local z = (id - 1) * Config.ZoneLength
	return {
		Vector3.new(-30, 4, z + 42), Vector3.new(30, 4, z + 62),
		Vector3.new(-30, 4, z + 92), Vector3.new(30, 4, z + 112), Vector3.new(0, 4, z + 142),
	}
end

function Config.GetSafeCFrame(id: number): CFrame
	local position = if id == 0 then Config.HubSpawn else Vector3.new(0, 5, (id - 1) * Config.ZoneLength + 12)
	return CFrame.lookAt(position, position + Vector3.new(0, 0, 1))
end

return table.freeze(Config)
