local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Shared = ReplicatedStorage.Shared
local FXConfig = require(Shared.Modules.Core.FXConfig)

local function log(message, ...)
	if FXConfig.GunDebug then
		print("[Viewmodel] " .. string.format(message, ...))
	end
end

local Viewmodel = {}
Viewmodel.__index = Viewmodel

local player = Players.LocalPlayer

local RECOIL_STIFFNESS = 300
local RECOIL_DAMPING = 30

local MUZZLE_PART_NAME = "muzzle"
local MUZZLE_COLOR = Color3.fromRGB(255, 201, 120)
local MUZZLE_BRIGHTNESS = 7
local MUZZLE_RANGE = 16
local MUZZLE_DECAY = 14

local VIEWMODEL_MODEL_NAME = "FirstPersonViewmodel"
local WEAPON_MODEL_NAME = "ViewmodelWeapon"
local MOUNT_PART_NAME = "RightHandGunMount"
local MOUNT_PART_SIZE = Vector3.new(0.05, 0.05, 0.05)

local APPEARANCE_CLASSES = {
	BodyColors = true,
	CharacterMesh = true,
	Shirt = true,
	ShirtGraphic = true,
}

local bindSerial = 0
local shared = nil
local registeredReloads = {}

local function makeInert(instance)
	local function apply(part)
		part.CanCollide = false
		part.Massless = true

		part.Anchored = false
	end
	if instance:IsA("BasePart") then apply(instance) end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then apply(descendant) end
	end
end

local function normalize(name)
	return string.lower((string.gsub(name, "%s+$", "")))
end

local function findPartNamed(model, name)
	local exact = model:FindFirstChild(name, true)
	if exact and exact:IsA("BasePart") then return exact end
	local wanted = normalize(name)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and normalize(descendant.Name) == wanted then
			return descendant
		end
	end
	return nil
end

local function weaponDataFolder(weaponName)
	local dataRoot = ReplicatedStorage:FindFirstChild("WeaponViewmodelData")
	return dataRoot and dataRoot:FindFirstChild(weaponName)
end

local function equippedTool(weaponName)
	local character = player.Character
	local tool = character and character:FindFirstChild(weaponName)
	if tool and tool:IsA("Tool") then return tool end
	return nil
end

local function cloneRigPart(sourcePart)
	local clone = sourcePart:Clone()
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("JointInstance") or descendant:IsA("LuaSourceContainer") then
			descendant:Destroy()
		end
	end
	makeInert(clone)
	clone.LocalTransparencyModifier = 0
	return clone
end

local function sourceMotor(character, part0, part1)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part0 == part0 and descendant.Part1 == part1 then
			return descendant
		end
	end
	return nil
end

local function createArmMotor(root, arm, name)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.C0 = root.CFrame:ToObjectSpace(arm.CFrame)
	motor.C1 = CFrame.identity
	motor.Part0 = root
	motor.Part1 = arm
	motor.Parent = root
	return motor
end

local function mirrorArmPose(motor, sourceRoot, sourceArm)
	if not motor or not sourceRoot or not sourceArm then return end
	local relative = sourceRoot.CFrame:ToObjectSpace(sourceArm.CFrame)
	motor.Transform = motor.C0:Inverse() * relative * motor.C1
end

local function farthestLocalCorner(hand, root)
	local rootLocal = hand.CFrame:PointToObjectSpace(root.Position)
	local halfSize = hand.Size * 0.5
	local bestCorner = Vector3.zero
	local bestDistanceSquared = -math.huge
	for _, xSign in { -1, 1 } do
		for _, ySign in { -1, 1 } do
			for _, zSign in { -1, 1 } do
				local corner = Vector3.new(
					halfSize.X * xSign,
					halfSize.Y * ySign,
					halfSize.Z * zSign
				)
				local delta = corner - rootLocal
				local distanceSquared = delta:Dot(delta)
				if distanceSquared > bestDistanceSquared then
					bestDistanceSquared = distanceSquared
					bestCorner = corner
				end
			end
		end
	end
	return bestCorner, rootLocal
end

