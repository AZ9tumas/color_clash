local RewardConfig = {
	Placement = {
		[1] = 5000,
		[2] = 2250,
		[3] = 1000,
		[4] = 750,
		[5] = 500,
		[6] = 350,
		[7] = 200,
		[8] = 100,
		Default = 50
	},
	-- Flat, not a range: the kill feed states the payout outright, so it has to be the
	-- same number every time.
	Kill = {
		Amount = 25
	}
}

return RewardConfig