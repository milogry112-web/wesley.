--!strict

-- A completely local, asset-free hub. Its centre stays clear for navigation;
-- furniture and foliage never participate in collision, touch, or raycasts.
-- The generator owns no connections, loops, or scripts. Regenerate by destroying
-- the returned model. All randomness is seeded for reproducible world layouts.
local SpawnHubGenerator = {}

local C = {
	Stone = Color3.fromRGB(89, 103, 113),
	StoneLight = Color3.fromRGB(132, 149, 151),
	StoneDark = Color3.fromRGB(54, 66, 78),
	Path = Color3.fromRGB(126, 126, 116),
	Earth = Color3.fromRGB(75, 67, 58),
	Grass = Color3.fromRGB(68, 106, 83),
	Wood = Color3.fromRGB(102, 65, 46),
	WoodLight = Color3.fromRGB(153, 103, 64),
	Timber = Color3.fromRGB(62, 46, 43),
	Plaster = Color3.fromRGB(203, 190, 150),
	Roof = Color3.fromRGB(47, 92, 100),
	Metal = Color3.fromRGB(53, 63, 72),
	Gold = Color3.fromRGB(225, 178, 89),
	Teal = Color3.fromRGB(79, 205, 190),
	Amber = Color3.fromRGB(255, 192, 103),
	Purple = Color3.fromRGB(143, 105, 190),
	Leaf = Color3.fromRGB(55, 111, 85),
	LeafLight = Color3.fromRGB(90, 139, 94),
}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	frame: CFrame,
	colour: Color3,
	material: Enum.Material?,
	collide: boolean?,
	shape: Enum.PartType?
): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.CFrame = frame
	item.Color = colour
	item.Material = material or Enum.Material.SmoothPlastic
	item.Anchored = true
	item.CanCollide = collide == true
	item.CanTouch = false
	item.CanQuery = collide == true
	item.TopSurface = Enum.SurfaceType.Smooth
	item.BottomSurface = Enum.SurfaceType.Smooth
	item.CastShadow = material ~= Enum.Material.Neon
	if shape then
		item.Shape = shape
	end
	item.Parent = parent
	return item
end

local function model(parent: Instance, name: string): Model
	local group = Instance.new("Model")
	group.Name = name
	group.Parent = parent
	return group
end

local function at(frame: CFrame, x: number, y: number, z: number): CFrame
	return frame * CFrame.new(x, y, z)
end

local function cylinder(parent: Instance, name: string, diameter: number, height: number, frame: CFrame, colour: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(height, diameter, diameter), frame * CFrame.Angles(0, 0, math.pi / 2), colour, material, false, Enum.PartType.Cylinder)
end

local function sign(parent: Instance, frame: CFrame, width: number, title: string, subtitle: string, accent: Color3)
	local backing = part(parent, "CarvedSign", Vector3.new(width, 3.2, 0.4), frame, C.Timber, Enum.Material.Wood)
	part(parent, "SignGiltTop", Vector3.new(width + 0.4, 0.16, 0.6), at(frame, 0, 1.6, 0), accent, Enum.Material.Metal)
	part(parent, "SignGiltBottom", Vector3.new(width + 0.4, 0.16, 0.6), at(frame, 0, -1.6, 0), accent, Enum.Material.Metal)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "ShopLettering"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 34
	surface.LightInfluence = 0.2
	surface.MaxDistance = 100
	surface.Parent = backing
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.fromScale(0.94, 0.56)
	titleLabel.Position = UDim2.fromScale(0.03, 0.08)
	titleLabel.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	titleLabel.Text = title
	titleLabel.TextColor3 = accent
	titleLabel.TextScaled = true
	titleLabel.Parent = surface
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Size = UDim2.fromScale(0.9, 0.22)
	subtitleLabel.Position = UDim2.fromScale(0.05, 0.68)
	subtitleLabel.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	subtitleLabel.Text = subtitle
	subtitleLabel.TextColor3 = Color3.fromRGB(220, 219, 204)
	subtitleLabel.TextScaled = true
	subtitleLabel.Parent = surface
end

local function lantern(parent: Instance, frame: CFrame, realLight: boolean, tall: boolean?)
	local group = model(parent, "Lantern")
	local height = if tall then 8 else 2.8
	if tall then
		cylinder(group, "Foot", 1.8, 0.45, at(frame, 0, 0.22, 0), C.StoneDark, Enum.Material.Slate)
		part(group, "Post", Vector3.new(0.36, 6.4, 0.36), at(frame, 0, 3.4, 0), C.Metal, Enum.Material.Metal)
		part(group, "Crossbar", Vector3.new(2.5, 0.25, 0.25), at(frame, 0.6, 6.8, 0), C.Metal, Enum.Material.Metal)
	end
	local centre = at(frame, if tall then 1.4 else 0, height - 1.2, 0)
	local core = part(group, "WarmGlass", Vector3.new(0.82, 1.35, 0.82), centre, C.Amber, Enum.Material.Neon)
	core.Transparency = 0.12
	part(group, "LanternCap", Vector3.new(1.25, 0.22, 1.25), at(centre, 0, 0.83, 0), C.Metal, Enum.Material.Metal)
	part(group, "LanternBase", Vector3.new(1.1, 0.2, 1.1), at(centre, 0, -0.8, 0), C.Metal, Enum.Material.Metal)
	for _, x in {-0.48, 0.48} do
		part(group, "LanternFrame", Vector3.new(0.1, 1.55, 0.1), at(centre, x, 0, -0.48), C.Metal, Enum.Material.Metal)
	end
	if realLight then
		local light = Instance.new("PointLight")
		light.Color = C.Amber
		light.Brightness = 1.4
		light.Range = 20
		light.Shadows = false
		light.Parent = core
	end
