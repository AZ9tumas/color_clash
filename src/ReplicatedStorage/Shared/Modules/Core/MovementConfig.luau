local MovementConfig = {

	Air = {
		GravityScale = 0.40,
		JumpHeight = 3.6,
		PreserveMomentum = true,
		MomentumRetention = 1.0,
		MinAirSpeed = 40,
		MaxAirSpeed = 110
	},
	Speeds = {
		Walk = 24,
		Sprint = 40,
		WallRun = 55,
		DoubleJumpPower = 29
	},

	Slide = {
		Cooldown = 0.25,
		Duration = 1.0,
		BasePower = 100,
		SprintPower = 130
	},
	WallRun = {
		GravityScale = 0.1,
		MinHeight = 2.0,
		JumpHeight = 37,
		ForwardRestrictionDot = -0.9,
		JumpOffForce = 50,
		MaxForce = 90,
		MaxSpeed = 90
	},
	WallClimb = {
		Speed = 45,
		Duration = 0.45,
		JumpOffForce = 45,
		JumpUpForce = 43,
		MaxHeight = 12
	},
	Vault = {
		Duration = 0.18,
		MaxHeight = 5.5,
		MinHeight = 0.5
	},
	Animations = {
		Sprint = "",
		Slide = "rbxassetid://91976212958197",
		WallRunLeft = "rbxassetid://86474990488312",
		WallRunRight = "rbxassetid://96573476717926",
		WallClimb = "rbxassetid://109354154236800",
		Vault = {"rbxassetid://136996366132471", "rbxassetid://103255899851707"}
	}
}

return MovementConfig