local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Modules.Core.Items)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local WeaponServer = require(ServerScriptService.Server.Classes.WeaponServer)
local AmmoServer = require(ServerScriptService.Server.Classes.AmmoServer)
local LagCompensation = require(ServerScriptService.Server.Classes.LagCompensation)
local CombatConfig = require(Shared.Modules.Core.CombatConfig)

local CombatServer = {}
local nextAllowed = {}

-- Shots fired exactly one cooldown apart can arrive closer together after
-- network jitter. The shooter now draws its tracer before the server sees the
-- shot, so a jitter rejection would show a bullet that does no damage. Allow
-- one shot up to this early; the sustained rate is still capped at the cooldown.
local COOLDOWN_GRACE = 0.05

-- When each Tool last came into its holder's hands, for the QuickSwap draw
-- time. The equip and the first shot after the draw each cross the network,
-- so allow some jitter between them.
local drawnAt = {}
local DRAW_GRACE = 0.12

local function watchDraws(character: Model)
	character.ChildAdded:Connect(function(child)
		if not child:IsA("Tool") then return end
		if not drawnAt[child] then
			child.Destroying:Once(function()
				drawnAt[child] = nil
			end)
		end
		drawnAt[child] = os.clock()
	end)
end

local function heldGun(player: Player, toolName: string): Tool?
	local tool = player.Character and player.Character:FindFirstChild(toolName)
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

function CombatServer.Init()
	CombatConfig.Publish()
	LagCompensation.Start()
	local AmmoSync = CombatRemotes.GetAmmoSync()

	local function watchPlayer(player: Player)
		if player.Character then watchDraws(player.Character) end
		player.CharacterAdded:Connect(watchDraws)
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	CombatRemotes.GetToolConnections().OnServerEvent:Connect(function(player, toolName, mousePos, isAiming, eyeOrigin, directions, claims)
		if not player:GetAttribute("IsPlaying") then return end

		if Workspace:GetAttribute("ArenaPhase") ~= "Shoot" then return end
		if type(toolName) ~= "string" then return end

		local data = Items[toolName]
		if not data then return end

		-- Under QuickSwap a gun cannot fire until it has been drawn.
		if CombatConfig.IsEnabled("QuickSwap") and data.MaxAmmo then
			local tool = heldGun(player, toolName)
			local drawn = tool and drawnAt[tool]
			local equipTime = data.Handling and data.Handling.EquipTime or 0
			if drawn and os.clock() < drawn + equipTime - DRAW_GRACE then return end
		end

		if not nextAllowed[player.UserId] then nextAllowed[player.UserId] = {} end
		local currentTime = os.clock()
		local allowedAt = nextAllowed[player.UserId][toolName] or 0
		if currentTime < allowedAt - COOLDOWN_GRACE then return end
		nextAllowed[player.UserId][toolName] = math.max(allowedAt, currentTime) + data.Cooldown

		if data.MaxAmmo then
			if CombatConfig.IsEnabled("ClientHitReg") then
				local tool = heldGun(player, toolName)
				if not tool then return end
				local fired, ammoLeft = AmmoServer.TryConsume(tool, data)
				if not fired then
					-- The client thinks it has rounds the server never saw loaded.
					AmmoSync:FireClient(player, tool, ammoLeft)
					return
				end
			end
			WeaponServer.FireHitscan(player, toolName, data, mousePos, isAiming == true, eyeOrigin, directions, claims)
		else
			WeaponServer.FireMelee(player, toolName, data)
		end
	end)

	CombatRemotes.GetReload().OnServerEvent:Connect(function(player, toolName)
		if not CombatConfig.IsEnabled("ClientHitReg") or type(toolName) ~= "string" then return end
		local data = Items[toolName]
		local tool = heldGun(player, toolName)
		if not data or not data.MaxAmmo or not tool then return end
		AmmoServer.StartReload(tool, data)
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
