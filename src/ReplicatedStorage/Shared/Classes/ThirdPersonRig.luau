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

local HIP_OFFSET = Vector3.new(2.0, 0.6, 9)
local ADS_OFFSET = Vector3.new(1.4, 0.45, 5.2)

local FOCUS_HEIGHT = 1.4
local PITCH_LIMIT = math.rad(75)
local BASE_SENSITIVITY = 0.0022
local YAW_FOLLOW_RATE = 16
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

local POSED_JOINTS = {

	{ "Right Shoulder", "Torso", function(pitch) return CFrame.Angles(0, 0, pitch) end },
	{ "Left Shoulder", "Torso", function(pitch) return CFrame.Angles(0, 0, -pitch) end },
	{ "Neck", "Torso", function(pitch) return CFrame.Angles(-pitch * NECK_PITCH_SCALE, 0, 0) end },
}

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

local function restoreJoints(character)
	if not character then return end
	for _, entry in POSED_JOINTS do
		local joint = findJoint(character, entry[2], entry[1])
		if joint and joint:GetAttribute("RigOriginalC0") then
			joint.C0 = joint:GetAttribute("RigOriginalC0")
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

function handler.new(tool, config)
	config = config or {}

	local self = setmetatable({
		tool = tool,

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

	if player:GetAttribute("InMenu") ~= false then
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		return
	end

	if not root or not humanoid or humanoid.Health <= 0 or character:GetAttribute("Ragdolled") then
		if camera.CameraType ~= Enum.CameraType.Custom then
			camera.CameraType = Enum.CameraType.Custom
		end

		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		return
	end
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

	local focus = root.Position + Vector3.new(0, FOCUS_HEIGHT, 0)
	local rotation = CFrame.fromOrientation(self.pitch + self.springPosition.X, self.yaw + self.springPosition.Y, 0)
	local offset = self.offsetSpring.Position
	local idealPosition = focus + rotation:VectorToWorldSpace(Vector3.new(offset.X, offset.Y, offset.Z))

	local toCamera = idealPosition - focus
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { character }
	local debris = Workspace:FindFirstChild("WallDebrisFolder")
	if debris then table.insert(ignore, debris) end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(focus, toCamera, params)
	if hit then
		idealPosition = hit.Position - toCamera.Unit * 0.5
	end

	camera.CFrame = CFrame.lookAlong(idealPosition, rotation.LookVector)
	camera.Focus = CFrame.new(focus)

	if not movementOwnsRotation() then
		humanoid.AutoRotate = false
		local flatLook = rotation.LookVector * Vector3.new(1, 0, 1)
		if flatLook.Magnitude > 0.001 then
			local targetRotation = CFrame.lookAlong(Vector3.zero, flatLook.Unit)
			local currentRotation = root.CFrame.Rotation
			root.CFrame = CFrame.new(root.Position) * currentRotation:Lerp(targetRotation, math.min(1, dt * YAW_FOLLOW_RATE))
		end
	end

	local posePitch = self.pitch + self.springPosition.X
	for _, entry in POSED_JOINTS do
		local joint = findJoint(character, entry[2], entry[1])
		if joint then
			local original = saveOriginalC0(joint)
			joint.C0 = original * entry[3](posePitch)
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
	self.bindName = "GunRig_" .. self.tool.Name .. "_" .. bindSerial
	RunService:BindToRenderStep(self.bindName, Enum.RenderPriority.Camera.Value + 2, function(dt)
		self:_update(dt)
	end)

	log("enabled for %s: scriptable combat camera, mouse-delta aim, permanent recoil channel", self.tool.Name)
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
	restoreJoints(character)

	self.aiming = false
	self.isSpringActive = false
	self.springPosition = Vector3.zero
	self.springVelocity = Vector3.zero
	self.offsetSpring.Target = self.hipOffset

	CombatRemotes.GetAimPitch():FireServer(0)

	log("disabled for %s: camera returned to Roblox, joints restored", self.tool.Name)
end

function rig:Destroy()
	self:Disable()
	self.offsetSpring:Destroy()
end

return handler
