local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local PLACE = "color_clash.rbxl"
local OUTPUT = "src/ReplicatedStorage/WeaponViewmodelData.rbxm"

assert(fs.isFile(PLACE), "place file not found at " .. PLACE)

local place = roblox.deserializePlace(fs.readFile(PLACE))
local folder = place:GetService("ReplicatedStorage"):FindFirstChild("WeaponViewmodelData")
assert(folder, "no ReplicatedStorage.WeaponViewmodelData in the place")

local weapons = {}
for _, child in folder:GetChildren() do
	local model = child:FindFirstChild("WeaponModel")
	local reload = child:FindFirstChild("Reload")
	local hold = child:FindFirstChild("Hold")
	local joints = child:FindFirstChild("Joints")
	assert(model, child.Name .. " is missing WeaponModel")
	assert(reload, child.Name .. " is missing Reload")
	assert(hold, child.Name .. " is missing Hold")
	assert(joints, child.Name .. " is missing Joints")
	table.insert(weapons, string.format("%s (joints=%d)", child.Name, #joints:GetChildren()))
end

fs.writeFile(OUTPUT, roblox.serializeModel({ folder:Clone() }))
print("wrote " .. OUTPUT .. " with: " .. table.concat(weapons, ", "))
