local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local gunInfo = require(script.Parent.GunInfo)
local viewmodelHandler = require(script.Parent.ViewModelHandler)
local ViewmodelSettings = require(script.Parent.ViewmodelSettings)
local FXUtil = require(ReplicatedStorage.Shared.Modules.Utils.FXUtil)

local MUZZLE_ATTACHMENT_NAMES = { "ProjectileStart", "MuzzlePoint", "Muzzle" }
local EJECT_ATTACHMENT_NAMES = { "EjectPort", "ShellEject", "ShellPort" }

-- AnimationTrack:Destroy() does NOT stop playback, and destroying straight after
-- Stop() cancels the fade - the track then plays forever on the shared Animator.
-- That is how two ViewmodelHold tracks used to end up blended together after a
-- weapon swap, skewing the whole rig. Let the fade finish before destroying.
local function releaseTrack(track: AnimationTrack?, fade: number?)
	if not track then return end
	local fadeTime = fade or 0.1
	track:Stop(fadeTime)
	task.delay(fadeTime + 0.05, function()
		track:Destroy()
	end)
end

local handler = {}
local gun = {}
local controllers = setmetatable({}, {__mode = "k"})
local VIEWMODEL_COLLISION_GROUP = "Viewmodel"

-- KeyframeSequences authored in Studio have no AnimationId, so they have to be
-- registered per client before an Animator can load them. Registration is
-- expensive, so cache the content id against the sequence instance.
local registeredSequences = setmetatable({}, {__mode = "k"})

local function registerSequence(sequence: KeyframeSequence): string?
	local cached = registeredSequences[sequence]
	if cached then return cached end

	local ok, contentId = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end)
	if not ok then
		warn(string.format(
			"[ViewmodelAnimation] Could not register %s: %s",
			sequence:GetFullName(),
			tostring(contentId)
		))
		return nil
	end

	registeredSequences[sequence] = contentId
	return contentId
end

local function contentIdFor(source): string?
	if typeof(source) == "string" then
		return source ~= "" and source or nil
	end
	if typeof(source) ~= "Instance" then
		return nil
	end
	if source:IsA("Animation") then
		return source.AnimationId ~= "" and source.AnimationId or nil
	end
	if source:IsA("KeyframeSequence") then
		return registerSequence(source)
	end
	return nil
end

-- Authored part names carry trailing spaces ("Reolader ", "Magzaine "), so joint
-- configs are matched leniently against the weapon model.
local function normalize(name: string): string
	return string.lower((string.gsub(name, "%s+$", "")))
end

local function findPartNamed(model: Instance, name: string): BasePart?
	local exact = model:FindFirstChild(name, true)
	if exact and exact:IsA("BasePart") then return exact end

	local wanted = normalize(name)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and normalize(descendant.Name) == wanted then
			return descendant
		end
	end
	return nil
end

local function weaponDataFolder(weaponName: string): Folder?
	local dataRoot = ReplicatedStorage:FindFirstChild("WeaponViewmodelData")
	local folder = dataRoot and dataRoot:FindFirstChild(weaponName)
	return folder and folder:IsA("Folder") and folder or nil
end

local function makeInert(model: Instance)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = VIEWMODEL_COLLISION_GROUP
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.CastShadow = false
			descendant.Anchored = false
		end
	end
end

local function constraintParts(instance)
	if instance:IsA("WeldConstraint") or instance:IsA("JointInstance") then
		return instance.Part0, instance.Part1
	end
	return nil, nil
end

-- A part driven by an authored Motor6D must not also be rigidly welded to the
-- Handle, or the reload cannot move it. Those welds are DISABLED, never destroyed:
-- the weapon keeps every weld it shipped with, and re-enabling one is a single
-- property. Welds that touch nothing motorised are left completely alone.
local function disableConflictingWelds(model: Instance, motorised: { [BasePart]: boolean }, handle: BasePart)
	local disabled = 0
	if disabled == 0 then return disabled end

	for _, descendant in ipairs(model:GetDescendants()) do
		local p0, p1 = constraintParts(descendant)
		if (p0 or p1) and descendant.Enabled then
			local conflicts = (p0 and p0 ~= handle and motorised[p0])
				or (p1 and p1 ~= handle and motorised[p1])
			if conflicts then
				descendant.Enabled = false
				disabled += 1
			end
		end
	end
	return disabled
end

local function findNamed(model: Instance, names: { string })
	for _, wanted in ipairs(names) do
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("Attachment") and descendant.Name == wanted then
				return descendant
			end
		end
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and string.find(string.lower(descendant.Name), "muzzle", 1, true) then
			return descendant
		end
	end
	return nil
