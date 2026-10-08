--!strict
-- Presentation and input only. The server owns damage, gates, objectives, and saves.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local packageRoot = ReplicatedStorage:WaitForChild("AetherDungeon")
local shared = packageRoot:WaitForChild("Shared")
local remotes = packageRoot:WaitForChild("Remotes")
local DungeonConfig = require(shared:WaitForChild("DungeonConfig"))
local NumberFormatter = require(shared:WaitForChild("NumberFormatter"))
local attackRemote = remotes:WaitForChild("Attack") :: RemoteEvent
local requestStateRemote = remotes:WaitForChild("RequestState") :: RemoteEvent
local stateRemote = remotes:WaitForChild("State") :: RemoteEvent
local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent

local COLORS = {
	Panel = Color3.fromRGB(17, 24, 33),
	Raised = Color3.fromRGB(28, 38, 48),
	Line = Color3.fromRGB(64, 75, 85),
	Text = Color3.fromRGB(246, 241, 226),
	Muted = Color3.fromRGB(167, 180, 183),
	Gold = Color3.fromRGB(234, 187, 107),
	Cyan = Color3.fromRGB(119, 223, 212),
	Red = Color3.fromRGB(233, 120, 117),
}
local ATTACK_RANGE = 16
local LOCAL_ATTACK_COOLDOWN = 0.66
local HEALTH_BAR_RANGE = 72

type DungeonState = {
	CurrentZone: number,
	HighestUnlocked: number,
	Kills: number,
	Required: number,
	Completed: boolean,
	DataStatus: string,
	SaveWritable: boolean,
}
type MonsterView = {
	Model: Model,
	Gui: BillboardGui,
	Fill: Frame,
	Value: TextLabel,
	NameLabel: TextLabel,
	Connections: {RBXScriptConnection},
	Tween: Tween?,
}
type GateView = {
	Model: Model,
	Gui: BillboardGui?,
	Label: TextLabel?,
	Connections: {RBXScriptConnection},
}

local state: DungeonState = {
	CurrentZone = 0,
	HighestUnlocked = 1,
	Kills = 0,
	Required = 5,
	Completed = false,
	DataStatus = "Loading",
	SaveWritable = false,
}
local monsterViews: {[Model]: MonsterView} = {}
local gateViews: {[Model]: GateView} = {}
local lifetimeConnections: {RBXScriptConnection} = {}
local selectedMonster: Model? = nil
local lastAttack = -math.huge
local running = true
local isCompact = false

