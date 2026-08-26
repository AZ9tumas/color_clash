local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SpringHandler = require(Shared.Modules.Utils.Spring)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local SettingsController = require(Shared.UIControllers.SettingsController)
local FXConfig = require(Shared.Modules.Core.FXConfig)
local Items = require(Shared.Modules.Core.Items)

local function log(message, ...)
	if FXConfig.GunDebug then
		print("[Rig] " .. string.format(message, ...))
	end
end

local handler = {}
local rig = {}
rig.__index = rig

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local HIP_OFFSET = Vector3.new(0, 0, 0)
local ADS_OFFSET = Vector3.new(0, 0, 0)

local EYE_HEIGHT_R6 = 1.5
local EYE_HEIGHT_R15 = 2.0
local PITCH_LIMIT = math.rad(75)
local BASE_SENSITIVITY = 0.0022
local NECK_PITCH_SCALE = 0.45

local AIM_PITCH_SEND_INTERVAL = 0.1
local AIM_PITCH_SEND_THRESHOLD = math.rad(2)

local ROTATION_OWNING_STATES = { "WallRun", "Slide", "WallClimb", "Vault" }

local bindSerial = 0

local function movementOwnsRotation()
	local state = player:GetAttribute("MovementState")
	if type(state) ~= "string" then return false end
	for _, owned in ROTATION_OWNING_STATES do
		if string.find(state, owned) then return true end
	end
	return false
end

local R15_HOLD_SHOULDER = math.rad(70)
local R15_HOLD_YAW = math.rad(25)
local R15_HOLD_ELBOW = math.rad(35)
local R6_MELEE_HOLD_RIGHT = math.rad(55)
local R6_MELEE_HOLD_LEFT = math.rad(15)

-- The published Shooting animation contains full-body/root motion, so the
-- first-person gun pose is applied directly to the shoulder joints instead.
local R6_GUN_HOLD_RIGHT = CFrame.new(
	0.916316986, 0.18094188, -0.0853027105,
	-0.21872443, -0.975766659, -0.00625243597,
	0.96808511, -0.217797115, 0.123998418,
	-0.122355267, 0.0210685767, 0.992262721
)
local R6_GUN_HOLD_LEFT = CFrame.new(
	-0.506633699, 0.109606683, -0.708618164,
	0.428542167, 0.786711931, -0.444338024,
	-0.28005603, -0.351905227, -0.893157959,
	-0.859022915, 0.507195234, 0.0695170164
)

local POSED_JOINTS_R6 = {
	{ "Right Shoulder", "Torso", function(pitch, hold, meleeHold, gunHold) return gunHold > 0 and R6_GUN_HOLD_RIGHT or CFrame.Angles(0, 0, pitch + meleeHold * R6_MELEE_HOLD_RIGHT) end },
	{ "Left Shoulder", "Torso", function(pitch, hold, meleeHold, gunHold) return gunHold > 0 and R6_GUN_HOLD_LEFT or CFrame.Angles(0, 0, -(pitch + meleeHold * R6_MELEE_HOLD_LEFT)) end },
	{ "Neck", "Torso", function(pitch) return CFrame.Angles(-pitch * NECK_PITCH_SCALE, 0, 0) end },
}

local POSED_JOINTS_R15 = {
	{ "RightShoulder", "RightUpperArm", function(pitch, hold) return CFrame.Angles(pitch + hold * R15_HOLD_SHOULDER, hold * R15_HOLD_YAW, 0) end },
	{ "LeftShoulder", "LeftUpperArm", function(pitch, hold) return CFrame.Angles(pitch + hold * R15_HOLD_SHOULDER, -hold * R15_HOLD_YAW, 0) end },
	{ "RightElbow", "RightLowerArm", function(pitch, hold) return CFrame.Angles(hold * R15_HOLD_ELBOW, 0, 0) end },
	{ "LeftElbow", "LeftLowerArm", function(pitch, hold) return CFrame.Angles(hold * R15_HOLD_ELBOW, 0, 0) end },
	{ "Neck", "Head", function(pitch) return CFrame.Angles(pitch * NECK_PITCH_SCALE, 0, 0) end },
}

local function posedJointsFor(humanoid)
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then
		return POSED_JOINTS_R15
	end
	return POSED_JOINTS_R6
end

local ARM_PARTS = {
	["Right Arm"] = true, ["Left Arm"] = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
}

local VIEWMODEL_WEAPON_NAME = "ViewmodelWeapon"

local function findJoint(character, parentName, jointName)
	local parent = character and character:FindFirstChild(parentName)
	return parent and parent:FindFirstChild(jointName)
end

local function saveOriginalC0(joint)
	if not joint:GetAttribute("RigOriginalC0") then
		joint:SetAttribute("RigOriginalC0", joint.C0)
	end
	return joint:GetAttribute("RigOriginalC0")
