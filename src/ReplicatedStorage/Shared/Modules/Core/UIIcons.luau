local UIIcons = {}

local function asset(id)
	return "rbxassetid://" .. id
end

UIIcons.Menu = {
	Shop = asset(17368217589),
	Store = asset(15403066964),
	Settings = asset(17368089841),
	Quests = asset(17368118782),
	Rewards = asset(17368068524),
	Friends = asset(17368071983),
	Inventory = asset(15402958715),
	Stats = asset(15403009775),
	Codes = asset(17368032566),
	Teleport = asset(17368164592),
}

UIIcons.Stat = {
	Kills = asset(17368093079),
	Wins = asset(12129301834),
	Playtime = asset(15937828418),
	Health = asset(17368075795),
	Speed = asset(17368052918),
	Power = asset(17368210998),
}

UIIcons.Currency = {
	Cash = asset(15402858705),
	CashPile = asset(15402864619),
	CashBag = asset(15402870039),
	Coin = asset(17368060122),
	Gem = asset(17368064384),
}

UIIcons.Misc = {
	Spectating = asset(15403401665),
	Player = asset(92109681457452),
	LockClosed = asset(17368080973),
	LockOpen = asset(17368081924),
	Accept = asset(17368190066),
	Deny = asset(17368208554),
	Exclaim = asset(15402956142),
	Question = asset(15403140844),
	SoundOn = asset(126420099797067),
	SoundOff = asset(78540890913606),
	Star = asset(17368097932),
	TripleStars = asset(15403047368),
}

UIIcons.Arrow = {
	Left = asset(15403018096),
	Right = asset(15403015683),
	Up = asset(14569017448),
	Down = asset(17368169201),
	Back = asset(17368177673),
	Upgrade = asset(17368045028),
}

return UIIcons
