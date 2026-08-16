local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DailyRewardConfig = require(Shared.Modules.Core.DailyRewardConfig)
local DailyRewardRemotes = require(Shared.Remotes.DailyRewardRemotes)
local DataServer = require(ServerScriptService.Server.Services.DataService.DataServer)
local CurrencyServer = require(ServerScriptService.Server.Services.CurrencyService.CurrencyServer)

local DailyRewardServer = {}

local SECONDS_PER_DAY = 86400

local granters = {
	Cash = function(player, amount)
		CurrencyServer.AddCash(player, amount)
	end,

	Weapon = function(player, weaponName)
		local profile = DataServer.GetProfile(player)
		if not profile then return end
		if type(profile.Data.Inventory) ~= "table" then profile.Data.Inventory = {} end
		if type(profile.Data.Inventory.Weapons) ~= "table" then profile.Data.Inventory.Weapons = {} end
		profile.Data.Inventory.Weapons[weaponName] = true
	end,
}

local function currentDay()
	return math.floor((os.time() - DailyRewardConfig.ResetHourUTC * 3600) / SECONDS_PER_DAY)
end

local function secondsUntilReset()
	local elapsed = (os.time() - DailyRewardConfig.ResetHourUTC * 3600) % SECONDS_PER_DAY
	return SECONDS_PER_DAY - elapsed
end

local function dailyData(player)
	local profile = DataServer.GetProfile(player)
	if not profile then return nil end

	if type(profile.Data.DailyRewards) ~= "table" then
		profile.Data.DailyRewards = { LastClaimedDay = 0, Streak = 0, TotalClaimed = 0 }
	end

	local daily = profile.Data.DailyRewards
	if type(daily.LastClaimedDay) ~= "number" then daily.LastClaimedDay = 0 end
	if type(daily.Streak) ~= "number" then daily.Streak = 0 end
	if type(daily.TotalClaimed) ~= "number" then daily.TotalClaimed = 0 end

	return daily
end

local function streakAfterMissedDays(daily, today)
	if not DailyRewardConfig.StreakResetsOnMiss then return daily.Streak end
	if daily.LastClaimedDay > 0 and (today - daily.LastClaimedDay) > 1 then return 0 end
	return daily.Streak
end

local function rewardIndexFor(streak)
	local rewards = DailyRewardConfig.Rewards
	local count = #rewards
	if count == 0 then return nil end
	if streak < count then return streak + 1 end
	if DailyRewardConfig.LoopAfterLastDay then return (streak % count) + 1 end
	return count
end

function DailyRewardServer.GetState(player)
	local daily = dailyData(player)
	if not daily then return nil end

	local today = currentDay()
	local streak = streakAfterMissedDays(daily, today)
	local index = rewardIndexFor(streak)

	return {
		CanClaim = daily.LastClaimedDay < today,
		Streak = streak,
		Day = index,
		Reward = index and DailyRewardConfig.Rewards[index] or nil,
		TotalClaimed = daily.TotalClaimed,
		SecondsUntilReset = secondsUntilReset(),
		Rewards = DailyRewardConfig.Rewards,
	}
end

function DailyRewardServer.Claim(player)
	local daily = dailyData(player)
	if not daily then return { Claimed = false, Reason = "NoProfile" } end

	local today = currentDay()
	if daily.LastClaimedDay >= today then
		return { Claimed = false, Reason = "AlreadyClaimed", SecondsUntilReset = secondsUntilReset() }
	end

	daily.Streak = streakAfterMissedDays(daily, today)

	local index = rewardIndexFor(daily.Streak)
	if not index then return { Claimed = false, Reason = "NoRewards" } end

	local reward = DailyRewardConfig.Rewards[index]

	daily.LastClaimedDay = today
	daily.Streak += 1
	daily.TotalClaimed += 1

	for key, value in pairs(reward) do
		local granter = granters[key]
		if granter then granter(player, value) end
	end

	return {
		Claimed = true,
		Day = index,
		Streak = daily.Streak,
		Reward = reward,
		SecondsUntilReset = secondsUntilReset(),
	}
end

function DailyRewardServer.Init()
	DailyRewardRemotes.GetStateFunction().OnServerInvoke = function(player)
		DataServer.WaitForProfile(player)
		return DailyRewardServer.GetState(player)
	end

	DailyRewardRemotes.GetClaimFunction().OnServerInvoke = function(player)
		DataServer.WaitForProfile(player)
		return DailyRewardServer.Claim(player)
	end
end

return DailyRewardServer
