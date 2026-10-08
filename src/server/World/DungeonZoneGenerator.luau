--!nonstrict
-- Thirty authored compositions, assembled deterministically from small reusable assets.
-- Positive Z is always forward. The central 24 studs and all encounter pads stay clear.
local CollectionService = game:GetService("CollectionService")
local D = require(script.Parent.DecorationGenerator)
local Generator = {}
local Builders = {}

local STONE = Enum.Material.Slate
local METAL = Enum.Material.Metal
local WOOD = Enum.Material.WoodPlanks
local NEON = Enum.Material.Neon

local function point(c, x, y, z)
	return Vector3.new(x, y, c.Start + z)
end

local function block(c, name, x, y, z, sx, sy, sz, color, material, rotation)
	return D.Part(c.Props, name, Vector3.new(sx, sy, sz), CFrame.new(point(c, x, y, z)) * (rotation or CFrame.identity), color or c.Wall, material or STONE)
end

local function beam(c, name, a, b, width, color, material)
	return D.Beam(c.Props, name, point(c, a.X, a.Y, a.Z), point(c, b.X, b.Y, b.Z), width, color or c.Wall, material)
end

local function sidePairs(callback)
	for _, side in {-1, 1} do callback(side) end
end

local function columns(c, locations, height, style)
	for _, z in locations do
		sidePairs(function(side)
			D.Column(c.Props, point(c, side * 51, 0, z), height, c.Wall, c.Accent, style)
		end)
	end
end

local function cave(c, count, color)
	for index = 1, count do
		local z = 15 + (index - 1) / math.max(1, count - 1) * 145
		sidePairs(function(side)
			local height = c.Rng:NextNumber(8, 17)
			D.Rock(c.Props, point(c, side * 57, 0, z), height, color or c.Wall, c.Rng)
			D.Wedge(c.Props, "CeilingTooth", Vector3.new(6, height * .7, 7), CFrame.new(point(c, side * c.Rng:NextNumber(33, 51), c.Height - height * .25, z)) * CFrame.Angles(math.pi, index, 0), color or c.Wall)
		end)
	end
end

local function wallRunes(c, zs)
	for _, z in zs do
		sidePairs(function(side)
			D.Rune(c.Props, point(c, side * 53, 11, z), 3.8, c.Accent)
		end)
	end
end

local function tomb(c, x, z)
	block(c, "SarcophagusBase", x, 1.1, z, 12, 2.2, 8, c.Wall)
	block(c, "CarvedSarcophagus", x, 3.2, z, 10.2, 2, 6.5, c.Wall:Lerp(c.Accent, .1))
	block(c, "TombLid", x, 4.4, z, 11.2, .8, 7.2, c.Wall:Lerp(Color3.new(1, 1, 1), .1))
	D.Cylinder(c.Props, "RecumbentEffigy", 2.3, 5, CFrame.new(point(c, x, 5.6, z)) * CFrame.Angles(math.pi / 2, 0, 0), c.Wall, Enum.Material.Marble)
	D.Rune(c.Props, point(c, x, 3.1, z - 3.31), 1.2, c.Accent)
end

local function candles(c, x, z)
	for index = 1, 3 do
		local h = 1.7 + index * .6
		D.Cylinder(c.Props, "WaxCandle", .65, h, CFrame.new(point(c, x + index - 2, h / 2 + .3, z)), Color3.fromRGB(222, 208, 163))
		D.Ball(c.Props, "CandleFlame", Vector3.new(.42, .8, .42), point(c, x + index - 2, h + .5, z), c.Accent, NEON)
	end
end

local function statue(c, x, z, height)
	local stone = c.Wall:Lerp(Color3.new(1, 1, 1), .12)
	block(c, "StatuePedestal", x, 1.3, z, 10, 2.6, 10, c.Wall)
	D.Wedge(c.Props, "RobedGuardian", Vector3.new(7, height * .65, 6), CFrame.new(point(c, x, height * .35 + 2, z)), stone, Enum.Material.Marble)
	D.Ball(c.Props, "GuardianHead", Vector3.one * 3.5, point(c, x, height * .86 + 2, z), stone, Enum.Material.Marble)
	beam(c, "CeremonialStaff", Vector3.new(x + 4, 2, z), Vector3.new(x + 4, height + 4, z), .7, c.Accent, METAL)
	D.Crystal(c.Props, point(c, x + 4, height + 4, z), 1.5, c.Accent)
end

local function pipe(c, x, z, length, radius)
	D.Cylinder(c.Props, "PressurePipe", radius * 2, length, CFrame.new(point(c, x, 10, z)) * CFrame.Angles(math.pi / 2, 0, 0), c.Wall:Lerp(Color3.fromRGB(127, 81, 53), .5), METAL)
	for _, offset in {-length * .4, 0, length * .4} do
		D.Cylinder(c.Props, "PipeCollar", radius * 2.3, .9, CFrame.new(point(c, x, 10, z + offset)) * CFrame.Angles(math.pi / 2, 0, 0), c.Accent:Lerp(c.Wall, .7), METAL)
	end
end

local function gear(c, x, y, z, radius)
	local frame = CFrame.new(point(c, x, y, z)) * CFrame.Angles(math.pi / 2, 0, 0)
	D.Cylinder(c.Props, "GearWheel", radius * 1.7, 1.3, frame, c.Wall:Lerp(c.Accent, .2), METAL)
	D.Cylinder(c.Props, "Axle", radius * .4, 2, frame, c.Accent, METAL)
	for index = 1, 10 do
		local theta = index * math.pi / 5
		block(c, "GearTooth", x + math.cos(theta) * radius, y + math.sin(theta) * radius, z, radius * .55, radius * .36, 1.5, c.Wall:Lerp(c.Accent, .2), METAL, CFrame.Angles(0, 0, theta))
	end
