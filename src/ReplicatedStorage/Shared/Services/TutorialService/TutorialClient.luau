local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Modules.Core.Items)
local CombatConfig = require(Shared.Modules.Core.CombatConfig)
local TutorialRemotes = require(Shared.Remotes.TutorialRemotes)
local FXUtil = require(Shared.Modules.Utils.FXUtil)

-- A short first-time tutorial. A card in the bottom-left corner walks through
-- moving and then shooting, and each step completes when the player actually
-- does it. Backspace or the Skip button ends it at any time (the mouse is locked
-- during matches, so the key matters). The shooting steps wait until the player
-- holds a gun in a match. TutorialServer saves that it was done; set the
-- Workspace attribute ForceTutorial = true in Studio to see it again.
local TutorialClient = {}

local player = Players.LocalPlayer

local SKIP_KEY = Enum.KeyCode.Backspace
local MOVE_DISTANCE = 14 -- studs walked to finish the first step
local STEP_PAUSE = 0.7 -- seconds a finished step stays ticked before the next

local FONT = Font.fromName("Rubik", Enum.FontWeight.ExtraBold)
local BODY_FONT = Font.fromName("Rubik", Enum.FontWeight.Medium)
local ACCENT = Color3.fromRGB(255, 205, 60)
local DONE_COLOR = Color3.fromRGB(120, 235, 140)
local MUTED = Color3.fromRGB(185, 185, 195)

local function rootPosition(): Vector3?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

local function heldTool(): Tool?
	return player.Character and player.Character:FindFirstChildOfClass("Tool") or nil
end

local function holdingGun(): boolean
	local tool = heldTool()
	local data = tool and Items[tool.Name]
	return data ~= nil and data.MaxAmmo ~= nil
end

-- Each step: what to show, and a check run every frame until it passes. `ctx`
-- is fresh per step; `pressed` holds the inputs seen since the step began.
local STEPS = {
	{
		title = "Move",
		keys = { "W", "A", "S", "D" },
		text = "Walk around the lobby.",
		done = function(ctx)
			local position = rootPosition()
			if position and ctx.last then
				local step = Vector3.new(position.X - ctx.last.X, 0, position.Z - ctx.last.Z).Magnitude
				if step < 20 then -- a teleport is not walking
					ctx.travelled = (ctx.travelled or 0) + step
				end
			end
			ctx.last = position
			return (ctx.travelled or 0) >= MOVE_DISTANCE
		end,
	},
	{
		title = "Sprint",
		keys = { "Shift" },
		text = "Hold Shift while moving to sprint.",
		done = function()
			return player:GetAttribute("MovementState") == "Sprint"
		end,
	},
	{
		title = "Double jump",
		keys = { "Space", "Space" },
		text = "Jump, then press Space again in the air.",
		done = function(_, pressed)
			return pressed.AirJump == true
		end,
	},
	{
		title = "Slide",
		keys = { "Shift", "C" },
		-- MovementClient only lets you slide during a match
		text = function()
			return player:GetAttribute("IsPlaying") and "While sprinting, press C (or Ctrl) to slide."
				or "Slides work once a match starts. Then sprint and press C (or Ctrl)."
		end,
		done = function()
			return player:GetAttribute("MovementState") == "Slide"
		end,
	},
	{
		title = "Draw your gun",
		keys = { "1" },
		text = "You get your guns when a match starts. Press 1 to hold yours.",
		done = holdingGun,
	},
	{
		title = "Aim",
		keys = { "Right-click" },
		text = "Hold right-click to aim down the sights.",
		done = function()
			return player:GetAttribute("AimFOV") ~= nil
		end,
	},
	{
		title = "Shoot",
		keys = { "Left-click" },
		text = "Click to fire. Hitting players fills your quests.",
		done = function(_, pressed)
			return pressed.Fire == true
		end,
	},
	{
		title = "Reload",
		keys = { "R" },
		text = "Press R to reload before you run dry.",
		done = function(_, pressed)
			return pressed.Reload == true
		end,
	},
	{
		title = "Swap weapons",
		keys = function()
			return CombatConfig.IsEnabled("QuickSwap") and { "Q" } or { "2" }
		end,
		text = "Switch between your gun and your melee weapon.",
		done = function(ctx)
			local tool = heldTool()
			if not ctx.tool then
				ctx.tool = tool
				return false
			end
			return tool ~= nil and tool ~= ctx.tool
		end,
	},
}

local function corner(parent: Instance, radius: number)
	local ui = Instance.new("UICorner")
	ui.CornerRadius = UDim.new(0, radius)
	ui.Parent = parent
end

