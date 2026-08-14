local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local SpectateRemotes = require(Shared.Remotes.SpectateRemotes)
local UIAnimations = require(Shared.Modules.Utils.UIAnimations)

local SpectateController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local PlayerGui = player:WaitForChild("PlayerGui")
local MainHUD = PlayerGui:WaitForChild("MainHUD")

local SpectateFrame = MainHUD:WaitForChild("Spectate")
local Pill = SpectateFrame:WaitForChild("Frame")
local SpectatingText = Pill:WaitForChild("Spectating")
local LeftBtn = Pill:WaitForChild("Left")
local RightBtn = Pill:WaitForChild("Right")
local ExitBtn = SpectateFrame:WaitForChild("Exit")
local SpectatorsText = SpectateFrame:WaitForChild("Spectators")

local SpectateBtn = MainHUD:WaitForChild("SpectateButton")

local SpectateBtnBackground = nil
for _, child in MainHUD:GetChildren() do
	if child:IsA("Frame") and child.Name == "Frame"
		and math.abs(child.Position.Y.Scale - SpectateBtn.Position.Y.Scale) < 0.01
	then
		SpectateBtnBackground = child
		break
	end
end

local currentTarget = nil

local function restoreOwnCamera()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then camera.CameraSubject = humanoid end
end

local function hasActivePlayers()
	for _, p in Players:GetPlayers() do
		if p ~= player and p:GetAttribute("IsPlaying") then return true end
	end
	return false
end

local function updateButtonVisibility()
	local shouldShow = player:GetAttribute("InMenu") == false
		and player:GetAttribute("IsPlaying") ~= true
		and currentTarget == nil
		and hasActivePlayers()

	SpectateBtn.Visible = shouldShow
	if SpectateBtnBackground then SpectateBtnBackground.Visible = shouldShow end
end

local function setTarget(target, spectatorCount)
	currentTarget = target
	SpectatorsText.Text = "Spectators: " .. tostring(spectatorCount or 0)

	if target then
		local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end

		SpectatingText.Text = "Spectating: " .. target.Name
		UIAnimations.PopIn(SpectateFrame)
	else
		restoreOwnCamera()
		UIAnimations.PopOut(SpectateFrame)
	end

	updateButtonVisibility()
end

function SpectateController.Init()
	UIAnimations.InitializePopObject(SpectateFrame)
	UIAnimations.BindButtonAnimations(SpectateBtn)
	UIAnimations.BindButtonAnimations(ExitBtn)
	UIAnimations.BindButtonAnimations(LeftBtn)
	UIAnimations.BindButtonAnimations(RightBtn)

	SpectateBtn.Visible = false
	if SpectateBtnBackground then SpectateBtnBackground.Visible = false end

	local requestEvent = SpectateRemotes.GetRequestEvent()

	SpectateBtn.MouseButton1Click:Connect(function() requestEvent:FireServer("Start") end)
	ExitBtn.MouseButton1Click:Connect(function() requestEvent:FireServer("Stop") end)
	LeftBtn.MouseButton1Click:Connect(function() requestEvent:FireServer("Prev") end)
	RightBtn.MouseButton1Click:Connect(function() requestEvent:FireServer("Next") end)

	SpectateRemotes.GetUpdateEvent().OnClientEvent:Connect(setTarget)

	player:GetAttributeChangedSignal("InMenu"):Connect(updateButtonVisibility)
	player:GetAttributeChangedSignal("IsPlaying"):Connect(function()
		if player:GetAttribute("IsPlaying") == true and currentTarget then setTarget(nil) end
		updateButtonVisibility()
	end)

	player.CharacterAdded:Connect(function()
		if not currentTarget then task.defer(restoreOwnCamera) end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			updateButtonVisibility()
		end
	end)
end

return SpectateController
