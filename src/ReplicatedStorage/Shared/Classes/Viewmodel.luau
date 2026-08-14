local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Shared = ReplicatedStorage.Shared
local FXConfig = require(Shared.Modules.Core.FXConfig)
local FirstPersonRig = require(Shared.Classes.FirstPersonRig)

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

local WEAPON_MODEL_NAME = "ViewmodelWeapon"
local DEFAULT_PIVOT_Y = 0.5

local bindSerial = 0
local shared = nil
local registeredReloads = {}
local registeredHolds = {}

local function makeInert(instance)
	local function apply(part)
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
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

function Viewmodel.new(config)
	return setmetatable({
		weaponName = nil,
		weaponFolder = nil,
		gunModel = nil,
		handle = nil,
		rootJoints = {},
		weaponJoints = {},
		reloadTrack = nil,
		holdTrack = nil,
		pivotY = DEFAULT_PIVOT_Y,

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

function Viewmodel:ClearWeapon()
	if self.reloadTrack then
		self.reloadTrack:Stop(0)
		self.reloadTrack:Destroy()
		self.reloadTrack = nil
	end
	if self.holdTrack then
		self.holdTrack:Stop(0)
		self.holdTrack:Destroy()
		self.holdTrack = nil
	end
	for _, entry in self.rootJoints do
		if entry.motor.Parent then entry.motor:Destroy() end
	end
	table.clear(self.rootJoints)
	for _, joint in self.weaponJoints do
		if joint.Parent then joint:Destroy() end
	end
	table.clear(self.weaponJoints)
	if self.gunModel then
		self.gunModel:Destroy()
		self.gunModel = nil
	end
	local character = player.Character
	local stray = character and character:FindFirstChild(WEAPON_MODEL_NAME)
	if stray then stray:Destroy() end

	self.handle = nil
	self.weaponName = nil
	self.weaponFolder = nil
	self.muzzlePart = nil
	self.muzzleAttachment = nil
	self.muzzleLight = nil
	self.muzzleAlpha = 0
end

local function shoulderPivotY(character, humanoid)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return DEFAULT_PIVOT_Y end
	local shoulder
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		local upperArm = character:FindFirstChild("RightUpperArm")
		shoulder = upperArm and upperArm:FindFirstChild("RightShoulder")
	else
		local torso = character:FindFirstChild("Torso")
		shoulder = torso and torso:FindFirstChild("Right Shoulder")
	end
	if shoulder and shoulder.Part0 then
		local world = (shoulder.Part0.CFrame * shoulder.C0).Position
		local localPos = root.CFrame:PointToObjectSpace(world)
		if localPos.Y == localPos.Y then
			return math.clamp(localPos.Y, -1, 2)
		end
	end
	return DEFAULT_PIVOT_Y
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

local function loadSequenceTrack(weaponName, cache, sequence, trackName)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
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

function Viewmodel:_playHold()
	local folder = self.weaponFolder
	local sequence = folder and folder:FindFirstChild("Hold")
	if not sequence then return end
	local track = loadSequenceTrack(self.weaponName, registeredHolds, sequence, "ViewmodelHold")
	if not track then return end
	track.Priority = Enum.AnimationPriority.Action3
	track.Looped = true
	track:Play(0.1)
	self.holdTrack = track
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

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return false end

	self.weaponName = weaponName

	local folder = weaponDataFolder(weaponName)
	local weaponModel = folder and folder:FindFirstChild("WeaponModel")
	if not weaponModel then
		self:_findMuzzle(tool or equippedTool(weaponName))
		log("%s renders as the held tool", weaponName)
		return true
	end

	self.weaponFolder = folder
	self.pivotY = shoulderPivotY(character, humanoid)

	local gun = weaponModel:Clone()
	gun.Name = WEAPON_MODEL_NAME
	makeInert(gun)

	local handle = findPartNamed(gun, "Handle")
	if not handle then
		warn(string.format("[Viewmodel] %s's weapon model has no Handle", weaponName))
		gun:Destroy()
		return false
	end
	self.handle = handle

	local jointed = {}
	local joints = folder:FindFirstChild("Joints")
	if joints then
		for _, jointConfig in joints:GetChildren() do
			local part1 = findPartNamed(gun, jointConfig:GetAttribute("Part1") or jointConfig.Name)
			if part1 and not jointed[part1] then
				local motor = Instance.new("Motor6D")
				motor.Name = jointConfig.Name
				motor.C0 = jointConfig:GetAttribute("C0")
				motor.C1 = jointConfig:GetAttribute("C1")
				motor.Part1 = part1
				if jointConfig:GetAttribute("Part0") == "HumanoidRootPart" then
					motor.Part0 = root
					motor.Parent = root
					table.insert(self.rootJoints, { motor = motor, baseC0 = motor.C0 })
				else
					motor.Part0 = handle
					motor.Parent = handle
					table.insert(self.weaponJoints, motor)
				end
				jointed[part1] = true
			end
		end
	end

	if not jointed[handle] then
		warn(string.format("[Viewmodel] %s has no authored Handle joint - using a default hold", weaponName))
		local motor = Instance.new("Motor6D")
		motor.Name = "Handle"
		motor.C0 = CFrame.new(0, 0.2, -2)
		motor.Part0 = root
		motor.Part1 = handle
		motor.Parent = root
		table.insert(self.rootJoints, { motor = motor, baseC0 = motor.C0 })
		jointed[handle] = true
	end

	for _, part in gun:GetDescendants() do
		if part:IsA("BasePart") and part ~= handle and not jointed[part] then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = handle
		end
	end

	self.gunModel = gun
	gun.Parent = character

	self:_findMuzzle(gun)
	if not self.muzzlePart then
		self:_mapToolMuzzle(tool or equippedTool(weaponName), handle)
	end

	self:_playHold()

	log("%s: %d root joint(s), %d handle joint(s)", weaponName, #self.rootJoints, #self.weaponJoints)
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
	if not self.weaponName then return false end
	local folder = self.weaponFolder
	local sequence = folder and folder:FindFirstChild("Reload")
	if not sequence then return false end

	if not self.reloadTrack then
		local track = loadSequenceTrack(self.weaponName, registeredReloads, sequence, "ViewmodelReload")
		if not track then return false end
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped = false
		self.reloadTrack = track
	end

	self.reloadTrack:Stop(0.1)
	self.reloadTrack:Play(0.15)

	local length = self.reloadTrack.Length
	if length <= 0 then
		length = folder:GetAttribute("ReloadLength") or 0
	end
	if duration and duration > 0 and length > 0 then
		self.reloadTrack:AdjustSpeed(length / duration)
	end
	return true
end

function Viewmodel:StopReload()
	if self.reloadTrack then
		self.reloadTrack:Stop(0.2)
	end
end

function Viewmodel:Enable()
	if self.bindName then return end
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

	if self.gunModel and self.gunModel.Parent then
		local target = owned and 0 or 1
		for _, part in self.gunModel:GetDescendants() do
			if part:IsA("BasePart") and part.LocalTransparencyModifier ~= target then
				part.LocalTransparencyModifier = target
			end
		end

		local pitch = FirstPersonRig.GetPosePitch() + self.springPosition.X
		local pivot = CFrame.new(0, self.pivotY, 0)
			* CFrame.Angles(pitch, self.springPosition.Y, self.springPosition.Z)
			* CFrame.new(0, -self.pivotY, 0)
		for _, entry in self.rootJoints do
			if entry.motor.Parent then
				entry.motor.C0 = pivot * entry.baseC0
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
	if self.gunModel then
		for _, part in self.gunModel:GetDescendants() do
			if part:IsA("BasePart") then part.LocalTransparencyModifier = 1 end
		end
	end
	self.isSpringActive = false
	self.springPosition = Vector3.zero
	self.springVelocity = Vector3.zero
end

function Viewmodel:Destroy()
	self.destroyed = true
	self:Disable()
	self:ClearWeapon()
end

return Viewmodel