end

local function barrel(parent: Instance, frame: CFrame, scale: number?)
	local s = scale or 1
	cylinder(parent, "BarrelBody", 2.5 * s, 3 * s, at(frame, 0, 1.5 * s, 0), C.Wood, Enum.Material.Wood)
	for _, y in {0.45, 2.45} do
		cylinder(parent, "BarrelBand", 2.58 * s, 0.2 * s, at(frame, 0, y * s, 0), C.Metal, Enum.Material.Metal)
	end
	cylinder(parent, "BarrelLid", 2.3 * s, 0.14 * s, at(frame, 0, 3.03 * s, 0), C.WoodLight, Enum.Material.WoodPlanks)
end

local function crate(parent: Instance, frame: CFrame, size: number)
	part(parent, "Crate", Vector3.new(size, size, size), at(frame, 0, size / 2, 0), C.WoodLight, Enum.Material.WoodPlanks)
	for _, y in {0.16, size - 0.16} do
		part(parent, "CrateRim", Vector3.new(size + 0.1, 0.22, size + 0.1), at(frame, 0, y, 0), C.Wood, Enum.Material.Wood)
	end
	part(parent, "CrateBrace", Vector3.new(0.25, size * 1.28, 0.18), at(frame, 0, size / 2, -size / 2 - 0.06) * CFrame.Angles(0, 0, -math.pi / 4), C.Wood, Enum.Material.Wood)
end

local function banner(parent: Instance, frame: CFrame, colour: Color3, small: boolean?)
	local s = if small then 0.7 else 1
	part(parent, "BannerSpar", Vector3.new(4.7 * s, 0.22, 0.3), at(frame, 0, 0, 0), C.Gold, Enum.Material.Metal)
	part(parent, "BannerCloth", Vector3.new(4 * s, 6.2 * s, 0.15), at(frame, 0, -3.2 * s, 0), colour, Enum.Material.Fabric)
	part(parent, "BannerStripe", Vector3.new(0.22, 5.7 * s, 0.18), at(frame, -1.55 * s, -3.15 * s, -0.02), C.Gold, Enum.Material.Fabric)
	part(parent, "BannerStripe", Vector3.new(0.22, 5.7 * s, 0.18), at(frame, 1.55 * s, -3.15 * s, -0.02), C.Gold, Enum.Material.Fabric)
	part(parent, "BannerEmblem", Vector3.new(1.25 * s, 1.25 * s, 0.2), at(frame, 0, -2.6 * s, -0.05) * CFrame.Angles(0, 0, math.pi / 4), C.Gold, Enum.Material.Metal)
end

