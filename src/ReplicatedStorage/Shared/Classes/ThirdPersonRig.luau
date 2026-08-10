local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SpringHandler = require(Shared.Modules.Utils.Spring)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local FXConfig = require(Shared.Modules.Core.FXConfig)

local function log(message, ...)
	if FXConfig.GunDebug then
		print("[Rig] " .. string.format(message, ...))
	end
end

-- Third-person aiming rig, Jailbreak/COD style: the character's REAL arms, neck and the
-- tool in their hands track the camera pitch through Motor6D C0 layering, on top of the
-- gun's own hold animations (animations write Motor6D.Transform, C0 is a static offset,
-- so the two compose without fighting). Recoil is a rotation spring fed into the same
-- joints, so the gun and arms physically jump on fire and settle back.
--
-- The C0 layering trick is the standard approach from the DevForum for R6 rigs:
-- shoulders post-multiplied by Angles(0, 0, +/- pitch), neck by Angles(pitch, 0, 0).
local handler = {}
local rig = {}
rig.__index = rig

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local HIP_CAMERA_OFFSET = Vector3.new(1.9, 0.45, 0)
local ADS_CAMERA_OFFSET = Vector3.new(1.35, 0.25, -1.1)

local YAW_FOLLOW_RATE = 16
local NECK_PITCH_SCALE = 0.45
local ARM_PITCH_SCALE = 1.0

local AIM_PITCH_SEND_INTERVAL = 0.1
local AIM_PITCH_SEND_THRESHOLD = math.rad(2)

local ROTATION_OWNING_STATES = { "WallRun", "Slide", "WallClimb", "Vault" }

local function movementOwnsRotation()
	local state = player:GetAttribute("MovementState")
	if type(state) ~= "string" then return false end
	for _, owned in ROTATION_OWNING_STATES do
		if string.find(state, owned) then return true end
	end
	return false
end

local POSED_JOINTS = {
	-- name, parent part, pitch axis builder. Neck X is NEGATED: measured in-place, the
	-- R6 neck joint's positive X rotation tilts the head DOWN, opposite to camera pitch.
	{ "Right Shoulder", "Torso", function(pitch) return CFrame.Angles(0, 0, pitch) end },
	{ "Left Shoulder", "Torso", function(pitch) return CFrame.Angles(0, 0, -pitch) end },
	{ "Neck", "Torso", function(pitch) return CFrame.Angles(-pitch * NECK_PITCH_SCALE / ARM_PITCH_SCALE, 0, 0) end },
}

local function findJoint(character, parentName, jointName)
	local parent = character and character:FindFirstChild(parentName)
	return parent and parent:FindFirstChild(jointName)
end

function handler.new(tool, config)
	config = config or {}

	local self = setmetatable({
		tool = tool,

		cameraSpring = SpringHandler.new(HIP_CAMERA_OFFSET),
		hipCameraOffset = config.HipCameraOffset or HIP_CAMERA_OFFSET,
		adsCameraOffset = config.AdsCameraOffset or ADS_CAMERA_OFFSET,

		-- rotation recoil spring, applied to the posed joints and recovered over time
		springPosition = Vector3.zero,
		springVelocity = Vector3.zero,
		isSpringActive = false,

		rbxConn = nil,
		savedAutoRotate = nil,
		savedMouseBehavior = nil,

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

function rig:StartADS()
	self.cameraSpring.Target = self.adsCameraOffset
end

function rig:StopADS()
	self.cameraSpring.Target = self.hipCameraOffset
end

local function saveOriginalC0(joint)
	if not joint:GetAttribute("RigOriginalC0") then
		joint:SetAttribute("RigOriginalC0", joint.C0)
	end
	return joint:GetAttribute("RigOriginalC0")
end

local function restoreJoints(character)
	if not character then return end
	for _, entry in POSED_JOINTS do
		local joint = findJoint(character, entry[2], entry[1])
		if joint and joint:GetAttribute("RigOriginalC0") then
			joint.C0 = joint:GetAttribute("RigOriginalC0")
		end
	end
end

function rig:_update(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not root or not humanoid or humanoid.Health <= 0 or character:GetAttribute("Ragdolled") then
		return
	end

	-- Recoil spring (300/30, the reference gunsystem's viewmodel constants).
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

	-- Spring-driven shoulder camera: hip and ADS offsets glide instead of snapping.
	humanoid.CameraOffset = self.cameraSpring.Position

	-- The engine resets MouseBehavior on focus changes and open menus, so lock is
	-- asserted every frame while the gun is out - the standard fix, not a hack.
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	local look = camera.CFrame.LookVector

	-- Character yaw follows the camera unless a movement mechanic owns rotation.
	if not movementOwnsRotation() then
		humanoid.AutoRotate = false
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.001 then
			local targetRotation = CFrame.lookAlong(Vector3.zero, flat.Unit)
			local currentRotation = root.CFrame.Rotation
			root.CFrame = CFrame.new(root.Position) * currentRotation:Lerp(targetRotation, math.min(1, dt * YAW_FOLLOW_RATE))
		end
	end

	-- Pose arms + neck by camera pitch, with the recoil spring layered in so the whole
	-- upper body kicks on fire. Animations keep playing through Motor6D.Transform.
	local pitch = math.asin(math.clamp(look.Y, -1, 1)) * ARM_PITCH_SCALE
	local recoiled = pitch + self.springPosition.X

	for _, entry in POSED_JOINTS do
		local joint = findJoint(character, entry[2], entry[1])
		if joint then
			local original = saveOriginalC0(joint)
			joint.C0 = original * entry[3](recoiled)
		end
	end

	-- Broadcast aim pitch (throttled) so other clients pose this character too.
	local now = os.clock()
	if now - self.lastSendTime >= AIM_PITCH_SEND_INTERVAL
		and math.abs(pitch - self.lastSentPitch) >= AIM_PITCH_SEND_THRESHOLD then
		self.lastSendTime = now
		self.lastSentPitch = pitch
		CombatRemotes.GetAimPitch():FireServer(pitch)
	end
end

function rig:Enable()
	if self.rbxConn then return end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	self.savedMouseBehavior = UserInputService.MouseBehavior
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	if humanoid then
		self.savedAutoRotate = humanoid.AutoRotate
	end

	self.cameraSpring.Position = Vector3.zero
	self.cameraSpring.Target = self.hipCameraOffset

	self.rbxConn = RunService.RenderStepped:Connect(function(dt)
		self:_update(dt)
	end)

	log("enabled for %s: shoulder cam, mouse lock, arm/neck tracking", self.tool.Name)
end

function rig:Disable()
	if not self.rbxConn then return end
	self.rbxConn:Disconnect()
	self.rbxConn = nil

	UserInputService.MouseBehavior = self.savedMouseBehavior or Enum.MouseBehavior.Default

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = self.savedAutoRotate ~= false
		humanoid.CameraOffset = Vector3.zero
	end
	restoreJoints(character)

	self.isSpringActive = false
	self.springPosition = Vector3.zero
	self.springVelocity = Vector3.zero
	self.cameraSpring.Target = self.hipCameraOffset

	CombatRemotes.GetAimPitch():FireServer(0)

	log("disabled for %s: camera and joints restored", self.tool.Name)
end

function rig:Destroy()
	self:Disable()
	self.cameraSpring:Destroy()
end

return handler
