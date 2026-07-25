local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local SettingsController = require(Shared.UIControllers.SettingsController)

local CrosshairController = {}

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local MainHUD = PlayerGui:WaitForChild("MainHUD")
local Crosshair = MainHUD:WaitForChild("Crosshair")

local currentBloom = 0
local targetBloom = 0
local originalCrosshairPos = {}
local isVis = false

local hitMarkerGroup = nil
local hitScaleObj = nil
local hitMarks = {}

local hitAnimCounter = 0
local feedbackLayerParent = nil

local function setupDynamicFeedback()
	if Crosshair:FindFirstChild("FeedbackLayer") then Crosshair.FeedbackLayer:Destroy() end
	hitMarks = {}
	
	local feedbackLayer = Instance.new("Frame")
	feedbackLayer.Name = "FeedbackLayer"
	feedbackLayer.Size = UDim2.fromScale(1, 1)
	feedbackLayer.Position = UDim2.fromScale(0.5, 0.5)
	feedbackLayer.AnchorPoint = Vector2.new(0.5, 0.5)
	feedbackLayer.BackgroundTransparency = 1
	feedbackLayer.ZIndex = 50
	feedbackLayer.Parent = Crosshair
	
	feedbackLayerParent = feedbackLayer

	hitMarkerGroup = Instance.new("Frame")
	hitMarkerGroup.Name = "HitMarkerGroup"
	hitMarkerGroup.Size = UDim2.fromScale(0, 0)
	hitMarkerGroup.Position = UDim2.fromScale(0.5, 0.5)
	hitMarkerGroup.BackgroundTransparency = 1
	hitMarkerGroup.Rotation = 45
	hitMarkerGroup.Parent = feedbackLayer

	hitScaleObj = Instance.new("UIScale")
	hitScaleObj.Scale = 1
	hitScaleObj.Parent = hitMarkerGroup

	local lineData = {
		{UDim2.new(0.5, 0, 0, -8), Vector2.new(0.5, 1), UDim2.new(0, 3, 0, 11)},
		{UDim2.new(0.5, 0, 0, 8), Vector2.new(0.5, 0), UDim2.new(0, 3, 0, 11)},
		{UDim2.new(0, -8, 0.5, 0), Vector2.new(1, 0.5), UDim2.new(0, 11, 0, 3)},
		{UDim2.new(0, 8, 0.5, 0), Vector2.new(0, 0.5), UDim2.new(0, 11, 0, 3)}
	}

	for i, data in ipairs(lineData) do
		local mark = Instance.new("Frame")
		mark.Name = "Mark_" .. i
		mark.Size = data[3]
		mark.AnchorPoint = data[2]
		mark.Position = data[1]
		mark.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		mark.BackgroundTransparency = 1
		mark.BorderSizePixel = 0
		mark.Parent = hitMarkerGroup

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.2
		stroke.Transparency = 1
		stroke.Color = Color3.new(0.05, 0.05, 0.05)
		stroke.Parent = mark

		table.insert(hitMarks, mark)
	end
end