local function create(className: string, properties: {[string]: any}, parent: Instance?): any
	local instance = Instance.new(className) :: any
	for key, value in pairs(properties) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function corner(parent: Instance, radius: number)
	create("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end

local function stroke(parent: Instance, color: Color3?, transparency: number?)
	return create("UIStroke", {
		Color = color or COLORS.Line,
		Thickness = 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function textLabel(parent: Instance, properties: {[string]: any}): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.Text,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for key, value in pairs(properties) do
		(defaults :: any)[key] = value
	end
	return create("TextLabel", defaults, parent)
end

local gui = create("ScreenGui", {
	Name = "EternalForgeHUD",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	DisplayOrder = 20,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui

local journey = create("Frame", {
	Name = "Journey",
	Position = UDim2.fromOffset(24, 22),
	Size = UDim2.fromOffset(368, 194),
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.06,
	BorderSizePixel = 0,
}, gui) :: Frame
corner(journey, 16)
stroke(journey, COLORS.Gold, 0.63)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(36, 44, 52), COLORS.Panel),
	Rotation = 115,
}, journey)
local brand = textLabel(journey, {
	Position = UDim2.fromOffset(18, 12),
	Size = UDim2.new(1, -110, 0, 18),
	Text = "E T E R N A L   F O R G E",
	TextColor3 = COLORS.Gold,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
})
local zoneNumber = textLabel(journey, {
	Position = UDim2.new(1, -92, 0, 12),
	Size = UDim2.fromOffset(72, 18),
	Text = "SANCTUARY",
	TextSize = 10,
	TextColor3 = COLORS.Muted,
	TextXAlignment = Enum.TextXAlignment.Right,
	Font = Enum.Font.GothamMedium,
})
local zoneName = textLabel(journey, {
	Position = UDim2.fromOffset(18, 38),
	Size = UDim2.new(1, -36, 0, 28),
	Text = "The journey begins",
	TextSize = 23,
	Font = Enum.Font.GothamBold,
})
local zoneSubtitle = textLabel(journey, {
	Position = UDim2.fromOffset(19, 71),
	Size = UDim2.new(1, -38, 0, 18),
	Text = "Follow the lanterns to the dungeon entrance.",
	TextSize = 11,
	TextColor3 = COLORS.Muted,
})
local journeyDivider = create("Frame", {
	Position = UDim2.fromOffset(18, 104),
	Size = UDim2.new(1, -36, 0, 1),
	BackgroundColor3 = COLORS.Line,
	BackgroundTransparency = 0.45,
	BorderSizePixel = 0,
}, journey)
local objectiveLabel = textLabel(journey, {
	Position = UDim2.fromOffset(19, 114),
	Size = UDim2.new(1, -100, 0, 18),
	Text = "YOUR NEXT CHAPTER",
	TextColor3 = COLORS.Cyan,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
})
local objectiveCount = textLabel(journey, {
	Position = UDim2.new(1, -85, 0, 113),
	Size = UDim2.fromOffset(66, 20),
	Text = "01 / 30",
	TextColor3 = COLORS.Gold,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Right,
})
local objectiveDetail = textLabel(journey, {
	Position = UDim2.fromOffset(19, 160),
	Size = UDim2.new(1, -38, 0, 17),
	Text = "A continuous adventure. Thirty ancient realms.",
	TextColor3 = COLORS.Muted,
	TextSize = 11,
})
local pips: {Frame} = {}
for index = 1, 5 do
	local pip = create("Frame", {
		Name = "Objective" .. tostring(index),
		Position = UDim2.new((index - 1) / 5, 19 - ((index - 1) * 6.4), 0, 143),
		Size = UDim2.new(0.2, -12, 0, 6),
		BorderSizePixel = 0,
		BackgroundColor3 = COLORS.Raised,
	}, journey) :: Frame
	corner(pip, 3)
	table.insert(pips, pip)
end

local milestone = create("Frame", {
	Name = "Milestone",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -24, 0, 22),
	Size = UDim2.fromOffset(180, 79),
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
}, gui) :: Frame
corner(milestone, 13)
stroke(milestone, COLORS.Line, 0.28)
local highestLabel = textLabel(milestone, {
	Position = UDim2.fromOffset(13, 11),
	Size = UDim2.new(1, -26, 0, 17),
	Text = "HIGHEST REALM   01 / 30",
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	TextColor3 = COLORS.Gold,
})
local saveDot = create("Frame", {
	Position = UDim2.fromOffset(14, 38),
	Size = UDim2.fromOffset(5, 5),
	BackgroundColor3 = COLORS.Muted,
	BorderSizePixel = 0,
}, milestone) :: Frame
corner(saveDot, 3)
local saveLabel = textLabel(milestone, {
	Position = UDim2.fromOffset(25, 31),
	Size = UDim2.new(1, -38, 0, 19),
	Text = "Loading progress",
	TextSize = 11,
	TextColor3 = COLORS.Muted,
})
local saveDetail = textLabel(milestone, {
	Position = UDim2.fromOffset(13, 55),
	Size = UDim2.new(1, -26, 0, 13),
	Text = "Connecting to your journey",
	TextSize = 9,
	TextColor3 = COLORS.Muted,
})

local attackButton = create("TextButton", {
	Name = "Attack",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -35, 1, -98),
	Size = UDim2.fromOffset(92, 92),
	Text = "",
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.04,
	BorderSizePixel = 0,
	AutoButtonColor = false,
	Selectable = true,
}, gui) :: TextButton
corner(attackButton, 46)
local attackStroke = stroke(attackButton, COLORS.Gold, 0.2)
local attackScale = create("UIScale", {Scale = 1}, attackButton) :: UIScale
-- An abstract forged blade, made from UI geometry rather than an external asset.
local blade = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.34),
	Size = UDim2.fromOffset(5, 28),
	Rotation = 38,
	BackgroundColor3 = COLORS.Gold,
	BorderSizePixel = 0,
}, attackButton) :: Frame
corner(blade, 2)
create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 1, -3),
	Size = UDim2.fromOffset(20, 4),
	BackgroundColor3 = COLORS.Gold,
	BorderSizePixel = 0,
}, blade)
local attackLabel = textLabel(attackButton, {
	Position = UDim2.fromScale(0, 0.60),
	Size = UDim2.new(1, 0, 0, 16),
	Text = "STRIKE",
	TextSize = 11,
	Font = Enum.Font.GothamBold,
	TextColor3 = COLORS.Gold,
	TextXAlignment = Enum.TextXAlignment.Center,
})
local attackKey = textLabel(attackButton, {
	Position = UDim2.fromScale(0, 0.79),
	Size = UDim2.new(1, 0, 0, 12),
	Text = if UserInputService.TouchEnabled then "TAP" else "F / CLICK",
	TextSize = 8,
	TextColor3 = COLORS.Muted,
	TextXAlignment = Enum.TextXAlignment.Center,
})

