local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

local Items: Types.WeaponCatalog = {
	["Wooden Knife"] = {
		Damage = 25, Cooldown = 0.35,
		Grip = CFrame.new(0, -1.00000143, 0.0000152587891, -1.04308128e-07, -7.91638666e-09, -1, 1.98139048e-07, 1, -7.91640709e-09, 1, -1.98139048e-07, -1.04308128e-07),
		Shake = { Intensity = 0.2, Decay = 22 },
		Animations = {
			Swing = { R15 = "rbxassetid://522635514", R6 = "rbxassetid://77680819428037" },
			Idle = "rbxassetid://137420088255996",
			Walk = "rbxassetid://83562505728101",
			Sprint = "rbxassetid://78575890133951"
		}
	},
	["Knife"] = {
		Damage = 45, Cooldown = 0.35,
		Grip = CFrame.new(0.0000152587891, -0.800001383, -0.0000152587891, 1.19209375e-07, 1.11757128e-08, -1, -9.22008283e-08, 1, 1.11757021e-08, 1, 9.22008283e-08, 1.19209375e-07),
		Shake = { Intensity = 0.25, Decay = 22 },
		Animations = {
			Swing = { R15 = "rbxassetid://522635514", R6 = "rbxassetid://77680819428037" },
			Idle = "rbxassetid://137420088255996",
			Walk = "rbxassetid://83562505728101",
			Sprint = "rbxassetid://78575890133951"
		}
	},
	["Metal Knife"] = {
		Damage = 75, Cooldown = 0.35,
		Grip = CFrame.new(0, -0.900000334, 0.0000152587891, -9.68574909e-08, -7.14789579e-08, 1, 3.87662631e-08, 1, 7.1478965e-08, -1, 3.87662737e-08, -9.68574909e-08),
		Shake = { Intensity = 0.3, Decay = 20 },
		Animations = {
			Swing = { R15 = "rbxassetid://522635514", R6 = "rbxassetid://77680819428037" },
			Idle = "rbxassetid://137420088255996",
			Walk = "rbxassetid://83562505728101",
			Sprint = "rbxassetid://78575890133951"
		}
	},
	["Wooden Axe"] = {
		Damage = 40, Cooldown = 0.75,
		Grip = CFrame.new(-0.400009155, -1.00000024, 0, 4.24683321e-07, 3.399321e-08, -1, -3.95230387e-07, 1, 3.3993043e-08, 1, 3.95230359e-07, 4.24683321e-07),
		Shake = { Intensity = 0.4, Decay = 12 },
		Animations = {
			Swing = { R15 = "rbxassetid://522635514", R6 = "rbxassetid://79633785464109" },
			Idle = "rbxassetid://137420088255996",
			Walk = "rbxassetid://83562505728101",
			Sprint = "rbxassetid://78575890133951"
		}
	},
	["Axe"] = {
		Damage = 70, Cooldown = 0.75,
		Grip = CFrame.new(0, -1.00000143, 0, 2.68221129e-07, -8.3818783e-08, -1, -7.63682309e-08, 1, -8.38188043e-08, 1, 7.63682522e-08, 2.68221129e-07),
		Shake = { Intensity = 0.55, Decay = 11 },
		Animations = {
			Swing = { R15 = "rbxassetid://522635514", R6 = "rbxassetid://79633785464109" },
			Idle = "rbxassetid://137420088255996",
			Walk = "rbxassetid://83562505728101",
			Sprint = "rbxassetid://78575890133951"
		}
	},
	["Metal Axe"] = {
		Damage = 110, Cooldown = 0.75,
		Grip = CFrame.new(-0.199989319, -1.80000043, 0, 2.30968084e-07, -2.24682388e-08, -1, -9.44127052e-08, 1, -2.24682601e-08, 1, 9.44127123e-08, 2.30968084e-07),
		Shake = { Intensity = 0.7, Decay = 10 },
		Animations = {
			Swing = { R15 = "rbxassetid://522635514", R6 = "rbxassetid://79633785464109" },
			Idle = "rbxassetid://137420088255996",
			Walk = "rbxassetid://83562505728101",
			Sprint = "rbxassetid://78575890133951"
		}
	},
	["Wooden Bat"] = {
		Damage = 35, Cooldown = 0.5,
		Grip = CFrame.new(0, -1.50000155, 0, 1, 1.05937978e-08, -1.11758652e-07, -1.05937898e-08, 1, 6.51925731e-08, 1.11758652e-07, -6.51925731e-08, 1),
		Shake = { Intensity = 0.35, Decay = 13 },
		Animations = {
			Swing = { R15 = "rbxassetid://522635514", R6 = "rbxassetid://115180322849073" },
			Idle = "rbxassetid://137420088255996",
			Walk = "rbxassetid://83562505728101",
			Sprint = "rbxassetid://78575890133951"
		}
	},
	["Metal Bat"] = {
		Damage = 55, Cooldown = 0.5,
		Grip = CFrame.new(0, -1.90000236, 0, 1, 1.30385391e-08, -1.26659771e-07, -1.30385249e-08, 1, 1.06170567e-07, 1.26659771e-07, -1.06170567e-07, 1),
		Shake = { Intensity = 0.5, Decay = 11 },
		Animations = {
			Swing = { R15 = "rbxassetid://522635514", R6 = "rbxassetid://115180322849073" },
			Idle = "rbxassetid://137420088255996",
			Walk = "rbxassetid://83562505728101",
			Sprint = "rbxassetid://78575890133951"
		}
	},
	["Spiked Bat"] = {
		Damage = 80, Cooldown = 0.5,
		Grip = CFrame.new(-0.0999984741, -2.20000696, 0, 1, 6.93835602e-08, -2.83121778e-07, -6.93835389e-08, 1, 7.45056781e-08, 2.83121778e-07, -7.45056568e-08, 1),
		Shake = { Intensity = 0.65, Decay = 9 },
		Animations = {
			Swing = { R15 = "rbxassetid://522635514", R6 = "rbxassetid://115180322849073" },
			Idle = "rbxassetid://137420088255996",
			Walk = "rbxassetid://83562505728101",
			Sprint = "rbxassetid://78575890133951"
		}
	},

	["Pistol"] = {
		Damage = 35, Cooldown = 0.2, Range = 500, MaxAmmo = 15, ReloadTime = 2.9, Spread = 0,
		Grip = CFrame.new(0.00197005272, -0.199962825, 0.00336956978, 1, 3.52563291e-07, -3.02863191e-06, -3.52560448e-07, 1, 9.36901358e-07, 3.02863214e-06, -9.36900278e-07, 1),
		Shake = { Intensity = 1.5, Decay = 18 },
		Recoil = { Pitch = 4.2, Yaw = 1.1 },
		Aim = { FOV = 65, SpreadMultiplier = 0.4 },

		Viewmodel = {
			-- Position (studs), then rotation (pitch, yaw, roll).
			GripOffset = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		},
		Animations = { Shoot = "rbxassetid://86304083830215", Reload = "rbxassetid://84055323674335", Idle = "rbxassetid://76788131144151", Walk = "rbxassetid://74737589673617", Sprint = "rbxassetid://74737589673617" }
	},
	["Sniper"] = {
		Damage = 250, Cooldown = 1.0, Range = 1000, MaxAmmo = 5, ReloadTime = 2.0, Spread = 0,
		Grip = CFrame.new(-0.00624847412, -0.394278824, 0.210967898, 1, 6.891797e-08, -7.52507219e-07, -6.89177426e-08, 1, 2.99885301e-07, 7.52507219e-07, -2.99885244e-07, 1),
		Shake = { Intensity = 4.0, Decay = 7 },
		Recoil = { Pitch = 9.5, Yaw = 1.6 },
		Aim = { FOV = 30, SpreadMultiplier = 0.1 },

		Viewmodel = {
			GripOffset = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		},
		Animations = { Shoot = "rbxassetid://101828241949203", Reload = "rbxassetid://93766855465736", Idle = "rbxassetid://98715180840350", Walk = "rbxassetid://133471749603993", Sprint = "rbxassetid://133471749603993" }
	},
	["AR"] = {
		Damage = 35, Cooldown = 0.08, Range = 600, MaxAmmo = 30, ReloadTime = 1.5, Spread = 8, AutoFire = true,
		Grip = CFrame.new(-0.00665211678, -0.495603472, 0.210575342, 1, 2.1851217e-07, -2.70454439e-06, -2.18510252e-07, 1, 7.0966405e-07, 2.70454461e-06, -7.09663482e-07, 1),
		Shake = { Intensity = 0.8, Decay = 12 },
		Recoil = { Pitch = 2.6, Yaw = 0.9 },
		Aim = { FOV = 55, SpreadMultiplier = 0.45 },

		Viewmodel = {
			GripOffset = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		},
		Animations = { Shoot = "rbxassetid://98842943786422", Reload = "rbxassetid://70986236399168", Idle = "rbxassetid://127694603378551", Walk = "rbxassetid://116073209021469", Sprint = "rbxassetid://116073209021469" }
	},
	["SMG"] = {
		Damage = 20, Cooldown = 0.06, Range = 400, MaxAmmo = 40, ReloadTime = 1.2, Spread = 15, AutoFire = true,
		Grip = CFrame.new(-0.0028334856, -0.297912478, 0.106027126, 1, 1.32946042e-07, -1.4156019e-06, -1.32945502e-07, 1, 3.81840067e-07, 1.4156019e-06, -3.81839868e-07, 1),
		Shake = { Intensity = 0.5, Decay = 16 },
		Recoil = { Pitch = 1.9, Yaw = 0.8 },
		Aim = { FOV = 58, SpreadMultiplier = 0.5 },

		Viewmodel = {
			GripOffset = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		},
		Animations = { Shoot = "rbxassetid://93777660426232", Reload = "rbxassetid://116733200772749", Idle = "rbxassetid://124267210387896", Walk = "rbxassetid://128330126585616", Sprint = "rbxassetid://128330126585616" }
	},
	["Scar"] = {
		Damage = 45, Cooldown = 0.1, Range = 650, MaxAmmo = 30, ReloadTime = 1.6, Spread = 5, AutoFire = true,
		Grip = CFrame.new(-0.0410887003, -0.674591601, 0.81887126, 1, 2.92669e-07, -3.04726973e-06, -2.92666442e-07, 1, 8.36323636e-07, 3.04726996e-06, -8.36322727e-07, 1),
		Shake = { Intensity = 1.0, Decay = 10 },
		Recoil = { Pitch = 3.4, Yaw = 1.0 },
		Aim = { FOV = 55, SpreadMultiplier = 0.4 },

		Viewmodel = {
			GripOffset = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		},
		Animations = { Shoot = "rbxassetid://133379495548916", Reload = "rbxassetid://116854355282803", Idle = "rbxassetid://127694603378551", Walk = "rbxassetid://116073209021469", Sprint = "rbxassetid://116073209021469" }
	},
	["Shotgun"] = {
		Damage = 35, Cooldown = 0.6, Range = 300, MaxAmmo = 8, ReloadTime = 0.8, ReloadPerShell = true, Spread = 30, Pellets = 8,
		Grip = CFrame.new(0.00684070587, -0.399756849, 0.0121920109, 1, 5.15719307e-08, -7.74855778e-07, -5.15716785e-08, 1, 3.31548762e-07, 7.74855778e-07, -3.31548733e-07, 1),
		Shake = { Intensity = 3.5, Decay = 8 },
		Recoil = { Pitch = 8.5, Yaw = 2.0 },
		Aim = { FOV = 62, SpreadMultiplier = 0.6 },

		Viewmodel = {
			GripOffset = CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0)),
		},
		Animations = { Shoot = "rbxassetid://140337976272295", Reload = "rbxassetid://84283526160957", Idle = "rbxassetid://128036426437584", Walk = "rbxassetid://113147747937745", Sprint = "rbxassetid://113147747937745" }
	}
}

return Items
