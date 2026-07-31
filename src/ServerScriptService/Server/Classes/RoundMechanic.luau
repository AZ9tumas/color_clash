local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local RoundConfig = require(Shared.Modules.Core.RoundConfig)
local MapConfig = require(Shared.Modules.Core.MapConfig)
local RoundRemotes = require(Shared.Remotes.RoundRemotes)
local PlayerUtil = require(Shared.Modules.Utils.PlayerUtil)
local janitor = require(Shared.Packages.janitor)

local rng = Random.new()

local RoundMechanic = {}
RoundMechanic.__index = RoundMechanic

-- Read by PushServer and CombatServer to decide which action is legal right now, and by
-- PushClient to know when to listen for input. A Workspace attribute replicates for free.
local PHASE_ATTRIBUTE = "ArenaPhase"
local PHASE_PUSH = "Push"
local PHASE_SHOOT = "Shoot"

function RoundMechanic.new(roundServer)
	local self = setmetatable({}, RoundMechanic)
	self.janitor = janitor.new()
	self.roundServer = roundServer
	return self
end

function RoundMechanic:Start()
	local mechanicThread = task.spawn(function()
		local colors = MapConfig.ColorOrder
		local phases = RoundConfig.Phases
		local map = Workspace:FindFirstChild("Map")

		local function inGame()
			return self.roundServer.CurrentState == RoundConfig.States.InGame
		end

		-- Counts down a phase a second at a time, bailing early if the round ends.
		local function hold(seconds)
			while seconds > 0 and inGame() do
				task.wait(1)
				seconds -= 1
			end
		end

		local function setPhase(phase)
			Workspace:SetAttribute(PHASE_ATTRIBUTE, phase)

			if RoundConfig.Push.Debug then
				print(string.format("[Phase] %s - %s", phase,
					phase == PHASE_SHOOT and "platforms down, weapons given" or "platforms up, push only"))
			end

			for _, player in Players:GetPlayers() do
				if player:GetAttribute("IsPlaying") then
					if phase == PHASE_SHOOT then
						PlayerUtil.GiveWeapons(player)
					else
						PlayerUtil.RemoveWeapons(player)
					end
				end
			end
		end

		task.wait(0.25)

		-- The round opens with every platform up, so it opens push-only.
		setPhase(PHASE_PUSH)
		RoundRemotes.GetColorEvent():FireAllClients("Next", phases.PushDuration)
		hold(phases.PushDuration)

		while inGame() do
			-- Colour is called while the platforms are still up: time to run for it.
			self.roundServer.CurrentColor = colors[rng:NextInteger(1, #colors)]
			RoundRemotes.GetColorEvent():FireAllClients(self.roundServer.CurrentColor, phases.AnnounceDuration)
			hold(phases.AnnounceDuration)
			if not inGame() then break end

			local hiddenParts = {}
			if map then
				for _, folder in map:GetChildren() do
					if folder.Name ~= self.roundServer.CurrentColor then
						for _, part in folder:GetDescendants() do
							if part:IsA("BasePart") then
								table.insert(hiddenParts, {obj = part, isPart = true, transparency = part.Transparency, canCollide = part.CanCollide})
								part.Transparency = 1
								part.CanCollide = false
							elseif part:IsA("Texture") or part:IsA("Decal") then
								table.insert(hiddenParts, {obj = part, isPart = false, transparency = part.Transparency})
								part.Transparency = 1
							end
						end
					end
				end
			end

			-- Players left standing on a hidden cell now fall onto Workspace["hit part"],
			-- which eliminates them on touch.
			task.wait(0.2)

			-- Platforms are gone, so this is the only window where weapons exist.
			setPhase(PHASE_SHOOT)
			hold(phases.HiddenDuration)

			-- Weapons go away before the platforms come back, so there is no interleaving
			-- where a player is holding a gun with every platform up.
			setPhase(PHASE_PUSH)

			for _, data in ipairs(hiddenParts) do
				if data.obj and data.obj.Parent then
					data.obj.Transparency = data.transparency
					if data.isPart then
						data.obj.CanCollide = data.canCollide
					end
				end
			end

			if not inGame() then break end

			RoundRemotes.GetColorEvent():FireAllClients("Next", phases.PushDuration)
			hold(phases.PushDuration)
		end
	end)

	self.janitor:Add(function()
		if coroutine.status(mechanicThread) ~= "dead" then
			task.cancel(mechanicThread)
		end
	end)
end

function RoundMechanic:Stop()
	self.janitor:Cleanup()

	Workspace:SetAttribute(PHASE_ATTRIBUTE, nil)

	for _, player in Players:GetPlayers() do
		PlayerUtil.RemoveWeapons(player)
	end

	local map = Workspace:FindFirstChild("Map")
	if map then
		for _, folder in map:GetChildren() do
			for _, part in folder:GetDescendants() do
				if part:IsA("BasePart") then
					part.Transparency = 0
					part.CanCollide = true
				elseif part:IsA("Texture") or part:IsA("Decal") then
					part.Transparency = 0.9
				end
			end
		end
	end
end

return RoundMechanic
