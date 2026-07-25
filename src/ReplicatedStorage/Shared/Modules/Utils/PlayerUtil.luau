local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage.Shared
local RagdollHandler = require(Shared.Modules.Utils.RagdollHandler)

local PlayerUtil = {}

function PlayerUtil.GetActivePlayerCount()
	local count = 0
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("IsPlaying") then count += 1 end
	end
	return count
end

function PlayerUtil.RemoveWeapons(player)
	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:UnequipTools() end
		for _, item in player.Character:GetChildren() do if item:IsA("Tool") then item:Destroy() end end
	end
	for _, item in player.Backpack:GetChildren() do if item:IsA("Tool") then item:Destroy() end end
end

function PlayerUtil.GiveWeapons(player)
	local assetsFolder = Shared:FindFirstChild("Assets")
	local weaponsFolder = assetsFolder and assetsFolder:FindFirstChild("Weapons")
	if not weaponsFolder then return end

	if RunService:IsServer() then
		local DataServer = require(game:GetService("ServerScriptService").Server.Services.DataService.DataServer)
		local profile = DataServer.GetProfile(player)
		
		if profile and profile.Data.Equipped then
			local mainWep = profile.Data.Equipped.Main
			local meleeWep = profile.Data.Equipped.Melee
			
			local function giveTool(name)
				if name then
					local tool = weaponsFolder:FindFirstChild(name)
					if tool and not player.Backpack:FindFirstChild(name) and (not player.Character or not player.Character:FindFirstChild(name)) then 
						tool:Clone().Parent = player.Backpack 
					end
				end
			end
			
			giveTool(mainWep)
			giveTool(meleeWep)
		end
	end
end

function PlayerUtil.TeleportEntity(entity, targetPart)
	if targetPart and entity then
		entity:PivotTo(CFrame.new(targetPart.Position + Vector3.new(math.random(-5, 5), 5, math.random(-5, 5))))
	end
end

function PlayerUtil.RagdollAndTeleport(player, lobbySpawn, kbVelocity)
	if not player.Character then return end
	local char = player.Character
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	
	PlayerUtil.RemoveWeapons(player)
	
	if hrp then
		pcall(function() hrp:SetNetworkOwner(nil) end)
	end
	
	RagdollHandler.apply(char, nil, kbVelocity)
	
	task.delay(2, function()
		if player.Character and player.Character == char and char:IsDescendantOf(workspace) then
			RagdollHandler.remove(char)
			
			if hrp then
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
			
			if hum then hum.Health = hum.MaxHealth end
			
			task.wait(0.05)
			PlayerUtil.TeleportEntity(char, lobbySpawn)
			
			if hrp then
				pcall(function() hrp:SetNetworkOwner(player) end)
			end
		elseif player.Parent == Players then
			player:LoadCharacter()
		end
	end)
end

return PlayerUtil