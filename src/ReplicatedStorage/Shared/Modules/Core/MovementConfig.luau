local MovementConfig = {
	-- Floaty air. A VectorForce cancels part of world gravity while airborne, and every
	-- upward impulse below is scaled by sqrt(GravityScale) so peak heights stay put.
	-- Net effect: the same jump height, but a longer hang and more reach.
	--
	-- Measured in-engine, not predicted. Note the effective scale lands above the value
	-- set here: the applied force is exactly right for 0.55, but roughly 16% of it is
	-- absorbed by the solver, so treat GravityScale as a dial to tune by feel, not a
	-- literal multiplier.
	--
	--                        before      after
	--   effective gravity    196.2       122.3   (0.623x, from a 0.55 setting)
	--   jump apex            7.20        7.13    studs, deliberately unchanged
	--   hang time            0.542       0.683   s
	--   reach at sprint 34   18.4        23.2    studs, +26%
	--
	-- Lower GravityScale for more glide, raise it toward 1 to go back to snappy. If you
	-- change it, move JumpHeight with it or the apex drifts: apex ~= JumpHeight / effective.
	Air = {
		GravityScale = 0.55,
		JumpHeight = 3.9
	},
	Speeds = {
		Walk = 22,
		Sprint = 34,
		WallRun = 45,
		DoubleJumpPower = 33 -- 45 * sqrt(0.55), keeps the double jump's old peak
	},
	Slide = {
		Cooldown = 0.3,
		Duration = 0.9,
		BasePower = 80,
		SprintPower = 110
	},
	WallRun = {
		GravityScale = 0.1,
		MinHeight = 2.0,
		JumpHeight = 41, -- 55 * sqrt(0.55)
		ForwardRestrictionDot = -0.9,
		JumpOffForce = 50,
		MaxForce = 90,
		MaxSpeed = 90
	},
	WallClimb = {
		Speed = 45,
		Duration = 0.45,
		JumpOffForce = 45,
		JumpUpForce = 48, -- 65 * sqrt(0.55); was hardcoded in MovementClient
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