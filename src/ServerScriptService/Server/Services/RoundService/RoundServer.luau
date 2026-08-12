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

-- Mirrors the active mode onto a Workspace attribute so clients can read it; module
-- state set here would never reach them. Paired with RoundConfig.GetActiveMode().
local function setMode(mode)
	RoundConfig.CurrentMode = mode
	Workspace:SetAttribute("RoundMode", mode.Name)
end

-- Wiped before every selection window so players re-pick each round rather than being
-- silently carried over on last round's side.
local function clearTeams()
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Team", nil)
	end
end

-- Everyone in the lobby who sat out the selection window still gets a side: the smallest
-- team, picked at random among ties. Letting them sit the round out instead meant a single
-- player could take an uncontested round and farm the first-place payout.
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

-- How far a character may settle below the point it was placed on before the placement is
-- treated as failed. A placed character sits roughly 3 studs above its landing point and
-- settles down onto it, so this only trips on an actual slide off the cell.
local PLACEMENT_DROP_TOLERANCE = 6

-- Players are dropped in from 10 studs, about 0.32s of airtime at default gravity. This
-- covers that with room for a bounce, and is the ceiling on how long one player can hold up
-- the rest if they never land.
local PLACEMENT_SETTLE_TIMEOUT = 0.6

-- Blocks until the character is standing on something, or the timeout runs out. This is
-- what makes the placements genuinely sequential: the next player is not positioned until
-- this one has come down, so two characters are never resolved into each other mid-air.
local function waitUntilGrounded(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local deadline = os.clock() + PLACEMENT_SETTLE_TIMEOUT

	-- The fall has to be seen before a landing counts. FloorMaterial can still read as the
	-- lobby floor on the first poll after the teleport, and taking that at face value would
	-- report the player grounded before they have moved - skipping the settle entirely and
	-- putting the next player down on top of them. Assumes a non-zero SPAWN_DROP_HEIGHT,
	-- which is the whole point of the drop-in.
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

-- Places one player on the arena and does not return until their landing has been stepped
-- and verified. Verification is the point: a raycast can land someone on a cell edge, and
-- the solver then slides them off into a gap.
--
-- Checked against where they were put rather than against the elimination pad, which now
-- sits 50 studs below the arena - far enough that "above the pad" no longer means "still on
-- the map", and a wedged player would pass a check against it.
--
-- Returns the position settled on, or nil if the character could not be placed at all.
local function placeOnMap(player, gameSpawn, claimed)
	local character = player.Character
	if not character then return nil end

	for attempt = 1, 3 do
		local ok, landed = PlayerUtil.TeleportOntoMap(character, gameSpawn, nil, claimed)

		-- Let the drop finish before judging where they ended up, and before the next player
		-- is placed. Checking a frame after the teleport would only ever see them in mid-air.
		waitUntilGrounded(character)

		local root = character:FindFirstChild("HumanoidRootPart")
		if not root or not root.Parent then return landed end

		if not ok or not landed then
			-- Off the arena entirely (no map, or nothing under the spawn); retrying will not
			-- find anything a second time.
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

			-- Team modes get a selection window between voting and intermission. Picking a
			-- side is what buys you into the round; anyone who does not pick sits it out in
			-- the lobby, exactly like an eliminated player or a mid-round joiner.
			if RoundConfig.CurrentMode.TeamBased then
				clearTeams()
				setState(RoundConfig.States.TeamSelect, RoundConfig.TeamSelectDuration)
				while RoundServer.TimeLeft > 0 do task.wait(1); RoundServer.TimeLeft -= 1; RoundRemotes.GetUpdateEvent():FireAllClients(RoundServer.CurrentState, RoundServer.TimeLeft) end
			end

			-- No intermission: voting (or team select) rolls straight into the round.
			-- Generation is synchronous and takes well under a second, so nothing needs a
			-- visible waiting state. Generate must run before HitPartMechanic.Build(),
			-- which measures Workspace.Map to size the pad.
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

			-- No wait is needed between Generate() and placement. Measured in this place:
			-- a freshly parented part answers raycasts in the same frame it is parented (40
			-- of 40), and a destroyed one stops answering in the same frame it is destroyed
			-- (0 of 40 stale hits). Generate() is synchronous, so by the time it returns the
			-- arena the raycasts see is exactly the arena that now exists.
			local waiting = {}
			for _, player in Players:GetPlayers() do
				local team = player:GetAttribute("Team")
				local eligible = player:GetAttribute("InMenu") == false
					and (not mode.TeamBased or table.find(RoundConfig.TeamNames, team) ~= nil)

				if eligible then
					table.insert(waiting, { player = player, team = team })
				end
			end

			-- One player at a time, each landing settled before the next is placed. Two
			-- characters spawned in the same frame get resolved into each other by the solver,
			-- and the way out of that is usually sideways into a gap between cells - which
			-- drops them onto the elimination pad at the whistle.
			local claimed = {}
			for _, entry in waiting do
				local player = entry.player
				local landed = placeOnMap(player, gameSpawn, claimed)
				if landed then table.insert(claimed, landed) end

				-- Armed only once they are standing on the map. HitPartMechanic ignores players
				-- who are not IsPlaying, so holding this until after the landing is what stops a
				-- teleport still in flight, or a bad drop, from eliminating someone instantly.
				player:SetAttribute("IsPlaying", true)
				QuestServer.UpdateGamesPlayed(player)
				if mode.TeamBased then roster[player] = entry.team end
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

			-- A team round that never managed to field both sides is a no contest.
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
						-- Both sides were never fielded, so nothing was actually won. Pay
						-- nothing at all: ProcessDeath is not a safe alternative here,
						-- because with nobody else alive it resolves to placement 1 and
						-- pays the top reward, which is the farm we are closing.
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

-- Last resort for a character that cannot be put back together.
--
-- The HealthChanged path below recovers a death by writing Health back and ragdoll-
-- teleporting the body to the lobby, which works as long as there IS a body. Falling off
-- the map is the case where there is not: once the character passes
-- Workspace.FallenPartsDestroyHeight the engine destroys its parts on the way down, and
-- that kills the Humanoid for real. From there Health can no longer be written back, there
-- is no HumanoidRootPart left to ragdoll or teleport, and the player is left owning a
-- limbless corpse with nothing for the camera to follow and IsPlaying still true - stuck
-- until the round ends. Died is the one signal that still fires in that state.
--
-- Idempotent on purpose: if HealthChanged already ran the elimination, IsPlaying is
-- already false and this only performs the recovery half.
local function retireCharacter(player, char, reason)
	if char:GetAttribute("DeathRetired") then return end
	char:SetAttribute("DeathRetired", true)

	if player:GetAttribute("IsPlaying") then
		player:SetAttribute("IsPlaying", false)
		RewardManager.ProcessDeath(player, "The Environment", reason, -1)
	end

	PlayerUtil.RemoveWeapons(player)

	-- Matches the two second beat RagdollAndTeleport recovers on, so the death screen and
	-- the spectate handoff play out at the same pace as every other death.
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

		-- A character whose parts are being destroyed under it may never reach Died - the
		-- Humanoid can go with them. Losing the root is the same unrecoverable state, so it
		-- is treated the same way.
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then
			root.AncestryChanged:Connect(function(_, parent)
				if parent ~= nil then return end
				if player.Character ~= char then return end
				-- Strict: a root that was merely reparented, or replaced by the ragdoll
				-- rebuild, is not a broken character. Only an actual absence is.
				if char:FindFirstChild("HumanoidRootPart") then return end
				retireCharacter(player, char, "Fell Off The Map")
			end)
		end

		humanoid.HealthChanged:Connect(function(health)
			if health <= 0 then
				-- Already mid-ragdoll (e.g. hit the void during death knockback): the
				-- existing flight owns recovery. Re-triggering here was one of the two
				-- paths that froze players after a round.
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
		if player.Character then task.spawn(bindCharacter, player, player.Character) end
		player.CharacterAdded:Connect(function(char) bindCharacter(player, char) end)
	end)
	
	RoundRemotes.GetPlayGameEvent().OnServerEvent:Connect(function(player) player:SetAttribute("InMenu", false) end)
	
	RoundRemotes.GetClientVoteEvent().OnServerEvent:Connect(function(player, modeName)
		if RoundServer.CurrentState ~= RoundConfig.States.Voting then return end
		VotingManager.CastVote(player, modeName)
	end)
	
	RoundRemotes.GetResetEvent().OnServerEvent:Connect(function(player)
		-- Mashing reset during the ragdoll flight was the classic repro for the
		-- stuck-after-round bug: a second ragdoll on top of the first.
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

	-- Harvest cell templates from the authored map. Generation itself happens right
	-- before every round's teleport, including the first.
	MapMechanic.Init()

	-- Publish the starting mode so clients are never reading a stale attribute.
	setMode(RoundConfig.CurrentMode)

	RoundRemotes.GetSelectTeamEvent().OnServerEvent:Connect(function(player, teamName)
		if typeof(teamName) ~= "string" then return end
		if not table.find(RoundConfig.TeamNames, teamName) then return end
		-- The pick is final for the round: no switching once you are in it.
		if player:GetAttribute("IsPlaying") then return end

		-- You may only join a side that is not already the larger one. When the sides are
		-- level both qualify, so the choice is free. Anything else is dropped silently.
		-- The requester's own current pick is excluded, so changing your mind still works.
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