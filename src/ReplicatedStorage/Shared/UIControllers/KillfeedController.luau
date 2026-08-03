local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage.Shared
local RoundRemotes = require(Shared.Remotes.RoundRemotes)
local UIAnimations = require(Shared.Modules.Utils.UIAnimations)
local Typewriter = require(Shared.Modules.Utils.Typewriter)
local FormatUtil = require(Shared.Modules.Utils.FormatUtil)
local FXUtil = require(Shared.Modules.Utils.FXUtil)

local KillFeedController = {}

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local MainHUD = PlayerGui:WaitForChild("MainHUD")

local KillList = MainHUD:WaitForChild("KillList")
local KillTemplate = KillList:WaitForChild("Template")
local DeathScreen = MainHUD:WaitForChild("DeathScreen")
local DeathMessage = DeathScreen:WaitForChild("Message")

local killFeedData = {}
local PADDING = 5

local function updateKillFeedPositions()
	local killFeedHeight = KillTemplate.Size.Y.Offset
	if killFeedHeight <= 0 then killFeedHeight = KillTemplate.AbsoluteSize.Y end
	if killFeedHeight <= 0 then killFeedHeight = 50 end

	for i, data in ipairs(killFeedData) do
		data.targetY = -(i - 1) * (killFeedHeight + PADDING)
		TweenService:Create(data.frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(data.targetXScale, 0, 0, data.targetY)
		}):Play()
	end
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
	KillTemplate.Visible = false
	KillTemplate.Parent = script
	UIAnimations.InitializePopObject(DeathScreen)
	DeathMessage.RichText = true

	for _, child in KillList:GetChildren() do
		if child:IsA("GuiObject") or child:IsA("UIListLayout") then child:Destroy() end
	end

	RoundRemotes.GetKillFeedEvent().OnClientEvent:Connect(function(killerName, victimName)
		local clone = KillTemplate:Clone()
		clone.KillerName.Text = killerName
		clone.VictimName.Text = victimName
		clone.Visible = true
		clone.Position = UDim2.new(-1.2, 0, 0, 0)
		clone.Parent = KillList

		local data = {frame = clone, targetXScale = 0, targetY = 0}
		table.insert(killFeedData, 1, data)
		updateKillFeedPositions()

		task.delay(2.5, function()
			local index = table.find(killFeedData, data)
			if index then
				table.remove(killFeedData, index)
				updateKillFeedPositions()
			end
			if clone.Parent then
				local outTween = TweenService:Create(clone, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.new(-1.2, 0, 0, clone.Position.Y.Offset)
				})
				outTween:Play()
				outTween.Completed:Connect(function() clone:Destroy() end)
			end
		end)
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