local function textLabel(parent: Instance, order: number, font: Font, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.FontFace = font
	label.TextSize = size
	label.TextColor3 = color
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function buildCard()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3

	-- Bottom-left, above the kill feed and below the match vote panel.
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0, 1)
	card.Position = UDim2.new(0, 24, 0.83, 0)
	card.Size = UDim2.fromOffset(290, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	card.BackgroundTransparency = 0.12
	card.Parent = gui
	corner(card, 10)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.85
	stroke.Parent = card

	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		padding[side] = UDim.new(0, 12)
	end
	padding.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = card

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = card

	-- step counter on the left, Skip on the right, sharing one line
	local headerRow = Instance.new("Frame")
	headerRow.LayoutOrder = 1
	headerRow.Size = UDim2.new(1, 0, 0, 16)
	headerRow.BackgroundTransparency = 1
	headerRow.Parent = card
	local header = textLabel(headerRow, 1, FONT, 12, ACCENT)
	header.AutomaticSize = Enum.AutomaticSize.None
	header.Size = UDim2.fromScale(1, 1)

	local title = textLabel(card, 2, FONT, 22, Color3.new(1, 1, 1))

	local keys = Instance.new("Frame")
	keys.LayoutOrder = 3
	keys.Size = UDim2.new(1, 0, 0, 30)
	keys.BackgroundTransparency = 1
	keys.Parent = card
	local keyLayout = Instance.new("UIListLayout")
	keyLayout.FillDirection = Enum.FillDirection.Horizontal
	keyLayout.Padding = UDim.new(0, 6)
	keyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	keyLayout.Parent = keys

	local body = textLabel(card, 4, BODY_FONT, 14, MUTED)

	local track = Instance.new("Frame")
	track.LayoutOrder = 5
	track.Size = UDim2.new(1, 0, 0, 4)
	track.BackgroundColor3 = Color3.fromRGB(70, 70, 78)
	track.BorderSizePixel = 0
	track.Parent = card
	corner(track, 2)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = ACCENT
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 2)

	local skip = Instance.new("TextButton")
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.fromScale(1, 0)
	skip.AutomaticSize = Enum.AutomaticSize.X
	skip.Size = UDim2.fromScale(0, 1)
	skip.BackgroundTransparency = 1
	skip.FontFace = BODY_FONT
	skip.TextSize = 12
	skip.TextColor3 = MUTED
	skip.Text = "Skip [Backspace]"
	skip.Parent = headerRow

	gui.Parent = player:WaitForChild("PlayerGui")
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	return {
		gui = gui, card = card, scale = scale, header = header, title = title,
		keys = keys, body = body, fill = fill, skip = skip,
	}
end

local function stepText(step): string
	return type(step.text) == "function" and step.text() or step.text
end

local function showKeys(ui, keys: { string })
	for _, child in ui.keys:GetChildren() do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	ui.keys.Visible = #keys > 0
	for index, key in keys do
		local cap = Instance.new("TextLabel")
		cap.LayoutOrder = index
		cap.AutomaticSize = Enum.AutomaticSize.X
		cap.Size = UDim2.fromOffset(30, 30)
		cap.BackgroundColor3 = Color3.fromRGB(235, 235, 240)
		cap.FontFace = FONT
		cap.TextSize = 15
		cap.TextColor3 = Color3.fromRGB(28, 28, 32)
		cap.Text = key
		cap.Parent = ui.keys
		corner(cap, 6)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 9)
		pad.PaddingRight = UDim.new(0, 9)
		pad.Parent = cap
	end
end

local function run()
	local ui = buildCard()
	local connections = {}
	local pressed = {}
	local ctx = {}
	local current = 0
	local advancing = false
	local finished = false

	local function close(fadeAfter: number)
		if finished then return end
		finished = true
		for _, connection in connections do
			connection:Disconnect()
		end
		TutorialRemotes.GetFinishedEvent():FireServer()
		task.delay(fadeAfter, function()
			TweenService:Create(ui.scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
			task.delay(0.3, function() ui.gui:Destroy() end)
		end)
	end

	local function showStep(index: number)
		current = index
		pressed = {}
		ctx = {}
		local step = STEPS[index]
		ui.header.Text = string.format("TUTORIAL  ·  STEP %d OF %d", index, #STEPS)
		ui.title.Text = step.title
		ui.title.TextColor3 = Color3.new(1, 1, 1)
		ui.body.Text = stepText(step)
		showKeys(ui, type(step.keys) == "function" and step.keys() or step.keys)
		TweenService:Create(ui.fill, TweenInfo.new(0.3), { Size = UDim2.fromScale((index - 1) / #STEPS, 1) }):Play()
	end

	local function finishAll()
		ui.header.Text = "TUTORIAL COMPLETE"
		ui.title.Text = "You're ready!"
		ui.title.TextColor3 = DONE_COLOR
		ui.body.Text = "The quests at the top of the screen show what to go for next."
		showKeys(ui, {})
		ui.skip.Visible = false
		TweenService:Create(ui.fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(1, 1) }):Play()
		close(3.5)
	end

	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == SKIP_KEY then
			close(0)
		elseif input.KeyCode == Enum.KeyCode.Space then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.FloorMaterial == Enum.Material.Air then
				pressed.AirJump = true
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and holdingGun() then
			pressed.Fire = true
		elseif input.KeyCode == Enum.KeyCode.R and holdingGun() then
			pressed.Reload = true
		end
	end))

	table.insert(connections, ui.skip.MouseButton1Click:Connect(function()
		close(0)
	end))

	table.insert(connections, player:GetAttributeChangedSignal("IsPlaying"):Connect(function()
		local step = STEPS[current]
		if step and not finished then ui.body.Text = stepText(step) end
	end))

	table.insert(connections, RunService.Heartbeat:Connect(function()
		if advancing or finished then return end
		local step = STEPS[current]
		if not step or not step.done(ctx, pressed) then return end

		-- tick the step, hold it a moment, then move on
		advancing = true
		ui.title.Text = "✓  " .. step.title
		ui.title.TextColor3 = DONE_COLOR
		FXUtil.PlaySoundAt("UIClick", SoundService)
		task.delay(STEP_PAUSE, function()
			advancing = false
			if finished then return end
			if current >= #STEPS then
				finishAll()
			else
				showStep(current + 1)
			end
		end)
	end))

	showStep(1)
end

function TutorialClient.Init()
	-- Waiting for the menu and the server must not hold up the other clients' Init.
	task.spawn(function()
		while player:GetAttribute("InMenu") ~= false do
			player:GetAttributeChangedSignal("InMenu"):Wait()
		end

		local forced = Workspace:GetAttribute("ForceTutorial") == true
		local ok, done = pcall(function()
			return TutorialRemotes.GetDoneFunction():InvokeServer()
		end)
		if not forced and (not ok or done) then return end

		run()
	end)
end

return TutorialClient