function CrosshairController.ShowHitMarker(typeId)
	if not hitMarkerGroup then return end
	
	if typeId == 1 or typeId == 2 then
		hitAnimCounter += 1
		local currentCounter = hitAnimCounter
		local targetColor = (typeId == 2) and Color3.fromRGB(255, 35, 35) or Color3.fromRGB(255, 255, 255)
		
		hitMarkerGroup.Rotation = 45 + math.random(-6, 6)
		hitScaleObj.Scale = (typeId == 2) and 2.4 or 1.6
		
		for _, mark in ipairs(hitMarks) do
			mark.BackgroundColor3 = targetColor
			mark.BackgroundTransparency = 0
			local stroke = mark:FindFirstChildOfClass("UIStroke")
			if stroke then stroke.Transparency = 0 end
		end
		
		TweenService:Create(hitScaleObj, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = (typeId == 2) and 1.3 or 0.95
		}):Play()
		
		if SettingsController.GetValue("Hit Marker Sound") ~= false then 
			local clickSfx = Instance.new("Sound", Workspace)
			clickSfx.SoundId = "rbxassetid://4606132034"
			clickSfx.Pitch = ((typeId == 2) and 1.3 or 1.0) + math.random(-8, 8)/100 
			clickSfx.Volume = 0.55
			clickSfx:Play()
			game.Debris:AddItem(clickSfx, 1)
		end
		
		task.delay(0.12, function()
			if hitAnimCounter ~= currentCounter then return end
			
			TweenService:Create(hitScaleObj, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Scale = 0.6
			}):Play()
			
			for _, mark in ipairs(hitMarks) do
				TweenService:Create(mark, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
				local stroke = mark:FindFirstChildOfClass("UIStroke")
				if stroke then
					TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
				end
			end
		end)
	end
	
	if typeId == 3 then
		hitAnimCounter += 1
		
		local explodeGroup = Instance.new("Frame")
		explodeGroup.Size = UDim2.fromScale(0, 0)
		explodeGroup.Position = UDim2.fromScale(0.5, 0.5)
		explodeGroup.AnchorPoint = Vector2.new(0.5, 0.5)
		explodeGroup.BackgroundTransparency = 1
		explodeGroup.Rotation = 45 + math.random(-5, 5)
		explodeGroup.Parent = feedbackLayerParent
		
		local expScale = Instance.new("UIScale")
		expScale.Scale = 0
		expScale.Parent = explodeGroup

		local offsets = {
			{UDim2.new(0.5, 0, 0, -5), Vector2.new(0.5, 1), UDim2.new(0, 6, 0, 24)},
			{UDim2.new(0.5, 0, 0, 5), Vector2.new(0.5, 0), UDim2.new(0, 6, 0, 24)},
			{UDim2.new(0, -5, 0.5, 0), Vector2.new(1, 0.5), UDim2.new(0, 24, 0, 6)},
			{UDim2.new(0, 5, 0.5, 0), Vector2.new(0, 0.5), UDim2.new(0, 24, 0, 6)}
		}
		
		for _, data in ipairs(offsets) do
			local mark = Instance.new("Frame")
			mark.Size = data[3]
			mark.AnchorPoint = data[2]
			mark.Position = data[1]
			mark.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
			mark.BorderSizePixel = 0
			mark.Parent = explodeGroup
			
			local st = Instance.new("UIStroke")
			st.Thickness = 2.0
			st.Color = Color3.new(0.1, 0, 0)
			st.Parent = mark

			local pushAmt = 25
			local tgtOffset = UDim2.new(
				0, mark.Position.X.Offset + (mark.Position.X.Offset < 0 and -pushAmt or (mark.Position.X.Offset > 0 and pushAmt or 0)),
				0, mark.Position.Y.Offset + (mark.Position.Y.Offset < 0 and -pushAmt or (mark.Position.Y.Offset > 0 and pushAmt or 0))
			)

			TweenService:Create(mark, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
				Position = tgtOffset,
				BackgroundTransparency = 1
			}):Play()

			TweenService:Create(st, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0.1), {
				Transparency = 1
			}):Play()
		end

		TweenService:Create(expScale, TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Scale = 1.9
		}):Play()

		game.Debris:AddItem(explodeGroup, 0.45)
		
		hitMarkerGroup.Rotation = explodeGroup.Rotation + math.random(-6, 6)
		hitScaleObj.Scale = 2.2
		TweenService:Create(hitScaleObj, TweenInfo.new(0.3, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Scale = 1.0
		}):Play()
		
		for _, mark in ipairs(hitMarks) do
			mark.BackgroundColor3 = Color3.fromRGB(255, 25, 25)
			mark.BackgroundTransparency = 0
			local stroke = mark:FindFirstChildOfClass("UIStroke")
			if stroke then 
				stroke.Transparency = 0 
				TweenService:Create(stroke, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0.1), { Transparency = 1 }):Play()
			end
			TweenService:Create(mark, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
		end
		
		if SettingsController.GetValue("Kill Sound Effect") ~= false then 
			local punchSfx = Instance.new("Sound", Workspace)
			punchSfx.SoundId = "rbxassetid://4606132034"
			punchSfx.Pitch = 0.7
			punchSfx.Volume = 0.85
			punchSfx:Play()
			
			local hitSfx = Instance.new("Sound", Workspace)
			hitSfx.SoundId = "rbxassetid://8617756184"
			hitSfx.Pitch = 1.05 + math.random(-6, 6)/100
			hitSfx.Volume = 0.9
			hitSfx:Play()
			
			game.Debris:AddItem(punchSfx, 1)
			game.Debris:AddItem(hitSfx, 2)
		end
	end
end

function CrosshairController.AddBloom(amount)
	if not SettingsController.GetValue("Dynamic Crosshair") then return end
	targetBloom = math.clamp(targetBloom + amount, 0, 75)
end

function CrosshairController.SetCrosshairVisible(isVisible)
	isVis = isVisible
	Crosshair.Visible = isVisible and SettingsController.GetValue("Show Crosshair")
	UserInputService.MouseIconEnabled = not isVis
end

function CrosshairController.Init()
	MainHUD.IgnoreGuiInset = true
	Crosshair.Visible = false
	local uiScale = Crosshair:FindFirstChild("UIScale") or Instance.new("UIScale", Crosshair)
	
	setupDynamicFeedback()

	for _, child in Crosshair:GetChildren() do
		if child:IsA("Frame") and child.Name ~= "FeedbackLayer" then
			originalCrosshairPos[child.Name] = child.Position
			local stroke = child:FindFirstChildOfClass("UIStroke")
			if not stroke then
				stroke = Instance.new("UIStroke", child)
				stroke.Thickness = 1.2
				stroke.Color = Color3.new(0, 0, 0)
			end
		end
	end

	RunService.RenderStepped:Connect(function(dt)
		Crosshair.Visible = isVis and SettingsController.GetValue("Show Crosshair")
		if not Crosshair.Visible then return end
		
		uiScale.Scale = (SettingsController.GetValue("Crosshair Scale") or 100) / 100
		local hasOutline = SettingsController.GetValue("Crosshair Outline")

		Crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
		Crosshair.Position = UDim2.fromScale(0.5, 0.5)

		if SettingsController.GetValue("Dynamic Crosshair") then
			currentBloom = currentBloom + (targetBloom - currentBloom) * math.min(1, dt * 15)
			targetBloom = targetBloom * (1 - dt * 8)
		else
			currentBloom = 0
			targetBloom = 0
		end

		local function updateCrosshairPart(name, posCalc)
			local part = Crosshair:FindFirstChild(name)
			if originalCrosshairPos[name] and part then
				part.Position = posCalc(originalCrosshairPos[name])
				local s = part:FindFirstChildOfClass("UIStroke")
				if s then s.Enabled = hasOutline end
			end
		end

		updateCrosshairPart("Top", function(o) return UDim2.new(o.X.Scale, o.X.Offset, o.Y.Scale, o.Y.Offset - currentBloom) end)
		updateCrosshairPart("Bottom", function(o) return UDim2.new(o.X.Scale, o.X.Offset, o.Y.Scale, o.Y.Offset + currentBloom) end)
		updateCrosshairPart("Left", function(o) return UDim2.new(o.X.Scale, o.X.Offset - currentBloom, o.Y.Scale, o.Y.Offset) end)
		updateCrosshairPart("Right", function(o) return UDim2.new(o.X.Scale, o.X.Offset + currentBloom, o.Y.Scale, o.Y.Offset) end)
	end)
end

return CrosshairController