local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local HitscanUtil = require(Shared.Modules.Utils.HitscanUtil)
local MovementConfig = require(Shared.Modules.Core.MovementConfig)

-- Client-side handling for one gun under CombatConfig.GunHandling: the live
-- spread cone (resting cone + movement + bloom) and the recoil pattern,
-- including the aim drifting back after a spray. Numbers come from
-- Items.Handling; HitscanUtil.SpreadBound is the server's matching limit.
local WeaponHandling = {}
WeaponHandling.__index = WeaponHandling

local player = Players.LocalPlayer

-- Below this horizontal speed moving costs no accuracy; the full Move penalty
-- applies at sprint speed.
local FREE_MOVE_SPEED = 8
local FULL_MOVE_SPEED = (MovementConfig.Speeds and MovementConfig.Speeds.Sprint) or 40

-- A pause this long between shots starts the recoil pattern over.
local DEFAULT_RESET_TIME = 0.35

function WeaponHandling.new(data)
	return setmetatable({
		data = data,
		spread = HitscanUtil.SpreadProfile(data),
		recoil = data.Handling and data.Handling.Recoil or nil,
		bloom = 0,
		shotIndex = 0,
		lastShotAt = -math.huge,
		recoilPitch = 0,
		recoilYaw = 0,
	}, WeaponHandling)
end

-- How much of the movement penalty applies right now (0..1), and whether the
-- player is airborne or sliding. Wall-running counts as moving, not airborne.
local function movementPenalties(): (number, boolean, boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return 0, false, false end

	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local moving = math.clamp((speed - FREE_MOVE_SPEED) / (FULL_MOVE_SPEED - FREE_MOVE_SPEED), 0, 1)

	local state = player:GetAttribute("MovementState")
	local wallRunning = type(state) == "string" and string.find(state, "WallRun") ~= nil
	local airborne = humanoid.FloorMaterial == Enum.Material.Air and not wallRunning
	return moving, airborne, state == "Slide"
end

-- The cone the next shot will use, in milliradians.
function WeaponHandling:Spread(isAiming: boolean): number
	local s = self.spread
	local moving, airborne, sliding = movementPenalties()
	local penalty = s.Move * moving
	if airborne then
		penalty += s.Air
	elseif sliding then
		penalty += s.Slide
	end
	if isAiming then
		penalty *= s.AimPenalty
	end
	return (isAiming and s.Aim or s.Hip) + penalty + self.bloom
end

-- Registers a shot: grows bloom and returns this shot's aim kick in degrees
-- (up, right), or nil when the gun has no recoil pattern.
function WeaponHandling:Shot(isAiming: boolean): (number?, number?)
	local now = os.clock()
	local recoil = self.recoil
	if now - self.lastShotAt > (recoil and recoil.ResetTime or DEFAULT_RESET_TIME) then
		self.shotIndex = 0
	end
	self.shotIndex += 1
	self.lastShotAt = now
	self.bloom = math.min(self.bloom + self.spread.Bloom, self.spread.MaxBloom)

	if not recoil or not recoil.Pattern or #recoil.Pattern == 0 then return nil, nil end
	local pattern = recoil.Pattern
	local step = pattern[math.min(self.shotIndex, #pattern)]
	local up, right = step[1], step[2]
	-- Past the authored steps the last one repeats with a little wander, so a
	-- long spray stays controllable without being perfectly predictable.
	if self.shotIndex > #pattern then
		right += (math.random() * 2 - 1) * (recoil.Wander or 0)
	end
	local scale = isAiming and (recoil.AimScale or 0.7) or 1
	up *= scale
	right *= scale
	self.recoilPitch += up
	self.recoilYaw += right
	return up, right
end

-- Bloom recovers only after a pause, so sustained fire can build a cone.
-- Recoil has its own recovery delay and returns through kick(up, right).
function WeaponHandling:Update(dt: number, kick: (number, number) -> ())
	local sinceShot = os.clock() - self.lastShotAt
	local recoveryDt = math.clamp(sinceShot - self.spread.BloomRecoveryDelay, 0, dt)
	self.bloom = math.max(self.bloom - self.spread.BloomRecovery * recoveryDt, 0)

	local recoil = self.recoil
	if not recoil or sinceShot < (recoil.RecoveryDelay or 0.15) then return end
	local total = math.sqrt(self.recoilPitch ^ 2 + self.recoilYaw ^ 2)
	if total < 1e-3 then
		self.recoilPitch, self.recoilYaw = 0, 0
		return
	end
	local step = math.min((recoil.RecoveryRate or 15) * dt, total)
	local up = self.recoilPitch / total * step
	local right = self.recoilYaw / total * step
	self.recoilPitch -= up
	self.recoilYaw -= right
	kick(-up, -right)
end

-- Forgets the spray, e.g. when the gun is put away.
function WeaponHandling:Reset()
	self.bloom = 0
	self.shotIndex = 0
	self.lastShotAt = -math.huge
	self.recoilPitch, self.recoilYaw = 0, 0
end

return WeaponHandling
