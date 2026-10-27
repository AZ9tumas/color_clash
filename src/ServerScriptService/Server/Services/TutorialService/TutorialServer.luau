local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local TutorialRemotes = require(Shared.Remotes.TutorialRemotes)
local DataServer = require(ServerScriptService.Server.Services.DataService.DataServer)

-- Remembers who has been through the first-time tutorial (Data.TutorialDone).
-- Players who had already played a game before the tutorial existed count as
-- done, so returning players are not sent through it.
local TutorialServer = {}

function TutorialServer.IsDone(player: Player): boolean
	local profile = DataServer.GetProfile(player)
	if not profile then return true end

	local data = profile.Data
	if data.TutorialDone == true then return true end
	local stats = type(data.Quests) == "table" and data.Quests.Stats
	return type(stats) == "table" and (stats.Plays or 0) > 0
end

function TutorialServer.Init()
	TutorialRemotes.GetDoneFunction().OnServerInvoke = function(player)
		DataServer.WaitForProfile(player)
		return TutorialServer.IsDone(player)
	end

	TutorialRemotes.GetFinishedEvent().OnServerEvent:Connect(function(player)
		local profile = DataServer.GetProfile(player)
		if profile then
			profile.Data.TutorialDone = true
		end
	end)
end

return TutorialServer
