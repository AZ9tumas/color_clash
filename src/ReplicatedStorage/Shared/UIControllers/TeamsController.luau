local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local RoundConfig = require(Shared.Modules.Core.RoundConfig)
local RoundRemotes = require(Shared.Remotes.RoundRemotes)
local UIAnimations = require(Shared.Modules.Utils.UIAnimations)

local TeamsController = {}

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

-- StarterGui.Teams ships with ResetOnSpawn = true, so the ScreenGui is destroyed and
-- recloned on respawn. Bind per instance rather than caching once, otherwise a respawn
-- leaves us holding a destroyed frame and the picker never opens again.
local bound = {}
local isOpen = false

local function bind(gui)
	local holder = gui:FindFirstChild("ButtonsHolder")
	if not holder then return nil end

	local entry = { holder = holder, labels = {} }
	UIAnimations.InitializePopObject(holder)

	for _, teamName in RoundConfig.TeamNames do
		local frame = holder:FindFirstChild(teamName)
		local btn = frame and frame:FindFirstChild("btn")
		if btn then
			entry.labels[teamName] = btn:FindFirstChild("Title")
			UIAnimations.BindButtonAnimations(btn)

			btn.MouseButton1Click:Connect(function()
				if not isOpen then return end
				RoundRemotes.GetSelectTeamEvent():FireServer(teamName)
			end)
		end
	end

	bound[gui] = entry
	return entry
end

local function resolve()
	local gui = PlayerGui:FindFirstChild("Teams")
	if not gui then return nil end
	return bound[gui] or bind(gui)
end

-- Team membership is a replicated attribute, so live counts need no remote. The side the
-- local player picked is marked so the choice reads back clearly.
local function refreshLabels()
	local entry = resolve()
	if not entry then return end

	local counts = {}
	for _, name in RoundConfig.TeamNames do counts[name] = 0 end
	for _, p in Players:GetPlayers() do
		local team = p:GetAttribute("Team")
		if counts[team] then counts[team] += 1 end
	end

	local mine = player:GetAttribute("Team")
	for name, label in pairs(entry.labels) do
		if label then
			label.Text = string.format("%s (%d)%s", string.upper(name), counts[name] or 0,
				mine == name and " ✓" or "")
		end
	end
end

local function setOpen(open)
	local entry = resolve()
	if not entry then return end

	if open == isOpen then
		if open then refreshLabels() end
		return
	end

	isOpen = open
	if open then
		refreshLabels()
		UIAnimations.PopIn(entry.holder)
	else
		UIAnimations.PopOut(entry.holder)
	end
end

function TeamsController.Init()
	local gui = PlayerGui:FindFirstChild("Teams")
	if gui then
		gui.Enabled = true
		bind(gui)
	end

	-- Driven purely by round state: the picker belongs to the TeamSelect phase, not to
	-- pressing Play. A player who joins mid-round simply sees it at the next window.
	RoundRemotes.GetUpdateEvent().OnClientEvent:Connect(function(newState)
		local inLobby = player:GetAttribute("InMenu") == false
		setOpen(newState == RoundConfig.States.TeamSelect and inLobby)
	end)

	player:GetAttributeChangedSignal("InMenu"):Connect(function()
		if player:GetAttribute("InMenu") ~= false then setOpen(false) end
	end)

	player:GetAttributeChangedSignal("Team"):Connect(refreshLabels)

	task.spawn(function()
		while true do
			task.wait(1)
			if isOpen then refreshLabels() end
		end
	end)
end

return TeamsController
