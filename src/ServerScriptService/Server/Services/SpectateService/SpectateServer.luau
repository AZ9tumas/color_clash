local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local SpectateRemotes = require(Shared.Remotes.SpectateRemotes)
local SpectateMechanic = require(ServerScriptService.Server.Classes.SpectateMechanic)

local SpectateServer = {}

function SpectateServer.Init()
	SpectateRemotes.GetRequestEvent().OnServerEvent:Connect(function(player, action)
		if action == "Start" then
			SpectateMechanic.Start(player)
		elseif action == "Stop" then
			SpectateMechanic.Stop(player)
		elseif action == "Next" then
			SpectateMechanic.Cycle(player, 1)
		elseif action == "Prev" then
			SpectateMechanic.Cycle(player, -1)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		SpectateMechanic.Spectators[player] = nil
		SpectateMechanic.Refresh()
	end)
end

return SpectateServer
