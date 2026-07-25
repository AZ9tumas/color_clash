local GamePassService = game:GetService("GamePassService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local RoundConfig = require(Shared.Modules.Core.RoundConfig)
local RoundRemotes = require(Shared.Remotes.RoundRemotes)
local PlayerUtil = require(Shared.Modules.Utils.PlayerUtil)
local VotingManager = require(Shared.Modules.Game.VotingManager)
local RewardManager = require(Shared.Modules.Game.RewardManager)
local signal = require(Shared.Packages.signal)
local RoundMechanic = require(ServerScriptService.Server.Classes.RoundMechanic)

local RoundServer = {}
RoundServer.StateChanged = signal.new()
RoundServer.CurrentState = RoundConfig.States.WaitingForPlayers
RoundServer.TimeLeft = 0
RoundServer.CurrentColor = nil

local roundMechanic = RoundMechanic.new(RoundServer)

local function setState(newState, time)
	RoundServer.CurrentState = newState
	RoundServer.TimeLeft = time or 0
	RoundServer.StateChanged:Fire(newState, RoundServer.TimeLeft)
	RoundRemotes.GetUpdateEvent():FireAllClients(RoundServer.CurrentState, RoundServer.TimeLeft)
end

local function startRoundLoop()
	task.spawn(function()
		while true do
			local defaultMode = RoundConfig.CurrentMode
			if #Players:GetPlayers() < defaultMode.MinimumPlayers then
				setState(RoundConfig.States.WaitingForPlayers, 0)
				repeat task.wait(1) until #Players:GetPlayers() >= defaultMode.MinimumPlayers
			end

			setState(RoundConfig.States.PostRound, 15)
			while RoundServer.TimeLeft > 0 do task.wait(1); RoundServer.TimeLeft -= 1; RoundRemotes.GetUpdateEvent():FireAllClients(RoundServer.CurrentState, RoundServer.TimeLeft) end

			setState(RoundConfig.States.Voting, RoundConfig.VotingDuration)
			VotingManager.StartVoting()
			
			while RoundServer.TimeLeft > 0 do task.wait(1); RoundServer.TimeLeft -= 1; RoundRemotes.GetUpdateEvent():FireAllClients(RoundServer.CurrentState, RoundServer.TimeLeft) end

			RoundConfig.CurrentMode = VotingManager.GetWinner(defaultMode)

			setState(RoundConfig.States.Intermission, RoundConfig.CurrentMode.IntermissionDuration)
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("InMenu") == false then 
					player:SetAttribute("Kills", 0) 
					player:SetAttribute("RoundCash", 0)
				end
			end

			while RoundServer.TimeLeft > 0 do task.wait(1); RoundServer.TimeLeft -= 1; RoundRemotes.GetUpdateEvent():FireAllClients(RoundServer.CurrentState, RoundServer.TimeLeft) end

			local gameSpawn = Workspace:FindFirstChild("Game")
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("InMenu") == false then
					player:SetAttribute("IsPlaying", true)
					PlayerUtil.TeleportEntity(player.Character, gameSpawn)
				end
			end

			setState(RoundConfig.States.InGame, RoundConfig.CurrentMode.GameDuration)
			roundMechanic:Start()
			
			while RoundServer.TimeLeft > 0 do
				if PlayerUtil.GetActivePlayerCount() <= (RoundConfig.CurrentMode.MinimumPlayers > 1 and 1 or 0) then break end
				task.wait(1); RoundServer.TimeLeft -= 1; RoundRemotes.GetUpdateEvent():FireAllClients(RoundServer.CurrentState, RoundServer.TimeLeft)
			end

			local lobbySpawn = Workspace:FindFirstChild("Spawnlocation")
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("IsPlaying") then
					player:SetAttribute("IsPlaying", false)
					PlayerUtil.RemoveWeapons(player)
					if player.Character then
						local hum = player.Character:FindFirstChildOfClass("Humanoid")
						if hum then hum.Health = hum.MaxHealth end
					end
					PlayerUtil.TeleportEntity(player.Character, lobbySpawn)
					RewardManager.ProcessWin(player)
				end
			end
			
			roundMechanic:Stop()
			setState(RoundConfig.States.InGame, 0)
			task.wait(2)
			RoundConfig.CurrentMode = RoundConfig.Modes.FFA
		end
	end)
end

local function bindCharacter(player, char)
	local humanoid = char:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.BreakJointsOnDeath = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		
		humanoid.HealthChanged:Connect(function(health)
			if health <= 0 then
				humanoid.Health = humanoid.MaxHealth
				local lobbySpawn = Workspace:FindFirstChild("Spawnlocation")
				
				if player:GetAttribute("IsPlaying") then
					player:SetAttribute("IsPlaying", false)
					RewardManager.ProcessDeath(player, "The Environment", "Fell Into The Void", -1)
					
					local hrp = char:FindFirstChild("HumanoidRootPart")
					local kbVelocity = Vector3.new(0, 80, 0)
					if hrp then kbVelocity = (-hrp.CFrame.LookVector * 60) + Vector3.new(0, 80, 0) end
					
					PlayerUtil.RagdollAndTeleport(player, lobbySpawn, kbVelocity)
				else
					local hrp = char:FindFirstChild("HumanoidRootPart")
					local kbVelocity = Vector3.new(0, 80, 0)
					if hrp then kbVelocity = (-hrp.CFrame.LookVector * 60) + Vector3.new(0, 80, 0) end
					PlayerUtil.RagdollAndTeleport(player, lobbySpawn, kbVelocity)
				end
			end
		end)
	end
end

function RoundServer.Init()
	Players.PlayerAdded:Connect(function(player)
		if player:GetAttribute("InMenu") == nil then player:SetAttribute("InMenu", true) end
		if player.Character then task.spawn(bindCharacter, player, player.Character) end
		player.CharacterAdded:Connect(function(char) bindCharacter(player, char) end)
	end)
	
	RoundRemotes.GetPlayGameEvent().OnServerEvent:Connect(function(player) player:SetAttribute("InMenu", false) end)
	
	RoundRemotes.GetClientVoteEvent().OnServerEvent:Connect(function(player, modeName)
		if RoundServer.CurrentState ~= RoundConfig.States.Voting then return end
		VotingManager.CastVote(player, modeName)
	end)
	
	RoundRemotes.GetResetEvent().OnServerEvent:Connect(function(player)
		local lobbySpawn = Workspace:FindFirstChild("Spawnlocation")
		
		if player:GetAttribute("IsPlaying") then
			player:SetAttribute("IsPlaying", false)
			
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local kbVelocity = Vector3.new(0, 80, 0)
			if hrp then kbVelocity = (-hrp.CFrame.LookVector * 60) + Vector3.new(0, 80, 0) end
			
			PlayerUtil.RagdollAndTeleport(player, lobbySpawn, kbVelocity)
			RewardManager.ProcessDeath(player, "The Environment", "Reset Your Character", -1)
		else
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local kbVelocity = Vector3.new(0, 80, 0)
			if hrp then kbVelocity = (-hrp.CFrame.LookVector * 60) + Vector3.new(0, 80, 0) end
			PlayerUtil.RagdollAndTeleport(player, lobbySpawn, kbVelocity)
		end
	end)

	startRoundLoop()
end

return RoundServer