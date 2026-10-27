local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local QuestConfig = require(Shared.Modules.Core.QuestConfig)
local QuestRemotes = require(Shared.Remotes.QuestRemotes)

-- A slim bar at the top of the screen listing the unfinished quests closest to
-- done, with their progress, so players don't have to open the Rewards menu to
-- know what to go for. Updates live from QuestServer's QuestUpdated pushes.
local QuestTrackerController = {}

local player = Players.LocalPlayer

local MAX_SHOWN = 3
-- Quests that depend on other people go after everything the player can do alone.
local SOCIAL_STATS = { FriendPlays = true }

local FONT = Font.fromName("Rubik", Enum.FontWeight.ExtraBold)
local PILL_COLOR = Color3.fromRGB(24, 24, 28)
local TRACK_COLOR = Color3.fromRGB(70, 70, 78)
local FILL_COLOR = Color3.fromRGB(255, 205, 60)
local DONE_COLOR = Color3.fromRGB(120, 235, 140)

local questState = { Stats = {}, Completed = {} }
local shownProgress = {} -- [questId] = progress last drawn, to pulse on change
local bar: Frame? = nil
local celebrating = false

local function progressOf(quest): number
	local stats = questState.Stats or {}
	return math.min(stats[quest.Stat] or 0, quest.Goal)
end

-- Unfinished quests, closest to done first; ties keep QuestConfig.Order.
local function questsToShow()
	local completed = questState.Completed or {}
	local list = {}
	for index, id in ipairs(QuestConfig.Order or {}) do
		local quest = QuestConfig.Quests[id]
		if quest and not completed[id] then
			table.insert(list, {
				id = id,
				quest = quest,
				index = index,
				fraction = progressOf(quest) / math.max(quest.Goal, 1),
				social = SOCIAL_STATS[quest.Stat] == true,
			})
		end
	end
	table.sort(list, function(a, b)
		if a.social ~= b.social then return not a.social end
		if a.fraction ~= b.fraction then return a.fraction > b.fraction end
		return a.index < b.index
	end)
	local shown = {}
	for i = 1, math.min(MAX_SHOWN, #list) do
		shown[i] = list[i]
	end
	return shown
end

local function makePill(name: string, countText: string, fraction: number, color: Color3?): Frame
	-- Sized from its text row below rather than AutomaticSize: the progress line
	-- is sized relative to the pill, which made an auto-sized pill keep growing.
	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromOffset(0, 28)
	pill.BackgroundColor3 = PILL_COLOR
	pill.BackgroundTransparency = 0.25

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = pill

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = pill

	local row = Instance.new("Frame")
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.new(0, 0, 1, -4)
	row.BackgroundTransparency = 1
	row.Parent = pill

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local title = Instance.new("TextLabel")
	title.LayoutOrder = 1
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Size = UDim2.new(0, 0, 1, 0)
	title.BackgroundTransparency = 1
	title.FontFace = FONT
	title.TextSize = 14
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Text = name
	title.Parent = row

	local count = Instance.new("TextLabel")
	count.LayoutOrder = 2
	count.AutomaticSize = Enum.AutomaticSize.X
	count.Size = UDim2.new(0, 0, 1, 0)
	count.BackgroundTransparency = 1
	count.FontFace = FONT
	count.TextSize = 14
	count.TextColor3 = color or FILL_COLOR
	count.Text = countText
	count.Parent = row

	-- thin progress line along the bottom of the pill
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.new(0, 0, 1, -3)
	track.Size = UDim2.new(1, 0, 0, 3)
	track.BackgroundColor3 = TRACK_COLOR
	track.BorderSizePixel = 0
	track.Parent = pill

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	fill.BackgroundColor3 = color or FILL_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = track

	for _, bit in { track, fill } do
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = bit
	end

	local function fitToText()
		pill.Size = UDim2.fromOffset(row.AbsoluteSize.X + 20, 28)
	end
	row:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToText)
	fitToText()

	return pill
end

local function pulse(pill: Frame)
	local scale = Instance.new("UIScale")
	scale.Scale = 1.12
	scale.Parent = pill
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function clearPills()
	if not bar then return end
	for _, child in bar:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end
end

local function render()
	if not bar or celebrating then return end
	clearPills()

	local shown = questsToShow()
	for order, entry in shown do
		local progress = progressOf(entry.quest)
		local pill = makePill(entry.quest.Name, string.format("%d/%d", progress, entry.quest.Goal), entry.fraction)
		pill.LayoutOrder = order
		pill.Parent = bar
		if shownProgress[entry.id] and progress > shownProgress[entry.id] then
			pulse(pill)
		end
		shownProgress[entry.id] = progress
	end
end

local function updateVisibility()
	if not bar then return end
	local hasQuests = #questsToShow() > 0 or celebrating
	bar.Visible = player:GetAttribute("InMenu") == false and hasQuests
end

-- A quest that just finished stays on the bar briefly, in green, before the
-- next one takes its place.
local function celebrate(quests)
	if not bar then return end
	celebrating = true
	clearPills()
	for order, quest in quests do
		local pill = makePill(quest.Name, "Complete!", 1, DONE_COLOR)
		pill.LayoutOrder = order
		pill.Parent = bar
		pulse(pill)
	end
	updateVisibility()
	task.delay(2.5, function()
		celebrating = false
		render()
		updateVisibility()
	end)
end

local function applyState(state)
	if type(state) ~= "table" then return end
	local before = questState.Completed or {}
	questState = { Stats = state.Stats or {}, Completed = state.Completed or {} }

	local finished = {}
	for _, id in ipairs(QuestConfig.Order or {}) do
		if questState.Completed[id] and not before[id] and shownProgress[id] ~= nil then
			table.insert(finished, QuestConfig.Quests[id])
		end
	end

	if #finished > 0 then
		celebrate(finished)
	else
		render()
		updateVisibility()
	end
end

local function buildBar()
	local gui = Instance.new("ScreenGui")
	gui.Name = "QuestTracker"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Sits under the round's top strip (timer and player icons) and above the
	-- centre message line.
	local frame = Instance.new("Frame")
	frame.Name = "Bar"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0.095, 0)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.Size = UDim2.fromOffset(0, 28)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.LayoutOrder = 0
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, 28)
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextSize = 13
	label.TextColor3 = FILL_COLOR
	label.Text = "QUESTS"
	label.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(20, 20, 24)
	stroke.Parent = label

	return frame
end

function QuestTrackerController.Init()
	bar = buildBar()

	QuestRemotes.GetUpdatedEvent().OnClientEvent:Connect(applyState)
	player:GetAttributeChangedSignal("InMenu"):Connect(updateVisibility)

	task.spawn(function()
		local ok, state = pcall(function()
			return QuestRemotes.GetStateFunction():InvokeServer()
		end)
		if ok and type(state) == "table" then
			questState = { Stats = state.Stats or {}, Completed = state.Completed or {} }
		end
		render()
		updateVisibility()
	end)
end

return QuestTrackerController
