local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FXConfig = require(ReplicatedStorage.Shared.Modules.Core.FXConfig)
local CombatConfig = require(ReplicatedStorage.Shared.Modules.Core.CombatConfig)

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
		if d:IsA("Attachment")
			and (d.Name == "ProjectileStart" or d.Name == "MuzzlePoint" or d.Name == "Muzzle") then
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

-- Viewmodel muzzle FX live on the gun itself so they track it every frame.
-- A world-space part placed at the muzzle's position desyncs immediately, since
-- the viewmodel is re-pivoted to the camera on every RenderStepped.
function FXUtil.EnsureMuzzleFX(parent)
	local config = FXConfig.MuzzleFlash
	if not config.Enabled or not parent then return nil end

	local existing = parent:FindFirstChild("ViewmodelMuzzleFX")
	if existing then
		return { light = existing, emitter = existing:FindFirstChildOfClass("ParticleEmitter") }
	end

	local light = Instance.new("PointLight")
	light.Name = "ViewmodelMuzzleFX"
	light.Color = config.Color
	light.Range = config.LightRange
	light.Brightness = 0
	light.Enabled = true

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Flash"
	emitter.Color = ColorSequence.new(config.Color)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, config.Size * 1.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(config.Duration * 0.6, config.Duration)
	emitter.Speed = NumberRange.new(0, 1)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Enabled = false
	emitter.Parent = light

	light.Parent = parent
	return { light = light, emitter = emitter }
end

function FXUtil.FlashMuzzle(fx, scale)
	if not fx or not fx.light or not fx.light.Parent then return end
	local config = FXConfig.MuzzleFlash
	scale = scale or 1

	if fx.emitter then
		fx.emitter:Emit(6)
	end

	fx.light.Brightness = config.LightBrightness * scale
	TweenService:Create(
		fx.light,
		TweenInfo.new(config.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0 }
	):Play()
end

-- Moving tracers (CombatConfig.CombatFeedback). One render-step loop flies every
-- streak in the air, and only runs while there is one.
local liveTracers = {}
local tracerLoop = nil

local function placeTracer(tracer, camera)
	local config = FXConfig.Tracer
	local head = math.min(tracer.travelled, tracer.distance)
	local tail = math.clamp(tracer.travelled - config.Length, 0, tracer.distance)
	local mid = tracer.origin + tracer.direction * ((head + tail) / 2)
	-- Thickness grows with distance from the camera, so a far streak keeps the
	-- same few pixels instead of thinning to nothing.
	local studsPerPixel = 2 * math.tan(math.rad(camera.FieldOfView) / 2) / camera.ViewportSize.Y
	local width = math.max((mid - camera.CFrame.Position).Magnitude * studsPerPixel * config.Pixels, config.MinWidth)
	tracer.part.Size = Vector3.new(width, width, math.max(head - tail, 0.05))
	tracer.part.CFrame = CFrame.lookAt(mid, mid + tracer.direction)
end

local function stepTracers(dt)
	local camera = Workspace.CurrentCamera
	for i = #liveTracers, 1, -1 do
		local tracer = liveTracers[i]
		tracer.travelled += tracer.speed * dt
		-- Finished once the tail has caught up with the impact point.
		if tracer.travelled - FXConfig.Tracer.Length >= tracer.distance then
			tracer.part:Destroy()
			table.remove(liveTracers, i)
		else
			placeTracer(tracer, camera)
		end
	end
	if #liveTracers == 0 and tracerLoop then
		tracerLoop:Disconnect()
		tracerLoop = nil
	end
end

local function movingTracer(origin, targetPos, distance)
	local config = FXConfig.Tracer
	local part = makeEffectPart(Enum.PartType.Block)
	part.Name = "Tracer"
	part.Color = config.Color
	part.Transparency = config.Transparency

	local speed = math.max(config.Speed, distance / config.MaxTime)
	local tracer = {
		part = part,
		origin = origin,
		direction = (targetPos - origin).Unit,
		distance = distance,
		speed = speed,
		-- One frame along already, so the streak shows the frame the shot is fired.
		travelled = speed / 60,
	}
	placeTracer(tracer, Workspace.CurrentCamera)
	part.Parent = effectsFolder()

	table.insert(liveTracers, tracer)
	if not tracerLoop then
		tracerLoop = RunService.RenderStepped:Connect(stepTracers)
	end
end

function FXUtil.BulletTracer(origin, targetPos)
	if not origin or not targetPos then return end

	local distance = (targetPos - origin).Magnitude
	if distance < 0.1 then return end

	if CombatConfig.IsEnabled("CombatFeedback") then
		movingTracer(origin, targetPos, distance)
		return
	end

	local tracer = Instance.new("Part")
	tracer.Name = "Tracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.CastShadow = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.new(1, 0.9, 0.5)
	tracer.Transparency = 0.2
	tracer.Size = Vector3.new(0.1, 0.1, distance)
	tracer.CFrame = CFrame.lookAt(origin, targetPos) * CFrame.new(0, 0, -distance / 2)
	tracer.Parent = effectsFolder()

	local tween = TweenService:Create(tracer, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(0, 0, distance),
	})
	tween:Play()
	tween.Completed:Connect(function() tracer:Destroy() end)
end

-- A bullet striking the world (CombatConfig.CombatFeedback): a short-lived
-- hole on the surface, a puff of dust in the surface's colour and a few sparks.
function FXUtil.BulletImpact(position, normal, surface)
	if not position or not normal then return end

	local right = normal
	local up = math.abs(right.Y) > 0.99 and Vector3.new(0, 0, 1) or Vector3.new(0, 1, 0)
	local back = right:Cross(up).Unit
	up = back:Cross(right).Unit

	local hole = makeEffectPart(Enum.PartType.Cylinder)
	hole.Name = "BulletHole"
	hole.Material = Enum.Material.SmoothPlastic
	hole.Color = Color3.fromRGB(25, 25, 25)
	local radius = 0.28 + math.random() * 0.08
	hole.Size = Vector3.new(0.02, radius, radius)
	hole.CFrame = CFrame.fromMatrix(position + normal * 0.012, right, up, back)
	hole.Parent = effectsFolder()

	local emitterPart = makeEffectPart(Enum.PartType.Ball)
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(0.2, 0.2, 0.2)
	emitterPart.CFrame = CFrame.lookAt(position, position + normal)

	local surfaceColor = (surface and surface:IsA("BasePart")) and surface.Color or Color3.fromRGB(180, 180, 180)
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(surfaceColor:Lerp(Color3.new(1, 1, 1), 0.25))
	dust.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Lifetime = NumberRange.new(0.25, 0.45)
	dust.Speed = NumberRange.new(4, 9)
	dust.SpreadAngle = Vector2.new(35, 35)
	dust.Acceleration = Vector3.new(0, -12, 0)
	dust.EmissionDirection = Enum.NormalId.Front
	dust.Enabled = false
	dust.Parent = emitterPart

	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140))
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.08),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Lifetime = NumberRange.new(0.08, 0.18)
	sparks.Speed = NumberRange.new(14, 26)
	sparks.SpreadAngle = Vector2.new(45, 45)
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Enabled = false
	sparks.Parent = emitterPart

	emitterPart.Parent = effectsFolder()
	dust:Emit(6)
	sparks:Emit(4)
	Debris:AddItem(emitterPart, 1)

	task.delay(2.5, function()
		if not hole.Parent then return end
		local fade = TweenService:Create(hole, TweenInfo.new(1), { Transparency = 1 })
		fade:Play()
		fade.Completed:Connect(function() hole:Destroy() end)
	end)
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
