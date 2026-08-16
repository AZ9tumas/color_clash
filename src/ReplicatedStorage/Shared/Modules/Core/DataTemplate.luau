local DataTemplate = {
	Cash = 0,
	Wins = 0,
	Kills = 0,
	Inventory = {
		Weapons = {
			["Pistol"] = true,
			["Wooden Knife"] = true
		},
		Skins = {},
		Effects = {}
	},
	Equipped = {
		Main = "Pistol",
		Melee = "Wooden Knife"
	},
	Settings = {},
	Quests = {
		Stats = {},
		Completed = {}
	},
	DailyRewards = {
		LastClaimedDay = 0,
		Streak = 0,
		TotalClaimed = 0
	}
}

return DataTemplate