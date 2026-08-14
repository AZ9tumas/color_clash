local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Shared = ReplicatedStorage.Shared
local SpringHandler = require(Shared.Modules.Utils.Spring)
local WeaponRigData = require(Shared.Classes.WeaponRigData)
local FXConfig = require(Shared.Modules.Core.FXConfig)

local function log(message, ...)
	if FXConfig.GunDebug then
		print("[Viewmodel] " .. string.format(message, ...))
	end
end

-- First-person viewmodel, built on the reference gunsystem's rig.
--
-- The choice of rig is the whole thing. ReplicatedStorage.Viewmodel was AUTHORED FOR A
-- CAMERA: its root is the eye, and its arm and gun slot sit where they belong in front of
-- it. That is why the weapon lands in frame with no guessed offsets.
--
-- The fsafs rigs are not that, and using them as viewmodels is what went wrong before: they
-- are standing R6 characters with the weapon jointed at hip height. Every pose in them is
-- body-relative, so no camera offset exists that brings the hands into view. They are still
-- used here, but only for what they legitimately describe - the weapon's own moving parts
-- and the reload that drives them.
--
--   placement   root pinned to camera.CFrame every frame, exactly as the reference did
--   arms        the player's own, swapped onto the reference arm joints at the reference
--               size, so they land where the rig says and wear the player's skin tone
--   weapon      Handle jointed to the right arm; sub-parts jointed to the Handle at their
--               authored spacing, which is what lets the reload move the magazine
--   ADS         field of view only - no movement, no pose swap
--   recoil      the reference's 300/30 rotational spring
local Viewmodel = {}
Viewmodel.__index = Viewmodel

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local DEFAULT_OFFSET = Vector3.zero

local RECOIL_STIFFNESS = 300
local RECOIL_DAMPING = 30

local MUZZLE_PART_NAME = "muzzle"
local MUZZLE_COLOR = Color3.fromRGB(255, 201, 120)
local MUZZLE_BRIGHTNESS = 7
local MUZZLE_RANGE = 16
local MUZZLE_DECAY = 14

-- Which of the player's limbs stands in for each of the rig's arms.
local ARM_SOURCE = { RightArm = "Right Arm", LeftArm = "Left Arm" }

local bindSerial = 0
local shared = nil

local function makeInert(instance)
	local function apply(part)
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
	end
	if instance:IsA("BasePart") then apply(instance) end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then apply(descendant) end
	end
end

-- Swaps the rig's stock arm meshes for the player's own limbs, keeping the rig's geometry
-- exactly: same Size, same joint, same C0/C1. Only the part hanging off the joint changes,
-- so the authored camera framing is untouched and the arms wear the player's skin tone.
--
-- R6 only. R15 splits the arm into three parts with no single stand-in, so those players
-- keep the stock meshes rather than get a broken limb.
local function useOwnArms(model)
	local character = player.Character
	if not character then return false, "no character" end

	local swapped = 0
	for rigArmName, sourceName in ARM_SOURCE do
		local template = model:FindFirstChild(rigArmName)
		local source = character:FindFirstChild(sourceName)

		if template and source and source:IsA("BasePart") then
			local joint = nil
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("Motor6D") and descendant.Part1 == template then
					joint = descendant
					break
				end
			end

			if joint then
				local arm = source:Clone()
				arm:ClearAllChildren()
				arm.Name = rigArmName
				arm.Size = template.Size
				arm.CFrame = template.CFrame
				arm.Transparency = 0
				arm.Parent = model

				joint.Part1 = arm
				template:Destroy()
				swapped += 1
			end
		end
	end

	if swapped == 0 then
		return false, "no arm could be swapped (R15 character?)"
	end
	return true
end

