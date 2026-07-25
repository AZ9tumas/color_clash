local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local PromptController = {}

local player = Players.LocalPlayer

function PromptController.Init()
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Default then return end

		local customRubikBold = Font.fromName("Rubik", Enum.FontWeight.ExtraBold)

		local promptGui = Instance.new("BillboardGui")
		promptGui.Name = "CustomPrompt"
		promptGui.Size = UDim2.fromOffset(245, 72)
		promptGui.StudsOffset = Vector3.new(0, 2.8, 0)
		promptGui.AlwaysOnTop = true
		promptGui.Adornee = prompt.Parent

		local holder = Instance.new("Frame")
		holder.Size = UDim2.fromScale(1, 1)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.BackgroundTransparency = 1
		holder.Rotation = 15
		holder.Parent = promptGui

		local uiScale = Instance.new("UIScale")
		uiScale.Scale = 0
		uiScale.Parent = holder

		TweenService:Create(uiScale, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
		TweenService:Create(holder, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Rotation = 0}):Play()

		local background = Instance.new("Frame")
		background.Size = UDim2.fromScale(1, 1)
		background.BackgroundColor3 = Color3.fromRGB(48, 48, 52)
		background.BackgroundTransparency = 0.2
		background.Parent = holder

		local bgCorner = Instance.new("UICorner")
		bgCorner.CornerRadius = UDim.new(0, 8)
		bgCorner.Parent = background

		local bgStroke = Instance.new("UIStroke")
		bgStroke.Thickness = 1.2
		bgStroke.Color = Color3.fromRGB(150, 150, 150)
		bgStroke.Transparency = 0.6
		bgStroke.Parent = background

		local inputFrame = Instance.new("Frame")
		inputFrame.Size = UDim2.fromOffset(42, 42)
		inputFrame.Position = UDim2.new(0, 15, 0.5, 0)
		inputFrame.AnchorPoint = Vector2.new(0, 0.5)
		inputFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
		inputFrame.BackgroundTransparency = 0.3
		inputFrame.Parent = background

		local inputCorner = Instance.new("UICorner")
		inputCorner.CornerRadius = UDim.new(0, 6)
		inputCorner.Parent = inputFrame

		local inputStroke = Instance.new("UIStroke")
		inputStroke.Color = Color3.fromRGB(150, 150, 150)
		inputStroke.Thickness = 1.2
		inputStroke.Transparency = 0.6
		inputStroke.Parent = inputFrame

		local keyLabel = Instance.new("TextLabel")
		keyLabel.Size = UDim2.fromScale(1, 1)
		keyLabel.BackgroundTransparency = 1
		keyLabel.FontFace = customRubikBold
		keyLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
		keyLabel.TextScaled = true
		keyLabel.Parent = inputFrame

		local keyPadding = Instance.new("UIPadding")
		keyPadding.PaddingTop = UDim.new(0.2, 0)
		keyPadding.PaddingBottom = UDim.new(0.2, 0)
		keyPadding.PaddingLeft = UDim.new(0.12, 0)
		keyPadding.PaddingRight = UDim.new(0.12, 0)
		keyPadding.Parent = keyLabel

		if inputType == Enum.ProximityPromptInputType.Gamepad then
			local btnName = UserInputService:GetStringForKeyCode(prompt.GamepadKeyCode)
			keyLabel.Text = string.gsub(btnName, "Button", "")
		elseif inputType == Enum.ProximityPromptInputType.Touch then
			keyLabel.Text = "TAP"
		else
			keyLabel.Text = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
		end

		local textHolder = Instance.new("Frame")
		textHolder.Size = UDim2.new(1, -72, 1, 0)
		textHolder.Position = UDim2.new(0, 72, 0, 0)
		textHolder.BackgroundTransparency = 1
		textHolder.Parent = background

		local objectLabel = Instance.new("TextLabel")
		objectLabel.Size = UDim2.new(1, -12, 0, 20)
		objectLabel.Position = UDim2.new(0, 0, 0, 14)
		objectLabel.BackgroundTransparency = 1
		objectLabel.TextXAlignment = Enum.TextXAlignment.Left
		objectLabel.FontFace = customRubikBold
		objectLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		objectLabel.TextScaled = true
		objectLabel.Text = prompt.ObjectText
		objectLabel.Parent = textHolder

		local actionLabel = Instance.new("TextLabel")
		actionLabel.Size = UDim2.new(1, -12, 0, 16)
		actionLabel.Position = UDim2.new(0, 0, 0, 36)
		actionLabel.BackgroundTransparency = 1
		actionLabel.TextXAlignment = Enum.TextXAlignment.Left
		actionLabel.FontFace = customRubikBold
		actionLabel.TextColor3 = Color3.fromRGB(180, 180, 185)
		actionLabel.TextScaled = true
		actionLabel.Text = prompt.ActionText
		actionLabel.Parent = textHolder

		local barTrack = Instance.new("Frame")
		barTrack.Size = UDim2.new(1, -20, 0, 4.5)
		barTrack.Position = UDim2.new(0, 0, 0, 56)
		barTrack.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
		barTrack.BackgroundTransparency = 0.5
		barTrack.BorderSizePixel = 0
		barTrack.Parent = textHolder

		local barCorner = Instance.new("UICorner")
		barCorner.CornerRadius = UDim.new(1, 0)
		barCorner.Parent = barTrack

		local fillBar = Instance.new("Frame")
		fillBar.Size = UDim2.fromScale(0, 1)
		fillBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		fillBar.BorderSizePixel = 0
		fillBar.Parent = barTrack

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fillBar

		local triggerButton = Instance.new("TextButton")
		triggerButton.Size = UDim2.fromScale(1, 1)
		triggerButton.BackgroundTransparency = 1
		triggerButton.Text = ""
		triggerButton.Parent = background
		triggerButton.ZIndex = 5

		local fillTween
		local emptyTween

		triggerButton.InputBegan:Connect(function(inputObj)
			if inputObj.UserInputType == Enum.UserInputType.Touch or inputObj.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldBegin()
			end
		end)

		triggerButton.InputEnded:Connect(function(inputObj)
			if inputObj.UserInputType == Enum.UserInputType.Touch or inputObj.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldEnd()
			end
		end)

		prompt.PromptButtonHoldBegan:Connect(function()
			if fillTween then fillTween:Cancel() end
			if emptyTween then emptyTween:Cancel() end

			local currentFill = fillBar.Size.X.Scale
			local durationTarget = math.max(0.01, prompt.HoldDuration * (1 - currentFill))

			fillTween = TweenService:Create(fillBar, TweenInfo.new(durationTarget, Enum.EasingStyle.Linear), {Size = UDim2.fromScale(1, 1)})
			fillTween:Play()

			TweenService:Create(inputFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = Color3.fromRGB(80, 80, 85),
				BackgroundTransparency = 0.2
			}):Play()
		end)

		prompt.PromptButtonHoldEnded:Connect(function()
			if fillTween then fillTween:Cancel() end
			if emptyTween then emptyTween:Cancel() end

			local currentFill = fillBar.Size.X.Scale
			if currentFill > 0 and currentFill < 1 then
				local reverseDuration = math.max(0.15, currentFill * 0.45)
				emptyTween = TweenService:Create(fillBar, TweenInfo.new(reverseDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0, 1)})
				emptyTween:Play()
			else
				fillBar.Size = UDim2.fromScale(0, 1)
			end

			TweenService:Create(inputFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = Color3.fromRGB(28, 28, 32),
				BackgroundTransparency = 0.3
			}):Play()
		end)

		promptGui.Parent = player.PlayerGui

		prompt.PromptHidden:Once(function()
			if fillBar.Size.X.Scale >= 1 then
				return
			end

			if fillTween then fillTween:Cancel() end
			if emptyTween then emptyTween:Cancel() end

			TweenService:Create(uiScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0}):Play()
			TweenService:Create(holder, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Rotation = -12}):Play()

			task.delay(0.22, function()
				if promptGui then promptGui:Destroy() end
			end)
		end)
	end)
end

return PromptController