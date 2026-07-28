local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local UIAnimations = require(Shared.Modules.Utils.UIAnimations)
local RoundRemotes = require(Shared.Remotes.RoundRemotes)
local SpectateRemotes = require(Shared.Remotes.SpectateRemotes)

local MenuController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local CamPart = Workspace:WaitForChild("Cam")

local PlayerGui = player:WaitForChild("PlayerGui")
local Menu = PlayerGui:WaitForChild("Menu")
local MenuHolder = Menu:WaitForChild("Holder")
local PlayFrame = MenuHolder:WaitForChild("Play")
local PlayBtn = PlayFrame:WaitForChild("btn")

local ShopGui = PlayerGui:WaitForChild("Shop")
local ShopFrameUI = ShopGui:WaitForChild("Frame")
local LeaderboardGui = PlayerGui:WaitForChild("Leaderboard")
local LeaderboardFrameUI = LeaderboardGui:WaitForChild("Frame")
local SettingsGui = PlayerGui:WaitForChild("Settings")
local SettingsFrameUI = SettingsGui:WaitForChild("Frame")

local MenuButtonsHolder = MenuHolder:WaitForChild("ButtonsHolder")
local MenuScrollingFrame = MenuButtonsHolder:WaitForChild("ScrollingFrame")

local playClicked = false

local function setupMenuButton(frame, unselectedSize, selectedSize, pos)
	local btn = frame:WaitForChild("btn")
	local title = btn:WaitForChild("Title")
	local titleFrame = title:WaitForChild("Frame")

	local colorNormal = Color3.fromRGB(200, 200, 200)
	local colorHover = Color3.fromRGB(255, 255, 255)
	local hoverInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	titleFrame.Size = unselectedSize
	titleFrame.Position = pos
	titleFrame.BackgroundColor3 = colorNormal
	title.TextColor3 = colorNormal

	btn.MouseEnter:Connect(function()
		TweenService:Create(titleFrame, hoverInfo, {Size = selectedSize, BackgroundColor3 = colorHover}):Play()
		TweenService:Create(title, hoverInfo, {TextColor3 = colorHover}):Play()
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(titleFrame, hoverInfo, {Size = unselectedSize, BackgroundColor3 = colorNormal}):Play()
		TweenService:Create(title, hoverInfo, {TextColor3 = colorNormal}):Play()
	end)
end

local function openSubMenu(targetFrame)
	UIAnimations.PopOut(MenuHolder)
	task.delay(0.15, function() UIAnimations.PopIn(targetFrame) end)
end

local function closeSubMenu(targetFrame)
	UIAnimations.PopOut(targetFrame)
	task.delay(0.15, function() UIAnimations.PopIn(MenuHolder) end)
end

-- Guarded on playClicked alone rather than the InMenu attribute, so returning to the menu
-- can restart it immediately without waiting for the server attribute to replicate back.
local menuCamConnection = nil
local function startMenuCamera()
	if menuCamConnection then menuCamConnection:Disconnect() end

	menuCamConnection = RunService.RenderStepped:Connect(function()
		if not playClicked then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CamPart.CFrame
		else
			if menuCamConnection then
				menuCamConnection:Disconnect()
				menuCamConnection = nil
			end
		end
	end)
end

-- Puts the player back in the state they are in the moment they join.
function MenuController.ReturnToMenu()
	playClicked = false
	Menu.Enabled = true
	startMenuCamera()
	UIAnimations.PopIn(MenuHolder)
end

local function enterGame(onEntered)
	if playClicked or player:GetAttribute("InMenu") == false then return end
	playClicked = true
	UIAnimations.PopOut(MenuHolder)

	task.delay(0.6, function()
		Menu.Enabled = false
		camera.CameraType = Enum.CameraType.Custom
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			camera.CameraSubject = player.Character.Humanoid
		end
		RoundRemotes.GetPlayGameEvent():FireServer()

		if onEntered then onEntered() end
	end)
end

