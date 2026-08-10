local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Shared = ReplicatedStorage.Shared
local SettingsConfig = require(Shared.Modules.Core.SettingsConfig)
local SettingsRemotes = require(Shared.Remotes.SettingsRemotes)

local SettingsController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local PlayerGui = player:WaitForChild("PlayerGui")
local SettingsGui = PlayerGui:WaitForChild("Settings")
local SettingsFrameUI = SettingsGui:WaitForChild("Frame")

local SettingsMain = SettingsFrameUI:WaitForChild("Main")
local SettingsContainer = SettingsMain:WaitForChild("Container")
local SectionNameTemplate = SettingsContainer:WaitForChild("SectionName")
local SliderSettingsTemplate = SettingsContainer:WaitForChild("SliderSettings")
local ToggleSettingsTemplate = SettingsContainer:WaitForChild("ToggleSettings")

local SettingsInfoFrame = SettingsFrameUI:WaitForChild("InfoFrame")
local SettingsInfoTitle = SettingsInfoFrame:WaitForChild("Title")
local SettingsInfoDesc = SettingsInfoFrame:WaitForChild("Description")

local SettingsCategory = SettingsFrameUI:WaitForChild("Category")
local SettingsScrolling = SettingsCategory:WaitForChild("ScrollingFrame")

local currentSettingsValues = {}
local currentSettingsTab = nil
local originalContainerPos = nil
local isSwitchingTab = false
local currentInfoThread = nil
local currentInfoTitle = ""
local settingsTabs = {}

function SettingsController.GetValue(settingName)
	if currentSettingsValues[settingName] ~= nil then
		return currentSettingsValues[settingName]
	end
	for _, cat in pairs(SettingsConfig.Categories) do
		for _, sec in pairs(cat) do
			for _, s in pairs(sec.Settings) do
				if s.Name == settingName then return s.Default end
			end
		end
	end
	return false
end

local function applyAccessibilitySettings()
	local ccColorblind = Lighting:FindFirstChild("ColorblindFilter")
	if not ccColorblind then
		ccColorblind = Instance.new("ColorCorrectionEffect")
		ccColorblind.Name = "ColorblindFilter"
		ccColorblind.Parent = Lighting
	end
	ccColorblind.TintColor = Color3.fromRGB(255, 235, 235)
	ccColorblind.Saturation = -0.15
	ccColorblind.Enabled = SettingsController.GetValue("Colorblind Mode")
	
	local ccContrast = Lighting:FindFirstChild("HighContrastFilter")
	if not ccContrast then
		ccContrast = Instance.new("ColorCorrectionEffect")
		ccContrast.Name = "HighContrastFilter"
		ccContrast.Parent = Lighting
	end
	ccContrast.Contrast = 0.25
	ccContrast.Saturation = 0.1
	ccContrast.Enabled = SettingsController.GetValue("High Contrast UI")
end

local function applyGraphicsSettings()
	Lighting.GlobalShadows = SettingsController.GetValue("Dynamic Shadows")
	Lighting.ShadowSoftness = SettingsController.GetValue("Soft Shadows") and 0.2 or 0
	
	if SettingsController.GetValue("Ambient Occlusion") then
		Lighting.EnvironmentDiffuseScale = 1
		Lighting.EnvironmentSpecularScale = 1
	else
		Lighting.EnvironmentDiffuseScale = 0.5
		Lighting.EnvironmentSpecularScale = 0.5
	end

	if SettingsController.GetValue("Global Illumination") then
		Lighting.Ambient = Color3.fromRGB(70, 70, 70)
	else
		Lighting.Ambient = Color3.fromRGB(120, 120, 120)
	end

	local bloom = Lighting:FindFirstChild("GameBloom") or Instance.new("BloomEffect", Lighting)
	bloom.Name = "GameBloom"
	bloom.Intensity = 0.4
	bloom.Enabled = SettingsController.GetValue("Bloom Effect")

	local dof = Lighting:FindFirstChild("GameDoF") or Instance.new("DepthOfFieldEffect", Lighting)
	dof.Name = "GameDoF"
	dof.FocusDistance = 15
	dof.InFocusRadius = 30
	dof.Enabled = SettingsController.GetValue("Depth of Field")

	local sunRays = Lighting:FindFirstChild("GameSunRays") or Instance.new("SunRaysEffect", Lighting)
	sunRays.Name = "GameSunRays"
	sunRays.Intensity = 0.05
	sunRays.Enabled = SettingsController.GetValue("Lens Flares")
end

