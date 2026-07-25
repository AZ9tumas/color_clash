local MovementConfig = {
	Speeds = {
		Walk = 22,
		Sprint = 34,
		WallRun = 45,
		DoubleJumpPower = 45
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
		JumpHeight = 55,
		ForwardRestrictionDot = -0.9,
		JumpOffForce = 50,
		MaxForce = 90,
		MaxSpeed = 90
	},
	WallClimb = {
		Speed = 45,
		Duration = 0.45,
		JumpOffForce = 45,
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