local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local QuestConfig = require(Shared.Modules.Core.QuestConfig)
local DataServer = require(ServerScriptService.Server.Services.DataService.DataServer)
local CurrencyServer = require(ServerScriptService.Server.Services.CurrencyService.CurrencyServer)

local QuestServer = {}

local function questData(player)
	local profile = DataServer.GetProfile(player)
	if not profile then return nil end

	if type(profile.Data.Quests) ~= "table" then
		profile.Data.Quests = { Stats = {}, Completed = {} }
	end
	local quests = profile.Data.Quests
	if type(quests.Stats) ~= "table" then quests.Stats = {} end
	if type(quests.Completed) ~= "table" then quests.Completed = {} end

	return quests
end

local function giveReward(player, questReward)
	if questReward.Cash then
		CurrencyServer.AddCash(player, questReward.Cash)
	end

	if questReward.Weapon then
		local profile = DataServer.GetProfile(player)
		if profile then
			if type(profile.Data.Inventory) ~= "table" then profile.Data.Inventory = {} end
			if type(profile.Data.Inventory.Weapons) ~= "table" then profile.Data.Inventory.Weapons = {} end
			profile.Data.Inventory.Weapons[questReward.Weapon] = true
		end
	end
end

local function bump(player, stat)
	local quests = questData(player)
	if not quests then return end

	quests.Stats[stat] = (quests.Stats[stat] or 0) + 1

	for id, quest in pairs(QuestConfig.Quests) do
		if quest.Stat == stat and not quests.Completed[id] and quests.Stats[stat] >= quest.Goal then
			quests.Completed[id] = true
			giveReward(player, quest.Reward)
		end
	end
end

function QuestServer.UpdateGamesPlayed(player) bump(player, "Plays") end
function QuestServer.UpdateRoundWins(player) bump(player, "Wins") end
function QuestServer.UpdateSecondPlace(player) bump(player, "Seconds") end
function QuestServer.UpdateEliminations(player) bump(player, "Eliminations") end
function QuestServer.UpdateShotsTaken(player) bump(player, "ShotsTaken") end
function QuestServer.UpdateShotsLanded(player) bump(player, "ShotsLanded") end
function QuestServer.UpdateFriendPlays(player) bump(player, "FriendPlays") end

function QuestServer.GetQuests(player)
	return questData(player)
end

function QuestServer.Init()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			DataServer.WaitForProfile(player)

			for _, other in Players:GetPlayers() do
				if other ~= player then
					local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
					if ok and isFriend then
						QuestServer.UpdateFriendPlays(player)
						QuestServer.UpdateFriendPlays(other)
					end
				end
			end
		end)
	end)
end

return QuestServer