local function building(parent: Instance, name: string, frame: CFrame, title: string, subtitle: string, accent: Color3, stationType: string): Model
	local group = model(parent, name)
	group:SetAttribute("StationType", stationType)
	part(group, "Foundation", Vector3.new(29, 0.7, 27), at(frame, 0, 0.35, 0), C.StoneDark, Enum.Material.Cobblestone, true)
	part(group, "Porch", Vector3.new(14, 0.45, 4), at(frame, 0, 0.225, -15.2), C.StoneLight, Enum.Material.Slate, true)
	part(group, "InteriorFloor", Vector3.new(25, 0.25, 20), at(frame, 0, 0.8, 0), C.WoodLight, Enum.Material.WoodPlanks, true)
	part(group, "BackWall", Vector3.new(26, 11.4, 0.7), at(frame, 0, 6.45, 10), C.Plaster, Enum.Material.Plaster, true)
	for _, x in {-12.65, 12.65} do
		part(group, "SideWall", Vector3.new(0.7, 11.4, 20), at(frame, x, 6.45, 0), C.Plaster, Enum.Material.Plaster, true)
	end
	for _, x in {-8.5, 8.5} do
		part(group, "FrontWall", Vector3.new(9, 11.4, 0.7), at(frame, x, 6.45, -10), C.Plaster, Enum.Material.Plaster, true)
		part(group, "WindowRecess", Vector3.new(4.6, 4.2, 0.24), at(frame, x, 6.5, -10.42), C.Timber, Enum.Material.Wood)
		part(group, "WindowGlass", Vector3.new(3.8, 3.4, 0.15), at(frame, x, 6.5, -10.58), C.Amber, Enum.Material.Neon).Transparency = 0.3
		part(group, "WindowMullion", Vector3.new(0.22, 3.5, 0.2), at(frame, x, 6.5, -10.71), C.Timber, Enum.Material.Wood)
		part(group, "WindowCrossbar", Vector3.new(3.9, 0.2, 0.2), at(frame, x, 6.35, -10.71), C.Timber, Enum.Material.Wood)
		part(group, "WindowSill", Vector3.new(5.3, 0.45, 1.2), at(frame, x, 4.15, -10.5), C.Wood, Enum.Material.Wood)
	end
	part(group, "DoorLintel", Vector3.new(8.2, 3, 0.8), at(frame, 0, 10.7, -10), C.Plaster, Enum.Material.Plaster)
	for _, x in {-13, -4.35, 4.35, 13} do
		part(group, "FrontTimber", Vector3.new(0.6, 11.6, 0.8), at(frame, x, 6.55, -10.3), C.Timber, Enum.Material.Wood)
	end
	for _, z in {-10.3, 10.3} do
		for _, y in {1.25, 3, 12.2} do
			part(group, "WallBeam", Vector3.new(26.8, 0.5, 0.65), at(frame, 0, y, z), C.Timber, Enum.Material.Wood)
		end
	end
	for _, side in {-1, 1} do
		local angle = -side * math.rad(25)
		part(group, "RoofPlane", Vector3.new(15.8, 0.75, 26), at(frame, side * 7, 15.55, 0) * CFrame.Angles(0, 0, angle), C.Roof, Enum.Material.Slate)
		for index = 0, 4 do
			local x = side * (1.4 + index * 2.8)
			part(group, "SlateCourse", Vector3.new(3.18, 0.23, 26.2), at(frame, x, 18.95 - math.abs(x) * math.tan(math.rad(25)), 0) * CFrame.Angles(0, 0, angle), if index % 2 == 0 then C.Roof else Color3.fromRGB(54, 103, 112), Enum.Material.Slate)
		end
		for _, z in {-13.3, 13.3} do
			part(group, "CarvedRafter", Vector3.new(16.2, 0.65, 0.65), at(frame, side * 7, 15.65, z) * CFrame.Angles(0, 0, angle), C.Timber, Enum.Material.Wood)
		end
	end
	part(group, "RoofRidge", Vector3.new(1.15, 0.8, 27.4), at(frame, 0, 19.15, 0), C.Gold, Enum.Material.Metal)
	part(group, "FrontGablePost", Vector3.new(0.6, 6.7, 0.65), at(frame, 0, 15.4, -12.8), C.Timber, Enum.Material.Wood)
	part(group, "GableEmblem", Vector3.new(1.8, 1.8, 0.3), at(frame, 0, 16, -13.2) * CFrame.Angles(0, 0, math.pi / 4), accent, Enum.Material.Neon)
	sign(group, at(frame, 0, 11, -11), 13.2, title, subtitle, accent)
	for _, x in {-10, 10} do
		lantern(group, at(frame, x, 1.1, -13), false, false)
	end
	banner(group, at(frame, -13.55, 10.5, -11.5), accent, true)
	local anchor = part(group, "InteractionAnchor", Vector3.new(1, 1, 1), at(frame, 0, 2.8, -14.6), accent)
	anchor.Transparency = 1
	group.PrimaryPart = anchor
	return group
end

