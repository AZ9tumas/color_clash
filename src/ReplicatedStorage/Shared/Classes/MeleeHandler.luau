local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HapticService = game:GetService("HapticService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Items: Types.WeaponCatalog = require(Shared.Modules.Core.Items)
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

local function loadTrack(animator, animId, priority, trackName)
	local anim = Instance.new("Animation")
	anim.Name = trackName or "MeleeAnimation"
	anim.AnimationId = animId
	local track = animator:LoadAnimation(anim)
	anim:Destroy()
	track.Priority = priority
	return track
end

-- The melee set is stock R6 character animation, so it is loaded twice: once on
-- the real character, which replicates so other players see the swing, and once
-- on the viewmodel, which is the only thing the local player can actually see now
-- that the character is hidden during a round.
-- swingOnly is used for the viewmodel: its resting pose comes from the melee hold
-- (ViewmodelSettings.AnimationIds.MeleeHold) at Action2, and the movement set sits
-- at Action3, so loading it there would mask the hold entirely. The character still
-- gets the full set, which is what replicates to other players.
local function loadTrackSet(animator, anims, rigTypeName, into, label, swingOnly)
	if not animator or not anims then return end

	local ok, err = pcall(function()
		if anims.Idle and not swingOnly then
			into.Idle = loadTrack(animator, anims.Idle, Enum.AnimationPriority.Action3, "MeleeIdle")
			into.Idle.Looped = true
		end
		if anims.Walk and not swingOnly then
			into.Walk = loadTrack(animator, anims.Walk, Enum.AnimationPriority.Action3, "MeleeWalk")
			into.Walk.Looped = true
		end
		if anims.Sprint and not swingOnly then
			into.Sprint = loadTrack(animator, anims.Sprint, Enum.AnimationPriority.Action3, "MeleeSprint")
			into.Sprint.Looped = true
		end
		if anims.Swing then
			local id = anims.Swing[rigTypeName]
			if id then
				into.Swing = loadTrack(animator, id, Enum.AnimationPriority.Action4, "MeleeSwing")
			end
		end
	end)

	if not ok then
		warn(string.format("[Melee] %s animations failed: %s", label, tostring(err)))
	end
end

function MeleeHandler.New(tool: Tool?)
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
		tracks = {} :: Types.AnimationTrackSet,
		viewTracks = {} :: Types.AnimationTrackSet,
		activeMoveTrack = nil,
		activeViewMoveTrack = nil,
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
	local viewSwingTrack = self.viewTracks.Swing

	local cooldown = self.Properties.Cooldown
	local reference = swingTrack or viewSwingTrack
	if reference and reference.Length > 0 then
		cooldown = reference.Length + 0.2
	end
	if tick() - self.lastSwing < cooldown then return end
	self.lastSwing = tick()

	if swingTrack then
		swingTrack:Stop(0)
		swingTrack:Play(0.05)
	end
	if viewSwingTrack then
		viewSwingTrack:Stop(0)
		viewSwingTrack:Play(0.05)
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

	self.viewmodel = Viewmodel.GetShared()
	if self.viewmodel then
		self.viewmodel:SetWeapon(self.tool.Name, nil, self.tool)
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

	local charAnimator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	loadTrackSet(charAnimator, anims, humanoid and humanoid.RigType.Name or "R6", self.tracks, self.tool.Name)

	local viewAnimator = self.viewmodel and self.viewmodel:GetAnimator()
	local viewHumanoid = self.viewmodel and self.viewmodel.model:FindFirstChildOfClass("Humanoid")
	loadTrackSet(
		viewAnimator,
		anims,
		viewHumanoid and viewHumanoid.RigType.Name or "R6",
		self.viewTracks,
		self.tool.Name .. " viewmodel",
		true -- swing only; the melee hold owns the viewmodel's resting pose
	)

	-- Start the idle here rather than waiting for the heartbeat below, which
	-- early-returns until the character has a root. Nothing else poses a melee
	-- weapon now that the rifle hold no longer stands in for one.
	self.currentMoveAnim = "Idle"
	self.activeMoveTrack = self.tracks.Idle
	self.activeViewMoveTrack = self.viewTracks.Idle
	if self.activeMoveTrack then self.activeMoveTrack:Play(0.15) end
	if self.activeViewMoveTrack then self.activeViewMoveTrack:Play(0.15) end

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
			if self.activeViewMoveTrack then self.activeViewMoveTrack:Stop(0.25) end

			self.activeMoveTrack = self.tracks[desired] or self.tracks.Idle
			self.activeViewMoveTrack = self.viewTracks[desired] or self.viewTracks.Idle

			if self.activeMoveTrack then self.activeMoveTrack:Play(0.25) end
			if self.activeViewMoveTrack then self.activeViewMoveTrack:Play(0.25) end
		end
	end)

	log("%s equipped", self.tool.Name)
end

function melee:Unequip()
	self.isEquipped = false

	if self.moveAnimConn then
		self.moveAnimConn:Disconnect()
		self.moveAnimConn = nil
	end

	-- The viewmodel is shared across weapons, so its melee tracks must be released
	-- here: a looping Idle left running at Action3 would override the next
	-- weapon's pose. Destroy after the fade so the stop still looks smooth.
	local function releaseSet(set)
		local pending = {}
		for name, track in pairs(set) do
			track:Stop(0.15)
			table.insert(pending, track)
			set[name] = nil
		end
		if #pending > 0 then
			task.delay(0.2, function()
				for _, track in ipairs(pending) do
					track:Destroy()
				end
			end)
		end
	end

	releaseSet(self.tracks)
	releaseSet(self.viewTracks)

	self.activeMoveTrack = nil
	self.activeViewMoveTrack = nil
	self.currentMoveAnim = nil

	if self.viewmodel then
		self.viewmodel:ClearWeapon()
		self.viewmodel = nil
	end

	MainHudController.SetWeaponInfo("N/A", "N/A")
end

function melee:Destroy()
	self:Unequip()
end

return MeleeHandler