end

local function writeJointC0(joint, c0)
	return (pcall(function()
		joint.C0 = c0
	end))
end

local function restoreJoints(character)
	if not character then return end
	for _, joints in { POSED_JOINTS_R6, POSED_JOINTS_R15 } do
		for _, entry in joints do
			local joint = findJoint(character, entry[2], entry[1])
			if joint and joint:GetAttribute("RigOriginalC0") then
				writeJointC0(joint, joint:GetAttribute("RigOriginalC0"))
			end
		end
	end
end

local function applyBodyVisibility(character, hidden)
	if not character then return end
	local tool = character:FindFirstChildOfClass("Tool")
	local toolData = tool and Items[tool.Name]
	local gunEquipped = toolData and toolData.MaxAmmo ~= nil
	local toolVisible = tool ~= nil and not (toolData and toolData.MaxAmmo)
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			if not part:FindFirstAncestor(VIEWMODEL_WEAPON_NAME) then
				local target = 0
				if hidden then
					local refName = part:IsA("Decal") and (part.Parent and part.Parent.Name or "") or part.Name
					if ARM_PARTS[refName] then
						target = gunEquipped and 1 or 0
					elseif tool and part:IsDescendantOf(tool) then
						target = toolVisible and 0 or 1
					else
						target = 1
					end
				end
				if part.LocalTransparencyModifier ~= target then
					part.LocalTransparencyModifier = target
				end
			end
		end
	end
end

local function sensitivity(aiming)
	local look = SettingsController.GetValue("Look Sensitivity")
	local scale = (type(look) == "number" and look or 50) / 50
	if aiming then
		local aim = SettingsController.GetValue("Aim Sensitivity")
		scale = scale * ((type(aim) == "number" and aim or 40) / 50)
	end
	return BASE_SENSITIVITY * scale
end

local function faceRootYaw(root, direction)
	local flatLook = direction * Vector3.new(1, 0, 1)
	if flatLook.Magnitude <= 0.001 then return end
	flatLook = flatLook.Unit

	local currentFlat = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if currentFlat.Magnitude > 0.001 and currentFlat.Unit:Dot(flatLook) > 0.99999 then
		return
	end

	local linearVelocity = root.AssemblyLinearVelocity
	local angularVelocity = root.AssemblyAngularVelocity
	root.CFrame = CFrame.lookAlong(root.Position, flatLook)
	root.AssemblyLinearVelocity = linearVelocity
	root.AssemblyAngularVelocity = angularVelocity
end

function handler.new(tool, config)
	config = config or {}

	local self = setmetatable({
		tool = tool,
		label = tool and tool.Name or "Player",

		offsetSpring = SpringHandler.new(config.HipOffset or HIP_OFFSET),
		hipOffset = config.HipOffset or HIP_OFFSET,
		adsOffset = config.AdsOffset or ADS_OFFSET,

		yaw = 0,
		pitch = 0,
		aiming = false,

		springPosition = Vector3.zero,
		springVelocity = Vector3.zero,
		isSpringActive = false,

		enabled = false,
		bindName = nil,
		savedCameraType = nil,

		lastSentPitch = 0,
		lastSendTime = 0,
	}, rig)

	return self
end

function rig:applyRecoilImpulse(impulse)
	self.springVelocity = self.springVelocity + Vector3.new(
		math.rad(impulse.X),
		math.rad(impulse.Y),
		math.rad(impulse.Z)
	)
	self.isSpringActive = true
end

function rig:ApplyAimKick(pitchDegrees, yawDegrees)
	if not self.enabled then return end
	self.pitch = math.clamp(self.pitch + math.rad(pitchDegrees), -PITCH_LIMIT, PITCH_LIMIT)
	self.yaw = self.yaw - math.rad(yawDegrees)
end

function rig:StartADS()
	self.aiming = true
	self.offsetSpring.Target = self.adsOffset
end

function rig:StopADS()
	self.aiming = false
	self.offsetSpring.Target = self.hipOffset
end