local function setLocalVisibility(container, value)
	if container:IsA("BasePart") or container:IsA("Decal") then
		container.LocalTransparencyModifier = value
	end
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = value
		end
	end
end

local function registeredIdFor(cache, key, sequence)
	local contentId = cache[key]
	if contentId then return contentId end
	local ok, result = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end)
	if not ok then
		warn(string.format("[Viewmodel] could not register a sequence for %s: %s", tostring(key), tostring(result)))
		return nil
	end
	cache[key] = result
	return result
end

local function loadSequenceTrack(animator, weaponName, cache, sequence, trackName)
	if not animator then return nil end
	local contentId = registeredIdFor(cache, weaponName, sequence)
	if not contentId then return nil end
	local animation = Instance.new("Animation")
	animation.Name = trackName
	animation.AnimationId = contentId
	local loaded, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not loaded then
		warn(string.format("[Viewmodel] could not load %s for %s: %s", trackName, tostring(weaponName), tostring(track)))
		return nil
	end
	return track
end

function Viewmodel.new(config)
	return setmetatable({
		sourceCharacter = nil,
		model = nil,
		humanoid = nil,
		animator = nil,
		poseAnimator = nil,
		root = nil,
		rightArm = nil,
		leftArm = nil,
		rightShoulder = nil,
		leftShoulder = nil,
		sourceRoot = nil,
		sourceRightArm = nil,
		sourceLeftArm = nil,
		mount = nil,
		mountLocalPosition = Vector3.zero,
		rootLocalFromHand = Vector3.zero,
		rigVisible = false,

		weaponName = nil,
		weaponFolder = nil,
		gunModel = nil,
		handle = nil,
		rootFollowerJoints = {},
		weaponJoints = {},
		reloadTrack = nil,
		reloadPoseTrack = nil,

		springPosition = Vector3.zero,
		springVelocity = Vector3.zero,
		isSpringActive = false,

		muzzlePart = nil,
		muzzleAttachment = nil,
		muzzleLight = nil,
		muzzleAlpha = 0,

		bindName = nil,
		destroyed = false,
	}, Viewmodel)
end

function Viewmodel.GetShared(config)
	if shared and not shared.destroyed then
		return shared
	end
	shared = Viewmodel.new(config)
	return shared
end

function Viewmodel.ClearShared()
	if shared then
		shared:Destroy()
		shared = nil
	end
end

function Viewmodel:_destroyRig()
	if self.model then
		self.model:Destroy()
	end
	self.sourceCharacter = nil
	self.model = nil
	self.humanoid = nil
	self.animator = nil
	self.poseAnimator = nil
	self.root = nil
	self.rightArm = nil
	self.leftArm = nil
	self.rightShoulder = nil
	self.leftShoulder = nil
	self.sourceRoot = nil
	self.sourceRightArm = nil
	self.sourceLeftArm = nil
	self.mount = nil
	self.mountLocalPosition = Vector3.zero
	self.rootLocalFromHand = Vector3.zero
	self.rigVisible = false
end

