local FXConfig = {}

FXConfig.SoundFolder = "GameSounds"

FXConfig.GunDebug = true

FXConfig.UI = {
	Enabled = true,
	Click = "UIClick",
	Hover = "UIHover",
	HoverScale = 0.5,
}

FXConfig.MuzzleFlash = {
	Enabled = true,
	Size = 0.9,
	Duration = 0.06,
	Color = Color3.fromRGB(255, 231, 150),
	LightRange = 14,
	LightBrightness = 4,

	Throttle = 0.05,
}

FXConfig.DoubleJump = {
	Enabled = true,
	Duration = 0.35,

	StartSize = Vector3.new(0.25, 3, 3),
	EndSize = Vector3.new(0.05, 11, 11),
	Color = Color3.fromRGB(150, 220, 255),
	Sound = "DoubleJump",
	SoundVolume = 1,
}

FXConfig.Land = {
	Enabled = true,
	Sound = "Land",
	SoundVolume = 1,

	MinFallSpeed = 45,
	DustParticles = 12,
	DustColor = Color3.fromRGB(225, 225, 215),
}

FXConfig.SpeedTrail = {
	Enabled = true,
	MinSpeed = 50,
	Color = Color3.fromRGB(160, 225, 255),
	Lifetime = 0.25,
}

FXConfig.Slide = {
	Enabled = true,
	Sound = "Slide",
	SoundVolume = 1,
}

return FXConfig