function rig:_update(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if player:GetAttribute("IsPlaying") ~= true then
		player:SetAttribute("GunCameraActive", false)
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		applyBodyVisibility(character, false)
		return
	end

	if not root or not humanoid or humanoid.Health <= 0 or character:GetAttribute("Ragdolled") then
		player:SetAttribute("GunCameraActive", false)
		if camera.CameraType ~= Enum.CameraType.Custom then
			camera.CameraType = Enum.CameraType.Custom
		end

		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		applyBodyVisibility(character, false)
		return
	end

	player:SetAttribute("GunCameraActive", true)

	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local mouseWasLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	if mouseWasLocked then
		local delta = UserInputService:GetMouseDelta()
		local sens = sensitivity(self.aiming)
		self.yaw = self.yaw - delta.X * sens
		self.pitch = math.clamp(self.pitch - delta.Y * sens, -PITCH_LIMIT, PITCH_LIMIT)
	end

	if self.isSpringActive then
		local stiffness, damping = 300, 30
		if self.springPosition.Magnitude < 0.001 and self.springVelocity.Magnitude < 0.001 then
			self.isSpringActive = false
			self.springPosition = Vector3.zero
			self.springVelocity = Vector3.zero
		else
			local force = -stiffness * self.springPosition
			local dampingForce = -damping * self.springVelocity
			self.springVelocity = self.springVelocity + (force + dampingForce) * dt
			self.springPosition = self.springPosition + self.springVelocity * dt
		end
	end

	local eyeHeight = humanoid.RigType == Enum.HumanoidRigType.R15 and EYE_HEIGHT_R15 or EYE_HEIGHT_R6
	local eye = root.Position + Vector3.new(0, eyeHeight, 0)
	local rotation = CFrame.fromOrientation(self.pitch + self.springPosition.X, self.yaw + self.springPosition.Y, 0)
	local offset = self.offsetSpring.Position
	local eyePosition = eye + rotation:VectorToWorldSpace(offset)

	camera.CFrame = CFrame.lookAlong(eyePosition, rotation.LookVector)
	camera.Focus = camera.CFrame

	applyBodyVisibility(character, true)

	if not movementOwnsRotation() then
		humanoid.AutoRotate = false
		faceRootYaw(root, rotation.LookVector)
	end

	local posePitch = self.pitch + self.springPosition.X
	local heldTool = character:FindFirstChildOfClass("Tool")
	local heldData = heldTool and Items[heldTool.Name]
	local heldGun = heldData and heldData.MaxAmmo ~= nil
	local hold = heldTool and 1 or 0
	local meleeHold = (heldTool and not (heldData and heldData.MaxAmmo)) and 1 or 0
	local gunHold = heldGun and 1 or 0
	for _, entry in posedJointsFor(humanoid) do
		local joint = findJoint(character, entry[2], entry[1])
		if joint and not joint:GetAttribute("RigPoseLocked") then
			local original = saveOriginalC0(joint)
			local target = original * entry[3](posePitch, hold, meleeHold, gunHold)
			if not writeJointC0(joint, target) then
				joint:SetAttribute("RigPoseLocked", true)
			end
		end
	end

	local now = os.clock()
	if now - self.lastSendTime >= AIM_PITCH_SEND_INTERVAL
		and math.abs(self.pitch - self.lastSentPitch) >= AIM_PITCH_SEND_THRESHOLD then
		self.lastSendTime = now
		self.lastSentPitch = self.pitch
		CombatRemotes.GetAimPitch():FireServer(self.pitch)
	end
end

function rig:Enable()
	if self.enabled then return end
	self.enabled = true

	local look = camera.CFrame.LookVector
	self.pitch = math.asin(math.clamp(look.Y, -1, 1))
	self.yaw = math.atan2(-look.X, -look.Z)

	self.savedCameraType = camera.CameraType
	self.offsetSpring.Position = self.hipOffset
	self.offsetSpring.Target = self.hipOffset

	player:SetAttribute("GunCameraActive", true)

	bindSerial += 1
	self.bindName = "FirstPerson_" .. self.label .. "_" .. bindSerial
	RunService:BindToRenderStep(self.bindName, Enum.RenderPriority.Camera.Value + 2, function(dt)
		self:_update(dt)
	end)

	log("enabled for %s: first-person camera, mouse-delta aim, permanent recoil channel", self.label)
end

function rig:Disable()
	if not self.enabled then return end
	self.enabled = false

	if self.bindName then
		pcall(RunService.UnbindFromRenderStep, RunService, self.bindName)
		self.bindName = nil
	end

	player:SetAttribute("GunCameraActive", nil)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	camera.CameraType = self.savedCameraType or Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = true
		camera.CameraSubject = humanoid
	end
	applyBodyVisibility(character, false)
	restoreJoints(character)

	self.aiming = false
	self.isSpringActive = false
	self.springPosition = Vector3.zero
	self.springVelocity = Vector3.zero
	self.offsetSpring.Target = self.hipOffset

	CombatRemotes.GetAimPitch():FireServer(0)

	log("disabled for %s: camera returned to Roblox, body and joints restored", self.label)
end

function rig:Destroy()
	self:Disable()
	self.offsetSpring:Destroy()
end

local shared = nil

function handler.GetShared()
	if not shared then
		shared = handler.new(nil, nil)
	end
	return shared
end

function handler.GetPosePitch()
	if shared and shared.enabled then
		return shared.pitch + shared.springPosition.X
	end
	return 0
end

return handler