function Viewmodel:_buildRig()
	self:_destroyRig()

	local character = player.Character
	local sourceHumanoid = character and character:FindFirstChildOfClass("Humanoid")
	local sourceRoot = character and character:FindFirstChild("HumanoidRootPart")
	local sourceTorso = character and character:FindFirstChild("Torso")
	local sourceRightArm = character and character:FindFirstChild("Right Arm")
	local sourceLeftArm = character and character:FindFirstChild("Left Arm")
	if not character or not sourceHumanoid or sourceHumanoid.RigType ~= Enum.HumanoidRigType.R6 then
		warn("[Viewmodel] an R6 character is required")
		return false
	end
	if not sourceRoot or not sourceTorso or not sourceRightArm or not sourceLeftArm then
		warn("[Viewmodel] the R6 root, torso, and both arms are required")
		return false
	end

	local sourceRightShoulder = sourceMotor(character, sourceTorso, sourceRightArm)
	local sourceLeftShoulder = sourceMotor(character, sourceTorso, sourceLeftArm)
	if not sourceRightShoulder or not sourceLeftShoulder then
		warn("[Viewmodel] the R6 shoulder Motor6Ds are required")
		return false
	end

	local model = Instance.new("Model")
	model.Name = VIEWMODEL_MODEL_NAME

	local root = cloneRigPart(sourceRoot)
	local rightArm = cloneRigPart(sourceRightArm)
	local leftArm = cloneRigPart(sourceLeftArm)
	root.Parent = model
	rightArm.Parent = model
	leftArm.Parent = model

	root.Transparency = 1
	root.Anchored = true

	local rightShoulder = createArmMotor(root, rightArm, sourceRightShoulder.Name)
	local leftShoulder = createArmMotor(root, leftArm, sourceLeftShoulder.Name)

	local humanoid = sourceHumanoid:Clone()
	humanoid.Name = "Humanoid"
	humanoid.AutoRotate = false
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local poseAnimator = sourceHumanoid:FindFirstChildOfClass("Animator")
	if not poseAnimator then
		poseAnimator = Instance.new("Animator")
		poseAnimator.Parent = sourceHumanoid
	end

	for _, child in character:GetChildren() do
		if APPEARANCE_CLASSES[child.ClassName] then
			child:Clone().Parent = model
		end
	end

	local mountLocalPosition, rootLocalFromHand = farthestLocalCorner(rightArm, root)
	local mount = Instance.new("Part")
	mount.Name = MOUNT_PART_NAME
	mount.Size = MOUNT_PART_SIZE
	mount.Transparency = 0
	mount.LocalTransparencyModifier = 1
	mount.CanCollide = false
	mount.CanQuery = false
	mount.CanTouch = false
	mount.CastShadow = false
	mount.Massless = true
	mount.Anchored = false
	mount.CFrame = rightArm.CFrame * CFrame.new(mountLocalPosition)
	mount.Parent = model

	local mountWeld = Instance.new("WeldConstraint")
	mountWeld.Name = "HandMountWeld"
	mountWeld.Part0 = rightArm
	mountWeld.Part1 = mount
	mountWeld.Parent = mount

	model.PrimaryPart = root

	self.sourceCharacter = character
	self.model = model
	self.humanoid = humanoid
	self.animator = animator
	self.poseAnimator = poseAnimator
	self.root = root
	self.rightArm = rightArm
	self.leftArm = leftArm
	self.rightShoulder = rightShoulder
	self.leftShoulder = leftShoulder
	self.sourceRoot = sourceRoot
	self.sourceRightArm = sourceRightArm
	self.sourceLeftArm = sourceLeftArm
	self.mount = mount
	self.mountLocalPosition = mountLocalPosition
	self.rootLocalFromHand = rootLocalFromHand
	self.rigVisible = false

	setLocalVisibility(rightArm, 1)
	setLocalVisibility(leftArm, 1)

	log(
		"built R6 camera rig; root in right-arm space=%s, mount corner=%s",
		tostring(rootLocalFromHand),
		tostring(mountLocalPosition)
	)
	return true
end

function Viewmodel:_ensureRig()
	if self.model and self.sourceCharacter == player.Character then
		return true
	end
	return self:_buildRig()
end

function Viewmodel:_applyRigVisibility(visible)
	if self.rightArm then setLocalVisibility(self.rightArm, visible and 0 or 1) end
	if self.leftArm then setLocalVisibility(self.leftArm, visible and 0 or 1) end
end

function Viewmodel:_setRigVisible(visible)
	self.rigVisible = visible
	self:_applyRigVisibility(visible)
end

function Viewmodel:GetAnimator()
	if not self:_ensureRig() then return nil end
	return self.poseAnimator
end

function Viewmodel:GetMountData()
	return self.mountLocalPosition, self.rootLocalFromHand
end

