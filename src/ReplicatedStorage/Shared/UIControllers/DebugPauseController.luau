-- Studio-only panel that freezes the server's round timer, so the viewmodel can
-- be inspected in a running client for as long as needed.
--
-- The panel is built only in Studio. The server also ignores the remote outside
-- Studio, so neither half of this can reach a published game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local RoundRemotes = require(ReplicatedStorage.Shared.Remotes.RoundRemotes)

local DebugPauseController = {}

local COLORS = {
	panel = Color3.fromRGB(19, 22, 29),
	header = Color3.fromRGB(26, 31, 41),
	text = Color3.fromRGB(242, 245, 250),
	muted = Color3.fromRGB(154, 164, 181),
	running = Color3.fromRGB(55, 196, 122),
	paused = Color3.fromRGB(255, 176, 46),
	stroke = Color3.fromRGB(58, 67, 83),
}

local PAUSED_ATTRIBUTE = "RoundPaused"

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

function DebugPauseController.Init()
	if not RunService:IsStudio() then return end

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local old = playerGui:FindFirstChild("RoundPausePanel")
	if old then old:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RoundPausePanel"
	screenGui.DisplayOrder = 1000
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Active = true
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -24, 0, 84)
	panel.Size = UDim2.fromOffset(244, 132)
	panel.BackgroundColor3 = COLORS.panel
	panel.BorderSizePixel = 0
	panel.Parent = screenGui
	addCorner(panel, 12)

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.stroke
	stroke.Transparency = 0.15
	stroke.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Active = true
	header.Size = UDim2.new(1, 0, 0, 42)
	header.BackgroundColor3 = COLORS.header
	header.BorderSizePixel = 0
	header.Parent = panel
	addCorner(header, 12)

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(14, 6)
	title.Size = UDim2.new(1, -28, 0, 18)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "ROUND TIMER"
	title.TextColor3 = COLORS.text
	title.TextSize = 15
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local subtitle = Instance.new("TextLabel")
	subtitle.Position = UDim2.fromOffset(14, 23)
	subtitle.Size = UDim2.new(1, -28, 0, 14)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Gotham
	subtitle.Text = "P: TOGGLE  -  DRAG TO MOVE"
	subtitle.TextColor3 = COLORS.muted
	subtitle.TextSize = 10
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Parent = header

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Position = UDim2.fromOffset(14, 50)
	status.Size = UDim2.new(1, -28, 0, 20)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.Text = "state: -"
	status.TextColor3 = COLORS.muted
	status.TextSize = 12
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = panel

	local button = Instance.new("TextButton")
	button.Name = "Toggle"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -14)
	button.Size = UDim2.new(1, -28, 0, 38)
	button.AutoButtonColor = false
	button.BackgroundColor3 = COLORS.running
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = "PAUSE TIMER"
	button.TextColor3 = Color3.fromRGB(12, 16, 22)
	button.TextSize = 14
	button.Parent = panel
	addCorner(button, 9)

	local function isPaused()
		return Workspace:GetAttribute(PAUSED_ATTRIBUTE) == true
	end

	local function render()
		local paused = isPaused()
		button.Text = paused and "RESUME TIMER" or "PAUSE TIMER"
		button.BackgroundColor3 = paused and COLORS.paused or COLORS.running
		title.Text = paused and "ROUND TIMER - PAUSED" or "ROUND TIMER"
	end

	-- The server owns the flag, so the panel only ever asks for the opposite of
	-- what it currently sees and waits for the attribute to come back.
	local function toggle()
		RoundRemotes.GetTogglePauseEvent():FireServer(not isPaused())
	end

	button.Activated:Connect(toggle)
	Workspace:GetAttributeChangedSignal(PAUSED_ATTRIBUTE):Connect(render)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.P then toggle() end
	end)

	-- Both halves of what a pause freezes: the round state/clock, and the arena
	-- phase that decides whether weapons are in hand.
	local lastState, lastTime = "-", "-"

	local function renderStatus()
		local phase = Workspace:GetAttribute("ArenaPhase")
		status.Text = string.format("%s  %ss  |  phase: %s",
			tostring(lastState), tostring(lastTime), phase and tostring(phase) or "-")
	end

	RoundRemotes.GetUpdateEvent().OnClientEvent:Connect(function(state, timeLeft)
		lastState, lastTime = state, timeLeft
		renderStatus()
	end)

	Workspace:GetAttributeChangedSignal("ArenaPhase"):Connect(renderStatus)

	local dragging = false
	local dragStart = Vector2.zero
	local startPosition = panel.Position

	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPosition = panel.Position
		end
	end)

	header.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		local delta = input.Position - dragStart
		panel.Position = UDim2.new(
			startPosition.X.Scale,
			startPosition.X.Offset + delta.X,
			startPosition.Y.Scale,
			startPosition.Y.Offset + delta.Y
		)
	end)

	render()
	renderStatus()
end

return DebugPauseController