local function forge(parent: Instance, frame: CFrame)
	local group = building(parent, "ForgeStation", frame, "EMBERFORGE", "CRAFTING  /  COMING SOON", C.Amber, "Forge")
	part(group, "ForgeHearth", Vector3.new(7, 4.8, 5), at(frame, -7.5, 3.1, 5.7), C.StoneDark, Enum.Material.Cobblestone)
	part(group, "HearthOpening", Vector3.new(4.8, 2.5, 0.18), at(frame, -7.5, 2.6, 3.12), C.Metal, Enum.Material.Slate)
	local coals = part(group, "GlowingCoals", Vector3.new(4.2, 0.3, 2.9), at(frame, -7.5, 1.45, 3.65), C.Amber, Enum.Material.Neon)
	part(group, "Chimney", Vector3.new(3.6, 14, 3.4), at(frame, -7.5, 12, 6.2), C.Stone, Enum.Material.Brick)
	part(group, "ChimneyCap", Vector3.new(4.8, 0.7, 4.7), at(frame, -7.5, 19.2, 6.2), C.StoneDark, Enum.Material.Slate)
	local light = Instance.new("PointLight")
	light.Color = C.Amber
	light.Range = 16
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = coals
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "ForgeSparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(C.Amber)
	sparks.LightEmission = 0.8
	sparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.13), NumberSequenceKeypoint.new(1, 0)})
	sparks.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
	sparks.Lifetime = NumberRange.new(0.7, 1.4)
	sparks.Speed = NumberRange.new(1.5, 3)
	sparks.SpreadAngle = Vector2.new(18, 18)
	sparks.Rate = 3
	sparks.Parent = coals
	cylinder(group, "AnvilStump", 3.5, 2.5, at(frame, 0, 2, -6), C.Wood, Enum.Material.Wood)
	part(group, "AnvilFoot", Vector3.new(3.7, 0.5, 2.6), at(frame, 0, 3.45, -6), C.Metal, Enum.Material.Metal)
	part(group, "AnvilWaist", Vector3.new(1.5, 1.2, 1.8), at(frame, 0, 4.15, -6), C.Metal, Enum.Material.Metal)
	part(group, "AnvilFace", Vector3.new(5.1, 0.55, 2.5), at(frame, 0.4, 5, -6), C.StoneLight, Enum.Material.Metal)
	part(group, "HammerHandle", Vector3.new(0.28, 0.28, 2.4), at(frame, -0.4, 5.45, -5.75) * CFrame.Angles(0, 0.4, 0), C.WoodLight, Enum.Material.Wood)
	part(group, "HammerHead", Vector3.new(1.6, 0.7, 0.7), at(frame, -0.85, 5.6, -6.7), C.Metal, Enum.Material.Metal)
	barrel(group, at(frame, 8, 0.85, -5), 0.9)
	crate(group, at(frame, 7, 0.85, 4), 3.2)
	crate(group, at(frame, 8, 4.05, 4.3), 2.2)
end

local function displaySword(parent: Instance, frame: CFrame, accent: Color3)
	part(parent, "DisplayBlade", Vector3.new(0.45, 4.8, 0.16), at(frame, 0, 2, 0), C.StoneLight, Enum.Material.Metal)
	part(parent, "DisplayGuard", Vector3.new(1.6, 0.22, 0.35), at(frame, 0, -0.3, 0), accent, Enum.Material.Metal)
	part(parent, "DisplayGrip", Vector3.new(0.3, 1, 0.3), at(frame, 0, -0.9, 0), C.Timber, Enum.Material.Wood)
end

local function outfitters(parent: Instance, frame: CFrame)
	local group = building(parent, "InventoryStation", frame, "WAYFARER'S KIT", "EQUIPMENT  /  COMING SOON", C.Teal, "Inventory")
	part(group, "WeaponRackBack", Vector3.new(15, 5.4, 0.5), at(frame, 0, 5.2, 8.8), C.Wood, Enum.Material.WoodPlanks)
	for _, x in {-5, 0, 5} do
		displaySword(group, at(frame, x, 4.6, 8.4), C.Gold)
	end
	part(group, "Counter", Vector3.new(13, 3.3, 3.2), at(frame, 0, 2.6, -4), C.Wood, Enum.Material.WoodPlanks)
	part(group, "CounterTop", Vector3.new(13.6, 0.35, 3.8), at(frame, 0, 4.4, -4), C.WoodLight, Enum.Material.Wood)
	for _, x in {-5.5, 5.5} do
		part(group, "CounterStud", Vector3.new(0.35, 2.8, 0.15), at(frame, x, 2.6, -5.68), C.Gold, Enum.Material.Metal)
	end
	part(group, "ShieldDisplay", Vector3.new(2.4, 3.2, 0.5), at(frame, 7.8, 5.2, 1.5) * CFrame.Angles(0, -0.35, 0), C.Teal, Enum.Material.Metal)
	part(group, "ShieldCrest", Vector3.new(0.35, 2.9, 0.58), at(frame, 7.8, 5.2, 1.5) * CFrame.Angles(0, -0.35, 0), C.Gold, Enum.Material.Metal)
	crate(group, at(frame, -9, 0.85, -5), 3)
end

local function alchemy(parent: Instance, frame: CFrame)
	local group = building(parent, "ShopStation", frame, "MOONLIT SUPPLIES", "PROVISIONS  /  COMING SOON", C.Purple, "Shop")
	part(group, "ShopCounter", Vector3.new(14, 3.3, 3.6), at(frame, 0, 2.6, -4), C.Wood, Enum.Material.WoodPlanks)
	part(group, "CounterTop", Vector3.new(14.6, 0.35, 4), at(frame, 0, 4.4, -4), C.WoodLight, Enum.Material.Wood)
	for _, y in {4.2, 7.4} do
		part(group, "ApothecaryShelf", Vector3.new(16, 0.3, 2.2), at(frame, 0, y, 8.5), C.Timber, Enum.Material.Wood)
		for index = 1, 5 do
			local colour = ({C.Teal, C.Purple, C.Amber})[(index % 3) + 1]
			part(group, "PotionBottle", Vector3.new(0.9, 1.05, 0.9), at(frame, (index - 3) * 2.5, y + 0.7, 8.3), colour, Enum.Material.Glass, false, Enum.PartType.Ball).Transparency = 0.18
			cylinder(group, "BottleStopper", 0.4, 0.45, at(frame, (index - 3) * 2.5, y + 1.4, 8.3), C.WoodLight, Enum.Material.Wood)
		end
	end
	part(group, "OpenLedger", Vector3.new(2.6, 0.18, 1.9), at(frame, 2, 4.7, -4) * CFrame.Angles(0, 0.2, 0), C.Plaster, Enum.Material.SmoothPlastic)
	barrel(group, at(frame, -9.3, 0.85, 0), 0.85)