end

local function lavaChannel(c, x, z, width, length, color)
	block(c, "SunkenChannel", x, .018, z, width + 2, .025, length + 2, Color3.fromRGB(24, 23, 29))
	block(c, "LuminousFlow", x, .039, z, width, .02, length, color or c.Accent, NEON)
	for _, edge in {-1, 1} do
		block(c, "ChannelCoping", x + edge * (width / 2 + 1), .35, z, 1.2, .7, length, c.Wall)
	end
end

local function anvil(c, x, z, size)
	block(c, "AnvilFoot", x, 1.2, z, size * .85, 2.4, size * .65, c.Wall, METAL)
	block(c, "AnvilWaist", x, size * .38, z, size * .46, size * .55, size * .4, Color3.fromRGB(50, 53, 62), METAL)
	block(c, "AnvilFace", x, size * .72, z, size, size * .22, size * .65, Color3.fromRGB(103, 106, 113), METAL)
	D.Wedge(c.Props, "AnvilHorn", Vector3.new(size * .5, size * .2, size * .5), CFrame.new(point(c, x + size * .68, size * .71, z)) * CFrame.Angles(0, -math.pi / 2, 0), Color3.fromRGB(103, 106, 113), METAL)
end

local function bookcase(c, x, z, height)
	local frame = block(c, "LibraryBack", x, height / 2, z, 13, height, 2, Color3.fromRGB(72, 46, 47), WOOD)
	for row = 0, 3 do
		block(c, "OakShelf", x, 1 + row * height / 4, z - 2, 13, .6, 4, Color3.fromRGB(109, 73, 57), WOOD)
		if row < 3 then
			for book = 1, 6 do
				local h = height / 4 - c.Rng:NextNumber(1, 2)
				local color = Color3.fromHSV((book * .12 + row * .2) % 1, .43, .47)
				block(c, "BoundTome", x - 5.5 + book * 1.7, 1.4 + row * height / 4 + h / 2, z - 2, 1.35, h, 2.8, color, Enum.Material.SmoothPlastic)
			end
		end
	end
	return frame
end

-- 01: processional masonry, fallen outer columns, hanging vines and warm sconces.
Builders[1] = function(c)
	for _, z in {25, 94, 156} do
		D.Arch(c.Props, point(c, 0, 0, z), 105, 21, 9, c.Wall, c.Accent)
	end
	for index = 1, 6 do
		sidePairs(function(side)
			local z = 16 + index * 23
			block(c, "AncientWallInlay", side * 61, 7, z, 1.1, 11, 16, c.Wall:Lerp(Color3.new(0, 0, 0), .2))
			beam(c, "HangingVine", Vector3.new(side * 59, 22, z), Vector3.new(side * 56, 9, z + 4), .55, Color3.fromRGB(66, 94, 57), Enum.Material.Grass)
			D.Torch(c.Props, point(c, side * 53, 7, z + 5), Color3.fromRGB(255, 169, 79))
		end)
	end
	D.Column(c.Props, point(c, -50, 0, 62), 8, c.Wall, c.Accent)
	D.Rock(c.Props, point(c, 50, 0, 125), 8, c.Wall, c.Rng)
end

-- 02: low burial galleries, roots breaking through ceiling, damp floor mosaics.
Builders[2] = function(c)
	for _, z in {30, 76, 124, 156} do
		sidePairs(function(side)
			block(c, "BurialNiche", side * 58, 8, z, 8, 13, 21, c.Wall:Lerp(Color3.new(0, 0, 0), .45))
			for row = 1, 3 do
				block(c, "NicheShelf", side * 53, row * 4, z, 10, 1, 22, c.Wall)
				block(c, "MossShelf", side * 50, row * 4 + .55, z, 4, .13, 18, Color3.fromRGB(66, 105, 60), Enum.Material.Grass)
			end
			D.Tree(c.Props, point(c, side * 57, 0, z + 9), 22, c.Accent, true)
			local pool = D.Cylinder(c.Props, "StillWater", 16, .07, CFrame.new(point(c, side * 47, .06, z - 12)), Color3.fromRGB(54, 106, 99), Enum.Material.Glass)
			pool.Transparency = .3
		end)
	end
	for _, z in {50, 111} do
		beam(c, "CrossingRoots", Vector3.new(-60, c.Height - 4, z), Vector3.new(60, c.Height - 1, z + 19), 2.8, Color3.fromRGB(72, 60, 47), Enum.Material.Wood)
	end
end

-- 03: encampment, sloped canvas shelters, raided supply piles and barricades.
Builders[3] = function(c)
	for index, z in {38, 87, 139} do
		sidePairs(function(side)
			local x = side * 51
			D.Wedge(c.Props, "CanvasLeanTo", Vector3.new(17, 13, 19), CFrame.new(point(c, x, 6.5, z)) * CFrame.Angles(0, side * math.pi / 2, 0), Color3.fromRGB(132 + index * 12, 111, 67), Enum.Material.Fabric)
			for stake = -2, 2 do
				block(c, "SharpenedPalisade", side * 42, 3, z + stake * 3.5, .8, 6, .8, Color3.fromRGB(95, 67, 47), WOOD, CFrame.Angles(0, 0, side * .15))
			end
			D.Crate(c.Props, point(c, side * 47, 0, z + 15), 4.5)
			D.Ball(c.Props, "StolenGold", Vector3.new(5, 1.8, 4), point(c, side * 55, .8, z + 14), Color3.fromRGB(216, 172, 67), METAL)
		end)
	end
