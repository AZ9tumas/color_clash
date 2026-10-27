-- Procedural motion layered over the animated viewmodel: recoil kick, look sway,
-- movement bob, landing dip and a faint idle breath. The authored animations pose
-- the rig; this moves the rig as a whole in camera space, so the two never fight.
-- ViewModelHandler evaluates it once per frame, after every camera writer.
local Players = game:GetService("Players")

local Motion = {}
Motion.__index = Motion

local player = Players.LocalPlayer

-- Springs are integrated in fixed substeps: a stiff spring stepped once per frame
-- blows up at low frame rates, and recoil springs are deliberately stiff.
local MAX_STEP = 1 / 120

local Spring = {}
Spring.__index = Spring

local function newSpring(frequency: number, dampingRatio: number)
	return setmetatable({
		position = Vector3.zero,
		velocity = Vector3.zero,
		target = Vector3.zero,
		frequency = frequency,
		damping = dampingRatio,
	}, Spring)
end

function Spring:step(dt: number)
	local omega = self.frequency * 2 * math.pi
	local remaining = dt
	while remaining > 0 do
		local h = math.min(remaining, MAX_STEP)
		local accel = (self.target - self.position) * (omega * omega)
			- self.velocity * (2 * self.damping * omega)
		self.velocity += accel * h
		self.position += self.velocity * h
		remaining -= h
	end
end

function Spring:reset()
	self.position = Vector3.zero
	self.velocity = Vector3.zero
	self.target = Vector3.zero
end

local function clampVector(v: Vector3, limit: Vector3): Vector3
	return Vector3.new(
		math.clamp(v.X, -limit.X, limit.X),
		math.clamp(v.Y, -limit.Y, limit.Y),
		math.clamp(v.Z, -limit.Z, limit.Z)
	)
end

local function isAiming(): boolean
	return player ~= nil and player:GetAttribute("AimFOV") ~= nil
end

function Motion.new(settings)
	return setmetatable({
		settings = settings,
		kickMove = newSpring(settings.KickFrequency, settings.KickDamping),
		kickTurn = newSpring(settings.KickFrequency * 0.9, settings.KickDamping),
		sway = newSpring(settings.SwayFrequency, settings.SwayDamping),
		swayMove = newSpring(settings.SwayFrequency, settings.SwayDamping),
		land = newSpring(settings.LandFrequency, settings.LandDamping),
		bobPhase = 0,
		bobAmount = 0,
		breathPhase = 0,
		lastCamera = nil,
		lastVerticalSpeed = 0,
		wasGrounded = true,
		drawDuration = nil,
		drawElapsed = 0,
	}, Motion)
end

function Motion:Reset()
	self.kickMove:reset()
	self.kickTurn:reset()
	self.sway:reset()
	self.swayMove:reset()
	self.land:reset()
	self.bobAmount = 0
	self.lastCamera = nil
	self.wasGrounded = true
	self.drawDuration = nil
end

-- Raises the gun into place over `duration`, so a weapon swap reads as a draw
-- rather than a pop while there is no authored equip animation.
function Motion:Draw(duration: number)
	self.drawDuration = math.max(duration, 0.05)
	self.drawElapsed = 0
end

-- recoilPitch / recoilYaw are the weapon's Items.Recoil values, so each gun kicks
-- in proportion to the same numbers that already drive its camera recoil.
function Motion:Kick(recoilPitch: number, recoilYaw: number, aiming: boolean?)
	local s = self.settings
	local scale = (aiming or isAiming()) and s.AimKickScale or 1
	local side = math.random() < 0.5 and -1 or 1

	-- camera space: +Z is back toward the eye, +Y is up
	self.kickMove.velocity += Vector3.new(
		recoilYaw * s.KickSide * (math.random() * 2 - 1),
		recoilPitch * s.KickUp,
		recoilPitch * s.KickBack
	) * scale

	-- +X pitches the barrel up
	self.kickTurn.velocity += Vector3.new(
		recoilPitch * s.KickPitch,
		recoilYaw * s.KickYaw * side,
		recoilYaw * s.KickRoll * (math.random() * 2 - 1)
	) * scale
end

