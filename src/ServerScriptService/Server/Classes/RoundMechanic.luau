local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local RoundConfig = require(Shared.Modules.Core.RoundConfig)
local MapConfig = require(Shared.Modules.Core.MapConfig)
local RoundRemotes = require(Shared.Remotes.RoundRemotes)
local PlayerUtil = require(Shared.Modules.Utils.PlayerUtil)
local janitor = require(Shared.Packages.janitor)

local rng = Random.new()

local RoundMechanic = {}
RoundMechanic.__index = RoundMechanic

function RoundMechanic.new(roundServer)
	local self = setmetatable({}, RoundMechanic)
	self.janitor = janitor.new()
	self.roundServer = roundServer
	return self
end

function RoundMechanic:Start()
	local mechanicThread = task.spawn(function()
		local colors = MapConfig.ColorOrder
		local map = Workspace:FindFirstChild("Map")

		task.wait(0.25)

		for _, player in Players:GetPlayers() do
			if player:GetAttribute("IsPlaying") then PlayerUtil.GiveWeapons(player) end
		end

		local startTimer = 5
		RoundRemotes.GetColorEvent():FireAllClients("Next", startTimer)
		while startTimer > 0 and self.roundServer.CurrentState == RoundConfig.States.InGame do
			task.wait(1)
			startTimer -= 1
		end

		while self.roundServer.CurrentState == RoundConfig.States.InGame do
			for _, player in Players:GetPlayers() do
				if player:GetAttribute("IsPlaying") then PlayerUtil.RemoveWeapons(player) end
			end

			self.roundServer.CurrentColor = colors[rng:NextInteger(1, #colors)]
			local colorTimer = 4
			RoundRemotes.GetColorEvent():FireAllClients(self.roundServer.CurrentColor, colorTimer)

			while colorTimer > 0 and self.roundServer.CurrentState == RoundConfig.States.InGame do
				task.wait(1)
				colorTimer -= 1
			end
			if self.roundServer.CurrentState ~= RoundConfig.States.InGame then break end

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
			-- which eliminates them on touch. No raycast sweep needed here.
			task.wait(0.2)

			local hideTimer = 8
			while hideTimer > 0 and self.roundServer.CurrentState == RoundConfig.States.InGame do
				task.wait(1)
				hideTimer -= 1
			end

			for _, data in ipairs(hiddenParts) do
				if data.obj and data.obj.Parent then
					data.obj.Transparency = data.transparency
					if data.isPart then
						data.obj.CanCollide = data.canCollide
					end
				end
			end

			if self.roundServer.CurrentState ~= RoundConfig.States.InGame then break end

			for _, player in Players:GetPlayers() do
				if player:GetAttribute("IsPlaying") then PlayerUtil.GiveWeapons(player) end
			end

			local ffaTimer = 10
			RoundRemotes.GetColorEvent():FireAllClients("Next", ffaTimer)
			while ffaTimer > 0 and self.roundServer.CurrentState == RoundConfig.States.InGame do
				task.wait(1)
				ffaTimer -= 1
			end
		end
	end)

	self.janitor:Add(function() task.cancel(mechanicThread) end)
end

function RoundMechanic:Stop()
	self.janitor:Cleanup()

	local map = Workspace:FindFirstChild("Map")
	if map then
		for _, folder in map:GetChildren() do
			for _, part in folder:GetDescendants() do
				if part:IsA("BasePart") then
					part.Transparency = 0
					part.CanCollide = true
				elseif part:IsA("Texture") or part:IsA("Decal") then
					part.Transparency = 0.95
				end
			end
		end
	end
end

return RoundMechanic