end

-- 04: alternating tomb courts and guardian monuments, candle-lined walls.
Builders[4] = function(c)
	columns(c, {21, 83, 153}, 24, "round")
	for _, z in {49, 111, 139} do
		sidePairs(function(side)
			tomb(c, side * 50, z)
			candles(c, side * 44, z - 7)
		end)
	end
	statue(c, -51, 25, 16)
	statue(c, 51, 83, 16)
end

-- 05: webbed cave hollows, hanging silk cocoons and radial wall webs.
Builders[5] = function(c)
	cave(c, 5)
	for _, z in {35, 84, 134} do
		sidePairs(function(side)
			D.Ball(c.Props, "SilkCocoon", Vector3.new(5, 9, 5), point(c, side * 48, 11, z), Color3.fromRGB(180, 184, 177), Enum.Material.Fabric)
			beam(c, "SuspensionSilk", Vector3.new(side * 48, 15, z), Vector3.new(side * 50, c.Height, z), .12, Color3.fromRGB(198, 204, 203))
			local center = Vector3.new(side * 57, 13, z + 14)
			for ray = 1, 7 do
				local angle = ray * 2 * math.pi / 7
				beam(c, "WebSpoke", center, center + Vector3.new(0, math.sin(angle) * 10, math.cos(angle) * 11), .12, Color3.fromRGB(171, 180, 185))
				local nextAngle = (ray + 1) * 2 * math.pi / 7
				for radius = 1, 2 do
					beam(c, "WebRing", center + Vector3.new(0, math.sin(angle) * radius * 4, math.cos(angle) * radius * 4), center + Vector3.new(0, math.sin(nextAngle) * radius * 4, math.cos(nextAngle) * radius * 4), .1, Color3.fromRGB(171, 180, 185))
				end
			end
		end)
	end
end

-- 06: mine supports, twin side tracks, ore carts and exposed seams.
Builders[6] = function(c)
	for _, z in {22, 68, 114, 159} do
		sidePairs(function(side)
			block(c, "MinePost", side * 55, 12, z, 3.5, 24, 3.5, Color3.fromRGB(111, 79, 49), WOOD)
			beam(c, "DiagonalShore", Vector3.new(side * 55, 17, z), Vector3.new(side * 39, 25, z), 2.8, Color3.fromRGB(111, 79, 49), WOOD)
		end)
		block(c, "CrossTimber", 0, 26, z, 114, 3, 4, Color3.fromRGB(111, 79, 49), WOOD)
	end
	sidePairs(function(side)
		for _, x in {45, 51} do block(c, "Rail", side * x, .3, 89, .45, .6, 158, Color3.fromRGB(98, 105, 112), METAL) end
		for z = 16, 162, 8 do block(c, "RailSleeper", side * 48, .12, z, 10, .24, 1, Color3.fromRGB(82, 59, 43), WOOD) end
		block(c, "OreCart", side * 48, 3.7, side == -1 and 49 or 128, 8, 5, 11, c.Wall, METAL)
		D.Rock(c.Props, point(c, side * 48, 6, side == -1 and 49 or 128), 5, c.Accent:Lerp(c.Wall, .5), c.Rng)
		for _, z in {36, 94, 147} do D.Crystal(c.Props, point(c, side * 58, 0, z), 3.5, c.Accent) end
	end)
end

-- 07: colossal geared machinery, overhead piping and broken workshop gantries.
Builders[7] = function(c)
	sidePairs(function(side)
		pipe(c, side * 57, 88, 147, 2)
		for index, z in {40, 91, 142} do
			gear(c, side * 50, 12 + index % 2 * 6, z, 8)
			block(c, "MachinePlinth", side * 50, 2, z, 16, 4, 13, c.Wall, METAL)
			block(c, "ControlConsole", side * 45, 5, z - 10, 5, 4, 4, Color3.fromRGB(69, 75, 73), METAL)
			block(c, "GaugeGlow", side * 45, 6, z - 12.1, 2, 1, .12, c.Accent, NEON)
		end
	end)
	for _, z in {64, 121} do block(c, "ServiceGantry", 0, 26, z, 111, 1.5, 9, c.Wall, METAL) end
end

-- 08: a stone causeway through a broad subterranean river with tiny bank gardens.
Builders[8] = function(c)
	local water = block(c, "UndergroundRiver", 0, .02, 90, 120, .035, 158, Color3.fromRGB(32, 109, 132), Enum.Material.Glass)
	water.Transparency = .32
	block(c, "DryCauseway", 0, .05, 90, 25, .08, 170, c.Floor, Enum.Material.Cobblestone)
	for _, z in {42, 92, 142} do block(c, "RiverCrossing", 0, .06, z, 118, .08, 19, c.Floor, Enum.Material.Cobblestone) end
	for _, z in {22, 67, 119, 164} do
		sidePairs(function(side)
			block(c, "BridgePost", side * 15, 1.8, z, 2.2, 3.6, 2.2, c.Wall)
			D.Rock(c.Props, point(c, side * 56, 0, z), 7, c.Wall, c.Rng)
			D.Mushroom(c.Props, point(c, side * 48, 0, z), 5, c.Accent)
		end)
	end
	D.Arch(c.Props, point(c, 0, 0, 87), 108, 22, 9, c.Wall, c.Accent)
