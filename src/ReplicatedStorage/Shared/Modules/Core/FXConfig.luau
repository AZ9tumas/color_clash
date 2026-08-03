local FXConfig = {}

-- Sound templates live in SoundService.GameSounds as real Sound instances, so volume,
-- pitch and rolloff are tunable in Studio without touching code. FXUtil clones the
-- template onto the emitting part so playback is positional. The Sound property is a
-- name in that folder; a missing or blank one is skipped rather than erroring.
FXConfig.SoundFolder = "GameSounds"

-- Global button audio, applied through UIAnimations.BindButtonAnimations and
-- MenuController.setupMenuButton, so every interactive button gets it for free.
FXConfig.UI = {
	Enabled = true,
	Click = "UIClick",
	Hover = "UIHover",
	HoverScale = 0.5, -- hover ticks sit well under clicks
}

FXConfig.MuzzleFlash = {
	Enabled = true,
	Size = 0.9,
	Duration = 0.06,
	Color = Color3.fromRGB(255, 231, 150),
	LightRange = 14,
	LightBrightness = 4,
	-- Shotguns fire eight tracers per shot; without this each pellet spawns its own flash
	-- and eight PointLights land on the same spot in one frame.
	Throttle = 0.05,
}

FXConfig.DoubleJump = {
	Enabled = true,
	Duration = 0.35,
	-- Cylinder parts run along their X axis, so X is the disc thickness and Y/Z the width.
	StartSize = Vector3.new(0.25, 3, 3),
	EndSize = Vector3.new(0.05, 11, 11),
	Color = Color3.fromRGB(150, 220, 255),
	Sound = "DoubleJump",
	SoundVolume = 1, -- multiplier on the template's own volume
}

FXConfig.Land = {
	Enabled = true,
	Sound = "Land",
	SoundVolume = 1,
	-- Downward speed needed before a landing counts. Without this every kerb step and
	-- every slope thuds, which gets grating fast now that air time is longer.
	MinFallSpeed = 45,
	DustParticles = 12,
	DustColor = Color3.fromRGB(225, 225, 215),
}

-- Trail behind fast-moving characters: reads as speed for slides, slide jumps and wall
-- runs, which is most of what the momentum system produces.
FXConfig.SpeedTrail = {
	Enabled = true,
	MinSpeed = 50, -- studs/s of horizontal speed before the trail shows
	Color = Color3.fromRGB(160, 225, 255),
	Lifetime = 0.25,
}

FXConfig.Slide = {
	Enabled = true,
	Sound = "Slide",
	SoundVolume = 1,
}

return FXConfig