end

local function worldPositionOf(instance): Vector3?
	if not instance or not instance.Parent then return nil end
	if instance:IsA("Attachment") then return instance.WorldPosition end
	if instance:IsA("BasePart") then return instance.Position end
	return nil
end

-- Anything left with no working constraint would float free, so it gets welded to
-- the Handle. Parts the Tool already welds are skipped: we add, never replace.
local function connectLooseParts(model: Instance, handle: BasePart, motorised: { [BasePart]: boolean })
	if true then return 0 end
	local constrained = { [handle] = true }
	for part in pairs(motorised) do constrained[part] = true end

	for _, descendant in ipairs(model:GetDescendants()) do
		local p0, p1 = constraintParts(descendant)
		if (p0 or p1) and descendant.Enabled then
			if p0 then constrained[p0] = true end
			if p1 then constrained[p1] = true end
		end
	end

	local added = 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and not constrained[part] then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "ViewmodelWeld"
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = handle
			constrained[part] = true
			added += 1
		end
	end
	return added
end

function handler.New(gunModel: Tool, sharedViewModel)
	local info = gunInfo[gunModel.Name]
	if not info then
		warn("Missing viewmodel metadata for", gunModel.Name)
		return nil
	end

	local newgun = {
		gunModel = gunModel,
		clonedGun = nil,
		viewModel = sharedViewModel or viewmodelHandler.new(Vector3.zero),
		ownsViewModel = sharedViewModel == nil,
		Properties = info,
		dataFolder = weaponDataFolder(gunModel.Name),
		tracks = {},
		createdJoints = {},
		muzzle = nil,
		ejectPort = nil,
		muzzleFX = nil,
	}

	controllers[newgun] = true
	return setmetatable(newgun, {__index = gun})
end

function gun:_loadTrack(source, trackName: string): AnimationTrack?
	local contentId = contentIdFor(source)
	if not contentId then return nil end

	local animator = self.viewModel:GetAnimator()
	if not animator then
		warn("[ViewmodelAnimation] Viewmodel rig has no Animator")
		return nil
	end

	local animation = Instance.new("Animation")
	animation.Name = trackName
	animation.AnimationId = contentId
	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()

	if not success then
		warn(string.format(
			"[ViewmodelAnimation] Could not load %s for %s: %s",
			trackName,
			self.gunModel.Name,
			tostring(track)
		))
		return nil
	end
	return track
end

-- Authored KeyframeSequences win over uploaded Tool animations, which win over
-- the shared fallback id in GunInfo.
function gun:_holdSource()
	local sequence = self.dataFolder and self.dataFolder:FindFirstChild("Hold")
	if sequence and sequence:IsA("KeyframeSequence") then return sequence end

	local source = self.clonedGun or self.gunModel
	local animation = source and source:FindFirstChild("Hold")
	if animation and animation:IsA("Animation") and animation.AnimationId ~= "" then
		return animation
	end

	-- Melee now carries its own Handle-hold id (GunInfo.MELEE_HOLD_ANIMATION_ID)
	-- rather than the rifle-shaped WeaponAction one, so this fallback is correct
	-- for both weapon types.
	return self.Properties.HoldAnimationId
end

function gun:_reloadSource()
	local sequence = self.dataFolder and self.dataFolder:FindFirstChild("Reload")
	if sequence and sequence:IsA("KeyframeSequence") then return sequence end

	local source = self.clonedGun or self.gunModel
	local animation = source and source:FindFirstChild("Reload")
	if animation and animation:IsA("Animation") and animation.AnimationId ~= "" then
		return animation
	end
	return nil
end

function gun:_shootSource()
	local sequence = self.dataFolder and self.dataFolder:FindFirstChild("Shoot")
	if sequence and sequence:IsA("KeyframeSequence") then return sequence end

	local source = self.clonedGun or self.gunModel
	local animation = source and source:FindFirstChild("Shoot")
	if animation and animation:IsA("Animation") and animation.AnimationId ~= "" then
		return animation
	end
	return nil
end

function gun:_track(name: string, source, priority: Enum.AnimationPriority, looped: boolean): AnimationTrack?
	local existing = self.tracks[name]
	if existing then return existing end
	if not source then return nil end

	local track = self:_loadTrack(source, "Viewmodel" .. name)
	if not track then return nil end

	track.Priority = priority
	track.Looped = looped
	self.tracks[name] = track
	return track
end