local hint = create("Frame", {
	Name = "CombatHint",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(328, 43),
	BackgroundColor3 = COLORS.Panel,
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
}, gui) :: Frame
corner(hint, 11)
stroke(hint, COLORS.Line, 0.5)
local hintLabel = textLabel(hint, {
	Position = UDim2.fromOffset(12, 0),
	Size = UDim2.new(1, -24, 1, 0),
	Text = "EXPLORE  /  Follow the path into the mountain",
	TextSize = 10,
	TextColor3 = COLORS.Muted,
	TextXAlignment = Enum.TextXAlignment.Center,
})

local selection = create("Highlight", {
	Name = "LocalCombatTarget",
	Enabled = false,
	FillTransparency = 0.94,
	OutlineTransparency = 0.28,
	FillColor = COLORS.Gold,
	OutlineColor = COLORS.Gold,
	DepthMode = Enum.HighlightDepthMode.Occluded,
}, gui) :: Highlight

local toastQueue: {{Title: string, Body: string, Kind: string}} = {}
local activeToast: Frame? = nil
local toastBusy = false
local lastNoticeKey = ""
local lastNoticeTime = -math.huge

local function toastLayout(): (UDim2, UDim2)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	if viewport.X < 1000 and viewport.Y < 480 then
		local width = math.max(180, math.min(280, viewport.X * 0.48 - 28))
		return UDim2.fromOffset(width, 81), UDim2.new(1, -14 - width / 2, 0, 12)
	end
	return UDim2.fromOffset(math.min(viewport.X - 28, 340), 81), UDim2.new(0.5, if isCompact then 0 else 94, 0, if isCompact then 220 else 22)
end

local function showNextToast()
	if toastBusy or #toastQueue == 0 or not running then
		return
	end
	toastBusy = true
	local notice = table.remove(toastQueue, 1)
	local accent = if notice.Kind == "Error" or notice.Kind == "Warning" then COLORS.Gold else COLORS.Cyan
	local toastSize, toastPosition = toastLayout()
	local toast = create("Frame", {
		Name = "Notification",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = toastPosition,
		Size = toastSize,
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ZIndex = 10,
	}, gui) :: Frame
	activeToast = toast
	corner(toast, 13)
	stroke(toast, accent, 0.3)
	create("Frame", {
		Position = UDim2.fromOffset(12, 16),
		Size = UDim2.fromOffset(3, 48),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, toast)
	textLabel(toast, {
		Position = UDim2.fromOffset(27, 13),
		Size = UDim2.new(1, -42, 0, 22),
		Text = notice.Title,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = accent,
		ZIndex = 11,
	})
	textLabel(toast, {
		Position = UDim2.fromOffset(27, 37),
		Size = UDim2.new(1, -42, 0, 33),
		Text = notice.Body,
		TextSize = 11,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextColor3 = COLORS.Text,
		ZIndex = 11,
	})
	local toastScale = create("UIScale", {Scale = 0.92}, toast) :: UIScale
	TweenService:Create(toastScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Scale = 1}):Play()
	task.delay(4.5, function()
		if toast.Parent then
			TweenService:Create(toastScale, TweenInfo.new(0.18), {Scale = 0.94}):Play()
			task.wait(0.18)
			toast:Destroy()
		end
		activeToast = nil
		toastBusy = false
		showNextToast()
	end)
end

local function notify(title: string, body: string, kind: string?)
	local key = title .. body
	if key == lastNoticeKey and os.clock() - lastNoticeTime < 3 then
		return
	end
	lastNoticeKey = key
	lastNoticeTime = os.clock()
	if #toastQueue >= 3 then
		table.remove(toastQueue, 1)
	end
	table.insert(toastQueue, {Title = title, Body = body, Kind = kind or "Info"})
	showNextToast()
end

