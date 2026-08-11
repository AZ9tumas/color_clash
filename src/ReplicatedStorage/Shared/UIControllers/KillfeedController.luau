local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage.Shared
local RoundRemotes = require(Shared.Remotes.RoundRemotes)
local RoundConfig = require(Shared.Modules.Core.RoundConfig)
local UIAnimations = require(Shared.Modules.Utils.UIAnimations)
local Typewriter = require(Shared.Modules.Utils.Typewriter)
local FormatUtil = require(Shared.Modules.Utils.FormatUtil)
local FXUtil = require(Shared.Modules.Utils.FXUtil)

local KillFeedController = {}

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local MainHUD = PlayerGui:WaitForChild("MainHUD")

local DeathScreen = MainHUD:WaitForChild("DeathScreen")
local DeathMessage = DeathScreen:WaitForChild("Message")

-- Valorant kill feed. Built in code rather than cloned from a Template because the row is
-- not one label - it is killer / weapon / headshot / victim as separate runs of text, each
-- coloured from the viewer's own point of view, and every row has to size itself to
-- whatever names it happens to hold. Sits under the top bar on the right, newest on top.
local FEED_ANCHOR = UDim2.new(0.99, 0, 0.155, 0)
local ROW_HEIGHT = 26
local ROW_PADDING = 4
local MAX_ROWS = 5
local ROW_LIFETIME = 5

local SLIDE_IN = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SHIFT = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local ROW_BACKGROUND = Color3.fromRGB(17, 20, 24)
local ROW_TRANSPARENCY = 0.25
local INVOLVED_TRANSPARENCY = 0.1
local WEAPON_COLOR = Color3.fromRGB(232, 236, 240)
local NEUTRAL_COLOR = Color3.fromRGB(208, 214, 220)
local SELF_COLOR = Color3.fromRGB(255, 214, 102)
local HEADSHOT_COLOR = Color3.fromRGB(255, 70, 85)
local CASH_COLOR = Color3.fromRGB(126, 224, 142)

local feedContainer = nil
local rows = {}

-- Team colours are the round's own Red/Blue, lifted toward white so they stay legible on
-- the dark row. Off-team modes fall back to "you versus everyone", which is all the
-- relationship there is in a free-for-all.
local function nameColor(name, team)
	if name == player.Name then return SELF_COLOR end

	local mode = RoundConfig.GetActiveMode()
	if mode and mode.TeamBased and team then
		local base = RoundConfig.TeamColors[team]
		if base then return base:Lerp(Color3.new(1, 1, 1), 0.4) end
	end

	return NEUTRAL_COLOR
end

local function buildContainer()
	local container = Instance.new("Frame")
	container.Name = "ValorantKillFeed"
	container.AnchorPoint = Vector2.new(1, 0)
	container.Position = FEED_ANCHOR
	container.Size = UDim2.fromScale(0.45, 0.3)
	container.BackgroundTransparency = 1
	container.ClipsDescendants = false
	container.ZIndex = 4
	container.Parent = MainHUD
	return container
end

local function makeLabel(text, color, size, weight)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.Font = weight
	label.TextSize = size
	label.TextColor3 = color
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.ZIndex = 5

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.55
	stroke.Parent = label

	return label
end

-- Single owner of every row's Position, entry slide included. Re-targeting a row that is
-- still sliding is the whole point: kills land in bursts, and a row that kept animating to
-- the slot it was assigned on spawn would come to rest underneath the one that displaced
-- it.
local function layoutRows()
	for index, row in rows do
		local targetY = (index - 1) * (ROW_HEIGHT + ROW_PADDING)
		if row.y ~= targetY then
			-- Never placed yet means it is still off-screen right: snappier curve for the
			-- arrival, the softer one for rows just shuffling down.
			local info = row.y < 0 and SLIDE_IN or SHIFT
			row.y = targetY
			TweenService:Create(row.frame, info, { Position = UDim2.new(1, 0, 0, targetY) }):Play()
		end
	end
end

