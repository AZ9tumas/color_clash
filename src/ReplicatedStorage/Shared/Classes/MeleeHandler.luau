local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HapticService = game:GetService("HapticService")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Modules.Core.Items)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local RaycastUtil = require(Shared.Modules.Utils.RaycastUtil)
local CameraFX = require(Shared.Modules.Utils.CameraFX)
local SettingsController = require(Shared.UIControllers.SettingsController)
local MainHudController = require(Shared.UIControllers.MainHudController)
local FirstPersonRig = require(Shared.Classes.FirstPersonRig)
local Viewmodel = require(Shared.Classes.Viewmodel)
local FXConfig = require(Shared.Modules.Core.FXConfig)

local function log(message, ...)
	if FXConfig.GunDebug then
		print("[Melee] " .. string.format(message, ...))
	end
end

local MeleeHandler = {}
local melee = {}
melee.__index = melee

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local ToolConnections = CombatRemotes.GetToolConnections()

local SWING_SOUNDS = {
	Axe = "rbxassetid://140650136639350",
	Bat = "rbxassetid://79459251446203",
	Default = "rbxassetid://140553108821312",
}

local function swingSoundId(name)
	if string.find(name, "Axe") then return SWING_SOUNDS.Axe end
	if string.find(name, "Bat") then return SWING_SOUNDS.Bat end
	return SWING_SOUNDS.Default
end

local function loadTrack(humanoid, animId, priority)
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid
	local track = animator:LoadAnimation(anim)
	track.Priority = priority
	return track
end

function MeleeHandler.New(tool)
	if not tool then return nil end
	local data = Items[tool.Name]
	if not data or data.MaxAmmo then return nil end

	return setmetatable({
		tool = tool,
		Properties = data,
		isEquipped = false,
		lastSwing = 0,
		rig = FirstPersonRig.GetShared(),
		viewmodel = nil,
		tracks = {},
		activeMoveTrack = nil,
		currentMoveAnim = nil,
		moveAnimConn = nil,
	}, melee)
end

function melee:getTargetPosition()
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
	local ignoreList = { player.Character }
	local debrisFolder = Workspace:FindFirstChild("WallDebrisFolder")
	if debrisFolder then table.insert(ignoreList, debrisFolder) end
	local result = RaycastUtil.CastWithIgnore(origin, direction, 1000, ignoreList, {"RepairP", "Repair"})
	return result and result.Position or origin + direction * 1000
end

function melee:Swing()
	if not self.isEquipped then return end

	local swingTrack = self.tracks.Swing
	local cooldown = self.Properties.Cooldown
	if swingTrack and swingTrack.Length > 0 then
		cooldown = swingTrack.Length + 0.2
	end
	if tick() - self.lastSwing < cooldown then return end
	self.lastSwing = tick()

	if swingTrack then
		swingTrack:Stop(0)
		swingTrack:Play(0.05)
	end

	local handle = self.tool:FindFirstChild("Handle") or self.tool:FindFirstChildWhichIsA("BasePart", true)
	local sound = handle and handle:FindFirstChild("MeleeSwingSound")
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end

	local intensity = self.Properties.Shake and self.Properties.Shake.Intensity or 0.4
	CameraFX.Recoil(Vector3.new(-0.9 * (0.5 + intensity), 0, 0))

	if SettingsController.GetValue("Controller Vibration") then
		pcall(function()
			if HapticService:IsMotorSupported(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small) then
				HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, math.min(1, intensity * 0.4))
				task.delay(0.15, function()
					HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
				end)
			end
		end)
	end

	ToolConnections:FireServer(self.tool.Name, self:getTargetPosition(), false)
	log("%s swing", self.tool.Name)
end

function melee:Equip()
	self.isEquipped = true

	self.viewmodel = Viewmodel.GetShared(self.Properties.Viewmodel)
	if self.viewmodel then
		self.viewmodel:SetWeapon(self.tool.Name, self.Properties.Viewmodel, self.tool)
	end

	MainHudController.SetWeaponInfo(self.tool.Name, "N/A")

	local handle = self.tool:FindFirstChild("Handle") or self.tool:FindFirstChildWhichIsA("BasePart", true)
	if handle and not handle:FindFirstChild("MeleeSwingSound") then
		local sfx = Instance.new("Sound")
		sfx.Name = "MeleeSwingSound"
		sfx.SoundId = swingSoundId(self.tool.Name)
		sfx.Volume = 1
		sfx.Parent = handle
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local anims = self.Properties.Animations

	if humanoid and anims then
		local ok, err = pcall(function()
			if anims.Idle then
				self.tracks.Idle = loadTrack(humanoid, anims.Idle, Enum.AnimationPriority.Action3)
				self.tracks.Idle.Looped = true
			end
			if anims.Walk then
				self.tracks.Walk = loadTrack(humanoid, anims.Walk, Enum.AnimationPriority.Action3)
				self.tracks.Walk.Looped = true
			end
			if anims.Sprint then
				self.tracks.Sprint = loadTrack(humanoid, anims.Sprint, Enum.AnimationPriority.Action3)
				self.tracks.Sprint.Looped = true
			end
			if anims.Swing then
				local id = anims.Swing[humanoid.RigType.Name]
				if id then
					self.tracks.Swing = loadTrack(humanoid, id, Enum.AnimationPriority.Action4)
				end
			end
		end)
		if not ok then
			warn(string.format("[Melee] animations failed for %q: %s", self.tool.Name, tostring(err)))
		end
	end

	self.moveAnimConn = RunService.Heartbeat:Connect(function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root or not self.isEquipped then return end

		local flatSpeed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		local moveState = player:GetAttribute("MovementState") or "Walk"
		local desired = "Idle"
		if flatSpeed > 0.5 then
			if moveState == "Sprint" and flatSpeed > 1 then
				desired = "Sprint"
			else
				desired = "Walk"
			end
		end

		if self.currentMoveAnim ~= desired then
			self.currentMoveAnim = desired
			if self.activeMoveTrack then self.activeMoveTrack:Stop(0.25) end
			self.activeMoveTrack = self.tracks[desired] or self.tracks.Idle
			if self.activeMoveTrack then self.activeMoveTrack:Play(0.25) end
		end
	end)

	log("%s equipped", self.tool.Name)
end

function melee:Unequip()
	self.isEquipped = false

	if self.viewmodel then
		self.viewmodel:ClearWeapon()
		self.viewmodel = nil
	end

	if self.moveAnimConn then
		self.moveAnimConn:Disconnect()
		self.moveAnimConn = nil
	end
	for _, track in pairs(self.tracks) do
		track:Stop(0.15)
	end
	table.clear(self.tracks)
	self.activeMoveTrack = nil
	self.currentMoveAnim = nil

	MainHudController.SetWeaponInfo("N/A", "N/A")
end

function melee:Destroy()
	self:Unequip()
end

return MeleeHandler