end

local function upgradeHouse(parent: Instance, frame: CFrame)
	local group = building(parent, "UpgradeStation", frame, "THE AETHER WELL", "UPGRADES  /  COMING SOON", C.Teal, "Upgrade")
	cylinder(group, "RuneDais", 8.3, 0.9, at(frame, 0, 1.3, -2), C.StoneDark, Enum.Material.Slate)
	cylinder(group, "RuneRing", 6.8, 0.18, at(frame, 0, 1.83, -2), C.Teal, Enum.Material.Neon)
	cylinder(group, "RuneInset", 6.1, 0.2, at(frame, 0, 1.94, -2), C.StoneDark, Enum.Material.Slate)
	part(group, "AetherCrystal", Vector3.new(2.7, 4.8, 2.7), at(frame, 0, 5, -2) * CFrame.Angles(0.2, 0.55, 0.25), C.Teal, Enum.Material.Neon).Transparency = 0.18
	for index = 0, 5 do
		local angle = index * math.pi / 3
		part(group, "RuneMark", Vector3.new(0.24, 0.11, 0.7), at(frame, math.sin(angle) * 2.65, 2.1, -2 + math.cos(angle) * 2.65) * CFrame.Angles(0, angle, 0), C.Gold, Enum.Material.Neon)
	end
	for _, x in {-8, 8} do
		part(group, "ScholarDesk", Vector3.new(4.3, 3.1, 4), at(frame, x, 2.4, 4), C.Wood, Enum.Material.WoodPlanks)
		for index = 0, 2 do
			part(group, "BoundTome", Vector3.new(2.7, 0.45, 1.8), at(frame, x, 4.15 + index * 0.48, 4) * CFrame.Angles(0, index * 0.13, 0), if index % 2 == 0 then C.Purple else C.Roof, Enum.Material.Fabric)
		end
	end
end

local function tree(parent: Instance, x: number, z: number, height: number, rng: Random)
	local group = model(parent, "WindwardTree")
	local frame = CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(-math.pi, math.pi), 0)
	part(group, "Trunk", Vector3.new(1.3, height * 0.64, 1.3), at(frame, 0, height * 0.3, 0) * CFrame.Angles(0, 0, 0.05), C.Wood, Enum.Material.Wood)
	part(group, "Branch", Vector3.new(0.7, height * 0.35, 0.7), at(frame, 1.2, height * 0.48, 0) * CFrame.Angles(0, 0, -0.5), C.Wood, Enum.Material.Wood)
	for index = 1, 3 do
		local diameter = height * (0.59 - index * 0.07)
		part(group, "Canopy", Vector3.new(diameter, diameter * 0.8, diameter), at(frame, if index == 1 then -1 else 1, height * (0.49 + index * 0.12), 0) * CFrame.Angles(0, index * 0.65, 0), if index % 2 == 0 then C.LeafLight else C.Leaf, Enum.Material.Grass, false, Enum.PartType.Ball)
	end
	for index = 1, 3 do
		local angle = index * math.pi * 2 / 3
		part(group, "RootStone", Vector3.new(1.7, 0.7, 1.4), at(frame, math.sin(angle) * 1.8, 0.25, math.cos(angle) * 1.8) * CFrame.Angles(0, angle, 0.15), C.Stone, Enum.Material.Rock)
	end
end

local function stall(parent: Instance, frame: CFrame, colour: Color3)
	local group = model(parent, "MarketStall")
	part(group, "StallCounter", Vector3.new(10, 2.8, 4), at(frame, 0, 1.4, 0), C.Wood, Enum.Material.WoodPlanks)
	part(group, "CounterTop", Vector3.new(10.8, 0.35, 4.7), at(frame, 0, 2.95, 0), C.WoodLight, Enum.Material.Wood)
	for _, x in {-4.7, 4.7} do
		part(group, "AwningPost", Vector3.new(0.3, 7.5, 0.3), at(frame, x, 3.75, 1.8), C.Timber, Enum.Material.Wood)
	end
	for index = 0, 4 do
		local stripe = if index % 2 == 0 then colour else C.Plaster
		part(group, "AwningStripe", Vector3.new(2.13, 0.18, 7), at(frame, -4.26 + index * 2.13, 6.9, -0.2) * CFrame.Angles(math.rad(9), 0, 0), stripe, Enum.Material.Fabric)
		part(group, "AwningValance", Vector3.new(2.13, 0.9, 0.16), at(frame, -4.26 + index * 2.13, 6, -3.64), stripe, Enum.Material.Fabric)
	end
	crate(group, at(frame, -7, 0, 1), 2.8)
	barrel(group, at(frame, 7, 0, 0), 0.8)
	for index = 1, 5 do
		part(group, "MarketProduce", Vector3.new(1, 0.9, 1), at(frame, (index - 3) * 1.55, 3.6, 0), if index % 2 == 0 then C.Amber else Color3.fromRGB(182, 83, 75), Enum.Material.SmoothPlastic, false, Enum.PartType.Ball)
	end
