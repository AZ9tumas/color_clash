local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SpringHandler = require(Shared.Modules.Utils.Spring)
local FXConfig = require(Shared.Modules.Core.FXConfig)

local function log(message, ...)
	if FXConfig.GunDebug then
		print("[Viewmodel] " .. string.format(message, ...))
	end
end

-- Viewmodel, ported from the reference gunsystem's ViewModelHandler and using its actual
-- rig (extract_reference_viewmodel.luau lifts ReplicatedStorage.Viewmodel straight out of
-- gunsystem.rbxl). The shape of it is deliberately unchanged from the reference:
--
--   * one small model - transparent HumanoidRootPart as PrimaryPart, one visible RightArm,
--     a transparent CameraBone - parented to the Camera while equipped and put back in
--     ReplicatedStorage when not,
--   * placed every frame with SetPrimaryPartCFrame(camera * positionalOffset * recoil),
--   * ADS is a Vector3 offset spring retargeted on aim,
--   * recoil is a 300/30 rotational spring fed by impulses.
--
-- The gun is not part of the rig. GunHandler clones the weapon in on equip and joints it
-- to RightArm through a Motor6D named GunGrip, which is the reference's arrangement and is
-- why per-gun grip offsets live in the item config rather than in the model.
--
-- The one thing tightened relative to the reference: every part is made non-collidable,
-- non-queryable, massless and explicitly unanchored. Nothing here may be anchored - an
-- anchored part sitting inside the player's own torso is immovable, so the solver resolves
-- the overlap by firing the player across the map instead.
local Viewmodel = {}
Viewmodel.__index = Viewmodel

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local DEFAULT_OFFSET = Vector3.zero
local DEFAULT_ADS_OFFSET = Vector3.new(-1.15, 0, 0)

local RECOIL_STIFFNESS = 300
local RECOIL_DAMPING = 30

-- Muzzle light. Driven off a part named "Muzzle" inside the weapon, which only some models
-- carry - Pistol and SMG at the time of writing, verified against the place. Guns without
-- one simply do not light, and gain it for free the day the part is added, because the
-- lookup is by name and nothing else depends on it.
local MUZZLE_PART_NAME = "muzzle"
local MUZZLE_COLOR = Color3.fromRGB(255, 201, 120)
local MUZZLE_BRIGHTNESS = 7
local MUZZLE_RANGE = 16
-- Per second. ~0.07s of flash, which for the SMG's 16 rounds a second means the light
-- effectively holds through sustained fire instead of strobing.
local MUZZLE_DECAY = 14

local bindSerial = 0

local function makeInert(instance)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			descendant.CastShadow = false
			descendant.Anchored = false
		end
	end
	if instance:IsA("BasePart") then
		instance.CanCollide = false
		instance.CanQuery = false
		instance.CanTouch = false
		instance.Massless = true
		instance.CastShadow = false
		instance.Anchored = false
	end
end

function Viewmodel.new(config)
	config = config or {}

	local template = ReplicatedStorage:FindFirstChild("Viewmodel")
	if not template then
		warn("[Viewmodel] ReplicatedStorage.Viewmodel is missing - run `lune run extract_reference_viewmodel` and resync")
		return nil
	end

	local model = template:Clone()
	makeInert(model)

	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChild("HumanoidRootPart")
	end
	if not model.PrimaryPart then
		warn("[Viewmodel] the rig has no PrimaryPart and no HumanoidRootPart to fall back to")
		model:Destroy()
		return nil
	end

	local offset = config.Offset or DEFAULT_OFFSET

	local self = setmetatable({
		model = model,
		offset = offset,
		adsOffset = config.AdsOffset or DEFAULT_ADS_OFFSET,
		offsetSpring = SpringHandler.new(offset),

		springPosition = Vector3.zero,
		springVelocity = Vector3.zero,
		isSpringActive = false,

		muzzlePart = nil,
		muzzleLight = nil,
		muzzleAlpha = 0,

		bindName = nil,
		shown = false,
	}, Viewmodel)

	return self
end

-- Rotational recoil, in degrees. Straight from the reference: impulses add velocity, the
-- spring carries it back to rest.
function Viewmodel:applyRecoilImpulse(impulse)
	self.springVelocity = self.springVelocity + Vector3.new(
		math.rad(impulse.X),
		math.rad(impulse.Y),
		math.rad(impulse.Z)
	)
	self.isSpringActive = true