end

-- 09: tall umbrella fungi, mycelium beds and suspended luminous spores.
Builders[9] = function(c)
	cave(c, 3)
	for index = 1, 7 do
		sidePairs(function(side)
			local z = 15 + index * 20
			D.Mushroom(c.Props, point(c, side * (48 + index % 2 * 8), 0, z), 11 + index % 3 * 5, index % 2 == 0 and c.Accent or Color3.fromRGB(115, 96, 168))
			D.Mushroom(c.Props, point(c, side * 43, 0, z - 5), 3 + index % 3, Color3.fromRGB(81, 162, 148))
		end)
	end
	for index = 1, 8 do D.Ball(c.Props, "DriftingSpore", Vector3.one * .3, point(c, c.Rng:NextNumber(-54, 54), c.Rng:NextNumber(8, 21), index * 20), c.Accent, NEON) end
end

-- 10: crystal geodes and faceted roof clusters, contrasting dark extraction bays.
Builders[10] = function(c)
	cave(c, 4, c.Wall:Lerp(Color3.new(0, 0, 0), .12))
	for _, z in {26, 67, 114, 151} do
		sidePairs(function(side)
			D.Crystal(c.Props, point(c, side * 51, 0, z), 10 + z % 3, c.Accent)
			D.Crystal(c.Props, point(c, side * 43, 0, z + 8), 4.2, c.Accent:Lerp(Color3.fromRGB(161, 132, 230), .5))
		end)
	end
	block(c, "CrystalHangingSill", 0, c.Height - 3, 96, 105, 3, 8, c.Wall)
	for x = -36, 36, 12 do D.Wedge(c.Props, "PendantCrystal", Vector3.new(4, 9, 5), CFrame.new(point(c, x, c.Height - 7, 96)) * CFrame.Angles(math.pi, .6, 0), c.Accent, Enum.Material.Glass) end
end

-- 11: ceremonial colonnade, engraved obelisks and a broken astronomical altar.
Builders[11] = function(c)
	columns(c, {25, 66, 107, 149}, 27, "round")
	wallRunes(c, {45, 86, 127})
	sidePairs(function(side)
		block(c, "TempleEntablature", side * 51, 28, 87, 8, 3, 140, c.Wall)
		block(c, "Obelisk", side * 45, 9, 134, 4, 18, 4, c.Wall:Lerp(c.Accent, .15))
		D.Wedge(c.Props, "ObeliskCap", Vector3.new(4, 4, 4), CFrame.new(point(c, side * 45, 20, 134)), c.Accent, METAL)
	end)
end

-- 12: open-looking ruin arcade and lush trees growing through shattered roofs.
Builders[12] = function(c)
	for index, z in {24, 70, 118, 153} do
		sidePairs(function(side)
			D.Column(c.Props, point(c, side * 54, 0, z), index % 2 == 0 and 9 or 22, c.Wall, c.Accent)
			D.Tree(c.Props, point(c, side * 49, 0, z + 12), 18 + index * 2, Color3.fromRGB(74, 128, 64))
			D.Rock(c.Props, point(c, side * 45, 0, z - 7), 5, c.Wall, c.Rng)
			block(c, "GardenMoss", side * 52, .04, z, 19, .06, 30, Color3.fromRGB(64, 103, 57), Enum.Material.Grass)
		end)
	end
	beam(c, "BrokenLintel", Vector3.new(-57, 22, 26), Vector3.new(-20, 26, 26), 4, c.Wall)
	beam(c, "BrokenLintel", Vector3.new(57, 22, 118), Vector3.new(23, 27, 118), 4, c.Wall)
end

-- 13: stepped sandstone tomb towers, gold bands and tiny dune pockets.
Builders[13] = function(c)
	for _, z in {37, 96, 148} do
		sidePairs(function(side)
			for level = 1, 4 do block(c, "SteppedTomb", side * 52, level * 3 - 1.5, z, 22 - level * 3, 3, 25 - level * 3, c.Wall:Lerp(c.Accent, level * .025), Enum.Material.Sandstone) end
			D.Rune(c.Props, point(c, side * 52, 6, z - 8.1), 2.4, c.Accent)
			D.Ball(c.Props, "DriftedSand", Vector3.new(21, 2, 15), point(c, side * 51, .1, z + 14), c.Floor:Lerp(c.Accent, .25), Enum.Material.Sand)
		end)
	end
	D.Arch(c.Props, point(c, 0, 0, 90), 109, 22, 6, c.Wall, c.Accent)
end

-- 14: staggered library stacks, elevated reading gallery and frozen spell tomes.
Builders[14] = function(c)
	for _, z in {26, 60, 98, 140} do
		sidePairs(function(side)
			bookcase(c, side * 51, z, 18)
			local floating = block(c, "SuspendedSpellbook", side * 42, 10, z + 8, 3, .7, 4, Color3.fromRGB(113, 62, 129), Enum.Material.SmoothPlastic, CFrame.Angles(.18, .4, .2))
			D.Part(c.Props, "GlowingPages", Vector3.new(2.7, .45, 3.7), floating.CFrame * CFrame.new(0, .42, 0), c.Accent:Lerp(Color3.new(1, 1, 1), .45), NEON)
		end)
	end
	for _, side in {-1, 1} do block(c, "ReadingBalcony", side * 49, 21, 89, 21, 1, 146, Color3.fromRGB(91, 58, 49), WOOD) end
	block(c, "GalleryCrosswalk", 0, 23, 88, 114, 1, 11, Color3.fromRGB(91, 58, 49), WOOD)
