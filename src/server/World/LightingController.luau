--!strict

-- The same scene contains an open-air hub and enclosed dungeon. Warm late-day
-- sunlight keeps the hub readable while roofed rooms get their colour from
-- emissive fixtures. We deliberately avoid depth of field, heavy bloom, and
-- changing Lighting.Technology (which is not script-writable on every client).
-- Only a handful of hub fixtures use real lights, so mobile GPUs keep headroom.
local Lighting = game:GetService("Lighting")

local LightingController = {}
local OWNED_ATTRIBUTE = "DungeonSimulatorLighting"

function LightingController.Apply()
	for _, child in Lighting:GetChildren() do
		if child:GetAttribute(OWNED_ATTRIBUTE) == true then
			child:Destroy()
		end
	end

	Lighting.ClockTime = 17.1
	Lighting.GeographicLatitude = 33
	Lighting.Brightness = 2.1
	Lighting.Ambient = Color3.fromRGB(64, 73, 92)
	Lighting.OutdoorAmbient = Color3.fromRGB(133, 142, 162)
	Lighting.ColorShift_Top = Color3.fromRGB(22, 12, 0)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 8)
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.55
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.ExposureCompensation = 0.15
	Lighting.FogColor = Color3.fromRGB(161, 183, 187)
	Lighting.FogStart = 180
	Lighting.FogEnd = 750

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "DungeonSimulator_Atmosphere"
	atmosphere:SetAttribute(OWNED_ATTRIBUTE, true)
	atmosphere.Density = 0.24
	atmosphere.Offset = 0.08
	atmosphere.Color = Color3.fromRGB(198, 216, 219)
	atmosphere.Decay = Color3.fromRGB(119, 129, 159)
	atmosphere.Glare = 0.12
	atmosphere.Haze = 1.5
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "DungeonSimulator_Bloom"
	bloom:SetAttribute(OWNED_ATTRIBUTE, true)
	bloom.Intensity = 0.23
	bloom.Size = 22
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local colour = Instance.new("ColorCorrectionEffect")
	colour.Name = "DungeonSimulator_Colour"
	colour:SetAttribute(OWNED_ATTRIBUTE, true)
	colour.Brightness = 0.01
	colour.Contrast = 0.09
	colour.Saturation = -0.03
	colour.TintColor = Color3.fromRGB(255, 247, 232)
	colour.Parent = Lighting

	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "DungeonSimulator_SunRays"
	sunRays:SetAttribute(OWNED_ATTRIBUTE, true)
	sunRays.Intensity = 0.025
	sunRays.Spread = 0.65
	sunRays.Parent = Lighting
end

return LightingController
