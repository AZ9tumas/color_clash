local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Modules.Core.Items)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local WeaponServer = require(ServerScriptService.Server.Classes.WeaponServer)

local CombatServer = {}
local nextAllowed = {}

-- Shots fired exactly one cooldown apart can arrive closer together after
-- network jitter. The shooter now draws its tracer before the server sees the
-- shot, so a jitter rejection would show a bullet that does no damage. Allow
-- one shot up to this early; the sustained rate is still capped at the cooldown.
local COOLDOWN_GRACE = 0.05

function CombatServer.Init()
	CombatRemotes.GetToolConnections().OnServerEvent:Connect(function(player, toolName, mousePos, isAiming, eyeOrigin, directions)
		if not player:GetAttribute("IsPlaying") then return end

		if Workspace:GetAttribute("ArenaPhase") ~= "Shoot" then return end
		if type(toolName) ~= "string" then return end

		local data = Items[toolName]
		if not data then return end

		if not nextAllowed[player.UserId] then nextAllowed[player.UserId] = {} end
		local currentTime = os.clock()
		local allowedAt = nextAllowed[player.UserId][toolName] or 0
		if currentTime < allowedAt - COOLDOWN_GRACE then return end
		nextAllowed[player.UserId][toolName] = math.max(allowedAt, currentTime) + data.Cooldown

		if data.MaxAmmo then
			WeaponServer.FireHitscan(player, toolName, data, mousePos, isAiming == true, eyeOrigin, directions)
		else
			WeaponServer.FireMelee(player, toolName, data)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		nextAllowed[player.UserId] = nil
	end)

	CombatRemotes.GetAimPitch().OnServerEvent:Connect(function(player, pitch)
		if type(pitch) ~= "number" or pitch ~= pitch then return end
		player:SetAttribute("AimPitch", math.clamp(pitch, -1.4, 1.4))
	end)
end

return CombatServer