end

-- 15: radiating sun sanctuary, white marble guardians and warm gold details.
Builders[15] = function(c)
	columns(c, {30, 81, 139}, 29, "round")
	statue(c, -50, 57, 19)
	statue(c, 50, 114, 19)
	for _, z in {29, 80, 137} do
		local ring = D.Cylinder(c.Props, "SunMedallion", 24, .08, CFrame.new(point(c, 0, .035, z)), c.Accent, METAL)
		D.Cylinder(c.Props, "MedallionCenter", 21, .09, ring.CFrame * CFrame.Angles(0, 0, -math.pi / 2), c.Floor, Enum.Material.Marble)
	end
	sidePairs(function(side) for _, z in {42, 103, 151} do candles(c, side * 43, z) end end)
	D.Arch(c.Props, point(c, 0, 0, 150), 110, 25, 11, c.Wall, c.Accent)
end

-- 16: snow drifts, icicles and leaning ice sheets around a dark dry trail.
Builders[16] = function(c)
	cave(c, 5, Color3.fromRGB(132, 166, 183))
	for index, z in {26, 63, 105, 144} do
		sidePairs(function(side)
			D.Ball(c.Props, "SnowDrift", Vector3.new(23, 5, 24), point(c, side * 52, 0, z), Color3.fromRGB(213, 228, 229), Enum.Material.Snow)
			D.Wedge(c.Props, "IceSheet", Vector3.new(7, 19 + index, 11), CFrame.new(point(c, side * 51, 9, z)) * CFrame.Angles(0, index, side * .24), c.Accent, Enum.Material.Ice)
		end)
	end
end

-- 17: battlement-lined fortress wall walks and iron-bound frozen gatehouses.
Builders[17] = function(c)
	for _, z in {31, 87, 143} do
		sidePairs(function(side)
			block(c, "FortressTower", side * 51, 13, z, 17, 26, 21, c.Wall, Enum.Material.Brick)
			block(c, "SnowyBattlement", side * 51, 26.5, z, 19, 1, 23, Color3.fromRGB(214, 230, 232), Enum.Material.Snow)
			for merlon = -1, 1 do block(c, "Merlon", side * 51 + merlon * 6, 29, z - 9, 3.5, 5, 4, c.Wall, Enum.Material.Brick) end
			block(c, "ArrowSlit", side * 51, 16, z - 10.6, 1, 5, .2, Color3.fromRGB(34, 60, 78))
		end)
	end
	for _, side in {-1, 1} do block(c, "WallWalk", side * 54, 22, 85, 14, 2, 140, c.Wall) end
end

-- 18: delicate crystalline arcades and an overhead ice chandelier.
Builders[18] = function(c)
	for _, z in {29, 84, 143} do
		D.Arch(c.Props, point(c, 0, 0, z), 105, 24, 13, c.Wall:Lerp(c.Accent, .3), c.Accent)
		sidePairs(function(side) D.Crystal(c.Props, point(c, side * 51, 0, z + 17), 11, c.Accent) end)
	end
	for index = 1, 8 do
		local theta = index * math.pi / 4
		local x, z = math.cos(theta) * 14, 88 + math.sin(theta) * 14
		beam(c, "ChandelierArm", Vector3.new(0, 33, 88), Vector3.new(x, 28, z), .5, c.Accent, METAL)
		D.Wedge(c.Props, "HangingIcePrism", Vector3.new(2, 7, 2), CFrame.new(point(c, x, 27, z)) * CFrame.Angles(math.pi, theta, 0), c.Accent, Enum.Material.Glass)
	end
end

-- 19: charged pylons, suspended rune rings and angular storm conductors.
Builders[19] = function(c)
	columns(c, {33, 91, 146}, 27)
	wallRunes(c, {33, 91, 146})
	for _, z in {45, 121} do
		sidePairs(function(side)
			D.Crystal(c.Props, point(c, side * 46, 0, z), 9, c.Accent)
			local last = Vector3.new(side * 46, 17, z)
			for step = 1, 5 do
				local nextPoint = Vector3.new(side * (46 - step * 6), 24 + step % 2 * 4, z + step * 3)
				beam(c, "CapturedLightning", last, nextPoint, .22, c.Accent, NEON)
				last = nextPoint
			end
		end)
	end
end

-- 20: suspended broken islands, constellation tracery and quiet star pools.
Builders[20] = function(c)
	for index, z in {30, 76, 122, 153} do
		sidePairs(function(side)
			local h = 7 + index % 2 * 8
			block(c, "SuspendedRuinIsland", side * 49, h, z, 19, 3, 20, c.Wall)
			D.Wedge(c.Props, "IslandUnderside", Vector3.new(17, 9, 17), CFrame.new(point(c, side * 49, h - 5, z)) * CFrame.Angles(math.pi, .4, 0), c.Wall)
			D.Column(c.Props, point(c, side * 50, h + 1.5, z), 10, c.Wall, c.Accent, "round")
		end)
	end
	local previous = Vector3.new(-34, 30, 25)
	for index = 1, 9 do
		local current = Vector3.new(math.sin(index * 1.6) * 35, 31 + math.cos(index) * 5, 22 + index * 14)
		beam(c, "ConstellationThread", previous, current, .085, c.Accent, NEON)
		D.Ball(c.Props, "Star", Vector3.one * .8, point(c, current.X, current.Y, current.Z), c.Accent, NEON)
		previous = current
	end
end

