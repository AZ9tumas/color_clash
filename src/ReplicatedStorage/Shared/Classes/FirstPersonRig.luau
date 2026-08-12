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

-- First-person combat camera + body rig. While a gun is equipped this module OWNS the
-- camera (Scriptable): it keeps its own yaw/pitch, steered directly by mouse delta, which
-- is what makes two things possible that the default camera forbids:
--   1. aiming by just moving the mouse, no right-click drag, and
--   2. truly permanent recoil - kicks are added straight into the pitch/yaw state, so
--      the muzzle climb stays until the player pulls it back down.
-- The eye rides the root at a fixed height rather than the Head part, so hold animations
-- and walk cycles cannot shake the view. What you see of yourself comes from the Viewmodel
-- class, not from this character - the real body is hidden locally (see
-- applyBodyVisibility). The neck and shoulders are still posed here from aim pitch, which
-- costs three joint writes and keeps the rig honest if a gun ever loads without a
-- viewmodel; what other clients actually render comes from the throttled AimPitch
-- broadcast at the bottom of _update.
local handler = {}
local rig = {}
rig.__index = rig

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

-- Eye offsets in aim space: X right, Y up, Z back. Hip is the eye itself; ADS creeps the
-- eye a touch forward and down, so settling into sights reads as more than an FOV change.
local HIP_OFFSET = Vector3.new(0, 0, 0)
local ADS_OFFSET = Vector3.new(0, -0.08, -0.3)

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

local POSED_JOINTS = {
	-- name, parent part, pitch axis builder. Neck X is NEGATED: measured in-place, the
	-- R6 neck joint's positive X rotation tilts the head DOWN, opposite to camera pitch.
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

-- Only the local view is touched - LocalTransparencyModifier is client-side, so everyone
-- else still sees a whole character holding a whole gun. Decals carry the property too,
-- which is what takes the face along with the head.
--
-- Two hiding modes, and which one applies is not cosmetic. With a Viewmodel up, the whole
-- character goes - tool included - because the viewmodel supplies the arms and gun you
-- actually see and the real body only clips into them. Without one, hiding everything
-- would leave the player looking at nothing at all, so only the head and its accessories
-- go: that is the view you would otherwise be sitting inside.
local function shouldHide(instance, fullBody)
	if fullBody then return true end
	if instance.Name == "Head" then return true end

	local parent = instance.Parent
	if not parent then return false end
	-- The face is a Decal parented to the Head; hats and hair are Accessories, whose
	-- Handle sits directly under them.
	return parent.Name == "Head" or parent:IsA("Accessory")
end

local function applyBodyVisibility(character, hidden, fullBody)
	if not character then return end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			local target = (hidden and shouldHide(part, fullBody)) and 1 or 0
			-- Asserted every frame because the engine and the ragdoll path both reset this,
			-- but only written on change - a blind write per part per frame is a property
			-- signal storm for no gain.
			if part.LocalTransparencyModifier ~= target then
				part.LocalTransparencyModifier = target
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
		viewmodelActive = false,
		bindName = nil,
		savedCameraType = nil,

		lastSentPitch = 0,
		lastSendTime = 0,
	}, rig)

	return self
end

-- Spring (visual) recoil: kicks and recovers.
function rig:applyRecoilImpulse(impulse)
	self.springVelocity = self.springVelocity + Vector3.new(
		math.rad(impulse.X),
		math.rad(impulse.Y),
		math.rad(impulse.Z)
	)
	self.isSpringActive = true
end

-- Permanent recoil: written straight into the aim state, stays until compensated.
function rig:ApplyAimKick(pitchDegrees, yawDegrees)
	if not self.enabled then return end
	self.pitch = math.clamp(self.pitch + math.rad(pitchDegrees), -PITCH_LIMIT, PITCH_LIMIT)
	self.yaw = self.yaw - math.rad(yawDegrees)
end

