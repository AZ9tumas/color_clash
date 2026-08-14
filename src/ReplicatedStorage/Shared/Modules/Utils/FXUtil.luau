local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FXConfig = require(ReplicatedStorage.Shared.Modules.Core.FXConfig)

local FXUtil = {}

local lastMuzzleFlash = 0

local function effectsFolder()
	local folder = Workspace:FindFirstChild("WallDebrisFolder")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WallDebrisFolder"
		folder.Parent = Workspace
	end
	return folder
end

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

function FXUtil.PlaySoundAt(name, parent, volumeScale)
	local template = soundTemplate(name)
	if not template or not parent then return end

	local sound = template:Clone()
	sound.Volume = template.Volume * (volumeScale or 1)
	sound.Parent = parent
	sound:Play()

	Debris:AddItem(sound, 5)
end

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

function FXUtil.GetMuzzlePosition(tool)
	if not tool then return nil end

	local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true)
	if not handle then return nil end

	local MAX_MUZZLE_OFFSET = 15

	for _, d in tool:GetDescendants() do
		if d:IsA("Attachment") and (d.Name == "MuzzlePoint" or d.Name == "Muzzle") then
			local position = d.WorldPosition
			if (position - handle.Position).Magnitude <= MAX_MUZZLE_OFFSET then
				return position
			end
		end
	end

	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") and string.find(string.lower(d.Name), "muzzle") then
			if (d.Position - handle.Position).Magnitude <= MAX_MUZZLE_OFFSET then
				return d.Position
			end
		end
	end

	return handle.Position + handle.CFrame.LookVector * (handle.Size.Z / 2)
end

function FXUtil.BodyHit(position, isHeadshot)
	if not position then return end

	local emitterPart = makeEffectPart(Enum.PartType.Ball)
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(0.3, 0.3, 0.3)
	emitterPart.CFrame = CFrame.new(position)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(190, 25, 25), Color3.fromRGB(120, 10, 10))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, isHeadshot and 0.55 or 0.35),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.2, 0.4)
	emitter.Speed = NumberRange.new(8, isHeadshot and 18 or 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.Enabled = false
	emitter.Parent = emitterPart

	emitterPart.Parent = effectsFolder()
	emitter:Emit(isHeadshot and 18 or 10)
	Debris:AddItem(emitterPart, 1)
end

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

function FXUtil.MuzzleFlash(position, scale)
	local config = FXConfig.MuzzleFlash
	if not config.Enabled or not position then return end

	local now = os.clock()
	if now - lastMuzzleFlash < (config.Throttle or 0) then return end
	lastMuzzleFlash = now

	scale = scale or 1
	local size = config.Size * scale

	local flash = makeEffectPart(Enum.PartType.Ball)
	flash.Name = "MuzzleFlash"
	flash.Color = config.Color
	flash.Size = Vector3.new(size, size, size)
	flash.CFrame = CFrame.new(position)

	local light = Instance.new("PointLight")
	light.Color = config.Color
	light.Range = config.LightRange * scale
	light.Brightness = config.LightBrightness
	light.Parent = flash

	flash.Parent = effectsFolder()

	local info = TweenInfo.new(config.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(flash, info, {Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1)}):Play()
	TweenService:Create(light, info, {Brightness = 0}):Play()

	Debris:AddItem(flash, config.Duration + 0.1)
end

function FXUtil.EjectShell(position, rightVector)
	if not position then return end

	local shell = Instance.new("Part")
	shell.Name = "ShellCasing"
	shell.Size = Vector3.new(0.12, 0.12, 0.34)
	shell.Color = Color3.fromRGB(200, 160, 60)
	shell.Material = Enum.Material.Metal
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.Massless = true
	shell.CFrame = CFrame.new(position) * CFrame.Angles(math.random(), math.random(), math.random())

	local direction = (rightVector or Vector3.xAxis)
	shell.AssemblyLinearVelocity = direction * (8 + math.random() * 5) + Vector3.new(0, 9 + math.random() * 4, 0)
	shell.AssemblyAngularVelocity = Vector3.new(math.random(-30, 30), math.random(-30, 30), math.random(-30, 30))

	shell.Parent = effectsFolder()

	TweenService:Create(shell, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
	}):Play()
	Debris:AddItem(shell, 0.9)
end

function FXUtil.DoubleJumpBurst(position)
	local config = FXConfig.DoubleJump
	if not config.Enabled or not position then return end

	local ring = makeEffectPart(Enum.PartType.Cylinder)
	ring.Name = "DoubleJumpRing"
	ring.Color = config.Color
	ring.Size = config.StartSize
	ring.Transparency = 0.15

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
