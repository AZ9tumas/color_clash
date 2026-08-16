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

		local cycle = 0
		local ramp = phases.Ramp or {}
		local function scaled(base, phaseKey)
			if base <= 0 then return 0 end
			if not ramp.Enabled then return base end
			local floor = (ramp.Min and ramp.Min[phaseKey]) or base
			return math.max(floor, math.floor(base * (ramp.Factor or 1) ^ cycle + 0.5))
		end

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

		local firstPushTime = phases.FirstPushDuration or phases.PushDuration

		setPhase(PHASE_PUSH)
		if firstPushTime > 0 then
			RoundRemotes.GetColorEvent():FireAllClients("Next", firstPushTime)
			hold(firstPushTime)
		end

		while inGame() do

			local announceTime = scaled(phases.AnnounceDuration, "Announce")
			self.roundServer.CurrentColor = colors[rng:NextInteger(1, #colors)]
			RoundRemotes.GetColorEvent():FireAllClients(self.roundServer.CurrentColor, announceTime)

			hold(math.max(announceTime - 1, 0))
			if not inGame() then break end

			local hiddenParts = {}
			if map then
				for _, folder in map:GetChildren() do
					if folder.Name ~= self.roundServer.CurrentColor then
						for _, part in folder:GetDescendants() do
							if part:IsA("BasePart") then
								table.insert(hiddenParts, {obj = part, isPart = true, transparency = part.Transparency, canCollide = part.CanCollide})
							elseif part:IsA("Texture") or part:IsA("Decal") then
								table.insert(hiddenParts, {obj = part, isPart = false, transparency = part.Transparency})
							end
						end
					end
				end
			end

			for _ = 1, 3 do
				if not inGame() then break end
				for _, data in ipairs(hiddenParts) do
					if data.isPart and data.obj.Parent then data.obj.Transparency = 0.6 end
				end
				task.wait(0.15)
				for _, data in ipairs(hiddenParts) do
					if data.isPart and data.obj.Parent then data.obj.Transparency = data.transparency end
				end
				task.wait(0.18)
			end
			if not inGame() then break end

			for _, data in ipairs(hiddenParts) do
				if data.obj.Parent then
					data.obj.Transparency = 1
					if data.isPart then data.obj.CanCollide = false end
				end
			end

			task.wait(0.2)

			setPhase(PHASE_SHOOT)
			hold(scaled(phases.HiddenDuration, "Hidden"))

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

			cycle += 1

			local pushTime = scaled(phases.PushDuration, "Push")
			if pushTime > 0 then
				RoundRemotes.GetColorEvent():FireAllClients("Next", pushTime)
				hold(pushTime)
			end
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
		if player:GetAttribute("InMenu") == false then
			PlayerUtil.RemoveWeapons(player)
		end
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
