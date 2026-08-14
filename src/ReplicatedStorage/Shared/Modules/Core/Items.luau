local Items = {
	["Wooden Knife"] = {
		Damage = 25, Cooldown = 0.35,
		Shake = { Intensity = 0.2, Decay = 22 },
		Animations = { 
			Swing = { R15 = 522635514, R6 = 77680819428037 }, 
			Idle = 137420088255996, 
			Walk = 83562505728101, 
			Sprint = 78575890133951 
		}
	},
	["Knife"] = {
		Damage = 45, Cooldown = 0.35,
		Shake = { Intensity = 0.25, Decay = 22 },
		Animations = { 
			Swing = { R15 = 522635514, R6 = 77680819428037 }, 
			Idle = 137420088255996, 
			Walk = 83562505728101, 
			Sprint = 78575890133951 
		}
	},
	["Metal Knife"] = {
		Damage = 75, Cooldown = 0.35,
		Shake = { Intensity = 0.3, Decay = 20 },
		Animations = { 
			Swing = { R15 = 522635514, R6 = 77680819428037 }, 
			Idle = 137420088255996, 
			Walk = 83562505728101, 
			Sprint = 78575890133951 
		}
	},
	["Wooden Axe"] = {
		Damage = 40, Cooldown = 0.75,
		Shake = { Intensity = 0.4, Decay = 12 },
		Animations = { 
			Swing = { R15 = 522635514, R6 = 79633785464109 }, 
			Idle = 137420088255996, 
			Walk = 83562505728101, 
			Sprint = 78575890133951 
		}
	},
	["Axe"] = {
		Damage = 70, Cooldown = 0.75,
		Shake = { Intensity = 0.55, Decay = 11 },
		Animations = { 
			Swing = { R15 = 522635514, R6 = 79633785464109 }, 
			Idle = 137420088255996, 
			Walk = 83562505728101, 
			Sprint = 78575890133951 
		}
	},
	["Metal Axe"] = {
		Damage = 110, Cooldown = 0.75,
		Shake = { Intensity = 0.7, Decay = 10 },
		Animations = { 
			Swing = { R15 = 522635514, R6 = 79633785464109 }, 
			Idle = 137420088255996, 
			Walk = 83562505728101, 
			Sprint = 78575890133951 
		}
	},
	["Wooden Bat"] = {
		Damage = 35, Cooldown = 0.5,
		Shake = { Intensity = 0.35, Decay = 13 },
		Animations = { 
			Swing = { R15 = 522635514, R6 = 115180322849073 }, 
			Idle = 137420088255996, 
			Walk = 83562505728101, 
			Sprint = 78575890133951 
		}
	},
	["Metal Bat"] = {
		Damage = 55, Cooldown = 0.5,
		Shake = { Intensity = 0.5, Decay = 11 },
		Animations = { 
			Swing = { R15 = 522635514, R6 = 115180322849073 }, 
			Idle = 137420088255996, 
			Walk = 83562505728101, 
			Sprint = 78575890133951 
		}
	},
	["Spiked Bat"] = {
		Damage = 80, Cooldown = 0.5,
		Shake = { Intensity = 0.65, Decay = 9 },
		Animations = { 
			Swing = { R15 = 522635514, R6 = 115180322849073 }, 
			Idle = 137420088255996, 
			Walk = 83562505728101, 
			Sprint = 78575890133951 
		}
	},
	-- Stats mirror the reference gunsystem's "Berreta silencer": 35 damage, 15 rounds,
	-- 2.9s reload, semi-auto, ADS FOV 65.
	["Pistol"] = {
		Damage = 35, Cooldown = 0.2, Range = 500, MaxAmmo = 15, ReloadTime = 2.9, Spread = 0,
		Shake = { Intensity = 1.5, Decay = 18 },
		Recoil = { Pitch = 4.2, Yaw = 1.1 },
		Aim = { FOV = 65, SpreadMultiplier = 0.4 },
		-- Viewmodel framing. Offset moves the arm rig in camera space - the default drops it
		-- 1.5 studs so the eye sits where an R6 head does - and AdsOffset is where it springs
		-- to while aiming. There is no grip offset: the weapon is jointed on with the C0s
		-- read from the authored rig, which is what keeps the reload animation driving the
		-- magazine and trigger.
		Viewmodel = {
			-- Offset nudges the whole rig in camera space; zero means the reference rig's own
			-- framing, which is already camera-authored. The grip is solved at runtime from
			-- this weapon's authored Handle joint, so there is no grip value to keep in sync
			-- here - add GripAdjust (a CFrame) only if a particular gun wants a nudge on top.
			Offset = Vector3.zero,
		},
		Animations = { Shoot = 86304083830215, Reload = 84055323674335, Idle = 76788131144151, Walk = 74737589673617, Sprint = 74737589673617 }
	},
	["Sniper"] = {
		Damage = 250, Cooldown = 1.0, Range = 1000, MaxAmmo = 5, ReloadTime = 2.0, Spread = 0,
		Shake = { Intensity = 4.0, Decay = 7 },
		Recoil = { Pitch = 9.5, Yaw = 1.6 },
		Aim = { FOV = 30, SpreadMultiplier = 0.1 },
		-- Viewmodel framing. Offset moves the arm rig in camera space - the default drops it
		-- 1.5 studs so the eye sits where an R6 head does - and AdsOffset is where it springs
		-- to while aiming. There is no grip offset: the weapon is jointed on with the C0s
		-- read from the authored rig, which is what keeps the reload animation driving the
		-- magazine and trigger.
		Viewmodel = {
			-- Offset nudges the whole rig in camera space; zero means the reference rig's own
			-- framing, which is already camera-authored. The grip is solved at runtime from
			-- this weapon's authored Handle joint, so there is no grip value to keep in sync
			-- here - add GripAdjust (a CFrame) only if a particular gun wants a nudge on top.
			Offset = Vector3.zero,
		},
		Animations = { Shoot = 101828241949203, Reload = 93766855465736, Idle = 98715180840350, Walk = 133471749603993, Sprint = 133471749603993 }
	},
	["AR"] = {
		Damage = 35, Cooldown = 0.08, Range = 600, MaxAmmo = 30, ReloadTime = 1.5, Spread = 8, AutoFire = true,
		Shake = { Intensity = 0.8, Decay = 12 },
		Recoil = { Pitch = 2.6, Yaw = 0.9 },
		Aim = { FOV = 55, SpreadMultiplier = 0.45 },
		-- Viewmodel framing. Offset moves the arm rig in camera space - the default drops it
		-- 1.5 studs so the eye sits where an R6 head does - and AdsOffset is where it springs
		-- to while aiming. There is no grip offset: the weapon is jointed on with the C0s
		-- read from the authored rig, which is what keeps the reload animation driving the
		-- magazine and trigger.
		Viewmodel = {
			-- Offset nudges the whole rig in camera space; zero means the reference rig's own
			-- framing, which is already camera-authored. The grip is solved at runtime from
			-- this weapon's authored Handle joint, so there is no grip value to keep in sync
			-- here - add GripAdjust (a CFrame) only if a particular gun wants a nudge on top.
			Offset = Vector3.zero,
		},
		Animations = { Shoot = 98842943786422, Reload = 70986236399168, Idle = 127694603378551, Walk = 116073209021469, Sprint = 116073209021469 }
	},
	["SMG"] = {
		Damage = 20, Cooldown = 0.06, Range = 400, MaxAmmo = 40, ReloadTime = 1.2, Spread = 15, AutoFire = true,
		Shake = { Intensity = 0.5, Decay = 16 },
		Recoil = { Pitch = 1.9, Yaw = 0.8 },
		Aim = { FOV = 58, SpreadMultiplier = 0.5 },
		-- Viewmodel framing. Offset moves the arm rig in camera space - the default drops it
		-- 1.5 studs so the eye sits where an R6 head does - and AdsOffset is where it springs
		-- to while aiming. There is no grip offset: the weapon is jointed on with the C0s
		-- read from the authored rig, which is what keeps the reload animation driving the
		-- magazine and trigger.
		Viewmodel = {
			-- Offset nudges the whole rig in camera space; zero means the reference rig's own
			-- framing, which is already camera-authored. The grip is solved at runtime from
			-- this weapon's authored Handle joint, so there is no grip value to keep in sync
			-- here - add GripAdjust (a CFrame) only if a particular gun wants a nudge on top.
			Offset = Vector3.zero,
		},
		Animations = { Shoot = 93777660426232, Reload = 116733200772749, Idle = 124267210387896, Walk = 128330126585616, Sprint = 128330126585616 }
	},
	["Scar"] = {
		Damage = 45, Cooldown = 0.1, Range = 650, MaxAmmo = 30, ReloadTime = 1.6, Spread = 5, AutoFire = true,
		Shake = { Intensity = 1.0, Decay = 10 },
		Recoil = { Pitch = 3.4, Yaw = 1.0 },
		Aim = { FOV = 55, SpreadMultiplier = 0.4 },
		-- Viewmodel framing. Offset moves the arm rig in camera space - the default drops it
		-- 1.5 studs so the eye sits where an R6 head does - and AdsOffset is where it springs
		-- to while aiming. There is no grip offset: the weapon is jointed on with the C0s
		-- read from the authored rig, which is what keeps the reload animation driving the
		-- magazine and trigger.
		Viewmodel = {
			-- Offset nudges the whole rig in camera space; zero means the reference rig's own
			-- framing, which is already camera-authored. The grip is solved at runtime from
			-- this weapon's authored Handle joint, so there is no grip value to keep in sync
			-- here - add GripAdjust (a CFrame) only if a particular gun wants a nudge on top.
			Offset = Vector3.zero,
		},
		Animations = { Shoot = 133379495548916, Reload = 116854355282803, Idle = 127694603378551, Walk = 116073209021469, Sprint = 116073209021469 }
	},
	["Shotgun"] = {
		Damage = 35, Cooldown = 0.6, Range = 300, MaxAmmo = 8, ReloadTime = 0.8, ReloadPerShell = true, Spread = 30, Pellets = 8,
		Shake = { Intensity = 3.5, Decay = 8 },
		Recoil = { Pitch = 8.5, Yaw = 2.0 },
		Aim = { FOV = 62, SpreadMultiplier = 0.6 },
		-- Viewmodel framing. Offset moves the arm rig in camera space - the default drops it
		-- 1.5 studs so the eye sits where an R6 head does - and AdsOffset is where it springs
		-- to while aiming. There is no grip offset: the weapon is jointed on with the C0s
		-- read from the authored rig, which is what keeps the reload animation driving the
		-- magazine and trigger.
		Viewmodel = {
			-- Offset nudges the whole rig in camera space; zero means the reference rig's own
			-- framing, which is already camera-authored. The grip is solved at runtime from
			-- this weapon's authored Handle joint, so there is no grip value to keep in sync
			-- here - add GripAdjust (a CFrame) only if a particular gun wants a nudge on top.
			Offset = Vector3.zero,
		},
		Animations = { Shoot = 140337976272295, Reload = 84283526160957, Idle = 128036426437584, Walk = 113147747937745, Sprint = 113147747937745 }
	}
}

return Items