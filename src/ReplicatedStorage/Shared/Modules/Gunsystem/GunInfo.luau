-- One source of truth for weapon metadata and first-person placement.
local ViewmodelSettings = require(script.Parent.ViewmodelSettings)
local WEAPON_ACTION_ANIMATION_ID = ViewmodelSettings.AnimationIds.WeaponAction
-- Generic Handle-hold pose for melee. Guns keep the rifle-shaped WeaponAction id,
-- though an authored WeaponViewmodelData.<Weapon>.Hold still takes priority.
local MELEE_HOLD_ANIMATION_ID = ViewmodelSettings.AnimationIds.MeleeHold

return {
	["Pistol"] = {
		WeaponType = "Gun",
		MaxAmmo = 15,
		HoldAnimationId = WEAPON_ACTION_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(0, -0.2, 0.6),
			Orientation = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(90)),
		},
	},
	["Sniper"] = {
		WeaponType = "Gun",
		MaxAmmo = 5,
		HoldAnimationId = WEAPON_ACTION_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(0, 0, 0),
			Orientation = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		},
	},
	["AR"] = {
		WeaponType = "Gun",
		MaxAmmo = 30,
		HoldAnimationId = WEAPON_ACTION_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(0, 0, 0),
			Orientation = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		},
	},
	["SMG"] = {
		WeaponType = "Gun",
		MaxAmmo = 40,
		HoldAnimationId = WEAPON_ACTION_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(0, 0, 0),
			Orientation = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		},
	},
	["Scar"] = {
		WeaponType = "Gun",
		MaxAmmo = 30,
		HoldAnimationId = WEAPON_ACTION_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(0, 0, 0),
			Orientation = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		},
	},
	["Shotgun"] = {
		WeaponType = "Gun",
		MaxAmmo = 8,
		HoldAnimationId = WEAPON_ACTION_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(0, 0, 0),
			Orientation = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		},
	},

	["Wooden Knife"] = {
		WeaponType = "Melee",
		HoldAnimationId = MELEE_HOLD_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(0, -1.000001, 0.000015),
			Orientation = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)),
		},
	},
	["Knife"] = {
		WeaponType = "Melee",
		HoldAnimationId = MELEE_HOLD_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(0.000015, -0.800001, -0.000015),
			Orientation = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)),
		},
	},
	["Metal Knife"] = {
		WeaponType = "Melee",
		HoldAnimationId = MELEE_HOLD_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(0, -0.9, 0.000015),
			Orientation = CFrame.Angles(math.rad(0), math.rad(90), math.rad(0)),
		},
	},
	["Wooden Axe"] = {
		WeaponType = "Melee",
		HoldAnimationId = MELEE_HOLD_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(-0.400009, -1, 0),
			Orientation = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)),
		},
	},
	["Axe"] = {
		WeaponType = "Melee",
		HoldAnimationId = MELEE_HOLD_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(0, -1.000001, 0),
			Orientation = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)),
		},
	},
	["Metal Axe"] = {
		WeaponType = "Melee",
		HoldAnimationId = MELEE_HOLD_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(-0.199989, -1.8, 0),
			Orientation = CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0)),
		},
	},
	["Wooden Bat"] = {
		WeaponType = "Melee",
		HoldAnimationId = MELEE_HOLD_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(0, 0, 0),
			Orientation = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		},
	},
	["Metal Bat"] = {
		WeaponType = "Melee",
		HoldAnimationId = MELEE_HOLD_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(0, -1.900002, 0),
			Orientation = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		},
	},
	["Spiked Bat"] = {
		WeaponType = "Melee",
		HoldAnimationId = MELEE_HOLD_ANIMATION_ID,
		ViewmodelGrip = {
			Position = CFrame.new(-0.099998, -2.200007, 0),
			Orientation = CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		},
	},
}
