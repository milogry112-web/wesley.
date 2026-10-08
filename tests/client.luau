-- Execute the real client script against Lune's instance model. Signals,
-- tweens and input are deterministic test doubles; this does NOT render UI.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local signals = {}
local nextSignalId = 0
local function signal(object, name)
	-- Lune may return fresh userdata handles for one Instance reference. Assign a
	-- test-only ID so events use engine identity rather than userdata table keys.
	if typeof(object) == "Instance" then
		local id = object:GetAttribute("TestSignalId")
		if id == nil then
			nextSignalId += 1
			id = nextSignalId
			object:SetAttribute("TestSignalId", id)
		end
		object = "instance:" .. tostring(id)
	end
	if not signals[object] then signals[object] = {} end
	if signals[object][name] then return signals[object][name] end
	local callbacks = {}
	local event = {}
	function event:Connect(callback)
		callbacks[callback] = true
		return { Disconnect = function() callbacks[callback] = nil end }
	end
	function event:Fire(...)
		for callback in table.clone(callbacks) do callback(...) end
	end
	signals[object][name] = event
	return event
end

for _, name in { "AncestryChanged", "Destroying", "DescendantAdded", "DescendantRemoving", "ChildAdded" } do
	r.implementProperty("Instance", name, function(object) return signal(object, name) end)
end
r.implementProperty("GuiButton", "Activated", function(object) return signal(object, "Activated") end)
r.implementProperty("RemoteEvent", "OnClientEvent", function(object) return signal(object, "OnClientEvent") end)
r.implementMethod("Instance", "GetPropertyChangedSignal", function(object, property) return signal(object, "property:" .. property) end)
r.implementMethod("Instance", "GetAttributeChangedSignal", function(object, attribute) return signal(object, "attribute:" .. attribute) end)
r.implementMethod("Instance", "WaitForChild", function(object, name) return assert(object:FindFirstChild(name), name) end)
r.implementProperty("BasePart", "Position", function(part) return part.CFrame.Position end)
local requests = {}
r.implementMethod("RemoteEvent", "FireServer", function(remote, ...) table.insert(requests, { Remote = remote.Name, Arguments = table.pack(...) }) end)

local workspace = r.Instance.new("Workspace")
local camera = r.Instance.new("Camera")
local viewport = r.Vector2.new(1280, 720)
camera.ViewportSize = viewport
camera.Parent = workspace
workspace.CurrentCamera = camera
local guiParent = r.Instance.new("PlayerGui")
local character = r.Instance.new("Model")
local root = r.Instance.new("Part")
root.Name = "HumanoidRootPart"
root.CFrame = r.CFrame.new(0, 4, 25)
root.Position = root.CFrame.Position
root.Parent = character
character.Parent = workspace
local localPlayer = { Character = character, WaitForChild = function(_, name) assert(name == "PlayerGui"); return guiParent end }
local remotes = r.Instance.new("Folder")
for _, name in { "Attack", "RequestState", "State", "Notify", "DamageFeedback" } do
	local remote = r.Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
local env = table.clone(r)
local config = luau.load(fs.readFile("src/shared/DungeonConfig.luau"), { environment = env })()
local formatter = luau.load(fs.readFile("src/shared/NumberFormatter.luau"))()
local shared = { WaitForChild = function(_, name) return if name == "DungeonConfig" then config else formatter end }
local package = { WaitForChild = function(_, name) return if name == "Shared" then shared else remotes end }
local collection = {}
function collection:GetTagged(tag)
	local result = {}
	for _, object in workspace:GetDescendants() do
		if object:HasTag(tag) then table.insert(result, object) end
	end
	return result
end
function collection:GetInstanceAddedSignal(tag) return signal(collection, "add:" .. tag) end
function collection:GetInstanceRemovedSignal(tag) return signal(collection, "remove:" .. tag) end
local input = { TouchEnabled = false, GetFocusedTextBox = function() return nil end }
input.InputBegan = signal(input, "began")
input.LastInputTypeChanged = signal(input, "type")
local pendingThreads = {}
env.task = {
	spawn = function(callback) table.insert(pendingThreads, coroutine.create(callback)) end,
	delay = function() end,
	wait = function() coroutine.yield() end,
}
local services = {
	Players = { LocalPlayer = localPlayer },
	ReplicatedStorage = { WaitForChild = function() return package end },
	CollectionService = collection, UserInputService = input,
	TweenService = { Create = function(_, object, _, properties)
		return { Play = function() for key, value in properties do object[key] = value end end, Cancel = function() end }
	end },
	Debris = { AddItem = function() end },
}
env.game = { GetService = function(_, name) return assert(services[name], name) end }
env.workspace = workspace
env.require = function(value) return value end
env.TweenInfo = { new = function() return {} end }
env.script = { Destroying = signal({}, "scriptDestroying") }
luau.load(fs.readFile("src/client/DungeonClient.client.luau"), { environment = env, debugName = "DungeonClient" })()