function Viewmodel.new(config)
	config = config or {}

	local template = ReplicatedStorage:FindFirstChild("Viewmodel")
	if not template then
		warn("[Viewmodel] ReplicatedStorage.Viewmodel is missing - run `lune run extract_reference_viewmodel` and resync")
		return nil
	end

	local model = template:Clone()
	model.Name = "Viewmodel"
	makeInert(model)

	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		warn("[Viewmodel] the reference rig has no HumanoidRootPart")
		model:Destroy()
		return nil
	end
	model.PrimaryPart = root
	-- Anchored root, everything else free on its joints. Without this the rig is a free body
	-- and falls between frames - measured at 72 studs in 5 frames before it was anchored.
	root.Anchored = true

	local ok, reason = useOwnArms(model)
	if not ok then
		log("using the stock arms (%s)", tostring(reason))
	end

	local offset = config.Offset or DEFAULT_OFFSET

	return setmetatable({
		model = model,
		weaponName = nil,
		gunModel = nil,
		weaponJoints = {},
		reloadTrack = nil,

		offset = offset,
		offsetSpring = SpringHandler.new(offset),

		springPosition = Vector3.zero,
		springVelocity = Vector3.zero,
		isSpringActive = false,

		muzzlePart = nil,
		muzzleLight = nil,
		muzzleAlpha = 0,

		bindName = nil,
		shown = false,
		destroyed = false,
	}, Viewmodel)
end

-- One viewmodel per client, owned by FirstPersonController and alive for the whole round,
-- weapon or no weapon.
function Viewmodel.GetShared(config)
	if shared and not shared.destroyed then
		return shared
	end
	shared = Viewmodel.new(config)
	return shared
end

function Viewmodel.ClearShared()
	if shared then
		shared:Destroy()
		shared = nil
	end
end

function Viewmodel:ClearWeapon()
	if self.reloadTrack then
		self.reloadTrack:Stop(0)
		self.reloadTrack = nil
	end
	for _, joint in self.weaponJoints do
		if joint.Parent then joint:Destroy() end
	end
	table.clear(self.weaponJoints)
	if self.gunModel then
		self.gunModel:Destroy()
		self.gunModel = nil
	end

	self.weaponName = nil
	self.muzzlePart = nil
	self.muzzleLight = nil
	self.muzzleAlpha = 0
end

