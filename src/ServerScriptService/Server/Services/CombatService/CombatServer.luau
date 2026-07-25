local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Modules.Core.Items)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local WeaponServer = require(ServerScriptService.Server.Classes.WeaponServer)

local CombatServer = {}
local lastUsed = {}

function CombatServer.Init()
	CombatRemotes.GetToolConnections().OnServerEvent:Connect(function(player, toolName, mousePos)
		if not player:GetAttribute("IsPlaying") then return end
		
		local data = Items[toolName]
		if not data then return end
		
		if not lastUsed[player.UserId] then lastUsed[player.UserId] = {} end
		local currentTime = tick()
		local lastTime = lastUsed[player.UserId][toolName] or 0
		if (currentTime - lastTime) < data.Cooldown then return end
		lastUsed[player.UserId][toolName] = currentTime

		if data.MaxAmmo then
			WeaponServer.FireHitscan(player, toolName, data, mousePos)
		else
			WeaponServer.FireMelee(player, toolName, data)
		end
	end)
end

return CombatServer