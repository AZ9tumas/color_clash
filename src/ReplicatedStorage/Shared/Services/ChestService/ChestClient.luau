local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ChestConfig = require(Shared.Modules.Core.ChestConfig)
local ChestRemotes = require(Shared.Remotes.ChestRemotes)
local FXUtil = require(Shared.Modules.Utils.FXUtil)

-- This player's view of the daily chests: the "Open Chest" prompt only while a
-- chest is ready, otherwise a countdown floating above it, and a coin popup
-- when one is opened. ChestServer decides; this only displays.
local ChestClient = {}

local player = Players.LocalPlayer
local FONT = Font.fromName("Rubik", Enum.FontWeight.ExtraBold)
local READY_COLOR = Color3.fromRGB(120, 235, 140)
local LOCKED_COLOR = Color3.fromRGB(215, 215, 222)
local COIN_COLOR = Color3.fromRGB(255, 205, 60)

-- [ChestId] = { prompt, label, readyAt (os.clock) }
local chests = {}

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	if hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	end
	if minutes > 0 then
		return string.format("%dm %02ds", minutes, seconds % 60)
	end
	return string.format("%ds", seconds)
end

local function buildTimer(chest: Model): TextLabel
	local root = chest.PrimaryPart
	local boxCFrame, boxSize = chest:GetBoundingBox()
	local top = boxCFrame.Position.Y + boxSize.Y / 2

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ChestTimer"
	billboard.Adornee = root
	billboard.Size = UDim2.fromOffset(190, 34)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, top - root.Position.Y + 1.4, 0)
	billboard.MaxDistance = 80
	billboard.LightInfluence = 0
	billboard.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
	label.BackgroundTransparency = 0.3
	label.FontFace = FONT
	label.TextSize = 17
	label.TextColor3 = LOCKED_COLOR
	label.Text = ""
	label.Visible = false
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	billboard.Parent = player:WaitForChild("PlayerGui")
	return label
end

local function refresh()
	local now = os.clock()
	for _, entry in chests do
		if entry.readyAt then
			local left = entry.readyAt - now
			local ready = left <= 0
			-- Local only: other players still see their own state of this chest.
			if entry.prompt then entry.prompt.Enabled = ready end
			entry.label.Visible = true
			entry.label.TextColor3 = ready and READY_COLOR or LOCKED_COLOR
			entry.label.Text = ready and "Ready to open!" or ("Opens in " .. formatTime(left))
		end
	end
end

local function applyState(state)
	if type(state) ~= "table" then return end
	local now = os.clock()
	for id, left in state do
		local entry = chests[id]
		if entry and type(left) == "number" then
			entry.readyAt = now + left
		end
	end
	refresh()
end

local function showReward(coins: number, chestName: string)
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChestReward"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.32)
	holder.Size = UDim2.fromOffset(360, 90)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder

	local amount = Instance.new("TextLabel")
	amount.Size = UDim2.new(1, 0, 0, 52)
	amount.BackgroundTransparency = 1
	amount.FontFace = FONT
	amount.TextSize = 46
	amount.TextColor3 = COIN_COLOR
	amount.Text = string.format("+%d COINS", coins)
	amount.Parent = holder

	local amountStroke = Instance.new("UIStroke")
	amountStroke.Thickness = 3
	amountStroke.Color = Color3.fromRGB(70, 45, 0)
	amountStroke.Parent = amount

	local source = Instance.new("TextLabel")
	source.Position = UDim2.fromOffset(0, 54)
	source.Size = UDim2.new(1, 0, 0, 24)
	source.BackgroundTransparency = 1
	source.FontFace = FONT
	source.TextSize = 20
	source.TextColor3 = Color3.new(1, 1, 1)
	source.Text = chestName .. " opened  ·  back in 24h"
	source.Parent = holder

	local sourceStroke = Instance.new("UIStroke")
	sourceStroke.Thickness = 2
	sourceStroke.Color = Color3.fromRGB(20, 20, 24)
	sourceStroke.Parent = source

	gui.Parent = player:WaitForChild("PlayerGui")
	FXUtil.PlaySoundAt("UIClick", SoundService)

	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.8, function()
		local fade = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(holder, fade, { Position = UDim2.fromScale(0.5, 0.26) }):Play()
		for _, label in { amount, source } do
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		end
		for _, stroke in { amountStroke, sourceStroke } do
			TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		end
		task.delay(0.65, function() gui:Destroy() end)
	end)
end

function ChestClient.Init()
	ChestRemotes.GetOpenedEvent().OnClientEvent:Connect(function(result)
		if type(result) ~= "table" or type(result.ChestId) ~= "string" then return end
		local entry = chests[result.ChestId]
		if entry and type(result.SecondsLeft) == "number" then
			entry.readyAt = os.clock() + result.SecondsLeft
			refresh()
		end
		if type(result.Coins) == "number" then
			showReward(result.Coins, ChestConfig.For(result.ChestId).DisplayName)
		end
	end)

	-- Waiting on the chests and the server must not hold up the other clients' Init.
	task.spawn(function()
		local folder = Workspace:WaitForChild("Chests", 30)
		if not folder then return end

		for _, chest in folder:GetChildren() do
			if chest:IsA("Model") and chest.PrimaryPart then
				local id = chest:GetAttribute("ChestId") or chest.Name
				chests[id] = {
					prompt = chest.PrimaryPart:WaitForChild("ChestPrompt", 10),
					label = buildTimer(chest),
					readyAt = nil,
				}
			end
		end

		local ok, state = pcall(function()
			return ChestRemotes.GetStateFunction():InvokeServer()
		end)
		if ok then applyState(state) end

		while true do
			task.wait(1)
			refresh()
		end
	end)
end

return ChestClient
