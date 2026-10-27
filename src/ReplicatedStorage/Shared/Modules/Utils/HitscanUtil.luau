local Workspace = game:GetService("Workspace")

local RaycastUtil = require(script.Parent.RaycastUtil)

-- Shared by the shooter's client and the server, so the client can draw a shot
-- the instant it is fired and the server resolves damage along the same ray.
local HitscanUtil = {}

-- Spread is authored in milliradians (Items.Spread).
local SPREAD_TO_RADIANS = 1 / 1000

-- Small allowance for Vector3 float precision (about 0.0006 degrees).
local DEVIATION_TOLERANCE = 1e-5

local IGNORE_NAMES = { "RepairP", "Repair" }

function HitscanUtil.IsFiniteVector(value): boolean
	return typeof(value) == "Vector3"
		and value.X == value.X and math.abs(value.X) < math.huge
		and value.Y == value.Y and math.abs(value.Y) < math.huge
		and value.Z == value.Z and math.abs(value.Z) < math.huge
end

function HitscanUtil.EffectiveSpread(data, isAiming: boolean?): number
	local spread = data.Spread or 0
	if isAiming and spread > 0 then
		local aimMultiplier = (data.Aim and data.Aim.SpreadMultiplier) or 0.5
		spread = spread * math.clamp(aimMultiplier, 0, 1)
	end
	return spread
end

-- Items.Handling.Spread with every missing field filled in, cached per weapon.
-- Without a Handling table the gun keeps its plain hip/aim Spread.
local spreadProfiles = {}

function HitscanUtil.SpreadProfile(data)
	local profile = spreadProfiles[data]
	if profile then return profile end

	local authored = data.Handling and data.Handling.Spread or {}
	profile = {
		Hip = authored.Hip or data.Spread or 0,
		Aim = authored.Aim or HitscanUtil.EffectiveSpread(data, true),
		Move = authored.Move or 0,
		Air = authored.Air or 0,
		Slide = authored.Slide or 0,
		AimPenalty = authored.AimPenalty or 0.5,
		Bloom = authored.Bloom or 0,
		MaxBloom = authored.MaxBloom or 0,
		BloomRecovery = authored.BloomRecovery or 30,
		BloomRecoveryDelay = authored.BloomRecoveryDelay or 0.25,
	}
	spreadProfiles[data] = profile
	return profile
end

-- The widest cone the client's handling can produce for this gun. The server
-- cannot see the shooter's exact movement state at the moment of firing, so
-- under GunHandling it accepts any direction inside this bound.
function HitscanUtil.SpreadBound(data): number
	local s = HitscanUtil.SpreadProfile(data)
	return math.max(s.Hip, s.Aim) + s.Move + math.max(s.Air, s.Slide) + s.MaxBloom
end

-- Damage for one pellet under GunHandling: range falloff, then the gun's
-- headshot multiplier. Rounded so hit numbers stay whole.
function HitscanUtil.HandlingDamage(data, distance: number, isHeadshot: boolean): number
	local handling = data.Handling or {}
	local multiplier = 1
	local falloff = handling.Falloff
	if falloff then
		local t = math.clamp((distance - falloff.Start) / math.max(falloff.End - falloff.Start, 1e-3), 0, 1)
		multiplier = 1 + (falloff.Min - 1) * t
	end
	if isHeadshot then
		multiplier *= handling.Headshot or 2
	end
	return math.max(1, math.floor(data.Damage * multiplier + 0.5))
end

function HitscanUtil.ConeDirection(direction: Vector3, spread: number): Vector3
	if spread <= 0 then return direction end

	local basis = CFrame.lookAt(Vector3.zero, direction)
	local theta = math.random() * math.pi * 2
	local radius = math.tan(spread * SPREAD_TO_RADIANS) * math.sqrt(math.random())
	local offset = basis.RightVector * (math.cos(theta) * radius)
		+ basis.UpVector * (math.sin(theta) * radius)

	local jittered = direction + offset
	if jittered.Magnitude < 1e-4 then return direction end
	return jittered.Unit
end

-- True when `direction` could have come out of ConeDirection(aimDirection, spread).
function HitscanUtil.WithinCone(aimDirection: Vector3, direction: Vector3, spread: number): boolean
	-- atan2 stays accurate for tiny angles and is independent of vector length.
	local angle = math.atan2(aimDirection:Cross(direction).Magnitude, aimDirection:Dot(direction))
	return angle <= spread * SPREAD_TO_RADIANS + DEVIATION_TOLERANCE
end

function HitscanUtil.ValidateDirections(directions, aimDirection: Vector3, spread: number, pellets: number)
	if type(directions) ~= "table" or #directions ~= pellets then return nil end

	local accepted = table.create(pellets)
	for i = 1, pellets do
		local direction = directions[i]
		if not HitscanUtil.IsFiniteVector(direction) then return nil end
		if math.abs(direction.Magnitude - 1) > 0.01 then return nil end
		direction = direction.Unit
		if not HitscanUtil.WithinCone(aimDirection, direction, spread) then return nil end
		accepted[i] = direction
	end
	return accepted
end

function HitscanUtil.Cast(origin: Vector3, direction: Vector3, range: number, character: Model?)
	return HitscanUtil.CastIgnoring(origin, direction, range, character and { character } or {})
end

-- Like Cast, but skips every instance in `ignore` as well as the usual debris.
function HitscanUtil.CastIgnoring(origin: Vector3, direction: Vector3, range: number, ignore: { Instance })
	ignore = table.clone(ignore)
	local debrisFolder = Workspace:FindFirstChild("WallDebrisFolder")
	if debrisFolder then table.insert(ignore, debrisFolder) end
	local baseModel = Workspace:FindFirstChild("Base")
	if baseModel then table.insert(ignore, baseModel) end
	-- Grenades must collide with the world; CanQuery=false alone cannot keep
	-- collidable parts out of raycasts.
	local grenades = Workspace:FindFirstChild("GrenadeProjectiles")
	if grenades then table.insert(ignore, grenades) end

	return RaycastUtil.CastWithIgnore(origin, direction, range, ignore, IGNORE_NAMES)
end

return HitscanUtil