function gun:PlayHoldAnimation()
	if not ViewmodelSettings.AnimationsEnabled then return false, "DISABLED" end
	if not self.clonedGun then return false, "EQUIP A WEAPON" end

	local track = self:_track("Hold", self:_holdSource(), Enum.AnimationPriority.Action2, true)
	if not track then return false, "UNAVAILABLE" end

	if not track.IsPlaying then
		track:Play(0.1)
	end
	return true, "PLAYING"
end

function gun:PlayShootAnimation()
	if not ViewmodelSettings.AnimationsEnabled then return false, "DISABLED" end
	if not self.clonedGun then return false, "EQUIP A WEAPON" end

	local track = self:_track("Shoot", self:_shootSource(), Enum.AnimationPriority.Action3, false)
	if not track then return false, "UNAVAILABLE" end

	track:Stop(0)
	track:Play(0.03)
	return true, "PLAYING"
end

function gun:PlayReloadAnimation(duration: number?)
	if not ViewmodelSettings.AnimationsEnabled then return false, "DISABLED" end
	if not self.clonedGun then return false, "EQUIP A WEAPON" end

	local track = self:_track("Reload", self:_reloadSource(), Enum.AnimationPriority.Action4, false)
	if not track then return false, "UNAVAILABLE" end

	track:Stop(0.1)
	track:Play(0.15)

	-- Length reads 0 until the asset resolves; the exporter stamps the authored
	-- duration on the weapon folder for exactly this case.
	local length = track.Length
	if length <= 0 and self.dataFolder then
		length = self.dataFolder:GetAttribute("ReloadLength") or 0
	end
	if duration and duration > 0 and length > 0 then
		track:AdjustSpeed(length / duration)
	end

	print(string.format(
		"[ViewmodelAnimation] Playing reload for %s | source=%s",
		self.gunModel.Name,
		self.dataFolder and self.dataFolder:FindFirstChild("Reload") and "KeyframeSequence" or "Animation"
	))
	return true, "PLAYING"
end

function gun:StopReloadAnimation()
	local track = self.tracks.Reload
	if track then
		track:Stop(0.2)
	end
end

function gun:HasReloadAnimation()
	return self:_reloadSource() ~= nil
end

function gun:_clearTracks()
	for name, track in pairs(self.tracks) do
		releaseTrack(track, 0.08)
		self.tracks[name] = nil
	end
	self.viewModel:ResetAnimationPose()
end

function gun:_buildAuthoredJoints(model: Instance, root: BasePart, handle: BasePart): boolean
	local joints = self.dataFolder and self.dataFolder:FindFirstChild("Joints")
	if not joints then return false end

	-- Resolve every config before touching the model, so a weapon that turns out to
	-- have no Handle joint is abandoned without anything having been changed.
	local plan = {}
	local motorised = {}

	for _, config in ipairs(joints:GetChildren()) do
		local part1 = findPartNamed(model, config:GetAttribute("Part1") or config.Name)
		local toRoot = config:GetAttribute("Part0") == "HumanoidRootPart"

		-- A Handle-parented config that resolves back to the Handle would be a
		-- self-joint, which the engine rejects.
		if part1 == handle and not toRoot then
			part1 = nil
		end

		if part1 and not motorised[part1] then
			motorised[part1] = true
			table.insert(plan, { config = config, part1 = part1, toRoot = toRoot })
		end
	end

	if not motorised[handle] then
		warn(string.format(
			"[Viewmodel] %s has no authored Handle joint - falling back to the grip attachment",
			self.gunModel.Name
		))
		return false
	end

	local disabled = disableConflictingWelds(model, motorised, handle)

	for _, entry in ipairs(plan) do
		local config = entry.config
		local motor = Instance.new("Motor6D")
		motor.Name = config.Name
		motor.C0 = config:GetAttribute("C0") or CFrame.new()
		motor.C1 = config:GetAttribute("C1") or CFrame.new()
		motor.Part1 = entry.part1

		-- Root-anchored joints are what the reload sequence drives directly;
		-- everything else hangs off the Handle.
		if entry.toRoot then
			motor.Part0 = root
			motor.Parent = root
		else
			motor.Part0 = handle
			motor.Parent = handle
		end

		table.insert(self.createdJoints, motor)
	end

	local added = connectLooseParts(model, handle, motorised)

	print(string.format(
		"[Viewmodel] %s jointed from authored data | %d motor(s), %d weld(s) disabled, %d added",
		self.gunModel.Name,
		#plan,
		disabled,
		added
	))
	return true
end

