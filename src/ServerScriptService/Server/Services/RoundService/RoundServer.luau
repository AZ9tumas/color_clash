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
local SpectateMechanic = require(ServerScriptService.Server.Classes.SpectateMechanic)
local HitPartMechanic = require(ServerScriptService.Server.Classes.HitPartMechanic)
local MapMechanic = require(ServerScriptService.Server.Classes.MapMechanic)

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

-- Wiped before every selection window so players re-pick each round rather than being
-- silently carried over on last round's side.
local function clearTeams()
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Team", nil)
	end
end

-- Counts only the players who started the round, so someone leaving cannot make a team
-- look wiped out and end the round early.
local function aliveByTeam(roster)
	local counts = {}
	for _, name in RoundConfig.TeamNames do counts[name] = 0 end
	for player, team in pairs(roster) do
		if player:GetAttribute("IsPlaying") and counts[team] then counts[team] += 1 end
	end
	return counts
end

local function killsByTeam(roster)
	local counts = {}
	for _, name in RoundConfig.TeamNames do counts[name] = 0 end
	for player, team in pairs(roster) do
		if counts[team] then counts[team] += (player:GetAttribute("Kills") or 0) end
	end
	return counts
end

-- Last team standing; on timeout the higher kill total wins, then the most survivors,
-- and a dead heat on both is a draw (nil).
local function resolveTeamWinner(roster, wipedOutWinner)
	if wipedOutWinner then return wipedOutWinner end

	local kills = killsByTeam(roster)
	local alive = aliveByTeam(roster)
	local a, b = RoundConfig.TeamNames[1], RoundConfig.TeamNames[2]

	if kills[a] ~= kills[b] then return kills[a] > kills[b] and a or b end
	if alive[a] ~= alive[b] then return alive[a] > alive[b] and a or b end
	return nil
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

			-- Team modes get a selection window between voting and intermission. Picking a
			-- side is what buys you into the round; anyone who does not pick sits it out in
			-- the lobby, exactly like an eliminated player or a mid-round joiner.
			if RoundConfig.CurrentMode.TeamBased then
				clearTeams()
				setState(RoundConfig.States.TeamSelect, RoundConfig.TeamSelectDuration)
				while RoundServer.TimeLeft > 0 do task.wait(1); RoundServer.TimeLeft -= 1; RoundRemotes.GetUpdateEvent():FireAllClients(RoundServer.CurrentState, RoundServer.TimeLeft) end
			end

			setState(RoundConfig.States.Intermission, RoundConfig.CurrentMode.IntermissionDuration)
			-- Every round gets a fresh grid. Must run before HitPartMechanic.Build(), which
			-- measures Workspace.Map to size the pad.
			MapMechanic.Generate()
			HitPartMechanic.Build()
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("InMenu") == false then 
					player:SetAttribute("Kills", 0) 
					player:SetAttribute("RoundCash", 0)
				end
			end

			while RoundServer.TimeLeft > 0 do task.wait(1); RoundServer.TimeLeft -= 1; RoundRemotes.GetUpdateEvent():FireAllClients(RoundServer.CurrentState, RoundServer.TimeLeft) end

			local mode = RoundConfig.CurrentMode
			local gameSpawn = Workspace:FindFirstChild("Game")
			local roster = {}

			for _, player in Players:GetPlayers() do
				local team = player:GetAttribute("Team")
				local eligible = player:GetAttribute("InMenu") == false
					and (not mode.TeamBased or table.find(RoundConfig.TeamNames, team) ~= nil)

				if eligible then
					player:SetAttribute("IsPlaying", true)
					PlayerUtil.TeleportEntity(player.Character, gameSpawn)
					if mode.TeamBased then roster[player] = team end
				end
			end
			SpectateMechanic.Refresh()

			setState(RoundConfig.States.InGame, RoundConfig.CurrentMode.GameDuration)
			roundMechanic:Start()
			
			-- Only trust the wipeout check if both sides actually fielded someone.
			local teamStart = mode.TeamBased and aliveByTeam(roster) or nil
			local teamsViable = teamStart ~= nil
			if teamsViable then
				for _, name in RoundConfig.TeamNames do
					if teamStart[name] == 0 then teamsViable = false end
				end
			end

			local wipedOutWinner = nil

			while RoundServer.TimeLeft > 0 do
				if teamsViable then
					local alive = aliveByTeam(roster)
					local survivors = {}
					for _, name in RoundConfig.TeamNames do
						if alive[name] > 0 then table.insert(survivors, name) end
					end
					if #survivors <= 1 then
						wipedOutWinner = survivors[1]
						break
					end
				elseif PlayerUtil.GetActivePlayerCount() <= (mode.MinimumPlayers > 1 and 1 or 0) then
					break
				end

				task.wait(1); RoundServer.TimeLeft -= 1; RoundRemotes.GetUpdateEvent():FireAllClients(RoundServer.CurrentState, RoundServer.TimeLeft)
			end

			local teamWinner = teamsViable and resolveTeamWinner(roster, wipedOutWinner) or nil

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

					if not teamsViable then
						RewardManager.ProcessWin(player)
					elseif teamWinner == nil then
						RewardManager.ProcessDeath(player, "Both Teams", "Drew The Round", -1)
					elseif roster[player] == teamWinner then
						RewardManager.ProcessWin(player)
					else
						RewardManager.ProcessDeath(player, "The Enemy Team", "Lost The Round", -1)
					end
				end
			end
			SpectateMechanic.Refresh()

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

	-- Harvest cell templates from the authored map. Generation itself happens in the
	-- Intermission step of every round, including the first.
	MapMechanic.Init()

	RoundRemotes.GetSelectTeamEvent().OnServerEvent:Connect(function(player, teamName)
		if typeof(teamName) ~= "string" then return end
		if not table.find(RoundConfig.TeamNames, teamName) then return end
		-- The pick is final for the round: no switching once you are in it.
		if player:GetAttribute("IsPlaying") then return end

		player:SetAttribute("Team", teamName)
	end)

	RoundRemotes.GetMainMenuEvent().OnServerEvent:Connect(function(player)
		local lobbySpawn = Workspace:FindFirstChild("Spawnlocation")

		SpectateMechanic.Stop(player)

		if player:GetAttribute("IsPlaying") then
			player:SetAttribute("IsPlaying", false)

			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local kbVelocity = Vector3.new(0, 80, 0)
			if hrp then kbVelocity = (-hrp.CFrame.LookVector * 60) + Vector3.new(0, 80, 0) end

			PlayerUtil.RagdollAndTeleport(player, lobbySpawn, kbVelocity)
			RewardManager.ProcessDeath(player, "The Environment", "Left To The Main Menu", -1)
		else
			PlayerUtil.RemoveWeapons(player)
			PlayerUtil.TeleportEntity(player.Character, lobbySpawn)
		end

		-- Back to the state a player is in the moment they join.
		player:SetAttribute("InMenu", true)
	end)

	startRoundLoop()
end

return RoundServer