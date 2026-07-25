local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local DataServer = require(ServerScriptService.Server.Services.DataService.DataServer)

local CurrencyServer = {}

local function setupStats(player, profile)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = profile.Data.Cash
	cash.Parent = leaderstats

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = profile.Data.Wins
	wins.Parent = leaderstats

	leaderstats.Parent = player

	local hiddenStats = Instance.new("Folder")
	hiddenStats.Name = "HiddenStats"

	local kills = Instance.new("IntValue")
	kills.Name = "TotalKills"
	kills.Value = profile.Data.Kills
	kills.Parent = hiddenStats

	hiddenStats.Parent = player
end

function CurrencyServer.Init()
	DataServer.ProfileLoaded:Connect(setupStats)
end

function CurrencyServer.AddCash(player, amount)
	local profile = DataServer.GetProfile(player)
	if not profile then return end

	profile.Data.Cash += amount

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Cash") then
		leaderstats.Cash.Value = profile.Data.Cash
	end
end

function CurrencyServer.RemoveCash(player, amount)
	local profile = DataServer.GetProfile(player)
	if not profile then return false end
	
	if profile.Data.Cash >= amount then
		profile.Data.Cash -= amount
		local leaderstats = player:FindFirstChild("leaderstats")
		if leaderstats and leaderstats:FindFirstChild("Cash") then
			leaderstats.Cash.Value = profile.Data.Cash
		end
		return true
	end
	return false
end

function CurrencyServer.AddWins(player, amount)
	local profile = DataServer.GetProfile(player)
	if not profile then return end

	profile.Data.Wins += amount

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Wins") then
		leaderstats.Wins.Value = profile.Data.Wins
	end
end

function CurrencyServer.AddKills(player, amount)
	local profile = DataServer.GetProfile(player)
	if not profile then return end

	profile.Data.Kills += amount

	local hiddenStats = player:FindFirstChild("HiddenStats")
	if hiddenStats and hiddenStats:FindFirstChild("TotalKills") then
		hiddenStats.TotalKills.Value = profile.Data.Kills
	end
end

function CurrencyServer.GetCash(player)
	local profile = DataServer.GetProfile(player)
	return profile and profile.Data.Cash or 0
end

function CurrencyServer.GetWins(player)
	local profile = DataServer.GetProfile(player)
	return profile and profile.Data.Wins or 0
end

function CurrencyServer.GetTotalKills(player)
	local profile = DataServer.GetProfile(player)
	return profile and profile.Data.Kills or 0
end

return CurrencyServer