function Motion:Update(dt: number, cameraCFrame: CFrame): CFrame
	local s = self.settings
	dt = math.min(dt, 1 / 15)
	local aiming = isAiming()

	-- Look sway: the gun trails the camera's turn rate, which is what gives it weight.
	if self.lastCamera then
		local delta = self.lastCamera:ToObjectSpace(cameraCFrame)
		local dPitch, dYaw = delta:ToEulerAnglesYXZ()
		local rate = Vector3.new(dPitch, dYaw, 0) / math.max(dt, 1e-3)
		local scale = aiming and s.AimSwayScale or 1
		self.sway.target = clampVector(
			Vector3.new(-rate.X, -rate.Y, rate.Y * 0.5) * s.SwayTurn * scale,
			s.SwayMaxTurn
		)
		self.swayMove.target = clampVector(
			Vector3.new(rate.Y, -rate.X, 0) * s.SwayShift * scale,
			s.SwayMaxShift
		)
	end
	self.lastCamera = cameraCFrame

	-- Movement bob and landing dip.
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local grounded = humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air

	local targetBob = 0
	local frequency = s.BobFrequency
	if root and root:IsA("BasePart") then
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local state = player:GetAttribute("MovementState")

		if grounded and state ~= "Slide" then
			targetBob = math.clamp(speed / s.BobReferenceSpeed, 0, 1.5)
			if state == "Sprint" then
				targetBob *= s.SprintBobScale
				frequency *= s.SprintBobRate
			end
		end
		if aiming then targetBob *= s.AimBobScale end

		if grounded and not self.wasGrounded then
			local fall = math.clamp(-self.lastVerticalSpeed, 0, s.LandMaxFallSpeed)
			self.land.velocity += Vector3.new(0, -fall * s.LandKick, 0)
		end
		self.lastVerticalSpeed = velocity.Y
	end
	self.wasGrounded = grounded

	self.bobAmount += (targetBob - self.bobAmount) * (1 - math.exp(-s.BobBlend * dt))
	self.bobPhase = (self.bobPhase + dt * frequency * 2 * math.pi) % (2 * math.pi)
	local bob = self.bobAmount
	local bobOffset = Vector3.new(
		math.sin(self.bobPhase) * s.BobSide * bob,
		(math.cos(self.bobPhase * 2) - 1) * 0.5 * s.BobVertical * bob,
		0
	)
	local bobRoll = math.sin(self.bobPhase) * s.BobRoll * bob

	-- Idle breath, so a gun at rest is never perfectly frozen.
	self.breathPhase = (self.breathPhase + dt * s.BreathRate * 2 * math.pi) % (2 * math.pi)
	local breath = math.sin(self.breathPhase) * s.BreathAmount * (aiming and 0.3 or 1)

	self.kickMove:step(dt)
	self.kickTurn:step(dt)
	self.sway:step(dt)
	self.swayMove:step(dt)
	self.land:step(dt)

	-- Sustained fire must not wind the gun up off screen.
	self.kickMove.position = clampVector(self.kickMove.position, s.KickMaxMove)
	self.kickTurn.position = clampVector(self.kickTurn.position, s.KickMaxTurn)

	local move = self.kickMove.position + self.swayMove.position + self.land.position
		+ bobOffset + Vector3.new(0, breath, 0)
	local turn = self.kickTurn.position + self.sway.position + Vector3.new(0, 0, bobRoll)

	if self.drawDuration then
		self.drawElapsed += dt
		local t = math.clamp(self.drawElapsed / self.drawDuration, 0, 1)
		local remaining = (1 - t) ^ 3
		move += Vector3.new(0, -(s.DrawDrop or 0.7), s.DrawPullBack or 0.25) * remaining
		turn += Vector3.new(-(s.DrawTilt or 0.7), 0, s.DrawRoll or 0.3) * remaining
		if t >= 1 then self.drawDuration = nil end
	end

	-- Rotate about a point near the gun, not the camera origin, so a kick pitches
	-- the weapon in the hands instead of swinging it around the player's eye.
	local pivot = CFrame.new(s.Pivot)
	return CFrame.new(move) * pivot * CFrame.Angles(turn.X, turn.Y, turn.Z) * pivot:Inverse()
end

return Motion