function Viewmodel:ClearWeapon()
	if self.reloadTrack then
		self.reloadTrack:Stop(0)
		self.reloadTrack:Destroy()
		self.reloadTrack = nil
	end
	if self.reloadPoseTrack then
		self.reloadPoseTrack:Stop(0)
		self.reloadPoseTrack:Destroy()
		self.reloadPoseTrack = nil
	end
	for _, entry in self.rootFollowerJoints do
		if entry.motor.Parent then entry.motor:Destroy() end
	end
	table.clear(self.rootFollowerJoints)
	for _, joint in self.weaponJoints do
		if joint.Parent then joint:Destroy() end
	end
	table.clear(self.weaponJoints)
	if self.gunModel then
		self.gunModel:Destroy()
		self.gunModel = nil
	end

	self.handle = nil
	self.weaponName = nil
	self.weaponFolder = nil
	self.muzzlePart = nil
	self.muzzleAttachment = nil
	self.muzzleLight = nil
	self.muzzleAlpha = 0
	self:_setRigVisible(false)
end

function Viewmodel:_setupMuzzleLight(parent)
	local light = Instance.new("PointLight")
	light.Name = "MuzzleLight"
	light.Color = MUZZLE_COLOR
	light.Brightness = 0
	light.Range = MUZZLE_RANGE
	light.Shadows = false
	light.Enabled = false
	light.Parent = parent
	self.muzzleLight = light
end

function Viewmodel:_findMuzzle(container)
	if not container then return end
	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") and string.find(string.lower(descendant.Name), MUZZLE_PART_NAME, 1, true) then
			self.muzzlePart = descendant
			self:_setupMuzzleLight(descendant)
			log("muzzle light on %q", descendant.Name)
			return
		end
	end
end

function Viewmodel:_mapToolMuzzle(tool, handle)
	if not tool then return end
	local toolHandle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true)
	if not toolHandle then return end
	local muzzleWorld = nil
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("Attachment") and (descendant.Name == "MuzzlePoint" or descendant.Name == "Muzzle") then
			muzzleWorld = descendant.WorldPosition
			break
		end
	end
	if not muzzleWorld then
		for _, descendant in tool:GetDescendants() do
			if descendant:IsA("BasePart") and string.find(string.lower(descendant.Name), MUZZLE_PART_NAME, 1, true) then
				muzzleWorld = descendant.Position
				break
			end
		end
	end
	if not muzzleWorld then return end
	local attachment = Instance.new("Attachment")
	attachment.Name = "MuzzlePoint"
	attachment.Position = toolHandle.CFrame:PointToObjectSpace(muzzleWorld)
	attachment.Parent = handle
	self.muzzleAttachment = attachment
	self:_setupMuzzleLight(attachment)
end

