local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local RoundConfig = require(Shared.Modules.Core.RoundConfig)

local TeamVisualsController = {}

local player = Players.LocalPlayer
local highlights = {}

-- Occluded, not AlwaysOnTop: a highlight visible through walls would be a free wallhack.
-- You can only read someone's team when you actually have line of sight to them.
local DEPTH_MODE = Enum.HighlightDepthMode.Occluded
local FILL_TRANSPARENCY = 0.65
local OUTLINE_TRANSPARENCY = 0

local function teamColorFor(target)
	local mode = RoundConfig.GetActiveMode()
	if not (mode and mode.TeamBased) then return nil end
	if target:GetAttribute("IsPlaying") ~= true then return nil end

	local team = target:GetAttribute("Team")
	return team and RoundConfig.TeamColors[team] or nil
end

local function clear(target)
	local existing = highlights[target]
	if existing then
		existing:Destroy()
		highlights[target] = nil
	end
end

local function refresh(target)
	local color = teamColorFor(target)
	local character = target.Character

	if not color or not character then
		clear(target)
		return
	end

	local highlight = highlights[target]
	if not highlight or highlight.Parent == nil then
		highlight = Instance.new("Highlight")
		highlight.Name = "TeamHighlight"
		highlight.DepthMode = DEPTH_MODE
		highlight.FillTransparency = FILL_TRANSPARENCY
		highlight.OutlineTransparency = OUTLINE_TRANSPARENCY
		highlights[target] = highlight
	end

	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.Adornee = character
	highlight.Parent = character
end

local function track(target)
	refresh(target)

	target:GetAttributeChangedSignal("Team"):Connect(function() refresh(target) end)
	target:GetAttributeChangedSignal("IsPlaying"):Connect(function() refresh(target) end)
	target.CharacterAdded:Connect(function()
		-- Characters are reused rather than respawned here, but a LoadCharacter from the
		-- ragdoll path still swaps the model out from under the highlight.
		task.defer(refresh, target)
	end)
end

function TeamVisualsController.Init()
	for _, target in Players:GetPlayers() do track(target) end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(clear)

	-- Teams are wiped between rounds and the mode can change, so re-evaluate everyone
	-- whenever the active mode flips.
	Workspace:GetAttributeChangedSignal("RoundMode"):Connect(function()
		for _, target in Players:GetPlayers() do refresh(target) end
	end)

	-- Cheap safety net: attributes can land before a character exists, and characters can
	-- be swapped without a CharacterAdded we caught.
	task.spawn(function()
		while true do
			task.wait(2)
			for _, target in Players:GetPlayers() do refresh(target) end
		end
	end)
end

return TeamVisualsController
