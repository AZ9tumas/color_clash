--!strict
-- Regenerates the reference viewmodel rig from the gunsystem place into
-- src/ReplicatedStorage/Viewmodel.rbxm, so Rojo mounts it at ReplicatedStorage.Viewmodel.
--
-- This rig is the thing the fsafs rigs are not: it was authored FOR A CAMERA. Its arm and
-- its gun slot sit where they belong in front of an eye, which is why the weapon lands in
-- frame with no guessed offsets. The fsafs rigs are standing R6 characters with the gun at
-- hip height - their poses are body-relative and there is no camera offset that rescues
-- them.
--
-- A LEFT ARM is added here, mirrored from the authored right one, because the shipped rig
-- has a single arm and a viewmodel wants two hands on the weapon. Mirroring is done on the
-- joint, not the mesh: the C0/C1 translation is negated in X and the basis is flipped, which
-- puts the second arm at the matching position on the other side of the view.
--
-- Re-run only if the reference place changes:  lune run extract_reference_viewmodel
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local SOURCE = "/Users/az9umas/Desktop/gunsystem/gunsystem.rbxl"
local OUTPUT = "src/ReplicatedStorage/Viewmodel.rbxm"

assert(fs.isFile(SOURCE), "reference place not found at " .. SOURCE)

local place = roblox.deserializePlace(fs.readFile(SOURCE))
local source = place:GetService("ReplicatedStorage"):FindFirstChild("Viewmodel")
assert(source, "no ReplicatedStorage.Viewmodel in the reference place")

local rig = source:Clone()

local root = rig:FindFirstChild("HumanoidRootPart")
assert(root, "reference viewmodel has no HumanoidRootPart")
rig.PrimaryPart = root

local rightArm = rig:FindFirstChild("RightArm")
assert(rightArm, "reference viewmodel has no RightArm")

local rightJoint = nil
for _, descendant in rig:GetDescendants() do
	if descendant.ClassName == "Motor6D" and descendant.Part1 == rightArm then
		rightJoint = descendant
	end
end
assert(rightJoint, "the RightArm is not jointed to the rig")

-- Mirror the arm across the view's X axis. Negating the X column and the X translation
-- reflects the placement without turning the part inside out.
local function mirrorX(cf)
	local x, y, z,
		r00, r01, r02,
		r10, r11, r12,
		r20, r21, r22 = cf:GetComponents()
	return roblox.CFrame.new(
		-x, y, z,
		r00, -r01, -r02,
		-r10, r11, r12,
		-r20, r21, r22
	)
end

local leftArm = rightArm:Clone()
leftArm.Name = "LeftArm"
leftArm.Parent = rig

local leftJoint = roblox.Instance.new("Motor6D")
leftJoint.Name = "LeftArm"
leftJoint.Part0 = root
leftJoint.Part1 = leftArm
leftJoint.C0 = mirrorX(rightJoint.C0)
leftJoint.C1 = mirrorX(rightJoint.C1)
leftJoint.Parent = root

-- Nothing in this rig may touch the physics world. The root is anchored and everything else
-- hangs off it through Motor6Ds; a Humanoid is deliberately absent, because with one present
-- the engine re-enables CanCollide on the torso and the rig shoves the player around.
for _, descendant in rig:GetDescendants() do
	if descendant.ClassName == "Humanoid" or descendant.ClassName == "Animator" then
		descendant:Destroy()
	end
end

local controller = roblox.Instance.new("AnimationController")
local animator = roblox.Instance.new("Animator")
animator.Parent = controller
controller.Parent = rig

for _, descendant in rig:GetDescendants() do
	if descendant:IsA("BasePart") then
		descendant.CanCollide = false
		descendant.CanQuery = false
		descendant.CanTouch = false
		descendant.Massless = true
		descendant.CastShadow = false
		descendant.Anchored = descendant.Name == "HumanoidRootPart"
	end
end

fs.writeFile(OUTPUT, roblox.serializeModel({ rig }))

print("Regenerated reference viewmodel -> " .. OUTPUT)
print("  PrimaryPart: " .. rig.PrimaryPart.Name)
for _, descendant in rig:GetDescendants() do
	if descendant:IsA("BasePart") then
		print(string.format("  part  %-18s size=%s transparency=%.1f anchored=%s",
			descendant.Name, tostring(descendant.Size), descendant.Transparency, tostring(descendant.Anchored)))
	elseif descendant.ClassName == "Motor6D" then
		print(string.format("  joint %-18s %s -> %s", descendant.Name,
			descendant.Part0 and descendant.Part0.Name or "nil",
			descendant.Part1 and descendant.Part1.Name or "nil (free gun slot)"))
	end
end
