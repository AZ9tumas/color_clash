local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local CurrencyServer = require(ServerScriptService.Server.Services.CurrencyService.CurrencyServer)
local QuestServer = require(ServerScriptService.Server.Services.QuestService.QuestServer)
local SpectateMechanic = require(ServerScriptService.Server.Classes.SpectateMechanic)
local RoundRemotes = require(Shared.Remotes.RoundRemotes)
local RewardConfig = require(Shared.Modules.Core.RewardConfig)
local PlayerUtil = require(Shared.Modules.Utils.PlayerUtil)

local RewardManager = {}

function RewardManager.ProcessKill(killer)
	local currentKills = (killer:GetAttribute("Kills") or 0) + 1
	killer:SetAttribute("Kills", currentKills)
	CurrencyServer.AddKills(killer, 1)
	
	local killReward = math.random(RewardConfig.Kill.Min, RewardConfig.Kill.Max)
	CurrencyServer.AddCash(killer, killReward)
	killer:SetAttribute("RoundCash", (killer:GetAttribute("RoundCash") or 0) + killReward)
	
	return currentKills
end

function RewardManager.ProcessDeath(victim, killerName, weaponName, victimsCount)
	local placement = PlayerUtil.GetActivePlayerCount() + 1
	local roundKills = victim:GetAttribute("Kills") or 0
	local roundCash = victim:GetAttribute("RoundCash") or 0
	local placementReward = RewardConfig.Placement[placement] or RewardConfig.Placement.Default
	local totalReward = placementReward + roundCash
	
	CurrencyServer.AddCash(victim, placementReward)
	QuestServer.UpdateEliminations(victim)
	if placement == 2 then QuestServer.UpdateSecondPlace(victim) end
	RoundRemotes.GetDeathScreenEvent():FireClient(victim, killerName, weaponName, victimsCount, placement, totalReward, roundKills)

	SpectateMechanic.Refresh()
	task.delay(3, function() SpectateMechanic.Start(victim) end)
end

function RewardManager.ProcessWin(player)
	local roundKills = player:GetAttribute("Kills") or 0
	local roundCash = player:GetAttribute("RoundCash") or 0
	local placementReward = RewardConfig.Placement[1]
	local totalReward = placementReward + roundCash
	
	CurrencyServer.AddCash(player, placementReward)
	CurrencyServer.AddWins(player, 1)
	QuestServer.UpdateRoundWins(player)
	RoundRemotes.GetDeathScreenEvent():FireClient(player, "You Survived", "Won The Round", -2, 1, totalReward, roundKills)
end

return RewardManager