function Viewmodel:SetWeapon(weaponName, config, tool)
	self:ClearWeapon()
	if not self:_ensureRig() then return false end

	self.weaponName = weaponName

	local folder = weaponDataFolder(weaponName)
	local weaponModel = folder and folder:FindFirstChild("WeaponModel")
	if not weaponModel then
		self:_findMuzzle(tool or equippedTool(weaponName))
		log("%s renders as the held tool", weaponName)
		return true
	end
	if not self.mount or not self.root then return false end

	self.weaponFolder = folder

	local gun = weaponModel:Clone()
	gun.Name = WEAPON_MODEL_NAME
	makeInert(gun)
	gun.Parent = self.model

	local boxCFrame, boxSize = gun:GetBoundingBox()
	local pivotDistance = (gun:GetPivot().Position - boxCFrame.Position).Magnitude
	if pivotDistance > math.max(10, boxSize.Magnitude * 2) then
		warn(string.format("[Viewmodel] %s pivot is %.2f studs from its bounds", weaponName, pivotDistance))
	end

	gun:PivotTo(self.mount.CFrame)

	local handle = findPartNamed(gun, "Handle")
	if not handle then
		warn(string.format("[Viewmodel] %s's weapon model has no Handle", weaponName))
		gun:Destroy()
		return false
	end

	self.gunModel = gun
	self.handle = handle

	local jointed = { [handle] = true }
	local rootFollowers = {}
	local joints = folder:FindFirstChild("Joints")
	if joints then
		for _, jointConfig in joints:GetChildren() do
			local part1 = findPartNamed(gun, jointConfig:GetAttribute("Part1") or jointConfig.Name)
			if part1 and part1 ~= handle and not jointed[part1] then
				if jointConfig:GetAttribute("Part0") == "HumanoidRootPart" then
					table.insert(rootFollowers, {
						config = jointConfig,
						part = part1,
						relative = handle.CFrame:ToObjectSpace(part1.CFrame),
					})
				else
					local motor = Instance.new("Motor6D")
					motor.Name = jointConfig.Name
					motor.C0 = jointConfig:GetAttribute("C0") or handle.CFrame:ToObjectSpace(part1.CFrame)
					motor.C1 = jointConfig:GetAttribute("C1") or CFrame.identity
					motor.Part0 = handle
					motor.Part1 = part1
					motor.Parent = handle
					table.insert(self.weaponJoints, motor)
				end
				jointed[part1] = true
			end
		end
	end

	for _, part in gun:GetDescendants() do
		if part:IsA("BasePart") and part ~= handle and not jointed[part] then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = handle
		end
	end

	local gunWeld = Instance.new("WeldConstraint")
	gunWeld.Name = "GunPivotWeld"
	gunWeld.Part0 = handle
	gunWeld.Part1 = self.mount
	gunWeld.Parent = handle

	for _, follower in rootFollowers do
		local motor = Instance.new("Motor6D")
		motor.Name = follower.config.Name
		motor.C1 = follower.config:GetAttribute("C1") or CFrame.identity
		motor.C0 = self.root.CFrame:ToObjectSpace(handle.CFrame * follower.relative) * motor.C1
		motor.Part0 = self.root
		motor.Part1 = follower.part
		motor.Parent = self.root
		table.insert(self.rootFollowerJoints, {
			motor = motor,
			relative = follower.relative,
		})
	end

	self:_findMuzzle(gun)
	if not self.muzzlePart then
		self:_mapToolMuzzle(tool or equippedTool(weaponName), handle)
	end

	self:_setRigVisible(true)
	log(
		"%s pivot aligned to hand mount; %d root follower(s), %d handle joint(s)",
		weaponName,
		#self.rootFollowerJoints,
		#self.weaponJoints
	)
	return true
end

function Viewmodel:GetMuzzlePosition()
	if self.muzzlePart and self.muzzlePart.Parent then
		return self.muzzlePart.Position
	end
	if self.muzzleAttachment and self.muzzleAttachment.Parent then
		return self.muzzleAttachment.WorldPosition
	end
	return nil
end

function Viewmodel:MuzzleFlash(scale)
	if not self.muzzleLight then return end
	self.muzzleAlpha = math.clamp(scale or 1, 0, 1)
end

function Viewmodel:applyRecoilImpulse(impulse)
	self.springVelocity = self.springVelocity + Vector3.new(
		math.rad(impulse.X),
		math.rad(impulse.Y),
		math.rad(impulse.Z)
	)
	self.isSpringActive = true
end

function Viewmodel:StartADS() end
function Viewmodel:StopADS() end

function Viewmodel:PlayReload(duration)
	if not self.weaponName or not self.animator then return false end
	local folder = self.weaponFolder
	local sequence = folder and folder:FindFirstChild("Reload")
	if not sequence then return false end

	if not self.reloadTrack then
		local track = loadSequenceTrack(self.animator, self.weaponName, registeredReloads, sequence, "ViewmodelReload")
		if not track then return false end
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped = false
		self.reloadTrack = track
	end
	if self.poseAnimator and not self.reloadPoseTrack then
		local track = loadSequenceTrack(self.poseAnimator, self.weaponName, registeredReloads, sequence, "CharacterReload")
		if track then
			track.Priority = Enum.AnimationPriority.Action4
			track.Looped = false
			self.reloadPoseTrack = track
		end
	end

	self.reloadTrack:Stop(0.1)
	self.reloadTrack:Play(0.15)
	if self.reloadPoseTrack then
		self.reloadPoseTrack:Stop(0.1)
		self.reloadPoseTrack:Play(0.15)
	end

	local length = self.reloadTrack.Length
	if length <= 0 then
		length = folder:GetAttribute("ReloadLength") or 0
	end
	if duration and duration > 0 and length > 0 then
		local speed = length / duration
		self.reloadTrack:AdjustSpeed(speed)
		if self.reloadPoseTrack then self.reloadPoseTrack:AdjustSpeed(speed) end
	end
	return true