local function renderState()
	local zone = DungeonConfig.Zones[state.CurrentZone]
	local inDungeon = zone ~= nil
	local accent = if zone and typeof(zone.AccentColor) == "Color3" then zone.AccentColor else COLORS.Cyan
	zoneNumber.Text = if inDungeon then string.format("REALM %02d / 30", state.CurrentZone) else "SANCTUARY"
	zoneName.Text = if zone then zone.Name else "The journey begins"
	zoneSubtitle.Text = if zone then (zone.Subtitle or zone.Theme or "Five guardians stand between you and the next realm.") else "Follow the lanterns to the dungeon entrance."
	objectiveLabel.TextColor3 = accent
	highestLabel.Text = string.format("HIGHEST REALM   %02d / 30", state.HighestUnlocked)
	local cleared = inDungeon and (state.HighestUnlocked > state.CurrentZone or (state.CurrentZone == 30 and state.Completed))
	if state.Completed and state.CurrentZone == 30 then
		objectiveLabel.Text = "LEGEND FORGED"
		objectiveCount.Text = "30 / 30"
		objectiveDetail.Text = "All realms conquered. Your journey is remembered."
	elseif cleared then
		objectiveLabel.Text = "REALM CONQUERED"
		objectiveCount.Text = "5 / 5"
		objectiveDetail.Text = "The path is open. Walk forward when you are ready."
	elseif inDungeon then
		objectiveLabel.Text = "DEFEAT THE FIVE GUARDIANS"
		objectiveCount.Text = string.format("%d / %d", state.Kills, state.Required)
		objectiveDetail.Text = if state.CurrentZone == 30 then "Defeat each guardian to complete your journey." else "Defeat each guardian to open the next gate."
	else
		objectiveLabel.Text = if state.Completed then "ALL THIRTY REALMS CONQUERED" else "YOUR NEXT CHAPTER"
		objectiveCount.Text = string.format("%02d / 30", state.HighestUnlocked)
		objectiveDetail.Text = "A continuous adventure. Thirty ancient realms."
	end
	for index, pip in ipairs(pips) do
		local filled = if inDungeon then (cleared or index <= state.Kills) else index <= math.ceil(state.HighestUnlocked / 6)
		TweenService:Create(pip, TweenInfo.new(0.24), {
			BackgroundColor3 = if filled then accent else COLORS.Raised,
		}):Play()
	end
	local status = string.lower(state.DataStatus)
	local sessionOnly = status == "sessiononly" or status == "session_only" or status == "session" or status == "error" or status == "failed" or status == "unavailable"
		or ((status == "savefailed" or status == "save_failed") and not state.SaveWritable)
	if sessionOnly then
		saveLabel.Text = "Session progress only"
		saveDetail.Text = "Progress is not saved between visits"
		saveLabel.TextColor3 = COLORS.Gold
		saveDot.BackgroundColor3 = COLORS.Gold
	elseif status == "savefailed" or status == "save_failed" then
		saveLabel.Text = "Save delayed"
		saveDetail.Text = "Retrying automatically"
		saveLabel.TextColor3 = COLORS.Gold
		saveDot.BackgroundColor3 = COLORS.Gold
	elseif status == "loading" then
		saveLabel.Text = "Loading progress"
		saveDetail.Text = "Connecting to your journey"
		saveLabel.TextColor3 = COLORS.Muted
		saveDot.BackgroundColor3 = COLORS.Muted
	elseif status == "saving" then
		saveLabel.Text = "Saving your journey"
		saveDetail.Text = "Progress saves automatically"
		saveLabel.TextColor3 = COLORS.Muted
		saveDot.BackgroundColor3 = COLORS.Gold
	else
		saveLabel.Text = if status == "saved" then "Progress saved" else "Progress connected"
		saveDetail.Text = "Progress saves automatically"
		saveLabel.TextColor3 = COLORS.Cyan
		saveDot.BackgroundColor3 = COLORS.Cyan
	end
end

local function removeMonster(model: Model)
	local view = monsterViews[model]
	if not view then
		return
	end
	monsterViews[model] = nil
	if view.Tween then
		view.Tween:Cancel()
	end
	for _, connection in ipairs(view.Connections) do
		connection:Disconnect()
	end
	view.Gui:Destroy()
	if selectedMonster == model then
		selectedMonster = nil
		selection.Adornee = nil
		selection.Enabled = false
	end
end