function MenuController.Init()
	local ReplicatedFirst = game:GetService("ReplicatedFirst")
	pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)

	Menu.Enabled = true
	ShopGui.Enabled = true
	LeaderboardGui.Enabled = true
	SettingsGui.Enabled = true

	UIAnimations.InitializePopObject(MenuHolder)
	UIAnimations.InitializePopObject(ShopFrameUI)
	UIAnimations.InitializePopObject(LeaderboardFrameUI)
	UIAnimations.InitializePopObject(SettingsFrameUI)

	setupMenuButton(PlayFrame, UDim2.new(0.374, 0, 0.116, 0), UDim2.new(1, 0, 0.116, 0), UDim2.new(0.5, 0, 1, 0))
	setupMenuButton(MenuScrollingFrame.Shop, UDim2.new(0.375, 0, 0.116, 0), UDim2.new(1, 0, 0.116, 0), UDim2.new(0.5, 0, 1, 0))
	setupMenuButton(MenuScrollingFrame.Settings, UDim2.new(0.193, 0, 0.116, 0), UDim2.new(0.866, 0, 0.116, 0), UDim2.new(0.5, 0, 1, 0))
	setupMenuButton(MenuScrollingFrame.Leaderboard, UDim2.new(0.193, 0, 0.116, 0), UDim2.new(0.81, 0, 0.116, 0), UDim2.new(0.5, 0, 1, 0))

	local SpectateFrame = MenuScrollingFrame:FindFirstChild("Spectate")
	if SpectateFrame then
		setupMenuButton(SpectateFrame, UDim2.new(0.193, 0, 0.116, 0), UDim2.new(0.866, 0, 0.116, 0), UDim2.new(0.5, 0, 1, 0))
		SpectateFrame.btn.MouseButton1Click:Connect(function()
			enterGame(function() SpectateRemotes.GetRequestEvent():FireServer("Start") end)
		end)
	end

	MenuScrollingFrame.Shop.btn.MouseButton1Click:Connect(function() if not playClicked then openSubMenu(ShopFrameUI) end end)
	MenuScrollingFrame.Leaderboard.btn.MouseButton1Click:Connect(function() if not playClicked then openSubMenu(LeaderboardFrameUI) end end)
	MenuScrollingFrame.Settings.btn.MouseButton1Click:Connect(function() if not playClicked then openSubMenu(SettingsFrameUI) end end)

	local ShopExitBtn = ShopFrameUI:WaitForChild("ExitButton"):WaitForChild("btn")
	local LeaderboardExitBtn = LeaderboardFrameUI:WaitForChild("ExitButton"):WaitForChild("btn")
	local SettingsExitBtn = SettingsFrameUI:WaitForChild("ExitButton"):WaitForChild("btn")

	UIAnimations.BindButtonAnimations(ShopExitBtn)
	UIAnimations.BindButtonAnimations(LeaderboardExitBtn)
	UIAnimations.BindButtonAnimations(SettingsExitBtn)

	ShopExitBtn.MouseButton1Click:Connect(function() closeSubMenu(ShopFrameUI) end)
	LeaderboardExitBtn.MouseButton1Click:Connect(function() closeSubMenu(LeaderboardFrameUI) end)
	SettingsExitBtn.MouseButton1Click:Connect(function() closeSubMenu(SettingsFrameUI) end)

	startMenuCamera()

	PlayBtn.MouseButton1Click:Connect(function() enterGame() end)

	local loadingScreen = ReplicatedFirst:FindFirstChild("LoadingScreen")
	if loadingScreen then
		local lsClone = loadingScreen:Clone()
		lsClone.Parent = PlayerGui

		local spinner = lsClone:FindFirstChild("Holder") and lsClone.Holder:FindFirstChild("Left") and lsClone.Holder.Left:FindFirstChild("Spinner")
		local spinConnection
		if spinner then
			spinConnection = RunService.RenderStepped:Connect(function(dt)
				spinner.Rotation = (spinner.Rotation + (dt * 75)) % 360
			end)
		end

		task.spawn(function()
			task.wait(math.random(40, 70) / 10)
			if spinConnection then spinConnection:Disconnect() end

			local targetObj = lsClone:IsA("GuiObject") and lsClone or lsClone:FindFirstChildWhichIsA("GuiObject")
			if targetObj then
				local outTween = TweenService:Create(targetObj, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.new(targetObj.Position.X.Scale, targetObj.Position.X.Offset, -1.5, 0)
				})
				outTween:Play()
				outTween.Completed:Connect(function()
					lsClone:Destroy()
					if not playClicked and player:GetAttribute("InMenu") ~= false then
						UIAnimations.PopIn(MenuHolder)
					end
				end)
			else
				lsClone:Destroy()
				if not playClicked and player:GetAttribute("InMenu") ~= false then
					UIAnimations.PopIn(MenuHolder)
				end
			end
		end)
	else
		if not playClicked and player:GetAttribute("InMenu") ~= false then
			UIAnimations.PopIn(MenuHolder)
		end
	end
end

return MenuController