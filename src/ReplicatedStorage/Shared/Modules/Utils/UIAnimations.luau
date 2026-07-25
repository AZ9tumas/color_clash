local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SettingsController = require(ReplicatedStorage.Shared.UIControllers.SettingsController)

local UIAnimations = {}
local originalPositions: {[GuiObject]: UDim2} = {}

local function getTweenInfo(duration, style, direction)
	if SettingsController.GetValue("Reduce Motion") then
		return TweenInfo.new(0.01, style, direction)
	end
	return TweenInfo.new(duration, style, direction)
end

function UIAnimations.BindButtonAnimations(button: Instance)
	if not button:IsA("GuiButton") then return end

	local uiScale = button:FindFirstChild("UIScale") :: UIScale?
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = button
	end

	button.MouseEnter:Connect(function()
		if uiScale then
			TweenService:Create(uiScale, getTweenInfo(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
		end
	end)

	button.MouseLeave:Connect(function()
		if uiScale then
			TweenService:Create(uiScale, getTweenInfo(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
		end
	end)
end

function UIAnimations.InitializePopObject(guiObject: GuiObject)
	if not originalPositions[guiObject] then
		originalPositions[guiObject] = guiObject.Position
		guiObject.Position = UDim2.new(guiObject.Position.X.Scale, guiObject.Position.X.Offset, 1.5, 0)
		guiObject.Visible = false
	end
end

function UIAnimations.PopIn(guiObject: GuiObject, disableSound: boolean?)
	local targetPos = originalPositions[guiObject]
	if not targetPos then return end

	guiObject.Visible = true
	TweenService:Create(guiObject, getTweenInfo(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetPos}):Play()
end

function UIAnimations.PopOut(guiObject: GuiObject, disableSound: boolean?)
	local originalPos = originalPositions[guiObject]
	if not originalPos then return end

	local hiddenPos = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, 1.5, 0)
	local tween = TweenService:Create(guiObject, getTweenInfo(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = hiddenPos})

	tween.Completed:Connect(function()
		if guiObject.Position == hiddenPos then
			guiObject.Visible = false
		end
	end)

	tween:Play()
end

function UIAnimations.SlideIn(guiObject: GuiObject)
	local targetPos = originalPositions[guiObject]
	if not targetPos then return end

	guiObject.Visible = true
	TweenService:Create(guiObject, getTweenInfo(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetPos}):Play()
end

function UIAnimations.SlideOut(guiObject: GuiObject)
	local originalPos = originalPositions[guiObject]
	if not originalPos then return end

	local hiddenPos = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, 1.5, 0)
	local tween = TweenService:Create(guiObject, getTweenInfo(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = hiddenPos})

	tween.Completed:Connect(function()
		if guiObject.Position == hiddenPos then
			guiObject.Visible = false
		end
	end)

	tween:Play()
end

function UIAnimations.InitializePopFromTop(guiObject: GuiObject)
	if not originalPositions[guiObject] then
		originalPositions[guiObject] = guiObject.Position
		guiObject.Position = UDim2.new(guiObject.Position.X.Scale, guiObject.Position.X.Offset, -1.5, 0)
		guiObject.Visible = false
	end
end

function UIAnimations.PopInFromTop(guiObject: GuiObject, disableSound: boolean?)
	local targetPos = originalPositions[guiObject]
	if not targetPos then return end

	guiObject.Visible = true
	TweenService:Create(guiObject, getTweenInfo(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetPos}):Play()
end

function UIAnimations.PopOutToTop(guiObject: GuiObject, disableSound: boolean?)
	local originalPos = originalPositions[guiObject]
	if not originalPos then return end

	local hiddenPos = UDim2.new(originalPos.X.Scale, originalPos.X.Offset, -1.5, 0)
	local tween = TweenService:Create(guiObject, getTweenInfo(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = hiddenPos})

	tween.Completed:Connect(function()
		if guiObject.Position == hiddenPos then
			guiObject.Visible = false
		end
	end)

	tween:Play()
end

function UIAnimations.PopText(textLabel: TextLabel)
	local uiScale = textLabel:FindFirstChild("UIScale") :: UIScale?
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = textLabel
	end

	uiScale.Scale = 1.15
	TweenService:Create(uiScale, getTweenInfo(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

function UIAnimations.FadeText(guiObject: GuiObject, isVisible: boolean, duration: number)
	local targetTrans = isVisible and 0 or 1

	if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") then
		TweenService:Create(guiObject, getTweenInfo(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = targetTrans, TextStrokeTransparency = targetTrans}):Play()
	end

	for _, child in ipairs(guiObject:GetChildren()) do
		if child:IsA("UIStroke") then
			TweenService:Create(child, getTweenInfo(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = targetTrans}):Play()
		end
	end
end

function UIAnimations.PromptPopAndShake(guiObject: GuiObject)
	local uiScale = guiObject:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = guiObject
	end

	uiScale.Scale = 0
	guiObject.Rotation = 15

	TweenService:Create(uiScale, getTweenInfo(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
	TweenService:Create(guiObject, getTweenInfo(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Rotation = 0}):Play()
end

function UIAnimations.PromptFadeOut(guiObject: GuiObject)
	local uiScale = guiObject:FindFirstChildOfClass("UIScale")
	if uiScale then
		TweenService:Create(uiScale, getTweenInfo(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0}):Play()
	end
	TweenService:Create(guiObject, getTweenInfo(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Rotation = -12}):Play()
end

return UIAnimations