function gun:_buildGripJoint(model: Instance, handle: BasePart)
	local rightArm = self.viewModel.model:WaitForChild("Right Arm")
	local gripAttachment = rightArm:WaitForChild("RightGripAttachment")
	assert(gripAttachment:IsA("Attachment"), "RightGripAttachment must be an Attachment")

	local gripInfo = self.Properties.ViewmodelGrip
	assert(gripInfo, "GunInfo is missing ViewmodelGrip for " .. self.gunModel.Name)

	local gripMotor = Instance.new("Motor6D")
	gripMotor.Name = "GunGrip"
	gripMotor.Part0 = rightArm
	gripMotor.Part1 = handle
	gripMotor.C0 = gripAttachment.CFrame * gripInfo.Position * gripInfo.Orientation
	gripMotor.C1 = CFrame.new(0, 0, 0)
	gripMotor.Parent = rightArm
	table.insert(self.createdJoints, gripMotor)

	-- The Tool's own welds already hold this weapon together; only genuinely
	-- unconstrained parts need one adding.
	connectLooseParts(model, handle, { [handle] = true })

	print("GunGrip attached at RightGripAttachment for", self.gunModel.Name, gripMotor.C0)
end

function gun:Equip()
	self.clonedGun = self.gunModel:Clone()

	for _, v in pairs(self.clonedGun:GetChildren()) do
		if v:IsA("BasePart") then
			v.Transparency = 0
		end
	end

	makeInert(self.clonedGun)

	local root = self.viewModel.model:WaitForChild("HumanoidRootPart")
	local handle = findPartNamed(self.clonedGun, "Handle")
	assert(handle, "Weapon model has no Handle for " .. self.gunModel.Name)

	self.clonedGun.Parent = self.viewModel.model

	local authored = ViewmodelSettings.UseAuthoredJoints
		and self:_buildAuthoredJoints(self.clonedGun, root, handle)
	if not authored then
		self:_buildGripJoint(self.clonedGun, handle)
	end

	-- FX anchors live on the cloned gun, so muzzle flash and shell ejection come
	-- off the weapon the player is actually looking at.
	self.muzzle = findNamed(self.clonedGun, MUZZLE_ATTACHMENT_NAMES)
	self.ejectPort = findNamed(self.clonedGun, EJECT_ATTACHMENT_NAMES) or self.muzzle
	self.muzzleFX = self.muzzle and FXUtil.EnsureMuzzleFX(self.muzzle) or nil
	if not self.muzzle then
		warn(string.format("[Viewmodel] %s has no muzzle attachment - FX will fall back to the Handle", self.gunModel.Name))
	end

	self.viewModel:Enable()
	self:PlayHoldAnimation()
end

function gun:GetMuzzlePosition(): Vector3?
	local position = worldPositionOf(self.muzzle)
	if position then return position end

	local handle = self.clonedGun and findPartNamed(self.clonedGun, "Handle")
	if handle then
		return handle.Position + handle.CFrame.LookVector * (handle.Size.Z / 2)
	end
	return nil
end

function gun:GetEjectPosition(): Vector3?
	return worldPositionOf(self.ejectPort) or self:GetMuzzlePosition()
end

function gun:MuzzleFlash(scale: number?)
	FXUtil.FlashMuzzle(self.muzzleFX, scale)
end

function gun:Unequip()
	self:_clearTracks()

	for _, motor in ipairs(self.createdJoints) do
		if motor.Parent then
			motor:Destroy()
		end
	end
	table.clear(self.createdJoints)

	self.muzzle = nil
	self.ejectPort = nil
	self.muzzleFX = nil

	if self.clonedGun then
		self.clonedGun:Destroy()
		self.clonedGun = nil
	end

	if self.ownsViewModel then
		self.viewModel:Disable()
	end
end

local function activeController()
	for controller in pairs(controllers) do
		if controller.clonedGun then
			return controller
		end
	end
	return nil
end

function handler.PlayEquippedAnimation()
	local controller = activeController()
	if not controller then
		warn("[ViewmodelAnimation] Cannot play weapon animation: no weapon is equipped")
		return false, "EQUIP A WEAPON"
	end
	return controller:PlayHoldAnimation()
end

function handler.PlayEquippedReloadAnimation()
	local controller = activeController()
	if not controller then
		warn("[ViewmodelAnimation] Cannot play reload animation: no weapon is equipped")
		return false, "EQUIP A WEAPON"
	end
	if not controller:HasReloadAnimation() then
		warn(string.format(
			"[ViewmodelAnimation] Reload animation unavailable for %s",
			controller.gunModel.Name
		))
		return false, "UNAVAILABLE"
	end
	return controller:PlayReloadAnimation()
end

function handler.HasEquippedReloadAnimation()
	local controller = activeController()
	return controller ~= nil and controller:HasReloadAnimation()
end

return handler