local function addMonster(instance: Instance)
	if not instance:IsA("Model") or monsterViews[instance] or not instance:IsDescendantOf(workspace) then
		return
	end
	local model = instance :: Model
	local healthGui = create("BillboardGui", {
		Name = "LocalMonsterHealth",
		Size = UDim2.fromOffset(218, 58),
		StudsOffsetWorldSpace = Vector3.new(0, 4.8, 0),
		MaxDistance = HEALTH_BAR_RANGE,
		AlwaysOnTop = false,
		LightInfluence = 0,
		Enabled = false,
		Adornee = model.PrimaryPart,
	}, gui) :: BillboardGui
	local nameLabel = textLabel(healthGui, {
		Size = UDim2.new(1, 0, 0, 21),
		Text = tostring(model:GetAttribute("DisplayName") or "Dungeon guardian"),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeColor3 = COLORS.Panel,
		TextStrokeTransparency = 0.3,
	})
	local track = create("Frame", {
		Position = UDim2.fromOffset(17, 24),
		Size = UDim2.new(1, -34, 0, 8),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, healthGui) :: Frame
	corner(track, 4)
	stroke(track, COLORS.Line, 0.35)
	local fill = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLORS.Cyan,
		BorderSizePixel = 0,
	}, track) :: Frame
	corner(fill, 4)
	local valueLabel = textLabel(healthGui, {
		Position = UDim2.fromOffset(0, 35),
		Size = UDim2.new(1, 0, 0, 17),
		Text = "",
		TextSize = 11,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeColor3 = COLORS.Panel,
		TextStrokeTransparency = 0.25,
	})
	local view: MonsterView = {
		Model = model,
		Gui = healthGui,
		Fill = fill,
		Value = valueLabel,
		NameLabel = nameLabel,
		Connections = {},
		Tween = nil,
	}
	monsterViews[model] = view
	local firstUpdate = true
	local function updateHealth()
		if not monsterViews[model] then
			return
		end
		local hp = model:GetAttribute("HP")
		local maxHP = model:GetAttribute("MaxHP")
		if typeof(hp) ~= "number" or typeof(maxHP) ~= "number" then
			healthGui.Enabled = false
			return
		end
		local ratio = NumberFormatter.Ratio(hp, maxHP)
		valueLabel.Text = NumberFormatter.Format(hp) .. " / " .. NumberFormatter.Format(maxHP)
		nameLabel.Text = tostring(model:GetAttribute("DisplayName") or "Dungeon guardian")
		local fillColor = if ratio <= 0.25 then COLORS.Red elseif ratio <= 0.55 then COLORS.Gold else COLORS.Cyan
		if view.Tween then
			view.Tween:Cancel()
		end
		if firstUpdate then
			fill.Size = UDim2.fromScale(ratio, 1)
			fill.BackgroundColor3 = fillColor
			firstUpdate = false
		else
			view.Tween = TweenService:Create(fill, TweenInfo.new(0.20, Enum.EasingStyle.Quad), {
				Size = UDim2.fromScale(ratio, 1),
				BackgroundColor3 = fillColor,
			})
			local healthTween = view.Tween :: Tween
			healthTween:Play()
		end
		if hp <= 0 then
			healthGui.Enabled = false
		end
	end
	for _, attribute in ipairs({"HP", "MaxHP", "DisplayName"}) do
		table.insert(view.Connections, model:GetAttributeChangedSignal(attribute):Connect(updateHealth))
	end
	table.insert(view.Connections, model:GetPropertyChangedSignal("PrimaryPart"):Connect(function()
		healthGui.Adornee = model.PrimaryPart
	end))
	table.insert(view.Connections, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			removeMonster(model)
		end
	end))
	updateHealth()
end

local function updateGate(view: GateView)
	local zoneId = view.Model:GetAttribute("ZoneId")
	if typeof(zoneId) ~= "number" then
		return
	end
	local open = if zoneId >= 30 then state.Completed else state.HighestUnlocked > zoneId
	local color = if open then COLORS.Cyan else COLORS.Gold
	local barrier: BasePart? = nil
	for _, descendant in ipairs(view.Model:GetDescendants()) do
		if descendant:IsA("BasePart") and (descendant.Name == "Barrier" or descendant.Name == "ForceField" or descendant.Name == "Veil" or descendant:GetAttribute("GateBarrier") == true) then
			-- These local cosmetic changes never grant access. The server validates movement.
			descendant.Color = color
			descendant.LocalTransparencyModifier = if open then 0.86 else 0.12
			barrier = descendant
		end
	end
	if barrier and not view.Gui then
		local gateGui = create("BillboardGui", {
			Name = "LocalGateStatus",
			Size = UDim2.fromOffset(240, 35),
			StudsOffsetWorldSpace = Vector3.new(0, -1.5, 0),
			MaxDistance = 62,
			AlwaysOnTop = false,
			Adornee = barrier,
		}, gui) :: BillboardGui
		view.Gui = gateGui
		view.Label = textLabel(gateGui, {
			Size = UDim2.fromScale(1, 1),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Enum.Font.GothamBold,
			TextStrokeColor3 = COLORS.Panel,
			TextStrokeTransparency = 0.2,
		})
	end
	if view.Label then
		view.Label.TextColor3 = color
		view.Label.Text = if open then (if zoneId >= 30 then "JOURNEY COMPLETE" else "PATH OPEN  /  WALK FORWARD") else "DEFEAT ALL FIVE GUARDIANS"
	end
	if view.Gui and barrier then
		view.Gui.Adornee = barrier
	end
end

local function removeGate(model: Model)
	local view = gateViews[model]
	if not view then
		return
	end
	gateViews[model] = nil
	for _, connection in ipairs(view.Connections) do
		connection:Disconnect()
	end
	if view.Gui then
		view.Gui:Destroy()
	end
end

