local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Modules.Core.CombatConfig)
local UtilityConfig = require(Shared.Modules.Core.UtilityConfig)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local Viewmodel = require(Shared.Classes.Viewmodel)

-- Throwables (CombatConfig.Utilities). F throws a frag grenade along the
-- camera; UtilityServer owns the charges, the flight and the blast. A small
-- counter beside the weapon slots shows the charges left.
local UtilityClient = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local THROW_KEY = Enum.KeyCode.F

local counter: TextLabel? = nil

local function buildCounter(): TextLabel?
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return nil end

	local gui = Instance.new("ScreenGui")
	gui.Name = "UtilityHUD"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 2
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "Grenades"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0.59, 0, 0.925, 0)
	label.Size = UDim2.fromOffset(150, 30)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	label.BackgroundTransparency = 0.35
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Visible = false
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return label
end

local function refreshCounter()
	if not counter or not counter.Parent then
		counter = buildCounter()
		if not counter then return end
	end
	local charges = player:GetAttribute("GrenadeCharges") or 0
	counter.Visible = CombatConfig.IsEnabled("Utilities") and player:GetAttribute("IsPlaying") == true
	counter.Text = string.format("[F]  GRENADE  x%d", charges)
	counter.TextTransparency = charges > 0 and 0 or 0.55
end

local function throw()
	if not CombatConfig.IsEnabled("Utilities") or player:GetAttribute("IsPlaying") ~= true then return end
	if (player:GetAttribute("GrenadeCharges") or 0) <= 0 then return end

	local cframe = camera.CFrame
	CombatRemotes.GetThrowUtility():FireServer("Grenade", cframe.Position, cframe.LookVector)

	-- a small flick of the held weapon sells the throw
	local viewmodel = Viewmodel.GetExisting()
	if viewmodel then
		viewmodel:Kick(2.5, 0.6, false)
	end
end

function UtilityClient.Init()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= THROW_KEY then return end
		if player:GetAttribute("InMenu") ~= false then return end
		throw()
	end)

	player:GetAttributeChangedSignal("GrenadeCharges"):Connect(refreshCounter)
	player:GetAttributeChangedSignal("IsPlaying"):Connect(refreshCounter)
	Workspace:GetAttributeChangedSignal("Utilities"):Connect(refreshCounter)
	refreshCounter()
end

return UtilityClient