-- Puts a weapon in the hands. The model used is the one the animation was authored on - the
-- Tool in Assets.Weapons is a different model with different part names, and the SMG tool
-- has no magazine part at all.
function Viewmodel:SetWeapon(weaponName, config, tool)
	self:ClearWeapon()

	local rigData = WeaponRigData.Get(weaponName)
	if not rigData or not rigData.gunModel then
		-- No authored rig - every melee weapon, and any gun that has not been rigged yet.
		-- Tools carry their own authored grip in Tool.Grip, which is the exact CFrame Roblox
		-- uses to seat the handle in the character's hand, so there is real data here too. It
		-- is just a different source, and it needs the Tool rather than a rig.
		if tool then
			return self:_holdTool(weaponName, tool, config)
		end
		log("no authored rig or tool for %s - the hands stay empty", weaponName)
		return false
	end

	if config then
		self.offset = config.Offset or self.offset
		self.offsetSpring.Target = self.offset
	end

	local arm = self.model:FindFirstChild("RightArm")
	if not arm then
		warn("[Viewmodel] the rig has no RightArm to hang a weapon from")
		return false
	end

	local armJoint = nil
	for _, descendant in self.model:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part1 == arm then
			armJoint = descendant
			break
		end
	end

	local gun = rigData.gunModel:Clone()
	local handle = nil
	for _, descendant in gun:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == "Handle" then
			handle = descendant
			break
		end
	end
	if not handle then
		warn(string.format("[Viewmodel] %s's authored model has no Handle", weaponName))
		gun:Destroy()
		return false
	end

	-- Sub-part spacing is read BEFORE anything is reparented, while the model still sits in
	-- its authored arrangement.
	local handleCF = handle.CFrame
	local subParts = {}
	for _, descendant in gun:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= handle then
			table.insert(subParts, { part = descendant, offset = handleCF:ToObjectSpace(descendant.CFrame) })
		end
	end

	makeInert(gun)
	for _, descendant in gun:GetDescendants() do
		if descendant:IsA("BasePart") then descendant.Anchored = false end
	end
	gun.Parent = self.model

	-- The grip is SOLVED, not hand-tuned, and that is what makes the weapon face forward.
	--
	-- A Motor6D places its part at  Part0 * C0 * Transform * C1:Inverse().  The fsafs rig
	-- already records how this weapon sits relative to a body:
	--
	--     A = handle joint C0 * C1:Inverse()          (handle, relative to the fsafs root)
	--
	-- and the reference rig records where its arm sits relative to the eye:
	--
	--     B = arm joint C0 * C1:Inverse()             (right arm, relative to our root)
	--
	-- We want the handle to end up at A relative to OUR root, hanging off the arm:
	--
	--     Root * B * C1:Inverse() = Root * A     ->     C1 = A:Inverse() * B
	--
	-- Hand-picking a rotation here is what had the gun aimed across the body at the other
	-- hand: the reference's own grip values were authored for the reference's gun models,
	-- and these are not those models. Solving it uses each weapon's real authored
	-- orientation, so every gun points where the animator pointed it, with no per-gun
	-- tuning table to keep in sync.
	local gripC1 = nil
	for _, spec in rigData.joints do
		if spec.Part1 == "Handle" then
			local authored = spec.C0 * spec.C1:Inverse()
			local armRelative = armJoint and (armJoint.C0 * armJoint.C1:Inverse()) or CFrame.new()
			gripC1 = authored:Inverse() * armRelative
			break
		end
	end

	if not gripC1 then
		-- No authored handle joint to solve from; fall back to whatever the config says
		-- rather than dropping the weapon on the floor.
		gripC1 = (config and config.GripOffset) or CFrame.new()
		log("%s has no authored Handle joint - using the configured grip", weaponName)
	end

	-- Optional per-gun nudge on top of the solved grip, for taste rather than correctness.
	if config and config.GripAdjust then
		gripC1 = gripC1 * config.GripAdjust
	end

	local grip = Instance.new("Motor6D")
	grip.Name = "GunGrip"
	grip.Part0 = arm
	grip.Part1 = handle
	grip.C1 = gripC1
	grip.Parent = arm
	table.insert(self.weaponJoints, grip)

	-- Every sub-part is jointed to the Handle rather than welded, and named for the part it
	-- drives. That is exactly how the reload clip finds it: a Pose named "Mag" drives the
	-- Motor6D whose Part1 is named "Mag".
	for _, entry in subParts do
		local motor = Instance.new("Motor6D")
		motor.Name = entry.part.Name
		motor.Part0 = handle
		motor.Part1 = entry.part
		motor.C0 = entry.offset
		motor.C1 = CFrame.new()
		motor.Parent = handle
		table.insert(self.weaponJoints, motor)
	end

	self.weaponName = weaponName
	self.gunModel = gun
	self:_setupMuzzle(gun)

	log("%s: handle + %d moving part(s) jointed", weaponName, #subParts)
	return true
end

-- Holds a plain Tool, using the grip the tool itself defines.
--
-- Roblox seats a tool with a RightGrip weld: Part0 the right arm, C0 the hand position at
-- the bottom of that arm, C1 the Tool.Grip CFrame. Reproducing exactly that puts the weapon
-- in the viewmodel's hand the same way it sits in the character's, with no per-weapon
-- tuning - the tool already carries the answer.
--
-- The hand offset is derived from THIS arm's height rather than assumed to be the R6 -1,
-- because the reference arm is 2.32 studs tall, not 2.
function Viewmodel:_holdTool(weaponName, tool, config)
	local arm = self.model:FindFirstChild("RightArm")
	if not arm then
		warn("[Viewmodel] the rig has no RightArm to hang a tool from")
		return false
	end

	local held = tool:Clone()
	-- A Tool inside a plain Model is inert, but strip the noisy parts anyway so the copy
	-- cannot fire scripts or play sounds of its own.
	for _, descendant in held:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("Sound") then
			descendant:Destroy()
		end
	end

	local handle = held:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		for _, descendant in held:GetDescendants() do
			if descendant:IsA("BasePart") then
				handle = descendant
				break
			end
		end
	end
	if not handle then
		warn(string.format("[Viewmodel] %s has no part to hold", weaponName))
		held:Destroy()
		return false
	end

	makeInert(held)
	for _, descendant in held:GetDescendants() do
		if descendant:IsA("BasePart") then descendant.Anchored = false end
	end
	held.Parent = self.model

	-- Anything not already joined to the handle would fall away once unanchored.
	for _, descendant in held:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= handle and #descendant:GetJoints() == 0 then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = descendant
			weld.Parent = handle
		end
	end

	local grip = Instance.new("Motor6D")
	grip.Name = "GunGrip"
	grip.Part0 = arm
	grip.Part1 = handle
	grip.C0 = CFrame.new(0, -arm.Size.Y / 2, 0)
	grip.C1 = tool.Grip
	if config and config.GripAdjust then
		grip.C1 = grip.C1 * config.GripAdjust
	end
	grip.Parent = arm
	table.insert(self.weaponJoints, grip)

	self.weaponName = weaponName
	self.gunModel = held
	self:_setupMuzzle(held)

	log("%s held from its Tool.Grip", weaponName)
	return true
end

function Viewmodel:_setupMuzzle(gunModel)
	for _, descendant in gunModel:GetDescendants() do
		if descendant:IsA("BasePart") and string.find(string.lower(descendant.Name), MUZZLE_PART_NAME, 1, true) then
			self.muzzlePart = descendant

			local light = Instance.new("PointLight")
			light.Name = "MuzzleLight"
			light.Color = MUZZLE_COLOR
			light.Brightness = 0
			light.Range = MUZZLE_RANGE
			light.Shadows = false
			light.Enabled = false
			light.Parent = descendant

			self.muzzleLight = light
			log("muzzle light on %q", descendant.Name)
			return
		end
	end
end

function Viewmodel:GetMuzzlePosition()
	if not self.muzzlePart or not self.muzzlePart.Parent then return nil end
	return self.muzzlePart.Position
end

function Viewmodel:MuzzleFlash(scale)
	if not self.muzzleLight then return end
	self.muzzleAlpha = math.clamp(scale or 1, 0, 1)
end

function Viewmodel:applyRecoilImpulse(impulse)
	self.springVelocity = self.springVelocity + Vector3.new(
		math.rad(impulse.X),
		math.rad(impulse.Y),
		math.rad(impulse.Z)
	)
	self.isSpringActive = true
end

-- Aiming is a field-of-view change and nothing else. The viewmodel does not move and no
-- pose is swapped in; CameraFX.SetAim, driven from GunHandler, is the whole of ADS.
function Viewmodel:StartADS() end
function Viewmodel:StopADS() end

-- The reload drives the WEAPON's own joints - magazine, trigger, charging handle - because
-- those are named for parts that exist here. Its arm and torso poses target an R6 skeleton
-- this rig does not have, so they find nothing and are ignored. That is the intended
-- outcome: the gun reloads without the arms being thrown somewhere this rig was never
-- built for.
function Viewmodel:PlayReload(duration)
	if not self.weaponName then return false end

	if not self.reloadTrack then
		local controller = self.model:FindFirstChildOfClass("AnimationController")
		local animator = controller and controller:FindFirstChildOfClass("Animator")
		local rigData = WeaponRigData.Get(self.weaponName)
		local sequence = rigData and rigData.reload
		if not animator or not sequence then return false end

		local ok, contentId = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
		end)
		if not ok then
			warn(string.format("[Viewmodel] could not register the %s reload: %s", tostring(self.weaponName), tostring(contentId)))
			return false
		end

		local animation = Instance.new("Animation")
		animation.Name = "Reload"
		animation.AnimationId = contentId

		local loaded, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not loaded then
			warn(string.format("[Viewmodel] could not load the %s reload: %s", tostring(self.weaponName), tostring(track)))
			return false
		end

		track.Priority = Enum.AnimationPriority.Action
		track.Looped = false
		self.reloadTrack = track
	end

	self.reloadTrack:Stop(0.1)
	self.reloadTrack:Play(0.15)
	if duration and duration > 0 and self.reloadTrack.Length > 0 then
		self.reloadTrack:AdjustSpeed(self.reloadTrack.Length / duration)
	end
	return true
