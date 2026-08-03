local QuestConfig = {}

QuestConfig.Quests = {
	OneFriend = { Stat = "FriendPlays", Goal = 1, Name = "Play with a friend", Reward = { Cash = 1000 } },

	PlayOne = { Stat = "Plays", Goal = 1, Name = "Play a game", Reward = { Cash = 250 } },
	PlayFive = { Stat = "Plays", Goal = 5, Name = "Play 5 games", Reward = { Cash = 1000 } },

	WinOne = { Stat = "Wins", Goal = 1, Name = "Win a game", Reward = { Cash = 1500 } },
	WinFive = { Stat = "Wins", Goal = 5, Name = "Win 5 games", Reward = { Weapon = "Metal Knife" } },

	SecondOne = { Stat = "Seconds", Goal = 1, Name = "Come second in a game", Reward = { Cash = 500 } },
	SecondThree = { Stat = "Seconds", Goal = 3, Name = "Come second in 3 games", Reward = { Cash = 1500 } },

	GetEliminated = { Stat = "Eliminations", Goal = 1, Name = "Get eliminated", Reward = { Cash = 100 } },
	GetShot = { Stat = "ShotsTaken", Goal = 1, Name = "Get shot", Reward = { Cash = 100 } },

	ShotOne = { Stat = "ShotsLanded", Goal = 1, Name = "Shoot someone", Reward = { Cash = 250 } },
	ShotFive = { Stat = "ShotsLanded", Goal = 5, Name = "Shoot 5 players", Reward = { Cash = 750 } },
	ShotTen = { Stat = "ShotsLanded", Goal = 10, Name = "Shoot 10 players", Reward = { Weapon = "Wooden Bat" } },
}

return QuestConfig
