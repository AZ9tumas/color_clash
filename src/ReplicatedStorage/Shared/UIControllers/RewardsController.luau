local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local DailyRewardConfig = require(Shared.Modules.Core.DailyRewardConfig)
local QuestConfig = require(Shared.Modules.Core.QuestConfig)
local DailyRewardRemotes = require(Shared.Remotes.DailyRewardRemotes)
local QuestRemotes = require(Shared.Remotes.QuestRemotes)
local FormatUtil = require(Shared.Modules.Utils.FormatUtil)
local UIAnimations = require(Shared.Modules.Utils.UIAnimations)

local RewardsController = {}

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local RewardsGui = PlayerGui:WaitForChild("Rewards")
local RewardsFrame = RewardsGui:WaitForChild("Frame")
local CategoryFrame = RewardsFrame:WaitForChild("Category")
local CategoryScroll = CategoryFrame:WaitForChild("ScrollingFrame")
local MainFrame = RewardsFrame:WaitForChild("MainFrame")
local Container = MainFrame:WaitForChild("Container")
local SectionTemplate = Container:WaitForChild("Section")
local ItemTemplate = Container:WaitForChild("Template")

local tabsData = {
	DailyRewards = {
		UI = CategoryScroll:WaitForChild("DailyRewards"),
		UnselectedSize = UDim2.new(0.15, 0, 0.116, 0),
		SelectedSize = UDim2.new(1, 0, 0.116, 0),
	},
	Quests = {
		UI = CategoryScroll:WaitForChild("Quests"),
		UnselectedSize = UDim2.new(0.15, 0, 0.116, 0),
		SelectedSize = UDim2.new(1, 0, 0.116, 0),
	},
}

local currentCategory
local isSwitching = false
local isFirstLoad = true
local renderVersion = 0
local originalSectionPosition
local originalItemPosition
local dailyState
local questState = { Stats = {}, Completed = {} }
local dailyCountdownButton
local renderCategory

local function invoke(remote, ...)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if ok then return result end
	return nil
end

local function formatDuration(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remaining = seconds % 60
	return string.format("%02d:%02d:%02d", hours, minutes, remaining)
end

local function rewardText(reward)
	local parts = {}
	if reward.Cash then
		table.insert(parts, "$" .. FormatUtil.Comma(reward.Cash) .. " Cash")
	end
	if reward.Weapon then
		table.insert(parts, reward.Weapon)
	end
	return table.concat(parts, " + ")
end

local function setButtonGradient(button, gradientName, animate)
	local target = button:FindFirstChild(gradientName)
	if not target then return end

	for _, child in button:GetChildren() do
		if child:IsA("UIGradient") and child ~= target then
			child.Enabled = false
		end
	end

	target.Enabled = true
	if animate then
		target.Offset = Vector2.new(-1, 0)
		TweenService:Create(target, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Offset = Vector2.new(0, 0) }):Play()
	else
		target.Offset = Vector2.new(0, 0)
	end
end

local function updateTabVisuals(activeName)
	local normal = Color3.fromRGB(200, 200, 200)
	local selected = Color3.fromRGB(255, 255, 255)
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

	for name, data in pairs(tabsData) do
		local title = data.UI.btn.Title
		local underline = title.Frame
		local active = name == activeName
		TweenService:Create(underline, info, {
			Size = active and data.SelectedSize or data.UnselectedSize,
			Position = UDim2.new(0.5, 0, 1, 0),
			BackgroundColor3 = active and selected or normal,
		}):Play()
		TweenService:Create(title, info, { TextColor3 = active and selected or normal }):Play()
	end
end

local function clearGenerated(animate)
	dailyCountdownButton = nil
	local outInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	if animate then
		for _, child in Container:GetChildren() do
			if child.Name == "RewardsItem" then
				local scale = child.Frame:FindFirstChildOfClass("UIScale")
				if scale then TweenService:Create(scale, outInfo, { Scale = 0 }):Play() end
			elseif child.Name == "RewardsSection" then
				TweenService:Create(child.Frame, outInfo, {
					Position = UDim2.new(1.5, 0, originalSectionPosition.Y.Scale, originalSectionPosition.Y.Offset),
				}):Play()
			end
		end
		task.wait(0.2)
	end

	for _, child in Container:GetChildren() do
		if child.Name == "RewardsItem" or child.Name == "RewardsSection" then
			child:Destroy()
		end
	end
end

local function addSection(titleText, layoutOrder)
	local clone = SectionTemplate:Clone()
	clone.Name = "RewardsSection"
	clone.LayoutOrder = layoutOrder
	clone.ZIndex = layoutOrder
	clone.Frame.Title.Text = titleText
	clone.Frame.Position = UDim2.new(-1.5, 0, originalSectionPosition.Y.Scale, originalSectionPosition.Y.Offset)
	clone.Visible = true
	clone.Parent = Container

	TweenService:Create(clone.Frame, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = originalSectionPosition,
	}):Play()

	return layoutOrder + 1
end

local function addItem(titleText, descriptionText, layoutOrder)
	local clone = ItemTemplate:Clone()
	clone.Name = "RewardsItem"
	clone.LayoutOrder = layoutOrder
	clone.ZIndex = layoutOrder
	clone.Frame.Title.Text = titleText
	clone.Frame.Description.Text = descriptionText
	clone.Frame.Position = originalItemPosition

	local scale = clone.Frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = clone.Frame
	scale.Scale = 0

	local button = clone.Frame.BuyButtons.btn
	UIAnimations.BindButtonAnimations(button)

	clone.Visible = true
	clone.Parent = Container
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	return clone, button, layoutOrder + 1
end