local function addGate(instance: Instance)
	if not instance:IsA("Model") or gateViews[instance] or not instance:IsDescendantOf(workspace) then
		return
	end
	local model = instance :: Model
	local view: GateView = {Model = model, Gui = nil, Label = nil, Connections = {}}
	gateViews[model] = view
	table.insert(view.Connections, model:GetAttributeChangedSignal("ZoneId"):Connect(function()
		updateGate(view)
	end))
	table.insert(view.Connections, model.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			updateGate(view)
		end
	end))
	table.insert(view.Connections, model.DescendantRemoving:Connect(function(descendant)
		if view.Gui and view.Gui.Adornee == descendant then
			view.Gui:Destroy()
			view.Gui = nil
			view.Label = nil
		end
	end))
	table.insert(view.Connections, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			removeGate(model)
		end
	end))
	updateGate(view)
end

local function currentRoot(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function nearestMonster(root: BasePart): Model?
	local nearest: Model? = nil
	local bestDistance = ATTACK_RANGE
	for model in pairs(monsterViews) do
		local primary = model.PrimaryPart
		local hp = model:GetAttribute("HP")
		if primary and model:GetAttribute("ZoneId") == state.CurrentZone and typeof(hp) == "number" and hp > 0 then
			local distance = (primary.Position - root.Position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				nearest = model
			end
		end
	end
	return nearest
end

local function attack()
	if UserInputService:GetFocusedTextBox() then
		return
	end
	local now = os.clock()
	if now - lastAttack < LOCAL_ATTACK_COOLDOWN then
		return
	end
	local root = currentRoot()
	if not root then
		return
	end
	local target = nearestMonster(root)
	if not target then
		notify("Move closer to a guardian", "Enter the arena and approach a foe to strike.", "Info")
		return
	end
	local monsterId = target:GetAttribute("MonsterId")
	if typeof(monsterId) ~= "string" then
		return
	end
	lastAttack = now
	-- Target identity is the only client combat argument; damage comes from trusted server data.
	attackRemote:FireServer(monsterId)
	attackScale.Scale = 0.9
	TweenService:Create(attackScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), {Scale = 1}):Play()
end

table.insert(lifetimeConnections, attackButton.Activated:Connect(attack))
table.insert(lifetimeConnections, UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 or input.UserInputType == Enum.UserInputType.MouseButton1 then
		attack()
	end
end))

table.insert(lifetimeConnections, stateRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	for _, key in ipairs({"CurrentZone", "HighestUnlocked", "Kills", "Required"}) do
		if typeof(payload[key]) == "number" and payload[key] == payload[key] then
			(state :: any)[key] = math.floor(payload[key])
		end
	end
	state.CurrentZone = math.clamp(state.CurrentZone, 0, 30)
	state.HighestUnlocked = math.clamp(state.HighestUnlocked, 1, 30)
	state.Required = math.max(1, state.Required)
	state.Kills = math.clamp(state.Kills, 0, state.Required)
	if typeof(payload.Completed) == "boolean" then
		state.Completed = payload.Completed
	end
	if typeof(payload.DataStatus) == "string" then
		state.DataStatus = payload.DataStatus
	end
	if typeof(payload.SaveWritable) == "boolean" then
		state.SaveWritable = payload.SaveWritable
	end
	renderState()
	for _, view in pairs(gateViews) do
		updateGate(view)
	end
end))
table.insert(lifetimeConnections, notifyRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" and typeof(payload.Title) == "string" and typeof(payload.Body) == "string" then
		notify(payload.Title, payload.Body, payload.Kind)
	end
end))

local function damageFeedback(payload: any)
	if typeof(payload) ~= "table" or typeof(payload.Position) ~= "Vector3" or typeof(payload.Amount) ~= "number" then
		return
	end
	local marker = create("Part", {
		Name = "LocalDamageFeedback",
		Size = Vector3.new(0.1, 0.1, 0.1),
		Position = payload.Position + Vector3.new(0, 3.1, 0),
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Transparency = 1,
		CastShadow = false,
	}, workspace) :: Part
	local popup = create("BillboardGui", {
		Size = UDim2.fromOffset(150, 42),
		Adornee = marker,
		AlwaysOnTop = false,
		MaxDistance = 80,
	}, marker) :: BillboardGui
	local damage = textLabel(popup, {
		Size = UDim2.fromScale(1, 1),
		Text = "−" .. NumberFormatter.Format(payload.Amount),
		TextSize = if payload.Killed then 25 else 21,
		Font = Enum.Font.GothamBold,
		TextColor3 = if payload.Killed then COLORS.Gold else COLORS.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeColor3 = COLORS.Panel,
		TextStrokeTransparency = 0.15,
	})
	TweenService:Create(marker, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = marker.Position + Vector3.new(0, 2.6, 0),
	}):Play()
	TweenService:Create(damage, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.24), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(marker, 0.85)
	local root = currentRoot()
	if root then
		local direction = payload.Position - root.Position
		if direction.Magnitude > 0.1 then
			local slash = create("Part", {
				Name = "LocalStrikeSpark",
				Size = Vector3.new(3.3, 0.08, 0.08),
				CFrame = CFrame.lookAt(root.Position + direction.Unit * 2.6, payload.Position) * CFrame.Angles(0, 0, math.rad(35)),
				Color = COLORS.Gold,
				Material = Enum.Material.Neon,
				Anchored = true,
				CanCollide = false,
				CanTouch = false,
				CanQuery = false,
				CastShadow = false,
			}, workspace) :: Part
			TweenService:Create(slash, TweenInfo.new(0.16), {Transparency = 1, Size = Vector3.new(5, 0.04, 0.04)}):Play()
			Debris:AddItem(slash, 0.2)
		end
	end