local function removeRow(row)
	local index = table.find(rows, row)
	if index then
		table.remove(rows, index)
		layoutRows()
	end

	if not row.frame.Parent then return end

	TweenService:Create(row.frame, FADE_OUT, { BackgroundTransparency = 1 }):Play()
	for _, label in row.labels do
		TweenService:Create(label, FADE_OUT, { TextTransparency = 1 }):Play()
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			TweenService:Create(stroke, FADE_OUT, { Transparency = 1 }):Play()
		end
	end
	task.delay(FADE_OUT.Time, function()
		row.frame:Destroy()
	end)
end

local function addRow(entry)
	local killerName = tostring(entry.Killer or "?")
	local victimName = tostring(entry.Victim or "?")
	local involved = (killerName == player.Name) or (victimName == player.Name)

	local frame = Instance.new("Frame")
	frame.Name = "KillRow"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = UDim2.new(1, 60, 0, 0)
	frame.Size = UDim2.new(0, 0, 0, ROW_HEIGHT)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ZIndex = 4

	-- Rows you are in sit brighter and team-tinted, the way Valorant lifts your own kills
	-- out of the stack. Mostly row colour still, or the names stop reading.
	local rowColor = ROW_BACKGROUND
	if involved then
		local myTeam = player:GetAttribute("Team")
		local tint = (myTeam and RoundConfig.TeamColors[myTeam]) or SELF_COLOR
		rowColor = tint:Lerp(ROW_BACKGROUND, 0.72)
	end
	frame.BackgroundColor3 = rowColor

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 7)
	layout.Parent = frame

	local labels = {}
	local function add(order, label)
		label.LayoutOrder = order
		label.Parent = frame
		table.insert(labels, label)
		return label
	end

	add(1, makeLabel(killerName, nameColor(killerName, entry.KillerTeam), 15, Enum.Font.GothamBold))
	add(2, makeLabel(string.upper(tostring(entry.Weapon or "?")), WEAPON_COLOR, 13, Enum.Font.GothamMedium))

	if entry.Headshot then
		add(3, makeLabel("HS", HEADSHOT_COLOR, 12, Enum.Font.GothamBold))
	end

	add(4, makeLabel(victimName, nameColor(victimName, entry.VictimTeam), 15, Enum.Font.GothamBold))

	-- The payout is the reason kills matter here, so your own rows state it. Only yours -
	-- what everyone else earned is not your business and would just be noise.
	if killerName == player.Name and type(entry.Reward) == "number" then
		add(5, makeLabel("+$" .. FormatUtil.Comma(entry.Reward), CASH_COLOR, 13, Enum.Font.GothamBold))
	end

	frame.Parent = feedContainer

	local row = { frame = frame, labels = labels, y = -1 }
	table.insert(rows, 1, row)

	while #rows > MAX_ROWS do
		removeRow(rows[#rows])
	end

	layoutRows()

	local targetTransparency = involved and INVOLVED_TRANSPARENCY or ROW_TRANSPARENCY
	TweenService:Create(frame, SLIDE_IN, { BackgroundTransparency = targetTransparency }):Play()

	task.delay(ROW_LIFETIME, function()
		if table.find(rows, row) then
			removeRow(row)
		end
	end)
end

local function getOrdinal(n)
	local suffix = "th"
	local mod10 = n % 10
	local mod100 = n % 100
	if mod10 == 1 and mod100 ~= 11 then suffix = "st"
	elseif mod10 == 2 and mod100 ~= 12 then suffix = "nd"
	elseif mod10 == 3 and mod100 ~= 13 then suffix = "rd" end
	return tostring(n) .. suffix
end

function KillFeedController.Init()
	UIAnimations.InitializePopObject(DeathScreen)
	DeathMessage.RichText = true

	-- The place file still carries the old single-line feed; it is replaced wholesale, so
	-- retire the frame rather than leave an empty box parked on the HUD.
	local legacyList = MainHUD:FindFirstChild("KillList")
	if legacyList then
		legacyList.Visible = false
	end

	feedContainer = buildContainer()

	RoundRemotes.GetKillFeedEvent().OnClientEvent:Connect(function(entry)
		if type(entry) ~= "table" then return end
		addRow(entry)
	end)

	RoundRemotes.GetDeathScreenEvent().OnClientEvent:Connect(function(killerName, weaponName, victimsCount, placement, reward, roundKills)
		-- The death screen is the one funnel every round outcome passes through, so the
		-- result stingers live here. -2 is the existing "won the round" sentinel; team
		-- losses and draws arrive as ProcessDeath with their reason in weaponName.
		if victimsCount == -2 then
			FXUtil.PlaySoundAt("Victory", SoundService)
		elseif weaponName == "Lost The Round" or weaponName == "Drew The Round" then
			FXUtil.PlaySoundAt("Defeat", SoundService)
		else
			FXUtil.PlaySoundAt("Eliminated", SoundService)
		end

		task.spawn(function()
			local deathReason = ""
			if victimsCount == -2 then
				deathReason = 'You survived and <b><font color="#FFD700">Won The Round!</font></b>'
			elseif victimsCount == -1 then
				deathReason = '<b><font color="#FF5555">' .. killerName .. '</font></b> eliminated you\nbecause you <b><font color="#FFB84D">' .. weaponName .. '</font></b>!'
			else
				deathReason = '<b><font color="#FF5555">' .. killerName .. '</font></b> killed you\nusing a <b><font color="#FFB84D">' .. weaponName .. '</font></b>! You\'re their <b><font color="#FF5555">' .. getOrdinal(victimsCount) .. '</font></b> victim!'
			end

			UIAnimations.PopIn(DeathScreen)
			Typewriter.Typewrite(DeathMessage, deathReason, 0.035)

			task.wait(1.5)
			UIAnimations.PopOut(DeathScreen)
			task.wait(0.35)

			local placeColor = "#ADD8E6"
			if placement == 1 then placeColor = "#FFD700"
			elseif placement == 2 then placeColor = "#C0C0C0"
			elseif placement == 3 then placeColor = "#CD7F32" end

			local placeStr = string.format('You placed <b><font color="%s">#%s</font></b>!\n', placeColor, getOrdinal(placement))

			UIAnimations.PopIn(DeathScreen)
			Typewriter.Typewrite(DeathMessage, placeStr, 0.04)
			task.wait(0.7)

			local function getStatsText(c, k, cColor, kColor)
				cColor = cColor or "#90EE90"
				kColor = kColor or "#87CEFA"
				local cStr = string.format('Reward: <b><font color="%s">$%s</font></b>\n', cColor, FormatUtil.Comma(c))
				local kStr = k >= 0 and string.format('Total Kills: <b><font color="%s">%s</font></b>', kColor, FormatUtil.Comma(k)) or ""
				return placeStr .. cStr .. kStr
			end

			Typewriter.CountUp(0, reward, 1.3, function(val)
				DeathMessage.Text = getStatsText(math.floor(val), -1)
			end)

			UIAnimations.PopText(DeathMessage)
			DeathMessage.Text = getStatsText(reward, -1, "#FFFFFF")
			task.wait(0.08)
			DeathMessage.Text = getStatsText(reward, -1, "#C0FFC0")
			task.wait(0.08)
			DeathMessage.Text = getStatsText(reward, -1)
			task.wait(0.7)

			Typewriter.CountUp(0, roundKills, 1.0, function(val)
				DeathMessage.Text = getStatsText(reward, math.floor(val))
			end)

			UIAnimations.PopText(DeathMessage)
			DeathMessage.Text = getStatsText(reward, roundKills, nil, "#FFFFFF")
			task.wait(0.08)
			DeathMessage.Text = getStatsText(reward, roundKills, nil, "#C0E8FF")
			task.wait(0.08)
			DeathMessage.Text = getStatsText(reward, roundKills)

			task.wait(3.5)
			UIAnimations.PopOut(DeathScreen)
		end)
	end)
end

return KillFeedController