local function configureButton(button, text, gradientName, enabled, animate)
	button.Price.Text = text
	button.Interactable = enabled
	button.Active = enabled
	setButtonGradient(button, gradientName, animate)
end

local function buildDailyRewards(layoutOrder)
	layoutOrder = addSection("Daily Rewards", layoutOrder)
	local rewards = dailyState and dailyState.Rewards or DailyRewardConfig.Rewards
	local count = #rewards
	local completedInCycle = count > 0 and ((dailyState and dailyState.Streak or 0) % count) or 0

	for index, reward in ipairs(rewards) do
		local _, button
		_, button, layoutOrder = addItem(reward.Name or ("Day " .. index), rewardText(reward), layoutOrder)
		local isCurrent = dailyState and index == dailyState.Day
		local isCompleted = index <= completedInCycle
		local canClaim = isCurrent and dailyState.CanClaim == true

		if canClaim then
			configureButton(button, "Claim", "Equip", true, false)
			local processing = false
			button.MouseButton1Click:Connect(function()
				if processing then return end
				processing = true
				configureButton(button, "Claiming", "Equip", false, true)
				task.spawn(function()
					local result = invoke(DailyRewardRemotes.GetClaimFunction())
					if result and result.Claimed then
						dailyState = invoke(DailyRewardRemotes.GetStateFunction()) or dailyState
					else
						configureButton(button, "Try Again", "Failed", false, true)
						task.wait(0.8)
						dailyState = invoke(DailyRewardRemotes.GetStateFunction()) or dailyState
					end
					processing = false
					if currentCategory == "DailyRewards" then renderCategory("DailyRewards", true, true) end
				end)
			end)
		elseif isCompleted then
			configureButton(button, "Claimed", "Equipped", false, false)
		elseif isCurrent then
			configureButton(button, formatDuration(dailyState.SecondsUntilReset), "Equipped", false, false)
			dailyCountdownButton = button
		else
			configureButton(button, "Upcoming", "Purchase", false, false)
		end

		task.wait(0.04)
	end
end

local function buildQuests(layoutOrder)
	layoutOrder = addSection("Quests", layoutOrder)
	local stats = questState.Stats or {}
	local completed = questState.Completed or {}
	local order = QuestConfig.Order or {}

	for _, id in ipairs(order) do
		local quest = QuestConfig.Quests[id]
		if quest then
			local progress = math.min(stats[quest.Stat] or 0, quest.Goal)
			local description = rewardText(quest.Reward) .. "\nProgress: " .. progress .. " / " .. quest.Goal
			local _, button
			_, button, layoutOrder = addItem(quest.Name, description, layoutOrder)
			if completed[id] then
				configureButton(button, "Completed", "Equipped", false, false)
			else
				configureButton(button, progress .. " / " .. quest.Goal, "Purchase", false, false)
			end
			task.wait(0.04)
		end
	end
end

renderCategory = function(categoryName, force, useCachedState)
	if isSwitching and not force then return end
	if currentCategory == categoryName and not force then return end

	renderVersion += 1
	local version = renderVersion
	currentCategory = categoryName
	isSwitching = true
	updateTabVisuals(categoryName)

	task.spawn(function()
		clearGenerated(not isFirstLoad)
		if version ~= renderVersion then return end

		if categoryName == "DailyRewards" and not useCachedState then
			dailyState = invoke(DailyRewardRemotes.GetStateFunction()) or dailyState or {
				CanClaim = false,
				Streak = 0,
				Day = 1,
				SecondsUntilReset = 0,
				Rewards = DailyRewardConfig.Rewards,
			}
		elseif categoryName == "Quests" and not useCachedState then
			questState = invoke(QuestRemotes.GetStateFunction()) or questState
		end

		if version ~= renderVersion then return end
		Container.CanvasPosition = Vector2.zero
		local layoutOrder = 1
		if categoryName == "DailyRewards" then
			buildDailyRewards(layoutOrder)
		else
			buildQuests(layoutOrder)
		end

		isFirstLoad = false
		isSwitching = false
	end)
end

function RewardsController.Init()
	SectionTemplate.Visible = false
	ItemTemplate.Visible = false
	originalSectionPosition = SectionTemplate.Frame.Position
	originalItemPosition = ItemTemplate.Frame.Position

	for name, data in pairs(tabsData) do
		data.UI.btn.MouseButton1Click:Connect(function()
			renderCategory(name, false)
		end)
	end

	QuestRemotes.GetUpdatedEvent().OnClientEvent:Connect(function(state)
		if type(state) ~= "table" then return end
		questState = state
		if currentCategory == "Quests" and not isSwitching then
			renderCategory("Quests", true, true)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if dailyState and dailyState.CanClaim == false then
				dailyState.SecondsUntilReset = math.max(0, (dailyState.SecondsUntilReset or 0) - 1)
				if dailyCountdownButton and dailyCountdownButton.Parent then
					dailyCountdownButton.Price.Text = formatDuration(dailyState.SecondsUntilReset)
				end
				if dailyState.SecondsUntilReset <= 0 then
					dailyState = invoke(DailyRewardRemotes.GetStateFunction()) or dailyState
					if currentCategory == "DailyRewards" then renderCategory("DailyRewards", true, true) end
				end
			end
		end
	end)

	renderCategory("DailyRewards", true)
end

return RewardsController