-- 21: charred tunnel ribs, burnt timber and still ash heaps.
Builders[21] = function(c)
	cave(c, 6, Color3.fromRGB(44, 42, 43))
	for _, z in {33, 84, 141} do
		sidePairs(function(side)
			D.Tree(c.Props, point(c, side * 50, 0, z), 20, c.Accent, true)
			D.Ball(c.Props, "AshBank", Vector3.new(23, 2.7, 27), point(c, side * 49, 0, z + 6), Color3.fromRGB(72, 69, 66), Enum.Material.Sand)
			block(c, "SmoulderingFissure", side * 53, .06, z + 14, .45, .1, 10, c.Accent, NEON, CFrame.Angles(0, .3, 0))
		end)
	end
end

-- 22: monumental forge bays and molten runnels around giant anvils.
Builders[22] = function(c)
	for _, z in {35, 88, 142} do
		sidePairs(function(side)
			anvil(c, side * 48, z, 12)
			block(c, "FurnaceChimney", side * 58, 15, z + 13, 10, 30, 12, c.Wall, Enum.Material.Brick)
			block(c, "FurnaceMouth", side * 52.8, 5, z + 13, .15, 7, 8, c.Accent, NEON)
		end)
	end
	for _, side in {-1, 1} do lavaChannel(c, side * 59, 89, 4, 156) end
	for _, z in {57, 111} do block(c, "OverheadHoistBeam", 0, 31, z, 117, 4, 5, c.Wall, METAL) end
end

-- 23: fractured obsidian, lava banks, volcanic crystals and hanging basalt teeth.
Builders[23] = function(c)
	cave(c, 5, Color3.fromRGB(35, 32, 40))
	sidePairs(function(side)
		lavaChannel(c, side * 51, 88, 18, 160, Color3.fromRGB(246, 92, 40))
		for _, z in {29, 79, 131} do
			D.Crystal(c.Props, point(c, side * 54, .2, z), 12, c.Accent)
			D.Rock(c.Props, point(c, side * 42, 0, z + 15), 6, Color3.fromRGB(36, 31, 43), c.Rng)
		end
	end)
end

-- 24: red citadel ramparts, outward spikes and heavy heraldic shields.
Builders[24] = function(c)
	for _, z in {29, 84, 142} do
		sidePairs(function(side)
			block(c, "CitadelBastion", side * 52, 15, z, 18, 30, 22, c.Wall, Enum.Material.Brick)
			for offset = -1, 1 do D.Wedge(c.Props, "RampartSpike", Vector3.new(3, 8, 3), CFrame.new(point(c, side * 52 + offset * 6, 34, z)), c.Accent:Lerp(c.Wall, .65), METAL) end
			D.Wedge(c.Props, "HeraldicShield", Vector3.new(7, 11, 1), CFrame.new(point(c, side * 52, 16, z - 11.3)) * CFrame.Angles(0, 0, math.pi), c.Accent:Lerp(c.Wall, .2), METAL)
			D.Torch(c.Props, point(c, side * 42, 10, z), c.Accent)
		end)
	end
	block(c, "IronPortcullisLintel", 0, 29, 93, 119, 4, 5, c.Wall, METAL)
end

-- 25: paired monumental thrones overlooking a central ceremonial carpet.
Builders[25] = function(c)
	columns(c, {24, 76, 145}, 31)
	sidePairs(function(side)
		lavaChannel(c, side * 59, 89, 5, 155)
		for _, z in {54, 121} do
			for stair = 1, 3 do block(c, "ThroneDais", side * 51, stair * .65, z, 22 - stair * 3, 1.3, 25 - stair * 3, c.Wall) end
			block(c, "ThroneSeat", side * 51, 6, z, 10, 4, 9, Color3.fromRGB(93, 45, 40), METAL)
			block(c, "ThroneBack", side * 51, 16, z + 4, 12, 25, 3, c.Wall, METAL)
			for offset = -1, 1 do block(c, "ThroneArm", side * 51 + offset * 6, 8, z, 2, 3, 10, c.Accent:Lerp(c.Wall, .7), METAL) end
			D.Rune(c.Props, point(c, side * 51, 19, z + 2.3), 3, c.Accent)
		end
	end)
	block(c, "CeremonialRunner", 0, .04, 89, 17, .07, 157, Color3.fromRGB(105, 34, 39), Enum.Material.Fabric)
end

-- 26: silhouettes of twisted trees, violet roots and tiny spectral mushrooms.
Builders[26] = function(c)
	for index = 1, 7 do
		sidePairs(function(side)
			local z = 11 + index * 22
			D.Tree(c.Props, point(c, side * (49 + index % 2 * 6), 0, z), 22 + index % 3 * 3, c.Accent, true)
			D.Mushroom(c.Props, point(c, side * 44, 0, z + 6), 4.5, c.Accent)
			beam(c, "LuminousRoot", Vector3.new(side * 49, .12, z), Vector3.new(side * 40, .12, z + 8), .22, c.Accent, NEON)
		end)
	end
end

-- 27: gothic buttresses, pointed windows, ghost lanterns and a ruined organ.
Builders[27] = function(c)
	for _, z in {28, 79, 135} do
		D.Arch(c.Props, point(c, 0, 0, z), 105, 22, 16, c.Wall, c.Accent)
		sidePairs(function(side)
			block(c, "GothicWindow", side * 59, 17, z + 16, 1, 20, 10, c.Accent:Lerp(Color3.fromRGB(25, 32, 47), .45), Enum.Material.Glass)
			D.Torch(c.Props, point(c, side * 47, 8, z + 15), c.Accent)
		end)
	end
	for index = 1, 9 do
		D.Cylinder(c.Props, "OrganPipe", 1.3, 12 + math.abs(index - 5) * 2, CFrame.new(point(c, -54 + (index - 5) * 1.5, 12, 122)), Color3.fromRGB(105, 109, 124), METAL)
	end
