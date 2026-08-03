local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FXConfig = require(ReplicatedStorage.Shared.Modules.Core.FXConfig)

local FXUtil = {}

local lastMuzzleFlash = 0

-- Everything lands in WallDebrisFolder because MovementClient's wall probes and
-- WeaponServer's hitscan already exclude it. Effects parented anywhere else in Workspace
-- would block shots and trigger false wall runs.
local function effectsFolder()
	local folder = Workspace:FindFirstChild("WallDebrisFolder")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WallDebrisFolder"
		folder.Parent = Workspace
	end
	return folder
end

-- Effects must never participate in physics or raycasts.
local function makeEffectPart(shape)
	local part = Instance.new("Part")
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	return part
end

local function soundTemplate(name)
	if not name or name == "" then return nil end

	local folder = SoundService:FindFirstChild(FXConfig.SoundFolder)
	local template = folder and folder:FindFirstChild(name)
	return (template and template:IsA("Sound")) and template or nil
end

-- Clones the SoundService template onto the emitting part so it plays positionally,
-- inheriting whatever volume and rolloff are set in Studio.
function FXUtil.PlaySoundAt(name, parent, volumeScale)
	local template = soundTemplate(name)
	if not template or not parent then return end

	local sound = template:Clone()
	sound.Volume = template.Volume * (volumeScale or 1)
	sound.Parent = parent
	sound:Play()

	Debris:AddItem(sound, 5)
end

-- Sound with no visual, for moments that only need audio. Emits from a throwaway anchored
-- part so it is positional without depending on the character surviving the sound.
function FXUtil.PlaySoundAtPosition(name, position, volumeScale)
	if not soundTemplate(name) or not position then return end

	local emitter = Instance.new("Part")
	emitter.Name = "SoundEmitter"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(0.1, 0.1, 0.1)
	emitter.CFrame = CFrame.new(position)
	emitter.Parent = effectsFolder()

	FXUtil.PlaySoundAt(name, emitter, volumeScale)
	Debris:AddItem(emitter, 5)
end

function FXUtil.LandImpact(position)
	local config = FXConfig.Land
	if not config.Enabled then return end
	FXUtil.PlaySoundAtPosition(config.Sound, position, config.SoundVolume)

	-- Dust puff kicked out sideways at ground level.
	if (config.DustParticles or 0) > 0 and position then
		local emitterPart = makeEffectPart(Enum.PartType.Ball)
		emitterPart.Transparency = 1
		emitterPart.Size = Vector3.new(0.5, 0.5, 0.5)
		emitterPart.CFrame = CFrame.new(position)

		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(config.DustColor or Color3.new(1, 1, 1))
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 1.6),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(0.25, 0.45)
		emitter.Speed = NumberRange.new(6, 10)
		emitter.SpreadAngle = Vector2.new(85, 85)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Enabled = false
		emitter.Parent = emitterPart

		emitterPart.Parent = effectsFolder()
		emitter:Emit(config.DustParticles)
		Debris:AddItem(emitterPart, 1)
	end
end

-- One Trail per character, between two vertical attachments on the root. The caller
-- toggles .Enabled by speed; recreating per toggle would leak attachments.
function FXUtil.EnsureSpeedTrail(root)
	local config = FXConfig.SpeedTrail
	if not config.Enabled or not root then return nil end

	local existing = root:FindFirstChild("SpeedTrail")
	if existing then return existing end

	local top = Instance.new("Attachment")
	top.Name = "SpeedTrailTop"
	top.Position = Vector3.new(0, 1, 0)
	top.Parent = root

	local bottom = Instance.new("Attachment")
	bottom.Name = "SpeedTrailBottom"
	bottom.Position = Vector3.new(0, -1, 0)
	bottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Name = "SpeedTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(config.Color or Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = config.Lifetime or 0.25
	trail.WidthScale = NumberSequence.new(1)
	trail.FaceCamera = true
	trail.LightInfluence = 0
	trail.Enabled = false
	trail.Parent = root

	return trail
end

function FXUtil.SlideStart(part)
	local config = FXConfig.Slide
	if not config.Enabled then return end
	FXUtil.PlaySoundAt(config.Sound, part, config.SoundVolume)
end

function FXUtil.MuzzleFlash(position)
	local config = FXConfig.MuzzleFlash
	if not config.Enabled or not position then return end

	local now = os.clock()
	if now - lastMuzzleFlash < (config.Throttle or 0) then return end
	lastMuzzleFlash = now

	local flash = makeEffectPart(Enum.PartType.Ball)
	flash.Name = "MuzzleFlash"
	flash.Color = config.Color
	flash.Size = Vector3.new(config.Size, config.Size, config.Size)
	flash.CFrame = CFrame.new(position)

	local light = Instance.new("PointLight")
	light.Color = config.Color
	light.Range = config.LightRange
	light.Brightness = config.LightBrightness
	light.Parent = flash

	flash.Parent = effectsFolder()

	local info = TweenInfo.new(config.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(flash, info, {Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1)}):Play()
	TweenService:Create(light, info, {Brightness = 0}):Play()

	Debris:AddItem(flash, config.Duration + 0.1)
end

-- Expanding shockwave ring under the player, plus a whoosh.
function FXUtil.DoubleJumpBurst(position)
	local config = FXConfig.DoubleJump
	if not config.Enabled or not position then return end

	local ring = makeEffectPart(Enum.PartType.Cylinder)
	ring.Name = "DoubleJumpRing"
	ring.Color = config.Color
	ring.Size = config.StartSize
	ring.Transparency = 0.15
	-- Rotate the cylinder's X axis to vertical so it reads as a flat disc on the ground.
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = effectsFolder()

	TweenService:Create(
		ring,
		TweenInfo.new(config.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = config.EndSize, Transparency = 1}
	):Play()

	FXUtil.PlaySoundAt(config.Sound, ring, config.SoundVolume)

	Debris:AddItem(ring, config.Duration + 0.2)
end

return FXUtil