local function applyParticleRates()
	local multiplier = (SettingsController.GetValue("Particle Effects") or 100) / 100
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			if not obj:GetAttribute("OriginalRate") then
				obj:SetAttribute("OriginalRate", obj.Rate)
			end
			obj.Rate = obj:GetAttribute("OriginalRate") * multiplier
		end
	end
end

local function setSettingsInfo(title, desc)
	if currentInfoTitle == title then return end
	currentInfoTitle = title

	if currentInfoThread then
		task.cancel(currentInfoThread)
		currentInfoThread = nil
	end

	currentInfoThread = task.spawn(function()
		if SettingsInfoTitle.Text ~= "" then
			TweenService:Create(SettingsInfoTitle, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
			TweenService:Create(SettingsInfoDesc, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
			task.wait(0.15)
		end

		SettingsInfoTitle.TextTransparency = 1
		SettingsInfoTitle.TextStrokeTransparency = 1
		SettingsInfoDesc.TextTransparency = 1
		SettingsInfoDesc.TextStrokeTransparency = 1

		SettingsInfoTitle.Text = title
		SettingsInfoDesc.Text = desc

		TweenService:Create(SettingsInfoTitle, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0, TextStrokeTransparency = 0}):Play()
		TweenService:Create(SettingsInfoDesc, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0, TextStrokeTransparency = 0}):Play()
	end)
end

local function clearSettingsContainer()
	for _, child in SettingsContainer:GetChildren() do
		if child:IsA("Frame") and child ~= SectionNameTemplate and child ~= SliderSettingsTemplate and child ~= ToggleSettingsTemplate then
			child:Destroy()
		end
	end
end

local function updateTabVisuals(activeTabName)
	local colorNormal = Color3.fromRGB(200, 200, 200)
	local colorSelected = Color3.fromRGB(255, 255, 255)
	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

	for tabName, data in pairs(settingsTabs) do
		local titleFrame = data.UI.btn.Title.Frame
		local titleText = data.UI.btn.Title
		local targetSize = (tabName == activeTabName) and data.Sel or data.Unsel
		local targetColor = (tabName == activeTabName) and colorSelected or colorNormal

		TweenService:Create(titleFrame, tweenInfo, {Size = targetSize, BackgroundColor3 = targetColor}):Play()
		TweenService:Create(titleText, tweenInfo, {TextColor3 = targetColor}):Play()
	end
end

local function updateStatsVisibility()
	local inMenu = player:GetAttribute("InMenu") ~= false
	local isLoading = PlayerGui:FindFirstChild("LoadingScreen") ~= nil
	local shouldShow = not inMenu and not isLoading

	local fpsPingGui = PlayerGui:FindFirstChild("FpsPing")
	if fpsPingGui then
		local statsHolder = fpsPingGui:FindFirstChild("StatsHolder")
		if statsHolder then
			local fpsFrame = statsHolder:FindFirstChild("FPS")
			if fpsFrame then fpsFrame.Visible = shouldShow and (currentSettingsValues["Show FPS"] == true) end
			
			local pingFrame = statsHolder:FindFirstChild("Ping")
			if pingFrame then pingFrame.Visible = shouldShow and (currentSettingsValues["Show Ping"] == true) end
		end
	end

	local perfGui = PlayerGui:FindFirstChild("Performance")
	if perfGui then
		local perfPanel = perfGui:FindFirstChild("MainPanel")
		if perfPanel then perfPanel.Visible = shouldShow and (currentSettingsValues["Show Performance Stats"] == true) end
	end
end

local function bindStatsGui(gui)
	if gui.Name == "FpsPing" then
		task.spawn(function()
			local statsHolder = gui:WaitForChild("StatsHolder", 5)
			if statsHolder then
				statsHolder:WaitForChild("FPS", 5)
				statsHolder:WaitForChild("Ping", 5)
				updateStatsVisibility()
			end
		end)
	elseif gui.Name == "Performance" then
		task.spawn(function()
			local mainPanel = gui:WaitForChild("MainPanel", 5)
			if mainPanel then updateStatsVisibility() end
		end)
	end
end

