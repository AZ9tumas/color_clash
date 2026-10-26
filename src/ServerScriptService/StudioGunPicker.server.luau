-- Temporary loadout tools for Studio playtests, alongside the round timer panel.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Modules.Core.Items)
local PlayerUtil = require(Shared.Modules.Utils.PlayerUtil)
local weapons = Shared.Assets.Weapons

local remote = Instance.new("RemoteFunction")
remote.Name = "StudioGiveGun"
remote.Parent = Shared.Remotes

remote.OnServerInvoke = function(player, name)
	if not RunService:IsStudio() then return false, "Studio only" end
	if type(name) ~= "string" then return false, "Choose a gun" end
	local data = Items[name]
	local template = weapons:FindFirstChild(name)
	if not data or type(data.MaxAmmo) ~= "number" or not template or not template:IsA("Tool") then
		return false, "Gun unavailable"
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return false, "Backpack not ready" end
	for _, container in {backpack, player.Character} do
		if container then
			for _, item in container:GetChildren() do
				if item:IsA("Tool") and item.Name == name then
					return true, "Already have " .. name
				end
			end
		end
	end

	-- No yields between the ownership check and parenting: repeated requests
	-- cannot grant duplicates. This does not touch saved inventory or loadouts.
	local clone = template:Clone()
	if typeof(data.Grip) == "CFrame" then clone.Grip = data.Grip end
	PlayerUtil.MakeToolPhysicsSafe(clone)
	clone.Parent = backpack
	return true, name .. " added to backpack"
end
