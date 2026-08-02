local MovementConfig = {
	-- Momentum-based air movement. Two things working together:
	--
	-- 1. A VectorForce cancels part of world gravity while airborne, so jumps hang.
	-- 2. WalkSpeed is raised to your launch speed while airborne. This is the important
	--    one. Roblox drives horizontal velocity toward MoveDirection * WalkSpeed even in
	--    mid-air, so without it a 130 stud/s slide collapses to walking pace the instant
	--    you leave the ground, and no amount of hang time buys you distance.
	--
	-- GravityScale is a feel dial, not a literal multiplier: the force applied is exactly
	-- right on paper, but roughly 16% is absorbed by the solver. Measured at the previous
	-- 0.55 setting the real figure was 0.623, i.e. effective = 1 - 0.84 * (1 - setting).
	--
	--                          old      measured 0.55    projected at 0.40
	--   effective gravity      196.2    122.3            ~97.5
	--   jump apex              7.20     7.13             ~7.2   studs
	--   hang time              0.542    0.683            ~0.77  s
	--   reach at sprint        18.4     23.2             ~31    studs
	--   reach off a full slide  n/a     n/a              ~85    studs (two map cells)
	--
	-- Set PreserveMomentum = false to fall back to stock Roblox air control.
	Air = {
		GravityScale = 0.40,
		JumpHeight = 3.6,
		PreserveMomentum = true,
		MomentumRetention = 1.0, -- fraction of launch speed carried into the air
		MinAirSpeed = 40, -- never slower in the air than a sprint
		MaxAirSpeed = 110 -- ceiling, and the server's anti-exploit clamp
	},
	Speeds = {
		Walk = 24,
		Sprint = 40,
		WallRun = 55,
		DoubleJumpPower = 29 -- rescaled so peak height survives the lower gravity
	},
	-- Slides are the main traversal tool: build speed on the ground, jump, keep it.
	Slide = {
		Cooldown = 0.25,
		Duration = 1.0,
		BasePower = 100,
		SprintPower = 130
	},
	WallRun = {
		GravityScale = 0.1,
		MinHeight = 2.0,
		JumpHeight = 37, -- rescaled for the lower gravity
		ForwardRestrictionDot = -0.9,
		JumpOffForce = 50,
		MaxForce = 90,
		MaxSpeed = 90
	},
	WallClimb = {
		Speed = 45,
		Duration = 0.45,
		JumpOffForce = 45,
		JumpUpForce = 43, -- rescaled for the lower gravity; was hardcoded in MovementClient
		MaxHeight = 12
	},
	Vault = {
		Duration = 0.18,
		MaxHeight = 5.5,
		MinHeight = 0.5
	},
	Animations = {
		Sprint = 0,
		Slide = 91976212958197,
		WallRunLeft = 86474990488312,
		WallRunRight = 96573476717926,
		WallClimb = 109354154236800,
		Vault = {136996366132471, 103255899851707}
	}
}

return MovementConfig