local function loadSettingsCategory(categoryName)
	clearSettingsContainer()
	currentInfoTitle = ""
	SettingsInfoTitle.Text = ""
	SettingsInfoDesc.Text = ""
	SettingsInfoTitle.TextTransparency = 1
	SettingsInfoTitle.TextStrokeTransparency = 1
	SettingsInfoDesc.TextTransparency = 1
	SettingsInfoDesc.TextStrokeTransparency = 1

	local categoryData = SettingsConfig.Categories[categoryName]
	if not categoryData then return end

	local orderIndex = 1
	for _, section in ipairs(categoryData) do
		local secUI = SectionNameTemplate:Clone()
		secUI.Name = section.SectionName
		secUI.btn.Title.Text = section.SectionName
		secUI.LayoutOrder = orderIndex
		secUI.ZIndex = orderIndex
		orderIndex += 1
		secUI.Visible = true
		secUI.Parent = SettingsContainer

		for _, setting in ipairs(section.Settings) do
			if currentSettingsValues[setting.Name] == nil then
				currentSettingsValues[setting.Name] = setting.Default
			end

			if setting.Type == "Toggle" then
				local togUI = ToggleSettingsTemplate:Clone()
				togUI.Name = setting.Name
				togUI.btn.Title.Text = setting.Name
				togUI.LayoutOrder = orderIndex
				togUI.ZIndex = orderIndex
				orderIndex += 1

				local toggleBtn = togUI.btn.Toggle.btn
				local onGrad = toggleBtn:WaitForChild("On")
				local offGrad = toggleBtn:WaitForChild("Off")

				local isOn = currentSettingsValues[setting.Name]

				if isOn then
					onGrad.Enabled = true
					offGrad.Enabled = false
					onGrad.Offset = Vector2.new(0, 0)
				else
					onGrad.Enabled = false
					offGrad.Enabled = true
					offGrad.Offset = Vector2.new(0, 0)
				end

				local function toggleSetting()
					isOn = not isOn
					currentSettingsValues[setting.Name] = isOn
					SettingsRemotes.GetUpdateSettingEvent():FireServer(setting.Name, isOn)
					setSettingsInfo(setting.Name, setting.Description or "")

					local scaleObj = toggleBtn:FindFirstChildOfClass("UIScale")
					if not scaleObj then scaleObj = Instance.new("UIScale", toggleBtn) end
					scaleObj.Scale = 0.85
					TweenService:Create(scaleObj, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

					if isOn then
						offGrad.Enabled = false
						onGrad.Enabled = true
						onGrad.Offset = Vector2.new(-1, 0) 
						TweenService:Create(onGrad, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Offset = Vector2.new(0, 0)}):Play()
					else
						onGrad.Enabled = false
						offGrad.Enabled = true
						offGrad.Offset = Vector2.new(1, 0)
						TweenService:Create(offGrad, TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Offset = Vector2.new(0, 0)}):Play()
					end

					if setting.Name == "Show FPS" or setting.Name == "Show Ping" or setting.Name == "Show Performance Stats" then
						updateStatsVisibility()
					elseif setting.Name == "Colorblind Mode" or setting.Name == "High Contrast UI" then
						applyAccessibilitySettings()
					elseif setting.Name == "Global Illumination" or setting.Name == "Dynamic Shadows" or setting.Name == "Soft Shadows" or setting.Name == "Ambient Occlusion" or setting.Name == "Bloom Effect" or setting.Name == "Depth of Field" or setting.Name == "Lens Flares" then
						applyGraphicsSettings()
					end
				end

				toggleBtn.MouseButton1Click:Connect(toggleSetting)

				local selectBtn = togUI:WaitForChild("Button")
				if selectBtn and selectBtn:IsA("TextButton") then
					selectBtn.MouseButton1Click:Connect(toggleSetting)
				end
				togUI.Visible = true
				togUI.Parent = SettingsContainer

			elseif setting.Type == "Slider" then
				local sldUI = SliderSettingsTemplate:Clone()
				sldUI.Name = setting.Name
				sldUI.btn.Title.Text = setting.Name
				sldUI.LayoutOrder = orderIndex
				sldUI.ZIndex = orderIndex
				orderIndex += 1

				local sliderFrame = sldUI.btn.SliderFrame
				local pctText = sliderFrame.Percentage
				local dragger = sliderFrame.btn
				dragger.AnchorPoint = Vector2.new(0.5, 0.5)

				local function updateSliderVisual()
					local val = currentSettingsValues[setting.Name]
					local percent = (val - setting.Min) / (setting.Max - setting.Min)
					local trackW = sliderFrame.AbsoluteSize.X
					local dW = dragger.AbsoluteSize.X

					if dW > 0 and trackW > 0 then
						local minOffset = dW / 2
						local maxOffset = trackW - (dW / 2)
						local activeW = math.max(1, maxOffset - minOffset)
						local currentPixels = minOffset + (activeW * percent)
						dragger.Position = UDim2.new(0, currentPixels, 0.5, 0)
					else
						dragger.Position = UDim2.new(percent, 0, 0.5, 0)
					end
					pctText.Text = tostring(math.floor(percent * 100)) .. "%"
				end

				updateSliderVisual()
				dragger:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSliderVisual)
				sliderFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSliderVisual)

				dragger.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						setSettingsInfo(setting.Name, setting.Description or "")
						local conn
						conn = RunService.RenderStepped:Connect(function()
							if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
								conn:Disconnect()
								SettingsRemotes.GetUpdateSettingEvent():FireServer(setting.Name, currentSettingsValues[setting.Name])
								if setting.Name == "Particle Effects" then
									applyParticleRates()
								end
								return
							end

							local dW = dragger.AbsoluteSize.X
							local trackW = sliderFrame.AbsoluteSize.X
							local minOffset = dW / 2
							local maxOffset = trackW - (dW / 2)
							local activeW = math.max(1, maxOffset - minOffset)
							local relativeX = mouse.X - sliderFrame.AbsolutePosition.X
							local percent = math.clamp((relativeX - minOffset) / activeW, 0, 1)

							currentSettingsValues[setting.Name] = setting.Min + (setting.Max - setting.Min) * percent
							updateSliderVisual()
						end)
					end
				end)

				local selectBtn = sldUI:WaitForChild("Button")
				if selectBtn and selectBtn:IsA("TextButton") then
					selectBtn.MouseButton1Click:Connect(function()
						setSettingsInfo(setting.Name, setting.Description or "")
					end)
				end
				sldUI.Visible = true
				sldUI.Parent = SettingsContainer
			end
		end
	end