end

function Viewmodel:StartADS()
	self.offsetSpring.Target = self.adsOffset
end

function Viewmodel:StopADS()
	self.offsetSpring.Target = self.offset
end

-- The gun rides here, jointed to the arm rather than parented into the world.
function Viewmodel:AttachGun(gunModel, gripC1)
	local arm = self.model:FindFirstChild("RightArm")
	local handle = gunModel:FindFirstChild("Handle") or gunModel:FindFirstChildWhichIsA("BasePart", true)
	if not arm or not handle then
		warn("[Viewmodel] cannot attach a gun without both a RightArm on the rig and a Handle on the gun")
		return false
	end

	makeInert(gunModel)
	gunModel.Parent = self.model

	-- Anything in the weapon that is not jointed to the Handle would simply fall away the
	-- moment it is unanchored, so weld the strays on the way in.
	for _, part in gunModel:GetDescendants() do
		if part:IsA("BasePart") and part ~= handle then
			local jointed = false
			for _, joint in part:GetJoints() do
				if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then
					jointed = true
					break
				end
			end
			if not jointed then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = part
				weld.Parent = handle
			end
		end
	end

	local grip = arm:FindFirstChild("GunGrip") or Instance.new("Motor6D")
	grip.Name = "GunGrip"
	grip.Part0 = arm
	grip.Part1 = handle
	grip.C1 = gripC1 or CFrame.new()
	grip.Parent = arm

	self:_setupMuzzle(gunModel)

	return true
end

-- The light lives on the viewmodel's copy of the gun, not the real one in the character's
-- hand. That is the copy the player can actually see, and in first person the real weapon
-- is hidden inside a fully transparent character several studs behind the camera - a flash
-- there lights the wrong place entirely.
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

	log("no muzzle part on this weapon - firing will not light")
end

-- World position of the visible barrel tip, for lining the flash particle up with the gun
-- the player is looking at. Nil when this weapon has no muzzle part.
function Viewmodel:GetMuzzlePosition()
	if not self.muzzlePart or not self.muzzlePart.Parent then return nil end
	return self.muzzlePart.Position
end

function Viewmodel:MuzzleFlash(scale)
	if not self.muzzleLight then return end
	self.muzzleAlpha = math.clamp(scale or 1, 0, 1)
end

function Viewmodel:Enable()
	if self.bindName then return end

	self.model.Parent = camera
	self.shown = true

	bindSerial += 1
	self.bindName = "Viewmodel_" .. bindSerial
	-- Last in the render phase, so the camera already carries this frame's aim, recoil and
	-- shake before the viewmodel is placed against it. The reference used RenderStepped;
	-- this game writes the camera from a render-step bind, which runs earlier, so binding
	-- here is what keeps the gun locked to the view instead of trailing it by a frame.
	RunService:BindToRenderStep(self.bindName, Enum.RenderPriority.Last.Value, function(dt)
		self:_update(dt)
	end)

	log("enabled")
end

function Viewmodel:_update(dt)
	-- The aim rig hands the camera back on death, ragdoll and menu without unequipping.
	-- Arms pinned to a camera that is no longer ours float in front of the death screen.
	local owned = player:GetAttribute("GunCameraActive") == true
	if owned ~= self.shown then
		self.shown = owned
		self.model.Parent = owned and camera or ReplicatedStorage
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

	local positionalOffset = CFrame.new(self.offsetSpring.Position)
	local recoilRotation = CFrame.Angles(self.springPosition.X, self.springPosition.Y, self.springPosition.Z)

	self.model:PivotTo(camera.CFrame * positionalOffset * recoilRotation)

	-- Decayed here rather than tweened per shot: an SMG fires sixteen times a second, and
	-- that is sixteen tweens a second competing for the same two properties.
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
		self.model.Parent = ReplicatedStorage
	end
	self.shown = false

	self.isSpringActive = false
	self.springPosition = Vector3.zero
	self.springVelocity = Vector3.zero
	self.offsetSpring.Target = self.offset

	log("disabled")
end

function Viewmodel:Destroy()
	self:Disable()

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
