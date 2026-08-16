local DailyRewardConfig = {}

DailyRewardConfig.ResetHourUTC = 0
DailyRewardConfig.StreakResetsOnMiss = true
DailyRewardConfig.LoopAfterLastDay = true

DailyRewardConfig.Rewards = {
	{ Name = "Day 1", Cash = 250 },
	{ Name = "Day 2", Cash = 500 },
	{ Name = "Day 3", Cash = 750 },
	{ Name = "Day 4", Cash = 1000 },
	{ Name = "Day 5", Cash = 1500 },
	{ Name = "Day 6", Cash = 2000 },
	{ Name = "Day 7", Cash = 3000, Weapon = "Metal Axe" },
}

return DailyRewardConfig
