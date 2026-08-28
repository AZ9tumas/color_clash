--!strict
-- Regenerates the exact viewmodel template used by the standalone Place 1 lab.
-- Re-run with: lune run extract_reference_viewmodel
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local SOURCE = "/Users/az9umas/Desktop/gunsystem/gunsystem.rbxl"
-- Kept outside src/ on purpose: anything under src/ is owned by Rojo, and dropping a
-- Viewmodel.rbxm into src/ReplicatedStorage/Shared/Assets would make the filesystem
-- overwrite the Studio-authored ReplicatedStorage.Shared.Assets.Viewmodel on sync.
-- Import this file into Studio by hand when you actually want to replace the rig.
local OUTPUT = "Viewmodel.rbxm"

assert(fs.isFile(SOURCE), "reference place not found at " .. SOURCE)

local place = roblox.deserializePlace(fs.readFile(SOURCE))
local source = place:GetService("ReplicatedStorage"):FindFirstChild("Viewmodel")
assert(source, "no ReplicatedStorage.Viewmodel in the reference place")

local rig = source:Clone()
rig.Name = "Viewmodel"

local root = rig:FindFirstChild("HumanoidRootPart")
local rightArm = rig:FindFirstChild("RightArm")
local humanoid = rig:FindFirstChildOfClass("Humanoid")
assert(root and root:IsA("BasePart"), "reference viewmodel has no HumanoidRootPart")
assert(rightArm and rightArm:IsA("BasePart"), "reference viewmodel has no RightArm")
assert(humanoid, "reference viewmodel has no Humanoid")

local rightJoint = nil
for _, descendant in rig:GetDescendants() do
	if descendant.ClassName == "Motor6D" and descendant.Part1 == rightArm then
		rightJoint = descendant
		break
	end
end
assert(rightJoint, "the RightArm is not jointed to the rig")

rightArm.Name = "Right Arm"
rightJoint.Name = "Right Arm"
rightJoint.C0 = roblox.CFrame.new(
	1.44986093044281, -1.2223740816116333, -2.9548890590667725,
	0, -1.7484555314695172e-7, -1,
	1, 0, 0,
	0, -1, 1.7484555314695172e-7
)
rightJoint.C1 = roblox.CFrame.new(-0.13000071048736572, 1.358698844909668, 0.060881614685058594)
rightArm.CFrame = root.CFrame * rightJoint.C0 * rightJoint.C1:Inverse()

local leftArm = rightArm:Clone()
leftArm.Name = "Left Arm"
local mirroredGripAttachment = leftArm:FindFirstChild("RightGripAttachment")
if mirroredGripAttachment then
	mirroredGripAttachment:Destroy()
end
leftArm.Parent = rig

local rightGripAttachment = rightArm:FindFirstChild("RightGripAttachment")
if not rightGripAttachment then
	rightGripAttachment = roblox.Instance.new("Attachment")
	rightGripAttachment.Name = "RightGripAttachment"
	rightGripAttachment.Parent = rightArm
end
rightGripAttachment.CFrame = roblox.CFrame.new(0, -1, 0)

local leftJoint = roblox.Instance.new("Motor6D")
leftJoint.Name = "Left Arm"
leftJoint.Part0 = root
leftJoint.Part1 = leftArm
leftJoint.C0 = rightJoint.C0
leftJoint.C1 = roblox.CFrame.new(
	-0.13000071048736572, 1.3586993217468262, -2.9391181468963623,
	1, 0, 0,
	0, 1, -1.7484555314695172e-7,
	0, 1.7484555314695172e-7, 1
)
leftJoint.Parent = root
leftArm.CFrame = root.CFrame * leftJoint.C0 * leftJoint.C1:Inverse()

root.Transparency = 0.5
root.Anchored = true

humanoid.EvaluateStateMachine = false
humanoid.AutoRotate = false
humanoid.BreakJointsOnDeath = false
humanoid.RequiresNeck = false
humanoid.DisplayDistanceType = roblox.Enum.HumanoidDisplayDistanceType.None

local animator = humanoid:FindFirstChildOfClass("Animator")
if not animator then
	animator = roblox.Instance.new("Animator")
	animator.Parent = humanoid
end

for _, descendant in rig:GetDescendants() do
	if descendant:IsA("BasePart") then
		descendant.CanCollide = false
		descendant.CanQuery = false
		descendant.CanTouch = false
		descendant.Massless = true
		descendant.Anchored = descendant == root
	end
end

rig.PrimaryPart = root
fs.writeFile(OUTPUT, roblox.serializeModel({ rig }))

print("Regenerated Place 1 viewmodel -> " .. OUTPUT)