end

function Viewmodel:StopReload()
	if self.reloadTrack then
		self.reloadTrack:Stop(0.2)
	end
	if self.reloadPoseTrack then
		self.reloadPoseTrack:Stop(0.2)
	end
end

function Viewmodel:Enable()
	if self.bindName then return end
	if not self:_ensureRig() then return end

	local camera = Workspace.CurrentCamera
	if not camera then return end
	self.model.Parent = camera
	self.model:PivotTo(camera.CFrame)

	bindSerial += 1
	self.bindName = "Viewmodel_" .. bindSerial
	RunService:BindToRenderStep(self.bindName, Enum.RenderPriority.Camera.Value + 3, function(dt)
		self:_update(dt)
	end)
	log("enabled (holding: %s)", self.weaponName or "nothing")
end

function Viewmodel:_update(dt)
	local owned = player:GetAttribute("GunCameraActive") == true

	if self.isSpringActive then
		if self.springPosition.Magnitude < 0.001 and self.springVelocity.Magnitude < 0.001 then
			self.isSpringActive = false
			self.springPosition = Vector3.zero
			self.springVelocity = Vector3.zero
		else
			local force = -RECOIL_STIFFNESS * self.springPosition
			local damping = -RECOIL_DAMPING * self.springVelocity
			self.springVelocity = self.springVelocity + (force + damping) * dt
			self.springPosition = self.springPosition + self.springVelocity * dt
		end
	end

	local camera = Workspace.CurrentCamera
	if self.model and camera then
		if self.model.Parent ~= camera then
			self.model.Parent = camera
		end
		local recoil = CFrame.Angles(self.springPosition.X, self.springPosition.Y, self.springPosition.Z)
		self.model:PivotTo(camera.CFrame * recoil)
		mirrorArmPose(self.rightShoulder, self.sourceRoot, self.sourceRightArm)
		mirrorArmPose(self.leftShoulder, self.sourceRoot, self.sourceLeftArm)
		self:_applyRigVisibility(owned and self.rigVisible)
	end

	if self.gunModel and self.gunModel.Parent then
		local target = owned and 0 or 1
		for _, part in self.gunModel:GetDescendants() do
			if part:IsA("BasePart") and part.LocalTransparencyModifier ~= target then
				part.LocalTransparencyModifier = target
			end
		end

		if self.root and self.handle then
			for _, entry in self.rootFollowerJoints do
				if entry.motor.Parent then
					entry.motor.C0 = self.root.CFrame:ToObjectSpace(self.handle.CFrame * entry.relative) * entry.motor.C1
				end
			end
		end
	end

	if self.muzzleLight then
		if self.muzzleAlpha > 0 and owned then
			self.muzzleAlpha = math.max(0, self.muzzleAlpha - dt * MUZZLE_DECAY)
			self.muzzleLight.Brightness = MUZZLE_BRIGHTNESS * self.muzzleAlpha
			self.muzzleLight.Range = MUZZLE_RANGE * (0.55 + 0.45 * self.muzzleAlpha)
			self.muzzleLight.Enabled = self.muzzleAlpha > 0.01
		elseif self.muzzleLight.Enabled then
			self.muzzleLight.Enabled = false
		end
	end
end

function Viewmodel:Disable()
	if self.bindName then
		pcall(RunService.UnbindFromRenderStep, RunService, self.bindName)
		self.bindName = nil
	end
	if self.model then
		self:_applyRigVisibility(false)
		self.model.Parent = nil
	end
	self.isSpringActive = false
	self.springPosition = Vector3.zero
	self.springVelocity = Vector3.zero
end

function Viewmodel:Destroy()
	self.destroyed = true
	self:Disable()
	self:ClearWeapon()
	self:_destroyRig()
end

return Viewmodel