end

local connectedFeedback: RemoteEvent? = nil
local function connectFeedback(instance: Instance)
	if instance.Name == "DamageFeedback" and instance:IsA("RemoteEvent") and connectedFeedback ~= instance then
		connectedFeedback = instance
		table.insert(lifetimeConnections, instance.OnClientEvent:Connect(damageFeedback))
	end
end
local existingFeedback = remotes:FindFirstChild("DamageFeedback")
if existingFeedback then
	connectFeedback(existingFeedback)
end
table.insert(lifetimeConnections, remotes.ChildAdded:Connect(connectFeedback))

local function resize()
	local camera = workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	local short = camera ~= nil and camera.ViewportSize.Y < 480
	isCompact = width < 1000
	zoneSubtitle.Visible = not (short and isCompact)
	hint.Visible = not (short and isCompact)
	if isCompact then
		local cardWidth = if short then math.min(width * 0.46, 300) else math.min(width - 28, 368)
		journey.Position = UDim2.fromOffset(14, 12)
		journey.Size = UDim2.fromOffset(cardWidth, if short then 136 else 164)
		brand.TextSize = 9
		zoneName.TextSize = if width < 360 then 19 else 21
		zoneName.Position = UDim2.fromOffset(18, 34)
		zoneSubtitle.Position = UDim2.fromOffset(19, 66)
		journeyDivider.Position = UDim2.fromOffset(18, if short then 68 else 90)
		objectiveLabel.Position = UDim2.fromOffset(19, if short then 76 else 98)
		objectiveCount.Position = UDim2.new(1, -85, 0, if short then 75 else 97)
		objectiveDetail.Position = UDim2.fromOffset(19, if short then 113 else 139)
		objectiveDetail.TextSize = 10
		for _, pip in ipairs(pips) do
			pip.Position = UDim2.new(pip.Position.X.Scale, pip.Position.X.Offset, 0, if short then 102 else 125)
		end
		milestone.AnchorPoint = Vector2.new(0, 0)
		milestone.Position = UDim2.fromOffset(14, if short then 156 else 184)
		milestone.Size = UDim2.fromOffset(cardWidth, 28)
		highestLabel.Position = UDim2.fromOffset(10, 5)
		highestLabel.Size = UDim2.fromOffset(math.floor(cardWidth * 0.48), 17)
		highestLabel.TextSize = 9
		saveDot.Position = UDim2.new(0.52, 0, 0, 12)
		saveLabel.Position = UDim2.new(0.52, 10, 0, 5)
		saveLabel.Size = UDim2.new(0.48, -17, 0, 17)
		saveLabel.TextSize = 9
		saveDetail.Visible = false
		hint.Size = UDim2.fromOffset(math.min(width - 32, 328), 32)
		hint.Position = UDim2.new(0.5, 0, 1, -10)
		hintLabel.TextSize = 9
		attackButton.Position = UDim2.new(1, -24, 1, if short then -120 else -147)
		attackButton.Size = UDim2.fromOffset(82, 82)
	else
		journey.Position = UDim2.fromOffset(24, 22)
		journey.Size = UDim2.fromOffset(368, 194)
		brand.TextSize = 10
		zoneName.TextSize = 23
		zoneName.Position = UDim2.fromOffset(18, 38)
		zoneSubtitle.Position = UDim2.fromOffset(19, 71)
		journeyDivider.Position = UDim2.fromOffset(18, 104)
		objectiveLabel.Position = UDim2.fromOffset(19, 114)
		objectiveCount.Position = UDim2.new(1, -85, 0, 113)
		objectiveDetail.Position = UDim2.fromOffset(19, 160)
		objectiveDetail.TextSize = 11
		for _, pip in ipairs(pips) do
			pip.Position = UDim2.new(pip.Position.X.Scale, pip.Position.X.Offset, 0, 143)
		end
		milestone.AnchorPoint = Vector2.new(1, 0)
		milestone.Position = UDim2.new(1, -24, 0, 22)
		milestone.Size = UDim2.fromOffset(180, 79)
		highestLabel.Position = UDim2.fromOffset(13, 11)
		highestLabel.Size = UDim2.new(1, -26, 0, 17)
		highestLabel.TextSize = 10
		saveDot.Position = UDim2.fromOffset(14, 38)
		saveLabel.Position = UDim2.fromOffset(25, 31)
		saveLabel.Size = UDim2.new(1, -38, 0, 19)
		saveLabel.TextSize = 11
		saveDetail.Visible = true
		hint.Size = UDim2.fromOffset(328, 43)
		hint.Position = UDim2.new(0.5, 0, 1, -24)
		hintLabel.TextSize = 10
		attackButton.Position = UDim2.new(1, -35, 1, if UserInputService.TouchEnabled then -147 else -98)
		attackButton.Size = UDim2.fromOffset(92, 92)
	end
	if activeToast then
		activeToast.Size, activeToast.Position = toastLayout()
	end
