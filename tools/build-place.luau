-- Bake the real static generators into the Rojo place for edit-mode inspection.
-- Roblox Bootstrap regenerates its own root during Play, without duplicates.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local path = "build/EternalForge.rbxlx"
local place = roblox.deserializePlace(fs.readFile(path))
local fixture = require("./world-fixture")(place)
local world = fixture.Generate()
fs.writeFile(path, roblox.serializePlace(place, true))
print(string.format("PASS: baked %d static parts into %s for Studio edit mode", world.PartCount, path))