end

local function switchSettingsTab(tabName)
	if currentSettingsTab == tabName or isSwitchingTab then return end
	isSwitchingTab = true
	currentSettingsTab = tabName
	updateTabVisuals(tabName)

	if #SettingsContainer:GetChildren() > 3 then
		local outPosTween = TweenService:Create(SettingsContainer, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(originalContainerPos.X.Scale, originalContainerPos.X.Offset, originalContainerPos.Y.Scale, originalContainerPos.Y.Offset + 250)
		})
		outPosTween:Play()
		outPosTween.Completed:Wait()
	end

	loadSettingsCategory(tabName)
	SettingsContainer.CanvasPosition = Vector2.new(0, 0)
	SettingsContainer.Position = UDim2.new(originalContainerPos.X.Scale, originalContainerPos.X.Offset, originalContainerPos.Y.Scale, originalContainerPos.Y.Offset - 250)

	local inPosTween = TweenService:Create(SettingsContainer, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = originalContainerPos
	})
	inPosTween:Play()
	inPosTween.Completed:Connect(function()
		isSwitchingTab = false
	end)
end

function SettingsController.Init()
	SettingsMain.ClipsDescendants = true
	SectionNameTemplate.Visible = false
	SliderSettingsTemplate.Visible = false
	ToggleSettingsTemplate.Visible = false

	settingsTabs = {
		Video = {UI = SettingsScrolling:WaitForChild("Video"), Unsel = UDim2.new(0.203, 0, 0.116, 0), Sel = UDim2.new(1, 0, 0.116, 0)},
		Audio = {UI = SettingsScrolling:WaitForChild("Audio"), Unsel = UDim2.new(0.15, 0, 0.116, 0), Sel = UDim2.new(0.778, 0, 0.116, 0)},
		Controls = {UI = SettingsScrolling:WaitForChild("Controls"), Unsel = UDim2.new(0.15, 0, 0.116, 0), Sel = UDim2.new(0.778, 0, 0.116, 0)},
		Cursor = {UI = SettingsScrolling:WaitForChild("Cursor"), Unsel = UDim2.new(0.15, 0, 0.116, 0), Sel = UDim2.new(0.778, 0, 0.116, 0)},
		Graphics = {UI = SettingsScrolling:WaitForChild("Graphics"), Unsel = UDim2.new(0.15, 0, 0.116, 0), Sel = UDim2.new(0.778, 0, 0.116, 0)}
	}

	originalContainerPos = SettingsContainer.Position
	currentSettingsTab = "Video"

	for _, categoryData in pairs(SettingsConfig.Categories) do
		for _, section in ipairs(categoryData) do
			for _, setting in ipairs(section.Settings) do
				if currentSettingsValues[setting.Name] == nil then
					currentSettingsValues[setting.Name] = setting.Default
				end
			end
		end
	end
	
	updateTabVisuals("Video")
	loadSettingsCategory("Video")

	task.spawn(function()
		local savedSettings = SettingsRemotes.GetSettingsFunction():InvokeServer()
		for k, v in pairs(savedSettings) do
			currentSettingsValues[k] = v
		end
		
		if currentSettingsTab then
			loadSettingsCategory(currentSettingsTab)
		end
		
		applyAccessibilitySettings()
		applyGraphicsSettings()
		applyParticleRates()
		updateStatsVisibility()
	end)

	for tabName, data in pairs(settingsTabs) do
		local titleFrame = data.UI.btn.Title.Frame
		titleFrame.AnchorPoint = Vector2.new(0.5, 1)
		titleFrame.Position = UDim2.new(0.5, 0, 1, 0)
		data.UI.btn.MouseButton1Click:Connect(function() switchSettingsTab(tabName) end)
	end

	for _, gui in ipairs(PlayerGui:GetChildren()) do
		bindStatsGui(gui)
	end
	
	PlayerGui.ChildAdded:Connect(function(child)
		if child.Name == "LoadingScreen" then 
			updateStatsVisibility() 
		else
			bindStatsGui(child)
		end
	end)
	
	PlayerGui.ChildRemoved:Connect(function(child)
		if child.Name == "LoadingScreen" then 
			updateStatsVisibility() 
		end
	end)
	
	player:GetAttributeChangedSignal("InMenu"):Connect(updateStatsVisibility)
	
	Workspace.DescendantAdded:Connect(function(obj)
		if obj:IsA("ParticleEmitter") then
			if not obj:GetAttribute("OriginalRate") then
				obj:SetAttribute("OriginalRate", obj.Rate)
			end
			local multiplier = (SettingsController.GetValue("Particle Effects") or 100) / 100
			obj.Rate = obj:GetAttribute("OriginalRate") * multiplier
		end
	end)
	
	local camera = Workspace.CurrentCamera
	local lastCamCFrame = camera.CFrame
	local motionBlur = Lighting:FindFirstChild("MotionBlur") or Instance.new("BlurEffect", Lighting)
	motionBlur.Name = "MotionBlur"
	
	RunService.RenderStepped:Connect(function(dt)
		local currentCamera = Workspace.CurrentCamera
		if not currentCamera then return end

		local baseFov = SettingsController.GetValue("Field of View") or 70
		local targetFov = baseFov
		local isPlaying = player:GetAttribute("IsPlaying") == true

		-- Aiming down sights (set locally by CameraFX) overrides everything else,
		-- including Dynamic FOV - a sniper scope must not wobble with run speed.
		local aimFov = player:GetAttribute("AimFOV")
		if type(aimFov) == "number" then
			targetFov = aimFov
		elseif SettingsController.GetValue("Dynamic FOV") and isPlaying then
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChild("Humanoid")
			if root and hum and hum.Health > 0 then
				local flatSpeed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
				local fovOffset = math.min(15, flatSpeed * 0.4)
				targetFov = baseFov + fovOffset
			end
		end
		
		currentCamera.FieldOfView = currentCamera.FieldOfView + (targetFov - currentCamera.FieldOfView) * math.min(1, dt * 10)

		if SettingsController.GetValue("Motion Blur") then
			motionBlur.Enabled = true
			local currentCFrame = currentCamera.CFrame
			local angle = lastCamCFrame.LookVector:Angle(currentCFrame.LookVector)
			motionBlur.Size = math.clamp(angle * 400, 0, 15)
			lastCamCFrame = currentCFrame
		else
			motionBlur.Enabled = false
			lastCamCFrame = currentCamera.CFrame
		end

		local baseLookSens = SettingsController.GetValue("Look Sensitivity") or 50
		local sensMultiplier = baseLookSens / 50
		
		if SettingsController.GetValue("Aim Assist") and isPlaying then
			local ray = currentCamera:ScreenPointToRay(mouse.X, mouse.Y)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			
			local ignoreList = {player.Character}
			local debrisFolder = Workspace:FindFirstChild("WallDebrisFolder")
			if debrisFolder then table.insert(ignoreList, debrisFolder) end
			local baseModel = Workspace:FindFirstChild("Base")
			if baseModel then table.insert(ignoreList, baseModel) end
			
			params.FilterDescendantsInstances = ignoreList

			local result = Workspace:Raycast(ray.Origin, ray.Direction * 200, params)
			if result and result.Instance then
				local targetChar = result.Instance:FindFirstAncestorWhichIsA("Model")
				if targetChar and targetChar:FindFirstChildOfClass("Humanoid") then
					sensMultiplier = sensMultiplier * 0.45
				end
			end
		end
		
		UserInputService.MouseDeltaSensitivity = sensMultiplier
	end)
end

return SettingsController