-- Studio-only gun picker, styled to match the round timer panel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Controller = {}
local initialized = false
local COLORS = {
	panel = Color3.fromRGB(19, 22, 29),
	header = Color3.fromRGB(26, 31, 41),
	text = Color3.fromRGB(242, 245, 250),
	muted = Color3.fromRGB(154, 164, 181),
	green = Color3.fromRGB(55, 196, 122),
	owned = Color3.fromRGB(31, 57, 44),
	stroke = Color3.fromRGB(58, 67, 83),
}

local function make(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in properties do instance[key] = value end
	instance.Parent = parent
	return instance
end

local function corner(parent, radius)
	make("UICorner", {CornerRadius = UDim.new(0, radius)}, parent)
end

function Controller.Init()
	if not RunService:IsStudio() or initialized then return end
	initialized = true
	local player = Players.LocalPlayer
	local shared = ReplicatedStorage.Shared
	local items = require(shared.Modules.Core.Items)
	local remote = shared.Remotes:WaitForChild("StudioGiveGun", 10)
	if not remote then return end
	local playerGui = player:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("StudioGunPicker")
	if old then old:Destroy() end

	local gui = make("ScreenGui", {
		Name = "StudioGunPicker", DisplayOrder = 1001,
		IgnoreGuiInset = true, ResetOnSpawn = false,
	}, playerGui)
	local panel = make("Frame", {
		Name = "Panel", Active = true, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 228), Size = UDim2.fromOffset(244, 42),
		BackgroundColor3 = COLORS.panel, BorderSizePixel = 0,
	}, gui)
	corner(panel, 12)
	make("UIStroke", {Color = COLORS.stroke, Transparency = 0.15}, panel)
	local header = make("Frame", {
		Name = "Header", Active = true, Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = COLORS.header, BorderSizePixel = 0,
	}, panel)
	corner(header, 12)
	make("TextLabel", {
		Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(115, 18),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
		Text = "GUN PICKER", TextSize = 15, TextColor3 = COLORS.text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)
	make("TextLabel", {
		Position = UDim2.fromOffset(14, 24), Size = UDim2.fromOffset(115, 12),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham,
		Text = "DRAG TO MOVE", TextSize = 10, TextColor3 = COLORS.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)
	local toggle = make("TextButton", {
		Name = "Toggle", AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(84, 28),
		BackgroundColor3 = COLORS.green, BorderSizePixel = 0,
		Font = Enum.Font.GothamBold, TextSize = 11,
		Text = "G · OPEN", TextColor3 = COLORS.panel,
	}, header)
	corner(toggle, 7)
	local content = make("ScrollingFrame", {
		Name = "Guns", Position = UDim2.fromOffset(14, 54),
		Size = UDim2.new(1, -28, 0, 142), BackgroundTransparency = 1,
		BorderSizePixel = 0, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 2,
		Visible = false,
	}, panel)
	make("UIGridLayout", {
		CellSize = UDim2.new(0.5, -4, 0, 42), CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, content)
	local status = make("TextLabel", {
		Name = "Status", Position = UDim2.fromOffset(14, 204),
		Size = UDim2.new(1, -28, 0, 28), BackgroundTransparency = 1,
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = COLORS.muted,
		Text = "Click a gun to add it.", TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, Visible = false,
	}, panel)

	local open, busy = false, false
	local buttons = {}
	local function hasGun(name)
		for _, container in {player:FindFirstChildOfClass("Backpack"), player.Character} do
			if container then
				for _, item in container:GetChildren() do
					if item:IsA("Tool") and item.Name == name then return true end
				end
			end
		end
		return false
	end
	local function render()
		for name, button in buttons do
			local owned = hasGun(name)
			button.Text = name .. (owned and "  ·  OWNED" or "  +")
			button.TextColor3 = owned and COLORS.green or COLORS.text
			button.BackgroundColor3 = owned and COLORS.owned or COLORS.header
			button.AutoButtonColor = not owned and not busy
		end
	end
	local function setOpen(value)
		open = value
		panel.Size = UDim2.fromOffset(244, open and 244 or 42)
		content.Visible = open
		status.Visible = open
		toggle.Text = open and "G · CLOSE" or "G · OPEN"
		-- Roblox's modal button releases the first-person mouse lock while open.
		toggle.Modal = open
		render()
	end
	toggle.Activated:Connect(function() setOpen(not open) end)

	local names = {}
	for _, template in shared.Assets.Weapons:GetChildren() do
		local data = items[template.Name]
		if template:IsA("Tool") and data and type(data.MaxAmmo) == "number" then
			table.insert(names, template.Name)
		end
	end
	table.sort(names)
	for order, name in names do
		local button = make("TextButton", {
			Name = name, LayoutOrder = order, BackgroundColor3 = COLORS.header,
			BorderSizePixel = 0, Font = Enum.Font.GothamMedium, TextSize = 12,
			TextColor3 = COLORS.text, Text = name .. "  +",
		}, content)
		corner(button, 8)
		buttons[name] = button
		button.Activated:Connect(function()
			if busy then return end
			if hasGun(name) then status.Text = "Already have " .. name; return end
			busy = true
			status.Text = "Adding " .. name .. "..."
			render()
			local ok, accepted, message = pcall(function() return remote:InvokeServer(name) end)
			status.Text = ok and message or "Could not add gun. Try again."
			status.TextColor3 = ok and accepted and COLORS.green or COLORS.muted
			busy = false
			render()
		end)
	end

	local backpackConnections, characterConnections = {}, {}
	local function watch(container, connections)
		for _, connection in connections do connection:Disconnect() end
		table.clear(connections)
		if container then
			table.insert(connections, container.ChildAdded:Connect(function() task.defer(render) end))
			table.insert(connections, container.ChildRemoved:Connect(function() task.defer(render) end))
		end
		task.defer(render)
	end
	watch(player:FindFirstChildOfClass("Backpack"), backpackConnections)
	watch(player.Character, characterConnections)
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then watch(child, backpackConnections) end
	end)
	player.CharacterAdded:Connect(function(character)
		watch(character, characterConnections)
		setOpen(false)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.G then setOpen(not open) end
	end)

	local dragStart, startPosition
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragStart, startPosition = input.Position, panel.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragStart = nil end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragStart then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local delta = input.Position - dragStart
		panel.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
	end)
	setOpen(false)
end

return Controller