local passed = 0
local function test(name, callback)
	local ok, message = pcall(callback)
	assert(ok, name .. ": " .. tostring(message))
	passed += 1
	print("PASS: " .. name)
end
local hud = guiParent:FindFirstChild("EternalForgeHUD")
local function hasText(text)
	for _, object in hud:GetDescendants() do
		if object:IsA("TextLabel") and object.Text == text then return true end
	end
	return false
end
local function state(highest, status, writable)
	signal(remotes.State, "OnClientEvent"):Fire({ CurrentZone = 1, HighestUnlocked = highest, Kills = 3, Required = 5, Completed = false, DataStatus = status, SaveWritable = writable })
end

test("the actual client constructs desktop HUD and requests server state", function()
	assert(hud and not hud.ResetOnSpawn)
	assert(hud.Journey.Size.X.Offset == 368)
	assert(#requests == 1 and requests[1].Remote == "RequestState")
end)
test("replicated state updates objectives and distinguishes failed reads from retrying saves", function()
	state(1, "SaveFailed", false)
	assert(hasText("3 / 5") and hasText("Session progress only"))
	state(1, "SaveFailed", true)
	assert(hasText("Save delayed"))
	state(1, "Saved", true)
	assert(hasText("Progress saved"))
end)
test("phone viewport recalculates card width and keeps attack control on screen", function()
	viewport = r.Vector2.new(320, 568)
	camera.ViewportSize = viewport
	signal(camera, "property:ViewportSize"):Fire()
	assert(hud.Journey.Size.X.Offset == 292)
	assert(hud.Journey.Position.X.Offset == 14)
	assert(hud.Attack.Size.X.Offset >= 44 and hud.Attack.Size.Y.Offset >= 44)
	camera.ViewportSize = r.Vector2.new(568, 320)
	signal(camera, "property:ViewportSize"):Fire()
	assert(hud.Journey.Size.Y.Offset == 136 and hud.Journey.Size.X.Offset < 300)
	assert(not hud.CombatHint.Visible)
end)
test("streamed monster UI appears, input sends only target identity, and cleanup removes it", function()
	local monster = r.Instance.new("Model")
	local body = r.Instance.new("Part")
	body.Name = "Root"
	body.CFrame = r.CFrame.new(0, 4, 30)
	body.Position = body.CFrame.Position
	body.Parent = monster
	monster.PrimaryPart = body
	monster:SetAttribute("HP", 5)
	monster:SetAttribute("MaxHP", 5)
	monster:SetAttribute("ZoneId", 1)
	monster:SetAttribute("MonsterId", "zone:01:slot:1")
	monster:SetAttribute("DisplayName", "Oathbound Sentinel")
	monster.Parent = workspace
	collection:GetInstanceAddedSignal("AetherMonster"):Fire(monster)
	assert(hud:FindFirstChild("LocalMonsterHealth"))
	input.InputBegan:Fire({ KeyCode = r.Enum.KeyCode.F, UserInputType = r.Enum.UserInputType.Keyboard }, false)
	assert(requests[#requests].Remote == "Attack")
	assert(requests[#requests].Arguments.n == 1 and requests[#requests].Arguments[1] == "zone:01:slot:1")
	collection:GetInstanceRemovedSignal("AetherMonster"):Fire(monster)
	assert(not hud:FindFirstChild("LocalMonsterHealth"))
end)
test("local gate presentation follows only this player's unlock", function()
	local gate = r.Instance.new("Model")
	gate.Name = "ExitGate"
	gate:SetAttribute("ZoneId", 1)
	local barrier = r.Instance.new("Part")
	barrier.Name = "Barrier"
	barrier.Parent = gate
	gate.Parent = workspace
	collection:GetInstanceAddedSignal("AetherGate"):Fire(gate)
	state(1, "Saved", true)
	assert(hasText("DEFEAT ALL FIVE GUARDIANS"))
	state(2, "Saved", true)
	assert(hasText("PATH OPEN  /  WALK FORWARD"))
	collection:GetInstanceRemovedSignal("AetherGate"):Fire(gate)
	assert(not hud:FindFirstChild("LocalGateStatus"))
end)
test("client destruction cleans its screen GUI and owned listeners", function()
	env.script.Destroying:Fire()
	assert(not guiParent:FindFirstChild("EternalForgeHUD"))
end)
print(string.format("%d actual-client construction/decision tests passed (no rendered GUI)", passed))
