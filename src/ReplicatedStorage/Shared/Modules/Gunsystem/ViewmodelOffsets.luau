-- The single tuning location for every first-person weapon pose.
--
-- Position is measured in studs.
-- Angles are pitch (X), yaw (Y), and roll (Z), expressed in degrees below.
-- GunGrip.C0 stays at identity; the renderer applies Position * Angles to C1.
--
-- Example:
-- Position = CFrame.new(0, -0.25, 1)
-- Angles = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90))

return {
	-- Guns
	["Pistol"] = {
		Position = CFrame.new(0, -.2, .6),
		Angles = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
	},
	["Sniper"] = {
		Position = CFrame.new(0, 0, 0),
		Angles = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
	},
	["AR"] = {
		Position = CFrame.new(0, 0, 0),
		Angles = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
	},
	["SMG"] = {
		Position = CFrame.new(0, 0, 0),
		Angles = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
	},
	["Scar"] = {
		Position = CFrame.new(0, 0, 0),
		Angles = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
	},
	["Shotgun"] = {
		Position = CFrame.new(0, 0, 0),
		Angles = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
	},

	-- Melee
	["Wooden Knife"] = {
		Position = CFrame.new(0, -1.000001, 0.000015),
		Angles = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)),
	},
	["Knife"] = {
		Position = CFrame.new(0.000015, -0.800001, -0.000015),
		Angles = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)),
	},
	["Metal Knife"] = {
		Position = CFrame.new(0, -0.9, 0.000015),
		Angles = CFrame.Angles(math.rad(0), math.rad(90), math.rad(0)),
	},
	["Wooden Axe"] = {
		Position = CFrame.new(-0.400009, -1, 0),
		Angles = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)),
	},
	["Axe"] = {
		Position = CFrame.new(0, -1.000001, 0),
		Angles = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)),
	},
	["Metal Axe"] = {
		Position = CFrame.new(-0.199989, -1.8, 0),
		Angles = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)),
	},
	["Wooden Bat"] = {
		Position = CFrame.new(0, -1.500002, 0),
		Angles = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
	},
	["Metal Bat"] = {
		Position = CFrame.new(0, -1.900002, 0),
		Angles = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
	},
	["Spiked Bat"] = {
		Position = CFrame.new(-0.099998, -2.200007, 0),
		Angles = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
	},
}