-- Set by GunHandler once it knows whether a viewmodel was actually built for this gun. It
-- decides whether the real body is hidden outright or only from the neck up.
function rig:SetViewmodelActive(active)
	self.viewmodelActive = active and true or false
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

	-- Back in the menu: MenuController owns the camera there and its buttons need a free
	-- cursor. The server strips the tool a beat after the client returns, so without this
	-- that round trip is spent with the menu locked out.
	if player:GetAttribute("InMenu") ~= false then
		player:SetAttribute("GunCameraActive", false)
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		applyBodyVisibility(character, false)
		return
	end

	-- Dead or ragdolled: hand the camera back to Roblox until the player recovers, so
	-- ragdoll flights and the death flow keep their normal camera - and their body, since
	-- watching your own ragdoll fly with the head missing is worse than the alternative.
	if not root or not humanoid or humanoid.Health <= 0 or character:GetAttribute("Ragdolled") then
		player:SetAttribute("GunCameraActive", false)
		if camera.CameraType ~= Enum.CameraType.Custom then
			camera.CameraType = Enum.CameraType.Custom
		end
		-- Hand the mouse back with the camera: the cursor is hidden while a gun is out, so
		-- staying locked here would leave the death and ragdoll screens unclickable.
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		applyBodyVisibility(character, false)
		return
	end
	-- Per-frame truth, not just a lifecycle flag: the two branches above hand the camera
	-- back mid-equip, and everything downstream (CombatClient's hands-off check, the
	-- Viewmodel's own visibility) has to follow that within the same frame.
	player:SetAttribute("GunCameraActive", true)

	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	-- The camera module is idle under Scriptable, but other systems still reset the
	-- mouse on focus changes; keep it locked while the gun is out.
	local mouseWasLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	-- Aim from the frame's mouse delta rather than an InputChanged connection. Delta is
	-- only reported while the mouse is locked, so the read is gated on the lock having
	-- survived the previous frame - that also discards the recentre jump on the frame the
	-- lock is acquired. Reading here instead of in an event handler additionally dodges
	-- gameProcessedEvent, which goes true whenever an Active GuiObject sits under the
	-- cursor: with the cursor pinned to screen centre that would silently kill aiming.
	if mouseWasLocked then
		local delta = UserInputService:GetMouseDelta()
		local sens = sensitivity(self.aiming)
		self.yaw = self.yaw - delta.X * sens
		self.pitch = math.clamp(self.pitch - delta.Y * sens, -PITCH_LIMIT, PITCH_LIMIT)
	end

	-- Recoil spring (300/30, the reference gunsystem's constants).
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

	-- Compose the camera: eye above the root, rotated by owned yaw/pitch plus the spring's
	-- visual kick, then nudged by the sprung eye offset. No wall-clip raycast - the eye is
	-- inside the character, so there is nothing to pull the camera through.
	local eyeHeight = humanoid.RigType == Enum.HumanoidRigType.R15 and EYE_HEIGHT_R15 or EYE_HEIGHT_R6
	local eye = root.Position + Vector3.new(0, eyeHeight, 0)
	local rotation = CFrame.fromOrientation(self.pitch + self.springPosition.X, self.yaw + self.springPosition.Y, 0)
	local offset = self.offsetSpring.Position
	local eyePosition = eye + rotation:VectorToWorldSpace(offset)

	camera.CFrame = CFrame.lookAlong(eyePosition, rotation.LookVector)
	camera.Focus = camera.CFrame

	applyBodyVisibility(character, true, self.viewmodelActive)

	-- Character yaw tracks the aim exactly, not on a lerp: in first person the arms and
	-- the gun hang off the torso, so a body that eases into position drags the weapon
	-- visibly behind the crosshair.
	if not movementOwnsRotation() then
		humanoid.AutoRotate = false
		local flatLook = rotation.LookVector * Vector3.new(1, 0, 1)
		if flatLook.Magnitude > 0.001 then
			root.CFrame = CFrame.new(root.Position) * CFrame.lookAlong(Vector3.zero, flatLook.Unit)
		end
	end

	-- Arms + neck pose from the same aim pitch, recoil spring layered in.
	local posePitch = self.pitch + self.springPosition.X
	for _, entry in POSED_JOINTS do
		local joint = findJoint(character, entry[2], entry[1])
		if joint then
			local original = saveOriginalC0(joint)
			joint.C0 = original * entry[3](posePitch)
		end
	end

	-- Broadcast aim pitch (throttled) so other clients pose this character too.
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

	-- Adopt the current camera direction so equipping does not snap the view.
	local look = camera.CFrame.LookVector
	self.pitch = math.asin(math.clamp(look.Y, -1, 1))
	self.yaw = math.atan2(-look.X, -look.Z)

	self.savedCameraType = camera.CameraType
	self.offsetSpring.Position = self.hipOffset
	self.offsetSpring.Target = self.hipOffset

	-- Declared, not inferred: the camera, the mouse lock, character yaw and the local
	-- body transparency are all ours until Disable. Other per-frame systems (CombatClient,
	-- MovementClient) read this and keep their hands off - they run on RenderStepped,
	-- which fires AFTER every BindToRenderStep callback, so anything they write to those
	-- wins the frame.
	player:SetAttribute("GunCameraActive", true)

	bindSerial += 1
	self.bindName = "GunRig_" .. self.tool.Name .. "_" .. bindSerial
	RunService:BindToRenderStep(self.bindName, Enum.RenderPriority.Camera.Value + 2, function(dt)
		self:_update(dt)
	end)

	log("enabled for %s: first-person camera, mouse-delta aim, permanent recoil channel", self.tool.Name)
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

	log("disabled for %s: camera returned to Roblox, body and joints restored", self.tool.Name)
end

function rig:Destroy()
	self:Disable()
	self.offsetSpring:Destroy()
end

return handler