end

local cameraConnection: RBXScriptConnection? = nil
local function bindCamera()
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	local camera = workspace.CurrentCamera
	if camera then
		cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	end
	resize()
end
table.insert(lifetimeConnections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
table.insert(lifetimeConnections, UserInputService.LastInputTypeChanged:Connect(function(inputType)
	attackKey.Text = if inputType == Enum.UserInputType.Touch then "TAP" elseif inputType == Enum.UserInputType.Gamepad1 then "R2" else "F / CLICK"
end))

-- Tags reconnect automatically as models stream in. All model-owned listeners are removed on stream-out.
table.insert(lifetimeConnections, CollectionService:GetInstanceAddedSignal("AetherMonster"):Connect(addMonster))
table.insert(lifetimeConnections, CollectionService:GetInstanceRemovedSignal("AetherMonster"):Connect(function(instance)
	if instance:IsA("Model") then
		removeMonster(instance)
	end
end))
table.insert(lifetimeConnections, CollectionService:GetInstanceAddedSignal("AetherGate"):Connect(addGate))
table.insert(lifetimeConnections, CollectionService:GetInstanceRemovedSignal("AetherGate"):Connect(function(instance)
	if instance:IsA("Model") then
		removeGate(instance)
	end
end))
-- Name discovery supports authored gates that have no tag; each gate is registered only once.
table.insert(lifetimeConnections, workspace.DescendantAdded:Connect(function(instance)
	if instance.Name == "ExitGate" and instance:IsA("Model") then
		addGate(instance)
	end
end))
for _, model in ipairs(CollectionService:GetTagged("AetherMonster")) do
	addMonster(model)
end
for _, model in ipairs(CollectionService:GetTagged("AetherGate")) do
	addGate(model)
end
local world = workspace:FindFirstChild("AetherWorld")
if world then
	for _, descendant in ipairs(world:GetDescendants()) do
		if descendant.Name == "ExitGate" and descendant:IsA("Model") then
			addGate(descendant)
		end
	end
end

-- One bounded 3 Hz scheduler for all streamed bars and target selection, never one loop per monster.
task.spawn(function()
	while running do
		local root = currentRoot()
		selectedMonster = if root then nearestMonster(root) else nil
		selection.Adornee = selectedMonster
		selection.Enabled = selectedMonster ~= nil
		local canAttack = selectedMonster ~= nil
		attackStroke.Color = if canAttack then COLORS.Gold else COLORS.Line
		attackLabel.TextColor3 = if canAttack then COLORS.Gold else COLORS.Muted
		blade.BackgroundColor3 = if canAttack then COLORS.Gold else COLORS.Muted
		if selectedMonster then
			hintLabel.Text = "TARGET  /  " .. tostring(selectedMonster:GetAttribute("DisplayName") or "Dungeon guardian")
			hintLabel.TextColor3 = COLORS.Gold
		elseif state.CurrentZone > 0 then
			hintLabel.Text = "TRAINING STRIKE  /  Move close to a guardian"
			hintLabel.TextColor3 = COLORS.Muted
		else
			hintLabel.Text = "EXPLORE  /  Follow the path into the mountain"
			hintLabel.TextColor3 = COLORS.Muted
		end
		for model, view in pairs(monsterViews) do
			local primary = model.PrimaryPart
			local hp = model:GetAttribute("HP")
			view.Gui.Enabled = root ~= nil and primary ~= nil and typeof(hp) == "number" and hp > 0
				and (primary.Position - root.Position).Magnitude <= HEALTH_BAR_RANGE
		end
		task.wait(0.3)
	end
end)

script.Destroying:Connect(function()
	running = false
	if cameraConnection then
		cameraConnection:Disconnect()
	end
	for _, connection in ipairs(lifetimeConnections) do
		connection:Disconnect()
	end
	for model in pairs(monsterViews) do
		removeMonster(model)
	end
	for model in pairs(gateViews) do
		removeGate(model)
	end
	gui:Destroy()
end)

renderState()
bindCamera()
requestStateRemote:FireServer()
