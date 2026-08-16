local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsController = require(ReplicatedStorage.Shared.UIControllers.SettingsController)

local CameraFX = {}

local camera = Workspace.CurrentCamera

local RECOIL_STIFFNESS = 300
local RECOIL_DAMPING = 15

local KICK_MULTIPLIER = 22

local springPosition = Vector3.zero
local springVelocity = Vector3.zero
local springActive = false

local function updateRecoilSpring(dt)
	camera.CFrame = camera.CFrame * CFrame.Angles(springPosition.X, springPosition.Y, springPosition.Z):Inverse()

	if springPosition.Magnitude < 0.001 and springVelocity.Magnitude < 0.001 then
		springActive = false
		springPosition = Vector3.zero
		springVelocity = Vector3.zero
		RunService:UnbindFromRenderStep("CameraFXRecoil")
		return
	end

	local force = -RECOIL_STIFFNESS * springPosition
	local damping = -RECOIL_DAMPING * springVelocity
	springVelocity = springVelocity + (force + damping) * dt
	springPosition = springPosition + springVelocity * dt

	camera.CFrame = camera.CFrame * CFrame.Angles(springPosition.X, springPosition.Y, springPosition.Z)
end

function CameraFX.Recoil(kickDegrees)
	if not SettingsController.GetValue("Camera Shake") then return end

	camera.FieldOfView += math.min(kickDegrees.X * 0.5, 4)

	springVelocity = springVelocity + Vector3.new(
		math.rad(kickDegrees.X),
		math.rad(kickDegrees.Y),
		math.rad(kickDegrees.Z)
	) * KICK_MULTIPLIER

	if not springActive then
		springActive = true
		RunService:BindToRenderStep("CameraFXRecoil", Enum.RenderPriority.Camera.Value + 10, updateRecoilSpring)
	end
end

local activeShakes = {}
local shakeLoopRunning = false
local previousShakeCFrame = CFrame.new()

local function updateShake(dt)
	local total = CFrame.new()

	for id, shake in pairs(activeShakes) do
		local decayAlpha = math.clamp(1 - (1 - shake.DecayRate) ^ (dt * 60), 0, 1)
		shake.Magnitude = shake.Magnitude:Lerp(Vector3.zero, decayAlpha)
		shake.TimeLeft -= dt

		if shake.TimeLeft <= 0 or shake.Magnitude.Magnitude < 0.01 then
			activeShakes[id] = nil
		else
			total = total * CFrame.Angles(
				math.rad(shake.Magnitude.X),
				math.rad(shake.Magnitude.Y),
				math.rad(shake.Magnitude.Z)
			)
		end
	end

	camera.CFrame = camera.CFrame * previousShakeCFrame:Inverse() * total
	previousShakeCFrame = total

	if not next(activeShakes) then
		shakeLoopRunning = false
		previousShakeCFrame = CFrame.new()
		RunService:UnbindFromRenderStep("CameraFXShake")
	end
end

function CameraFX.Shake(magnitudeDegrees, duration, decayRate)
	if not SettingsController.GetValue("Camera Shake") then return end

	table.insert(activeShakes, {
		Magnitude = magnitudeDegrees,
		TimeLeft = duration,
		DecayRate = decayRate or 0.85,
	})

	if not shakeLoopRunning then
		shakeLoopRunning = true
		previousShakeCFrame = CFrame.new()
		RunService:BindToRenderStep("CameraFXShake", Enum.RenderPriority.Camera.Value + 5, updateShake)
	end
end

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local AIM_VIGNETTE_COLOR = Color3.fromRGB(0, 0, 0)
local AIM_VIGNETTE_TRANSPARENCY = 0.45
local AIM_VIGNETTE_FADE_IN = 0.12
local AIM_VIGNETTE_FADE_OUT = 0.1

local AIM_VIGNETTE_EDGES = {
	{ position = UDim2.fromScale(0, 0), size = UDim2.fromScale(1, 0.3), rotation = 90 },
	{ position = UDim2.fromScale(0, 0.7), size = UDim2.fromScale(1, 0.3), rotation = -90 },
	{ position = UDim2.fromScale(0, 0), size = UDim2.fromScale(0.22, 1), rotation = 0 },
	{ position = UDim2.fromScale(0.78, 0), size = UDim2.fromScale(0.22, 1), rotation = 180 },
}

local aimVignetteFrames = nil

local function buildAimVignette()
	local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return false end

	local existing = playerGui:FindFirstChild("AimVignette")
	if existing then existing:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AimVignette"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	aimVignetteFrames = {}

	for _, edge in AIM_VIGNETTE_EDGES do
		local frame = Instance.new("Frame")
		frame.Position = edge.position
		frame.Size = edge.size
		frame.BackgroundColor3 = AIM_VIGNETTE_COLOR
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Parent = gui

		local gradient = Instance.new("UIGradient")
		gradient.Rotation = edge.rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame

		table.insert(aimVignetteFrames, frame)
	end

	return true
end

local function setAimVignette(active)
	if not aimVignetteFrames or not aimVignetteFrames[1] or not aimVignetteFrames[1].Parent then
		if not buildAimVignette() then return end
	end

	local target = active and AIM_VIGNETTE_TRANSPARENCY or 1
	local duration = active and AIM_VIGNETTE_FADE_IN or AIM_VIGNETTE_FADE_OUT

	for _, frame in aimVignetteFrames do
		TweenService:Create(frame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = target,
		}):Play()
	end
end

function CameraFX.SetAim(fov)
	if localPlayer then
		localPlayer:SetAttribute("AimFOV", fov)
	end
	setAimVignette(true)
end

function CameraFX.ClearAim()
	if localPlayer then
		localPlayer:SetAttribute("AimFOV", nil)
	end
	setAimVignette(false)
end

function CameraFX.IsAiming()
	return localPlayer ~= nil and localPlayer:GetAttribute("AimFOV") ~= nil
end

local fireBlur = nil

function CameraFX.FirePulse(size)
	if not SettingsController.GetValue("Camera Shake") then return end

	if not fireBlur or not fireBlur.Parent then
		fireBlur = Instance.new("BlurEffect")
		fireBlur.Name = "CameraFXFireBlur"
		fireBlur.Size = 0
		fireBlur.Parent = Lighting
	end

	fireBlur.Size = size or 6
	TweenService:Create(fireBlur, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = 0}):Play()
end

return CameraFX