end

local function cart(parent: Instance, frame: CFrame)
	local group = model(parent, "ProvisionCart")
	part(group, "CartBed", Vector3.new(5, 0.35, 7), at(frame, 0, 2.1, 0), C.WoodLight, Enum.Material.WoodPlanks)
	for _, x in {-2.35, 2.35} do
		part(group, "CartSide", Vector3.new(0.3, 2.1, 7), at(frame, x, 3.2, 0), C.Wood, Enum.Material.WoodPlanks)
	end
	part(group, "CartBack", Vector3.new(4.8, 2.1, 0.3), at(frame, 0, 3.2, 3.35), C.Wood, Enum.Material.WoodPlanks)
	for _, x in {-3, 3} do
		local wheel = at(frame, x, 1.55, 0)
		part(group, "WheelRim", Vector3.new(0.35, 3.1, 3.1), wheel, C.Metal, Enum.Material.Metal, false, Enum.PartType.Cylinder)
		part(group, "WheelInset", Vector3.new(0.42, 2.5, 2.5), wheel, C.Wood, Enum.Material.Wood, false, Enum.PartType.Cylinder)
		part(group, "WheelHub", Vector3.new(0.6, 0.65, 0.65), wheel, C.Gold, Enum.Material.Metal, false, Enum.PartType.Cylinder)
	end
	for _, x in {-1.6, 1.6} do
		part(group, "CartHandle", Vector3.new(0.32, 0.32, 5.3), at(frame, x, 2, -5), C.Wood, Enum.Material.Wood)
	end
	crate(group, at(frame, 0, 2.35, 1), 2.7)
end

local function gateway(parent: Instance)
	local group = model(parent, "DungeonGateway")
	for _, side in {-1, 1} do
		local x = side * 21
		part(group, "GateFoundation", Vector3.new(12, 1.5, 13), CFrame.new(x, 0.75, -5), C.StoneDark, Enum.Material.Cobblestone, true)
		part(group, "GateTower", Vector3.new(9, 22, 10), CFrame.new(x, 12, -5), C.Stone, Enum.Material.Slate)
		for _, y in {3, 9, 15, 23} do
			part(group, "TowerCourse", Vector3.new(10, 0.7, 11), CFrame.new(x, y, -5), C.StoneLight, Enum.Material.Slate)
		end
		part(group, "TowerCrown", Vector3.new(12, 1.4, 13), CFrame.new(x, 24, -5), C.StoneDark, Enum.Material.Slate)
		for offset = -1, 1 do
			part(group, "Crenellation", Vector3.new(2.3, 2.7, 2.5), CFrame.new(x + offset * 4.4, 26, -10.15), C.Stone, Enum.Material.Slate)
		end
		banner(group, CFrame.new(x, 20, -10.55), C.Roof)
		part(group, "GateObelisk", Vector3.new(3.6, 8.5, 3.6), CFrame.new(side * 15, 4.25, -13), C.StoneDark, Enum.Material.Slate)
		part(group, "ObeliskRune", Vector3.new(0.42, 5.7, 0.12), CFrame.new(side * 15, 5, -14.88), C.Teal, Enum.Material.Neon)
		lantern(group, CFrame.new(side * 20, 0.75, -16.5), true, true)
	end
	part(group, "GateLintel", Vector3.new(34, 4.2, 8), CFrame.new(0, 23.8, -4), C.StoneDark, Enum.Material.Slate)
	part(group, "GateCrown", Vector3.new(37, 1.1, 9.2), CFrame.new(0, 26.4, -4), C.StoneLight, Enum.Material.Slate)
	for _, side in {-1, 1} do
		part(group, "GateShoulder", Vector3.new(9.5, 2, 8), CFrame.new(side * 12.5, 20.8, -4) * CFrame.Angles(0, 0, side * math.rad(32)), C.StoneDark, Enum.Material.Slate)
	end
	sign(group, CFrame.new(0, 24, -8.25), 20, "THE HOLLOW DEPTHS", "ENTER THE DUNGEON", C.Teal)
	part(group, "GateCrest", Vector3.new(3.2, 3.2, 1), CFrame.new(0, 29, -4) * CFrame.Angles(0, 0, math.pi / 4), C.Gold, Enum.Material.Metal)
	part(group, "GateCrestGem", Vector3.new(1.6, 1.6, 1.15), CFrame.new(0, 29, -4.1) * CFrame.Angles(0, 0, math.pi / 4), C.Teal, Enum.Material.Neon)
	for _, x in {-8, -4, 0, 4, 8} do
		part(group, "ThresholdRune", Vector3.new(0.45, 0.06, 1.7), CFrame.new(x, 0.13, -7), C.Teal, Enum.Material.Neon)
	end
