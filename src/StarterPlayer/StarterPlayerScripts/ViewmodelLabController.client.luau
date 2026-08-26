local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local GunsystemGunHandler = require(ReplicatedStorage.Shared.Modules.Gunsystem.GunHandler)

local COLORS = {
	panel = Color3.fromRGB(19, 22, 29),
	header = Color3.fromRGB(26, 31, 41),
	row = Color3.fromRGB(32, 38, 49),
	rowHover = Color3.fromRGB(38, 45, 58),
	text = Color3.fromRGB(242, 245, 250),
	muted = Color3.fromRGB(154, 164, 181),
	accent = Color3.fromRGB(61, 139, 255),
	success = Color3.fromRGB(55, 196, 122),
	failure = Color3.fromRGB(104, 113, 129),
	stroke = Color3.fromRGB(58, 67, 83),
}

-- Add future debug actions here. Each action returns success and a short status.
local ACTIONS = {
	{
		id = "play_animation",
		keyCode = Enum.KeyCode.Q,
		keyLabel = "Q",
		label = "Play weapon animation",
		description = "Replay the equipped viewmodel animation",
		run = GunsystemGunHandler.PlayEquippedAnimation,
	},
	{
		id = "play_reload",
		keyCode = Enum.KeyCode.E,
		keyLabel = "E",
		label = "Play reload animation",
		description = "Uses the equipped Tool's Reload animation",
		run = GunsystemGunHandler.PlayEquippedReloadAnimation,
	},
}

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function addStroke(instance, color, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency or 0
	stroke.Thickness = 1
	stroke.Parent = instance
end

local oldGui = playerGui:FindFirstChild("ViewmodelLab")
if oldGui then oldGui:Destroy() end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ViewmodelLab"
screenGui.DisplayOrder = 1000
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Active = true
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -24, 0, 84)
panel.Size = UDim2.fromOffset(320, 238)
panel.BackgroundColor3 = COLORS.panel
panel.BorderSizePixel = 0
panel.Parent = screenGui
addCorner(panel, 12)
addStroke(panel, COLORS.stroke, 0.15)

local header = Instance.new("Frame")
header.Name = "Header"
header.Active = true
header.Size = UDim2.new(1, 0, 0, 58)
header.BackgroundColor3 = COLORS.header
header.BorderSizePixel = 0
header.Parent = panel
addCorner(header, 12)

local headerMask = Instance.new("Frame")
headerMask.Name = "SquareBottom"
headerMask.AnchorPoint = Vector2.new(0, 1)
headerMask.Position = UDim2.fromScale(0, 1)
headerMask.Size = UDim2.new(1, 0, 0, 12)
headerMask.BackgroundColor3 = COLORS.header
headerMask.BorderSizePixel = 0
headerMask.Parent = header

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(16, 9)
title.Size = UDim2.new(1, -32, 0, 23)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "VIEWMODEL LAB"
title.TextColor3 = COLORS.text
title.TextSize = 17
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Position = UDim2.fromOffset(16, 31)
subtitle.Size = UDim2.new(1, -32, 0, 17)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "M: FIRST PERSON  •  DRAG TO MOVE"
subtitle.TextColor3 = COLORS.muted
subtitle.TextSize = 11
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local controlsFrame = Instance.new("ScrollingFrame")
controlsFrame.Name = "Controls"
controlsFrame.Position = UDim2.fromOffset(10, 68)
controlsFrame.Size = UDim2.new(1, -20, 1, -78)
controlsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
controlsFrame.CanvasSize = UDim2.new()
controlsFrame.BackgroundTransparency = 1
controlsFrame.BorderSizePixel = 0
controlsFrame.ScrollBarImageColor3 = COLORS.accent
controlsFrame.ScrollBarThickness = 3
controlsFrame.Parent = panel

local controlsPadding = Instance.new("UIPadding")
controlsPadding.PaddingBottom = UDim.new(0, 2)
controlsPadding.Parent = controlsFrame

local controlsLayout = Instance.new("UIListLayout")
controlsLayout.Padding = UDim.new(0, 8)
controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
controlsLayout.Parent = controlsFrame

local actionTriggers = {}

local function createActionRow(action, layoutOrder)
	local row = Instance.new("TextButton")
	row.Name = action.id
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, -4, 0, 68)
	row.AutoButtonColor = false
	row.BackgroundColor3 = COLORS.row
	row.BorderSizePixel = 0
	row.Text = ""
	row.Parent = controlsFrame
	addCorner(row, 9)
	addStroke(row, COLORS.stroke, 0.35)

	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(13, 10)
	label.Size = UDim2.new(1, -108, 0, 22)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamSemibold
	label.Text = action.label
	label.TextColor3 = COLORS.text
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	local description = Instance.new("TextLabel")
	description.Position = UDim2.fromOffset(13, 34)
	description.Size = UDim2.new(1, -108, 0, 18)
	description.BackgroundTransparency = 1
	description.Font = Enum.Font.Gotham
	description.Text = action.description
	description.TextColor3 = COLORS.muted
	description.TextSize = 11
	description.TextTruncate = Enum.TextTruncate.AtEnd
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.Parent = row

	local actionButton = Instance.new("TextLabel")
	actionButton.Name = "Action"
	actionButton.AnchorPoint = Vector2.new(1, 0.5)
	actionButton.Position = UDim2.new(1, -13, 0.5, 0)
	actionButton.Size = UDim2.fromOffset(76, 32)
	actionButton.BackgroundColor3 = COLORS.accent
	actionButton.BorderSizePixel = 0
	actionButton.Font = Enum.Font.GothamBold
	local defaultActionText = action.keyLabel .. " · PLAY"
	actionButton.Text = defaultActionText
	actionButton.TextColor3 = COLORS.text
	actionButton.TextSize = 11
	actionButton.Parent = row
	addCorner(actionButton, 8)

	local feedbackToken = 0
	local function runAction()
		feedbackToken += 1
		local token = feedbackToken
		local success, status = action.run()
		actionButton.Text = status or (success and "PLAYING" or "UNAVAILABLE")
		actionButton.BackgroundColor3 = success and COLORS.success or COLORS.failure

		task.delay(1.25, function()
			if feedbackToken ~= token then return end
			actionButton.Text = defaultActionText
			actionButton.BackgroundColor3 = COLORS.accent
		end)
	end

	actionTriggers[action.keyCode] = runAction
	row.Activated:Connect(runAction)

	row.MouseEnter:Connect(function()
		row.BackgroundColor3 = COLORS.rowHover
	end)
	row.MouseLeave:Connect(function()
		row.BackgroundColor3 = COLORS.row
	end)
end

for index, action in ipairs(ACTIONS) do
	createActionRow(action, index)
end

UserInputService.InputBegan:Connect(function(input)
	if UserInputService:GetFocusedTextBox() then return end

	local trigger = actionTriggers[input.KeyCode]
	if trigger then
		-- Let Roblox's Tool hotkey finish equipping before the debug action runs.
		task.delay(0.05, trigger)
	end
end)

local function resizePanel()
	local contentHeight = controlsLayout.AbsoluteContentSize.Y
	panel.Size = UDim2.fromOffset(320, math.clamp(78 + contentHeight, 154, 430))
end
controlsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizePanel)
task.defer(resizePanel)

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