end

function Viewmodel:StopReload()
	if self.reloadTrack then
		self.reloadTrack:Stop(0.2)
	end
end

function Viewmodel:Enable()
	if self.bindName then return end

	-- Anything else called Viewmodel under the Camera is an orphan - an instance that lost
	-- its owner without being destroyed. Nothing pins it, so it hangs in the world exactly
	-- where it was built, which is what a stray gun floating over the map turns out to be.
	-- Swept on every Enable rather than only at construction, because that is when this one
	-- becomes the single owner of the view.
	for _, existing in camera:GetChildren() do
		if existing.Name == "Viewmodel" and existing ~= self.model then
			existing:Destroy()
		end
	end

	self.model.Parent = camera
	self.shown = true

	bindSerial += 1
	self.bindName = "Viewmodel_" .. bindSerial
	-- Last in the render phase, so the camera already carries this frame's aim, recoil and
	-- shake before the viewmodel is pinned to it.
	RunService:BindToRenderStep(self.bindName, Enum.RenderPriority.Last.Value, function(dt)
		self:_update(dt)
	end)

	log("enabled (holding: %s)", self.weaponName or "nothing")
end

function Viewmodel:_update(dt)
	local owned = player:GetAttribute("GunCameraActive") == true
	if owned ~= self.shown then
		self.shown = owned
		self.model.Parent = owned and camera or nil
	end
	if not owned then return end

	if self.isSpringActive then
		if self.springPosition.Magnitude < 0.001 and self.springVelocity.Magnitude < 0.001 then
			self.isSpringActive = false
			self.springPosition = Vector3.zero
			self.springVelocity = Vector3.zero
		else
			local force = -RECOIL_STIFFNESS * self.springPosition
			local damping = -RECOIL_DAMPING * self.springVelocity
			self.springVelocity = self.springVelocity + (force + damping) * dt
			self.springPosition = self.springPosition + self.springVelocity * dt
		end
	end

	-- The root IS the eye in this rig, so it goes straight onto the camera. This is the
	-- reference's placement, unchanged, and it is why nothing here needs a tuned offset.
	local positionalOffset = CFrame.new(self.offsetSpring.Position)
	local recoilRotation = CFrame.Angles(self.springPosition.X, self.springPosition.Y, self.springPosition.Z)
	self.model:PivotTo(camera.CFrame * positionalOffset * recoilRotation)

	if self.muzzleLight then
		if self.muzzleAlpha > 0 then
			self.muzzleAlpha = math.max(0, self.muzzleAlpha - dt * MUZZLE_DECAY)
			self.muzzleLight.Brightness = MUZZLE_BRIGHTNESS * self.muzzleAlpha
			self.muzzleLight.Range = MUZZLE_RANGE * (0.55 + 0.45 * self.muzzleAlpha)
			self.muzzleLight.Enabled = self.muzzleAlpha > 0.01
		elseif self.muzzleLight.Enabled then
			self.muzzleLight.Enabled = false
		end
	end
end

function Viewmodel:Disable()
	if self.bindName then
		pcall(RunService.UnbindFromRenderStep, RunService, self.bindName)
		self.bindName = nil
	end
	if self.model then
		self.model.Parent = nil
	end
	self.shown = false

	self.isSpringActive = false
	self.springPosition = Vector3.zero
	self.springVelocity = Vector3.zero
end

function Viewmodel:Destroy()
	self.destroyed = true
	self:Disable()
	self:ClearWeapon()

	if self.offsetSpring then
		self.offsetSpring:Destroy()
		self.offsetSpring = nil
	end
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
end

return Viewmodel