end

local function leaderboard(parent: Instance, frame: CFrame)
	local group = model(parent, "HallOfAdventurers")
	for _, x in {-6.3, 6.3} do
		part(group, "NoticePost", Vector3.new(0.8, 11, 0.8), at(frame, x, 5.5, 0), C.Timber, Enum.Material.Wood)
		part(group, "NoticeFinial", Vector3.new(1.3, 1.3, 1.3), at(frame, x, 11.2, 0) * CFrame.Angles(0, 0, math.pi / 4), C.Gold, Enum.Material.Metal)
	end
	sign(group, at(frame, 0, 10, -0.1), 13, "HALL OF ADVENTURERS", "YOUR LEGEND STARTS HERE", C.Gold)
	local board = part(group, "LeaderboardBoard", Vector3.new(12, 5.6, 0.5), at(frame, 0, 5.4, 0), C.StoneDark, Enum.Material.Slate)
	board:SetAttribute("LeaderboardDisplay", true)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardSurface"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 32
	gui.LightInfluence = 0.1
	gui.MaxDistance = 85
	gui.Parent = board
	local copy = Instance.new("TextLabel")
	copy.Name = "LeaderboardText"
	copy.Size = UDim2.fromScale(0.9, 0.85)
	copy.Position = UDim2.fromScale(0.05, 0.075)
	copy.BackgroundTransparency = 1
	copy.TextColor3 = C.Plaster
	copy.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	copy.TextSize = 21
	copy.TextWrapped = true
	copy.Text = "YOUR LEGEND STARTS HERE\n\nDefeat five different guardians.\nOpen the next gate. Walk into the unknown."
	copy.Parent = gui
end

