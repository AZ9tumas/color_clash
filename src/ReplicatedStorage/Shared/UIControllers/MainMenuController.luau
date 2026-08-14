local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local RoundRemotes = require(Shared.Remotes.RoundRemotes)
local UIAnimations = require(Shared.Modules.Utils.UIAnimations)
local MenuController = require(Shared.UIControllers.MenuController)

local MainMenuController = {}

local COUNTDOWN = 5

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local MainHUD = PlayerGui:WaitForChild("MainHUD")

local MainMenuBtn = MainHUD:WaitForChild("MainMenuButton")
local Title = MainMenuBtn:WaitForChild("Title")

local function findBackdrop(button)
	for _, child in MainHUD:GetChildren() do
		if child:IsA("Frame") and child.Name == "Frame"
			and math.abs(child.Position.Y.Scale - button.Position.Y.Scale) < 0.01
		then
			return child
		end
	end
	return nil
end

local defaultText = Title.Text
local isCounting = false
local runToken = 0

local function reset()
	isCounting = false
	runToken += 1
	Title.Text = defaultText
end

local function toggleReturnToMenu()
	if isCounting then
		reset()
		return
	end

	isCounting = true
	runToken += 1
	local myToken = runToken

	task.spawn(function()
		for remaining = COUNTDOWN, 1, -1 do
			if runToken ~= myToken then return end
			Title.Text = tostring(remaining)
			task.wait(1)
		end
		if runToken ~= myToken then return end

		reset()
		RoundRemotes.GetMainMenuEvent():FireServer()
		MenuController.ReturnToMenu()
	end)
end

function MainMenuController.Init()
	UIAnimations.BindButtonAnimations(MainMenuBtn)

	local backdrop = findBackdrop(MainMenuBtn)

	MainMenuBtn.MouseButton1Click:Connect(toggleReturnToMenu)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or player:GetAttribute("InMenu") ~= false then return end
		if input.KeyCode == Enum.KeyCode.M then
			toggleReturnToMenu()
		end
	end)

	if backdrop then
		MainMenuBtn:GetPropertyChangedSignal("Visible"):Connect(function()
			backdrop.Visible = MainMenuBtn.Visible
		end)
		backdrop.Visible = MainMenuBtn.Visible
	end
end

return MainMenuController
