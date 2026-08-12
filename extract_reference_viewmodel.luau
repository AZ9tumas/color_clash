--!strict
-- Lifts ReplicatedStorage.Viewmodel out of the reference gunsystem place and writes it to
-- src/ReplicatedStorage/Viewmodel.rbxm, so Rojo mounts it at the same path the reference
-- used and the handler can WaitForChild("Viewmodel") exactly as it did there.
--
-- The rig is deliberately tiny: a transparent HumanoidRootPart as the PrimaryPart, one
-- visible RightArm mesh, a transparent CameraBone, and a Humanoid holding an Animator.
-- The gun is not part of it - GunHandler clones the weapon in on equip and joints it to
-- RightArm through a Motor6D named GunGrip.
--
-- Re-run only if the reference place changes:  lune run extract_reference_viewmodel
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local SOURCE = "/Users/az9umas/Desktop/gunsystem/gunsystem.rbxl"
local OUTPUT = "src/ReplicatedStorage/Viewmodel.rbxm"

assert(fs.isFile(SOURCE), "reference place not found at " .. SOURCE)

local place = roblox.deserializePlace(fs.readFile(SOURCE))
local viewmodel = place:GetService("ReplicatedStorage"):FindFirstChild("Viewmodel")
assert(viewmodel, "no ReplicatedStorage.Viewmodel in the reference place")

local rig = viewmodel:Clone()

-- The reference warns at runtime when this is unset and falls back to the same part; set
-- it here so the warning can never fire.
local root = rig:FindFirstChild("HumanoidRootPart")
assert(root, "reference viewmodel has no HumanoidRootPart")
rig.PrimaryPart = root

-- Nothing in this rig may touch the physics world. The reference leaves these to chance;
-- being explicit is what keeps an anchored or collidable part from ever ejecting the
-- player who is standing inside it.
local parts = {}
for _, descendant in rig:GetDescendants() do
	if descendant:IsA("BasePart") then
		descendant.CanCollide = false
		descendant.CanQuery = false
		descendant.CanTouch = false
		descendant.Massless = true
		descendant.CastShadow = false
		-- Anchored stays false on purpose: the handler moves the model with
		-- SetPrimaryPartCFrame every frame, and an anchored part inside the player's torso
		-- is what the solver resolves by launching them.
		descendant.Anchored = false
		table.insert(parts, string.format("%s (%s, transparency %.2f)", descendant.Name, descendant.ClassName, descendant.Transparency))
	end
end

fs.writeFile(OUTPUT, roblox.serializeModel({ rig }))

print("Extracted reference viewmodel -> " .. OUTPUT)
print("  PrimaryPart: " .. rig.PrimaryPart.Name)
print("  parts:")
for _, description in parts do
	print("    " .. description)
end
print("  joints:")
for _, descendant in rig:GetDescendants() do
	if descendant:IsA("Motor6D") then
		print(string.format("    %s: %s -> %s", descendant.Name,
			descendant.Part0 and descendant.Part0.Name or "nil",
			descendant.Part1 and descendant.Part1.Name or "nil (free slot)"))
	end
end
