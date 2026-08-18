local GamePassService = game:GetService("GamePassService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local QuestServer = require(ServerScriptService.Server.Services.QuestService.QuestServer)

local rng = Random.new()

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

local function setMode(mode)
	RoundConfig.CurrentMode = mode
	Workspace:SetAttribute("RoundMode", mode.Name)
end

local function clearTeams()
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Team", nil)
	end
end

local function assignMissingTeams()
	local counts = {}
	for _, name in RoundConfig.TeamNames do counts[name] = 0 end
	for _, p in Players:GetPlayers() do
		local team = p:GetAttribute("Team")
		if counts[team] then counts[team] += 1 end
	end

	for _, p in Players:GetPlayers() do
		if p:GetAttribute("InMenu") == false and not counts[p:GetAttribute("Team")] then
			local smallest, lowest = {}, math.huge
			for _, name in RoundConfig.TeamNames do
				if counts[name] < lowest then
					lowest = counts[name]
					smallest = { name }
				elseif counts[name] == lowest then
					table.insert(smallest, name)
				end
			end

			local chosen = smallest[rng:NextInteger(1, #smallest)]
			p:SetAttribute("Team", chosen)
			counts[chosen] += 1
		end
	end
end

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

local function resolveTeamWinner(roster, wipedOutWinner)
	if wipedOutWinner then return wipedOutWinner end

	local kills = killsByTeam(roster)
	local alive = aliveByTeam(roster)
	local a, b = RoundConfig.TeamNames[1], RoundConfig.TeamNames[2]

	if kills[a] ~= kills[b] then return kills[a] > kills[b] and a or b end
	if alive[a] ~= alive[b] then return alive[a] > alive[b] and a or b end
	return nil
end

local PLACEMENT_DROP_TOLERANCE = 6

local PLACEMENT_SETTLE_TIMEOUT = 0.6

local function waitUntilGrounded(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local deadline = os.clock() + PLACEMENT_SETTLE_TIMEOUT

	local sawAirborne = false

	repeat
		RunService.Heartbeat:Wait()
		if not character.Parent then return false end

		local grounded = humanoid and humanoid.Parent and humanoid.FloorMaterial ~= Enum.Material.Air
		if not grounded then
			sawAirborne = true
		elseif sawAirborne then
			return true
		end
	until os.clock() >= deadline

	return false
end

local function placeOnMap(player, gameSpawn, claimed)
	local character = player.Character
	if not character then return nil end

	for attempt = 1, 3 do
		local ok, landed = PlayerUtil.TeleportOntoMap(character, gameSpawn, nil, claimed)

		waitUntilGrounded(character)

		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root.Parent then return landed end

		if not ok or not landed then

			return landed
		end

		if root.Position.Y > landed.Y - PLACEMENT_DROP_TOLERANCE then
			return landed
		end

		warn(string.format("[Round] %s slid off their spawn cell on attempt %d, replacing", player.Name, attempt))
	end

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

			setMode(VotingManager.GetWinner(defaultMode))

			if RoundConfig.CurrentMode.TeamBased then
				clearTeams()
				setState(RoundConfig.States.TeamSelect, RoundConfig.TeamSelectDuration)
				while RoundServer.TimeLeft > 0 do task.wait(1); RoundServer.TimeLeft -= 1; RoundRemotes.GetUpdateEvent():FireAllClients(RoundServer.CurrentState, RoundServer.TimeLeft) end
			end

			MapMechanic.Generate()
			HitPartMechanic.Build()
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("InMenu") == false then
					player:SetAttribute("Kills", 0)
					player:SetAttribute("RoundCash", 0)
				end
			end

			local mode = RoundConfig.CurrentMode
			if mode.TeamBased then assignMissingTeams() end

			local gameSpawn = Workspace:FindFirstChild("Game")
			local roster = {}

			local waiting = {}
			for _, player in Players:GetPlayers() do
				local team = player:GetAttribute("Team")
				local eligible = player:GetAttribute("InMenu") == false
					and (not mode.TeamBased or table.find(RoundConfig.TeamNames, team) ~= nil)

				if eligible then
					player:SetAttribute("MenuReturnLocked", true)
					table.insert(waiting, { player = player, team = team })
				end
			end

			local claimed = {}
			for _, entry in waiting do
				local player = entry.player
				if player.Parent == Players and player:GetAttribute("InMenu") == false then
					local landed = placeOnMap(player, gameSpawn, claimed)
					if landed then table.insert(claimed, landed) end

					player:SetAttribute("IsPlaying", true)
					QuestServer.UpdateGamesPlayed(player)
					if mode.TeamBased then roster[player] = entry.team end
				end
				if player.Parent == Players then player:SetAttribute("MenuReturnLocked", nil) end
			end
			SpectateMechanic.Refresh()

			setState(RoundConfig.States.InGame, RoundConfig.CurrentMode.GameDuration)
			roundMechanic:Start()

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

			local noContest = mode.TeamBased and not teamsViable

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

					if noContest then

					elseif not mode.TeamBased then
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
			setMode(RoundConfig.Modes.FFA)
		end
	end)
end

local function retireCharacter(player, char, reason)
	if char:GetAttribute("DeathRetired") then return end
	char:SetAttribute("DeathRetired", true)

	if player:GetAttribute("IsPlaying") then
		player:SetAttribute("IsPlaying", false)
		RewardManager.ProcessDeath(player, "The Environment", reason, -1)
	end

	PlayerUtil.RemoveWeapons(player)

	task.delay(2, function()
		if player.Parent == Players and player.Character == char then
			player:LoadCharacter()
		end
	end)
end

local function bindCharacter(player, char)
	local humanoid = char:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.BreakJointsOnDeath = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

		humanoid.Died:Connect(function()
			retireCharacter(player, char, "Fell Off The Map")
		end)

		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			root.AncestryChanged:Connect(function(_, parent)
				if parent ~= nil then return end
				if player.Character ~= char then return end

				if char:FindFirstChild("HumanoidRootPart") then return end
				retireCharacter(player, char, "Fell Off The Map")
			end)
		end

		humanoid.HealthChanged:Connect(function(health)
			if health <= 0 then

				if char:GetAttribute("Ragdolled") then return end

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
		player:SetAttribute("MenuReturnLocked", nil)
		if player.Character then task.spawn(bindCharacter, player, player.Character) end
		player.CharacterAdded:Connect(function(char) bindCharacter(player, char) end)
	end)

	RoundRemotes.GetPlayGameEvent().OnServerEvent:Connect(function(player) player:SetAttribute("InMenu", false) end)

	RoundRemotes.GetClientVoteEvent().OnServerEvent:Connect(function(player, modeName)
		if RoundServer.CurrentState ~= RoundConfig.States.Voting then return end
		VotingManager.CastVote(player, modeName)
	end)

	RoundRemotes.GetResetEvent().OnServerEvent:Connect(function(player)

		local existingChar = player.Character
		if existingChar and existingChar:GetAttribute("Ragdolled") then return end

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

	MapMechanic.Init()

	setMode(RoundConfig.CurrentMode)

	RoundRemotes.GetSelectTeamEvent().OnServerEvent:Connect(function(player, teamName)
		if typeof(teamName) ~= "string" then return end
		if not table.find(RoundConfig.TeamNames, teamName) then return end

		if player:GetAttribute("IsPlaying") then return end

		local counts = {}
		for _, name in RoundConfig.TeamNames do counts[name] = 0 end
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local team = other:GetAttribute("Team")
				if counts[team] then counts[team] += 1 end
			end
		end

		local lowest = math.huge
		for _, name in RoundConfig.TeamNames do lowest = math.min(lowest, counts[name]) end
		if counts[teamName] > lowest then return end

		player:SetAttribute("Team", teamName)
	end)

	RoundRemotes.GetMainMenuEvent().OnServerEvent:Connect(function(player)
		if player:GetAttribute("MenuReturnLocked") then return end
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

		player:SetAttribute("InMenu", true)
	end)

	startRoundLoop()
end

return RoundServer