end

-- 28: broken portal frames, void seams and improbable suspended masonry.
Builders[28] = function(c)
	for index, z in {31, 80, 135} do
		sidePairs(function(side)
			block(c, "VoidMonolith", side * 51, 14, z, 9, 28, 9, c.Wall, STONE, CFrame.Angles(0, index * .1, side * .06))
			D.Crystal(c.Props, point(c, side * 44, 0, z + 13), 7, c.Accent)
		end)
		for shard = 1, 5 do
			block(c, "FloatingArchSegment", (shard - 3) * 16, 28 + math.abs(shard - 3) * 2, z, 11, 3, 7, c.Wall, STONE, CFrame.Angles(.05, .05, (shard - 3) * .11))
		end
	end
	for _, side in {-1, 1} do block(c, "VoidFloorSeam", side * 17, .04, 90, .16, .06, 160, c.Accent, NEON) end
end

-- 29: enormous palace pillars, onyx pools and elevated sigil tablets.
Builders[29] = function(c)
	columns(c, {27, 82, 142}, 36, "round")
	for _, z in {49, 110, 157} do
		sidePairs(function(side)
			block(c, "TabletPlinth", side * 52, 6, z, 13, 12, 8, c.Wall)
			block(c, "FloatingSigilTablet", side * 52, 21, z, 10, 12, 2, c.Wall:Lerp(c.Accent, .09), METAL)
			D.Rune(c.Props, point(c, side * 52, 21, z - 1.1), 4, c.Accent)
			D.Cylinder(c.Props, "OnyxPool", 19, .09, CFrame.new(point(c, side * 51, .07, z)), Color3.fromRGB(35, 27, 57), Enum.Material.Glass)
		end)
	end
	D.Arch(c.Props, point(c, 0, 0, 151), 109, 33, 15, c.Wall, c.Accent)
end

-- 30: legendary forge nave, suspended celestial hammer and six monumental bays.
Builders[30] = function(c)
	columns(c, {24, 81, 140}, 41)
	sidePairs(function(side)
		lavaChannel(c, side * 59, 89, 6, 157, c.Accent:Lerp(Color3.fromRGB(255, 173, 66), .6))
		for _, z in {43, 103, 150} do
			anvil(c, side * 49, z, 13)
			D.Rune(c.Props, point(c, side * 51, 25, z), 4.5, c.Accent)
		end
	end)
	block(c, "LegendaryHammerHead", 0, 33, 92, 21, 8, 10, Color3.fromRGB(117, 107, 99), METAL, CFrame.Angles(0, 0, -.18))
	block(c, "LegendaryHammerHaft", -3, 47, 92, 3, 23, 3, Color3.fromRGB(80, 52, 45), WOOD, CFrame.Angles(0, 0, -.18))
	block(c, "HammerRuneband", 0, 33, 86.8, 15, .5, .1, c.Accent, NEON)
	for _, x in {-19, 19} do beam(c, "SuspensionChain", Vector3.new(x, c.Height - 1, 92), Vector3.new(x * .48, 35, 92), .65, c.Accent, METAL) end
	D.Arch(c.Props, point(c, 0, 0, 157), 109, 35, 15, c.Wall, c.Accent)
end

local function buildShell(config, model, definition, id)
	local start = (id - 1) * config.ZoneLength
	local height = definition.CeilingHeight or 38
	local floorColor = definition.FloorColor or Color3.fromRGB(66, 73, 77)
	local wallColor = definition.WallColor or Color3.fromRGB(79, 86, 91)
	local accent = definition.AccentColor or Color3.fromRGB(164, 194, 190)
	local structure = D.Model(model, "Architecture")
	D.Part(structure, "Foundation", Vector3.new(config.ZoneWidth, 5, config.ZoneLength), CFrame.new(0, -2.5, start + config.ZoneLength / 2), floorColor, id == 13 and Enum.Material.Sandstone or Enum.Material.Cobblestone, true)
	for _, side in {-1, 1} do
		D.Part(structure, "OuterWall", Vector3.new(4, height, config.ZoneLength), CFrame.new(side * (config.ZoneWidth / 2 + 2), height / 2, start + config.ZoneLength / 2), wallColor, STONE, true)
		D.Part(structure, "WallFooting", Vector3.new(2, 2, config.ZoneLength), CFrame.new(side * (config.ZoneWidth / 2 - 1), 1, start + config.ZoneLength / 2), wallColor:Lerp(Color3.new(0, 0, 0), .15), STONE)
		D.Part(structure, "CrownCornice", Vector3.new(3, 2, config.ZoneLength), CFrame.new(side * (config.ZoneWidth / 2 - 1), height - 2, start + config.ZoneLength / 2), wallColor:Lerp(accent, .1), STONE)
		D.Part(structure, "RoofWing", Vector3.new(44, 2, config.ZoneLength), CFrame.new(side * 43, height + 1, start + config.ZoneLength / 2), wallColor, STONE)
	end
	for step = 1, 8 do
		local z = start + (step - .5) * config.ZoneLength / 8
		local tile = D.Part(structure, "ProcessionalPaving", Vector3.new(23.5, .05, config.ZoneLength / 8 - .45), CFrame.new(0, .028, z), floorColor:Lerp(Color3.new(1, 1, 1), step % 2 == 0 and .045 or .015), Enum.Material.Slate)
		tile.CastShadow = false
	end
	D.Label(structure, "ZoneTitle", string.format("%02d  /  %s", id, string.upper(definition.Name)), Vector3.new(44, 4.6, .7), CFrame.new(0, 19.5, start + 10), accent)
	D.Label(structure, "ZoneSubtitle", string.upper(definition.Subtitle or "DEFEAT THE FIVE GUARDIANS TO ADVANCE"), Vector3.new(41, 1.5, .35), CFrame.new(0, 16.4, start + 9.8), Color3.fromRGB(198, 200, 195))
	return {Props = D.Model(model, "StoryAndDecoration"), Start = start, Height = height, Floor = floorColor, Wall = wallColor, Accent = accent, Rng = Random.new(1731 + id * 97)}