function SpawnHubGenerator.Generate(config: any, parent: Instance): Model
	local hub = model(parent, "SpawnHub")
	hub:SetAttribute("GeneratedHub", true)
	local rng = Random.new(28471)
	local ground = part(hub, "HubGround", Vector3.new(128, 3, 180), CFrame.new(0, -1.5, -90), C.Grass, Enum.Material.Grass, true)
	hub.PrimaryPart = ground
	part(hub, "EarthFoundation", Vector3.new(130, 6, 182), CFrame.new(0, -6, -90), C.Earth, Enum.Material.Ground)
	part(hub, "CentralWalkway", Vector3.new(24, 0.12, 180), CFrame.new(0, 0.06, -90), C.Path, Enum.Material.Cobblestone)
	part(hub, "SpawnPlaza", Vector3.new(60, 0.15, 36), CFrame.new(0, 0.075, -93), C.StoneLight, Enum.Material.Cobblestone)
	for _, x in {-13, 13} do
		part(hub, "PathCurb", Vector3.new(0.8, 0.25, 180), CFrame.new(x, 0.125, -90), C.StoneLight, Enum.Material.Slate)
	end
	for index = 0, 17 do
		part(hub, "WalkwayInset", Vector3.new(20, 0.03, 0.25), CFrame.new(0, 0.135, -5 - index * 10), C.StoneDark, Enum.Material.Slate)
	end
	for _, z in {-59, -122} do
		for _, x in {-25, 25} do
			part(hub, "ShopApproach", Vector3.new(24, 0.13, 9), CFrame.new(x, 0.065, z), C.Path, Enum.Material.Cobblestone)
		end
	end

	local spawnPosition = if config and typeof(config.HubSpawn) == "Vector3" then config.HubSpawn else Vector3.new(0, 5, -95)
	local medallionFrame = CFrame.new(spawnPosition.X, 0, spawnPosition.Z)
	cylinder(hub, "SpawnMedallionBorder", 18, 0.12, at(medallionFrame, 0, 0.17, 0), C.Gold, Enum.Material.Metal)
	cylinder(hub, "SpawnMedallionStone", 16.8, 0.13, at(medallionFrame, 0, 0.23, 0), C.StoneDark, Enum.Material.Slate)
	for index = 0, 7 do
		local angle = index * math.pi / 4
		part(hub, "CompassRay", Vector3.new(0.3, 0.05, 3.5), at(medallionFrame, math.sin(angle) * 4.7, 0.325, math.cos(angle) * 4.7) * CFrame.Angles(0, angle, 0), if index % 2 == 0 then C.Teal else C.Gold, Enum.Material.Neon)
	end
	part(hub, "CompassHeart", Vector3.new(3, 0.05, 3), at(medallionFrame, 0, 0.34, 0) * CFrame.Angles(0, math.pi / 4, 0), C.Gold, Enum.Material.Metal)

	forge(hub, CFrame.new(-43, 0, -59) * CFrame.Angles(0, -math.pi / 2, 0))
	alchemy(hub, CFrame.new(43, 0, -59) * CFrame.Angles(0, math.pi / 2, 0))
	upgradeHouse(hub, CFrame.new(-43, 0, -122) * CFrame.Angles(0, -math.pi / 2, 0))
	outfitters(hub, CFrame.new(43, 0, -122) * CFrame.Angles(0, math.pi / 2, 0))
	stall(hub, CFrame.new(-29, 0, -157) * CFrame.Angles(0, -0.3, 0), C.Roof)
	stall(hub, CFrame.new(29, 0, -157) * CFrame.Angles(0, 0.3, 0), C.Purple)
	cart(hub, CFrame.new(48, 0, -159) * CFrame.Angles(0, -0.5, 0))
	leaderboard(hub, CFrame.new(-39, 0, -24) * CFrame.Angles(0, -0.25, 0))
	gateway(hub)

	for _, z in {-37, -77, -110, -143, -172} do
		for _, side in {-1, 1} do
			lantern(hub, CFrame.new(side * 15.5, 0, z) * CFrame.Angles(0, if side == 1 then math.pi else 0, 0), z == -77, true)
		end
	end
	for _, coordinates in {
		{-57, -172}, {-53, -145}, {-59, -99}, {-50, -88}, {-58, -35}, {-58, -12},
		{57, -176}, {57, -143}, {58, -96}, {48, -87}, {55, -33}, {41, -20},
	} do
		tree(hub, coordinates[1], coordinates[2], rng:NextNumber(13, 19), rng)
	end
	for index = 1, 26 do
		local side = if index % 2 == 0 then -1 else 1
		local x = side * rng:NextNumber(60, 63)
		local z = rng:NextNumber(-178, -5)
		part(hub, "BorderShrub", Vector3.new(rng:NextNumber(2, 4), rng:NextNumber(1.3, 2.8), rng:NextNumber(2, 4)), CFrame.new(x, 0.9, z), if index % 3 == 0 then C.LeafLight else C.Leaf, Enum.Material.Grass, false, Enum.PartType.Ball)
	end
	-- Low timber fences frame the village gardens, away from all walking routes.
	local fences = model(hub, "GardenFences")
	for _, side in {-1, 1} do
		for _, centre in {-164, -95, -24} do
			for offset = -1, 1 do
				part(fences, "FencePost", Vector3.new(.55, 3.3, .55), CFrame.new(side * 61, 1.65, centre + offset * 6), C.Wood, Enum.Material.Wood)
				part(fences, "PostCap", Vector3.new(.8, .2, .8), CFrame.new(side * 61, 3.4, centre + offset * 6), C.WoodLight, Enum.Material.Wood)
			end
			for _, height in {1.1, 2.45} do
				part(fences, "FenceRail", Vector3.new(.32, .36, 12.5), CFrame.new(side * 61, height, centre), C.WoodLight, Enum.Material.WoodPlanks)
			end
		end
	end
	for _, side in {-1, 1} do
		for _, z in {-85, -102} do
			local x = side * 23
			part(hub, "PlazaPlanter", Vector3.new(6, 1, 3), CFrame.new(x, 0.5, z), C.StoneDark, Enum.Material.Slate)
			part(hub, "PlanterSoil", Vector3.new(5.5, 0.16, 2.5), CFrame.new(x, 1.05, z), C.Earth, Enum.Material.Ground)
			for index = -1, 1 do
				part(hub, "PlanterBush", Vector3.new(2.1, 1.8, 2), CFrame.new(x + index * 1.6, 1.8, z), C.LeafLight, Enum.Material.Grass, false, Enum.PartType.Ball)
				part(hub, "PlanterFlower", Vector3.new(0.6, 0.6, 0.6), CFrame.new(x + index * 1.6, 2.75, z - 0.2), if side == 1 then C.Purple else C.Amber, Enum.Material.SmoothPlastic, false, Enum.PartType.Ball)
			end
		end
		for _, z in {-88, -98} do
			local frame = CFrame.new(side * 27, 0, z) * CFrame.Angles(0, math.pi / 2, 0)
			part(hub, "BenchSeat", Vector3.new(6.5, 0.4, 1.8), at(frame, 0, 1.9, 0), C.WoodLight, Enum.Material.WoodPlanks)
			part(hub, "BenchBack", Vector3.new(6.5, 1.6, 0.3), at(frame, 0, 3, 0.8), C.Wood, Enum.Material.WoodPlanks)
			for _, x in {-2.4, 2.4} do
				part(hub, "BenchLeg", Vector3.new(0.5, 1.7, 1.4), at(frame, x, 0.85, 0), C.Metal, Enum.Material.Metal)
			end
		end
	end
	local count = 0
	for _, descendant in hub:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	hub:SetAttribute("GeneratedPartCount", count)
	hub:SetAttribute("DesignBudget", 1100)
	return hub
end

return SpawnHubGenerator
