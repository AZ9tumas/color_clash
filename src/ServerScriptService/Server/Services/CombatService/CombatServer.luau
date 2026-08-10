local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Modules.Core.Items)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local WeaponServer = require(ServerScriptService.Server.Classes.WeaponServer)

local CombatServer = {}
local lastUsed = {}

function CombatServer.Init()
	CombatRemotes.GetToolConnections().OnServerEvent:Connect(function(player, toolName, mousePos, isAiming)
		if not player:GetAttribute("IsPlaying") then return end
		-- Shooting is only legal while the platforms are down.
		if Workspace:GetAttribute("ArenaPhase") ~= "Shoot" then return end

		local data = Items[toolName]
		if not data then return end
		
		if not lastUsed[player.UserId] then lastUsed[player.UserId] = {} end
		local currentTime = tick()
		local lastTime = lastUsed[player.UserId][toolName] or 0
		if (currentTime - lastTime) < data.Cooldown then return end
		lastUsed[player.UserId][toolName] = currentTime

		if data.MaxAmmo then
			WeaponServer.FireHitscan(player, toolName, data, mousePos, isAiming == true)
		else
			WeaponServer.FireMelee(player, toolName, data)
		end
	end)

	-- Aim pitch relay: the client reports where it is looking so other clients can pose
	-- that character's neck. Clamped and stored as a replicated attribute, so there is
	-- no rebroadcast loop and late joiners get the current pose for free.
	CombatRemotes.GetAimPitch().OnServerEvent:Connect(function(player, pitch)
		if type(pitch) ~= "number" or pitch ~= pitch then return end
		player:SetAttribute("AimPitch", math.clamp(pitch, -1.4, 1.4))
	end)
end

return CombatServer