end

local function buildEncounter(config, model, c, id)
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	for index, position in config.GetSpawnPositions(id) do
		local marker = D.Part(spawns, tostring(index), Vector3.new(1, 1, 1), CFrame.new(position), c.Accent)
		marker.Transparency = 1
		marker:SetAttribute("ZoneId", id)
		marker:SetAttribute("SlotId", index)
		local ground = Vector3.new(position.X, .075, position.Z)
		D.Cylinder(c.Props, "EncounterMedallion", 13, .08, CFrame.new(ground), c.Wall:Lerp(c.Accent, .25), METAL)
		D.Cylinder(c.Props, "EncounterInset", 11.7, .09, CFrame.new(ground + Vector3.new(0, .03, 0)), c.Floor, Enum.Material.Slate)
	end
	local gate = D.Model(model, "ExitGate")
	gate:SetAttribute("ZoneId", id)
	CollectionService:AddTag(gate, "AetherGate")
	for _, side in {-1, 1} do
		D.Column(gate, Vector3.new(side * 57, 0, c.Start + config.ZoneLength - 2), 26, c.Wall, c.Accent)
	end
	D.Part(gate, "GateLintel", Vector3.new(119, 2.5, 4), CFrame.new(0, 26, c.Start + config.ZoneLength - 2), c.Wall)
	local barrier = D.Part(gate, "Barrier", Vector3.new(109, 24, .3), CFrame.new(0, 12, c.Start + config.ZoneLength - 1), c.Accent, Enum.Material.ForceField)
	barrier.Transparency = .86
	barrier:SetAttribute("GateBarrier", true)
	CollectionService:AddTag(barrier, "AetherGateBarrier")
	D.Label(gate, "GateTitle", id == config.ZoneCount and "THE WORLDHEART  /  FINAL CHAMBER" or string.format("PASSAGE  %02d  >  %02d", id, id + 1), Vector3.new(43, 3, .5), CFrame.new(0, 26, c.Start + config.ZoneLength - 4.1), c.Accent)
end

function Generator.Generate(config, parent: Instance, id: number): Model
	assert(id >= 1 and id <= config.ZoneCount, "Zone outside configured range")
	local definition = assert(config.Zones[id], "Missing dungeon zone definition")
	local model = D.Model(parent, string.format("Zone%02d", id))
	model:SetAttribute("ZoneId", id)
	model:SetAttribute("Theme", definition.Theme or definition.Name)
	model:SetAttribute("Layout", definition.Layout or "Authored")
	-- Leave default streaming behavior: a whole 180-stud zone need not load atomically.
	local c = buildShell(config, model, definition, id)
	Builders[id](c)
	buildEncounter(config, model, c, id)
	return model
end

function Generator.GenerateBossReserve(config, parent: Instance): Model
	local model = D.Model(parent, "FutureBossArena")
	model:SetAttribute("ZoneId", config.ZoneCount)
	model:SetAttribute("ReservedForFutureBoss", true)
	local start = config.ZoneCount * config.ZoneLength
	local finish = config.BossArenaEnd or (start + 170)
	local z = (start + finish) / 2
	local color = Color3.fromRGB(51, 48, 63)
	local gold = Color3.fromRGB(231, 174, 87)
	D.Part(model, "BossFoundation", Vector3.new(config.ZoneWidth, 5, finish - start), CFrame.new(0, -2.5, z), color, Enum.Material.Slate, true)
	D.Cylinder(model, "ArenaSeal", 87, .08, CFrame.new(0, .06, z), gold, METAL)
	D.Cylinder(model, "ArenaCenter", 82, .09, CFrame.new(0, .1, z), color, Enum.Material.Marble)
	for _, side in {-1, 1} do
		D.Part(model, "ArenaWall", Vector3.new(4, 60, finish - start), CFrame.new(side * 66, 30, z), color, STONE, true)
		for _, offset in {-52, 0, 52} do D.Column(model, Vector3.new(side * 52, 0, z + offset), 46, color, gold) end
	end
	D.Part(model, "TerminusWall", Vector3.new(136, 60, 4), CFrame.new(0, 30, finish + 2), color, STONE, true)
	D.Arch(model, Vector3.new(0, 0, finish - 15), 104, 38, 14, color, gold)
	D.Label(model, "BossReserveInscription", "A LEGEND IS YET TO BE FORGED", Vector3.new(51, 5, 1), CFrame.new(0, 22, finish - 4), gold)
	D.Label(model, "FutureBossNotice", "THE NEXT CHAPTER AWAITS", Vector3.new(45, 2.5, .6), CFrame.new(0, 17, finish - 4.1), Color3.fromRGB(196, 190, 185))
	return model
end

return Generator
