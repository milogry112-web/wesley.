--!strict
-- Static, owned geometry only: no heartbeat callbacks, physics or imported assets.
local Decoration = {}

local wood = Color3.fromRGB(91, 63, 44)
local iron = Color3.fromRGB(51, 56, 63)

function Decoration.Model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Decoration.Part(parent: Instance, name: string, size: Vector3, frame: CFrame, color: Color3, material: Enum.Material?, solid: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = frame
	part.Color = color
	part.Material = material or Enum.Material.Slate
	part.Anchored = true
	part.CanCollide = solid == true
	part.CanTouch = false
	part.CanQuery = solid == true
	part.CastShadow = solid == true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function Decoration.Beam(parent: Instance, name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material?): Part
	return Decoration.Part(parent, name, Vector3.new(thickness, thickness, (b - a).Magnitude), CFrame.lookAt((a + b) * .5, b), color, material)
end

function Decoration.Cylinder(parent: Instance, name: string, diameter: number, height: number, frame: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Decoration.Part(parent, name, Vector3.new(height, diameter, diameter), frame * CFrame.Angles(0, 0, math.pi / 2), color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

function Decoration.Ball(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Decoration.Part(parent, name, size, CFrame.new(position), color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

function Decoration.Wedge(parent: Instance, name: string, size: Vector3, frame: CFrame, color: Color3, material: Enum.Material?): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Size = size
	part.CFrame = frame
	part.Color = color
	part.Material = material or Enum.Material.Slate
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Parent = parent
	return part
end

function Decoration.Label(parent: Instance, name: string, text: string, size: Vector3, frame: CFrame, accent: Color3): Part
	local slab = Decoration.Part(parent, name, size, frame, Color3.fromRGB(24, 29, 38), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Inscription"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 28
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Parent = slab
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(.94, .9)
	label.Position = UDim2.fromScale(.03, .05)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = accent
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = .7
	label.Parent = gui
	return slab
end

function Decoration.Column(parent: Instance, position: Vector3, height: number, color: Color3, accent: Color3, style: string?)
	local model = Decoration.Model(parent, "Column")
	Decoration.Part(model, "Foot", Vector3.new(7, 1.1, 7), CFrame.new(position + Vector3.new(0, .55, 0)), color)
	Decoration.Part(model, "Plinth", Vector3.new(5.7, 1, 5.7), CFrame.new(position + Vector3.new(0, 1.6, 0)), color:Lerp(accent, .13))
	if style == "round" then
		Decoration.Cylinder(model, "Shaft", 4.4, height - 4, CFrame.new(position + Vector3.new(0, height / 2, 0)), color, Enum.Material.Marble)
	else
		Decoration.Part(model, "Shaft", Vector3.new(4.5, height - 4, 4.5), CFrame.new(position + Vector3.new(0, height / 2, 0)), color)
	end
	Decoration.Part(model, "Capital", Vector3.new(6.7, 1.7, 6.7), CFrame.new(position + Vector3.new(0, height - 1.4, 0)), color:Lerp(accent, .16))
	Decoration.Part(model, "Collar", Vector3.new(4.8, .45, 4.8), CFrame.new(position + Vector3.new(0, height * .68, 0)), accent, Enum.Material.Metal)
	return model
end

function Decoration.Arch(parent: Instance, origin: Vector3, width: number, springHeight: number, rise: number, color: Color3, accent: Color3)
	local model = Decoration.Model(parent, "VaultArch")
	for _, side in {-1, 1} do
		Decoration.Column(model, origin + Vector3.new(side * width / 2, 0, 0), springHeight, color, accent)
	end
	for index = 0, 7 do
		local thetaA = index / 8 * math.pi
		local thetaB = (index + 1) / 8 * math.pi
		local a = origin + Vector3.new(math.cos(thetaA) * width / 2, springHeight + math.sin(thetaA) * rise, 0)
		local b = origin + Vector3.new(math.cos(thetaB) * width / 2, springHeight + math.sin(thetaB) * rise, 0)
		Decoration.Beam(model, "Voussoir", a, b, 3.5, color:Lerp(accent, index % 2 * .09))
	end
	return model
end

function Decoration.Rock(parent: Instance, position: Vector3, scale: number, color: Color3, rng: Random)
	local rock = Decoration.Part(parent, "WeatheredRock", Vector3.new(scale * 1.2, scale, scale * .9), CFrame.new(position + Vector3.new(0, scale * .38, 0)) * CFrame.Angles(rng:NextNumber(-.35, .35), rng:NextNumber(0, math.pi), rng:NextNumber(-.3, .3)), color)
	Decoration.Wedge(parent, "RockFacet", Vector3.new(scale * .8, scale * .6, scale), rock.CFrame * CFrame.new(scale * .4, .1, 0), color:Lerp(Color3.new(1, 1, 1), .07))
end

function Decoration.Crystal(parent: Instance, position: Vector3, scale: number, accent: Color3)
	local model = Decoration.Model(parent, "CrystalCluster")
	for index = 1, 3 do
		local height = scale * (index == 2 and 1.4 or .8)
		local frame = CFrame.new(position + Vector3.new((index - 2) * scale * .35, height * .5, 0)) * CFrame.Angles(0, index * .6, (index - 2) * -.23)
		local shard = Decoration.Part(model, "CrystalPrism", Vector3.new(scale * .32, height, scale * .32), frame, accent, Enum.Material.Glass)
		shard.Transparency = .08
		Decoration.Wedge(model, "CrystalTip", Vector3.new(scale * .32, scale * .4, scale * .32), frame * CFrame.new(0, height / 2 + scale * .15, 0), accent:Lerp(Color3.new(1, 1, 1), .2), Enum.Material.Glass)
		Decoration.Part(model, "LuminousVein", Vector3.new(.15, height * .7, .15), frame * CFrame.new(0, 0, -scale * .17), accent, Enum.Material.Neon)
	end
	return model
end

function Decoration.Torch(parent: Instance, position: Vector3, accent: Color3)
	local model = Decoration.Model(parent, "Sconce")
	Decoration.Part(model, "Bracket", Vector3.new(1.2, 4, 1.2), CFrame.new(position), wood, Enum.Material.Wood)
	Decoration.Cylinder(model, "Brazier", 3, 1.1, CFrame.new(position + Vector3.new(0, 2, 0)), iron, Enum.Material.Metal)
	Decoration.Ball(model, "FireCore", Vector3.new(1.8, 3.3, 1.8), position + Vector3.new(0, 3.4, 0), accent, Enum.Material.Neon)
	-- Emissive surfaces give readable warmth without hundreds of real lights.
	return model
end

function Decoration.Crate(parent: Instance, position: Vector3, scale: number)
	local model = Decoration.Model(parent, "SupplyCrate")
	Decoration.Part(model, "Box", Vector3.one * scale, CFrame.new(position + Vector3.new(0, scale / 2, 0)), wood, Enum.Material.WoodPlanks)
	for _, offset in {-.37, .37} do
		Decoration.Part(model, "IronBand", Vector3.new(scale + .15, .22, scale + .15), CFrame.new(position + Vector3.new(0, scale * (.5 + offset), 0)), iron, Enum.Material.Metal)
	end
	Decoration.Beam(model, "DiagonalBrace", position + Vector3.new(-scale * .45, .2, -scale / 2 - .1), position + Vector3.new(scale * .45, scale - .2, -scale / 2 - .1), .4, Color3.fromRGB(151, 112, 67), Enum.Material.Wood)
	return model
end

function Decoration.Mushroom(parent: Instance, position: Vector3, height: number, accent: Color3)
	local model = Decoration.Model(parent, "GiantMushroom")
	Decoration.Cylinder(model, "Stem", height * .16, height * .8, CFrame.new(position + Vector3.new(0, height * .4, 0)), Color3.fromRGB(165, 167, 143), Enum.Material.Wood)
	Decoration.Ball(model, "Cap", Vector3.new(height * .95, height * .34, height * .95), position + Vector3.new(0, height * .84, 0), accent)
	Decoration.Cylinder(model, "LuminousGills", height * .79, .3, CFrame.new(position + Vector3.new(0, height * .76, 0)), accent:Lerp(Color3.new(1, 1, 1), .42), Enum.Material.Neon)
	return model
end

function Decoration.Tree(parent: Instance, position: Vector3, height: number, foliage: Color3, bare: boolean?)
	local model = Decoration.Model(parent, bare and "TwistedTree" or "RootedTree")
	Decoration.Cylinder(model, "Trunk", height * .12, height * .72, CFrame.new(position + Vector3.new(0, height * .34, 0)) * CFrame.Angles(.1, 0, -.1), wood, Enum.Material.Wood)
	for index = 1, 3 do
		local angle = index * math.pi * 2 / 3
		local tip = position + Vector3.new(math.cos(angle) * height * .32, height * (.72 + index * .045), math.sin(angle) * height * .32)
		Decoration.Beam(model, "GnarledBranch", position + Vector3.new(0, height * .43, 0), tip, height * .06, wood, Enum.Material.Wood)
		Decoration.Beam(model, "ExposedRoot", position + Vector3.new(0, 1, 0), position + Vector3.new(math.cos(angle) * height * .22, .15, math.sin(angle) * height * .22), 1.1, wood, Enum.Material.Wood)
		if not bare then
			Decoration.Ball(model, "Canopy", Vector3.new(height * .63, height * .42, height * .62), tip, foliage)
		end
	end
	return model
end

function Decoration.Rune(parent: Instance, position: Vector3, scale: number, accent: Color3)
	local rune = Decoration.Model(parent, "RunicSigil")
	for index = 1, 4 do
		local angle = index * math.pi / 2
		local nextAngle = (index + 1) * math.pi / 2
		Decoration.Beam(rune, "Glyph", position + Vector3.new(math.sin(angle) * scale, math.cos(angle) * scale, 0), position + Vector3.new(math.sin(nextAngle) * scale, math.cos(nextAngle) * scale, 0), .24, accent, Enum.Material.Neon)
	end
	Decoration.Part(rune, "Heart", Vector3.new(.35, scale * .7, .25), CFrame.new(position), accent, Enum.Material.Neon)
	return rune
end

return Decoration
