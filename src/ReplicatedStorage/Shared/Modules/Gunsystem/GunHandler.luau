local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local gunInfo = require(script.Parent.GunInfo)
local viewmodelHandler = require(script.Parent.ViewModelHandler)
local ViewmodelSettings = require(script.Parent.ViewmodelSettings)

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

-- The Tool ships welded together. Rebuilding connectivity from scratch is the
-- only way the authored per-part joints can move independently of the Handle.
local function stripJoints(model: Instance)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			descendant:Destroy()
		end
	end
end

local function weldRemaining(model: Instance, handle: BasePart, jointed: { [BasePart]: boolean })
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= handle and not jointed[part] then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = handle
		end
	end
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
		track:Stop(0.08)
		track:Destroy()
		self.tracks[name] = nil
	end
	self.viewModel:ResetAnimationPose()
end

function gun:_buildAuthoredJoints(model: Instance, root: BasePart, handle: BasePart): boolean
	local joints = self.dataFolder and self.dataFolder:FindFirstChild("Joints")
	if not joints then return false end

	local jointed = {}
	local built = {}

	for _, config in ipairs(joints:GetChildren()) do
		local part1 = findPartNamed(model, config:GetAttribute("Part1") or config.Name)
		local toRoot = config:GetAttribute("Part0") == "HumanoidRootPart"

		-- A Handle-parented config that resolves back to the Handle would be a
		-- self-joint, which the engine rejects.
		if part1 == handle and not toRoot then
			part1 = nil
		end

		if part1 and not jointed[part1] then
			local motor = Instance.new("Motor6D")
			motor.Name = config.Name
			motor.C0 = config:GetAttribute("C0") or CFrame.new()
			motor.C1 = config:GetAttribute("C1") or CFrame.new()
			motor.Part1 = part1

			-- Root-anchored joints are what the reload sequence drives directly;
			-- everything else hangs off the Handle.
			if toRoot then
				motor.Part0 = root
				motor.Parent = root
			else
				motor.Part0 = handle
				motor.Parent = handle
			end

			jointed[part1] = true
			table.insert(built, motor)
		end
	end

	if not jointed[handle] then
		for _, motor in ipairs(built) do
			motor:Destroy()
		end
		warn(string.format(
			"[Viewmodel] %s has no authored Handle joint - falling back to the grip attachment",
			self.gunModel.Name
		))
		return false
	end

	weldRemaining(model, handle, jointed)
	for _, motor in ipairs(built) do
		table.insert(self.createdJoints, motor)
	end

	print(string.format(
		"[Viewmodel] %s jointed from authored data | %d motor(s)",
		self.gunModel.Name,
		#built
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

	weldRemaining(model, handle, {})

	print("GunGrip attached at RightGripAttachment for", self.gunModel.Name, gripMotor.C0)
end

function gun:Equip()
	self.clonedGun = self.gunModel:Clone()

	for _, v in pairs(self.clonedGun:GetChildren()) do
		if v:IsA("BasePart") then
			v.Transparency = 0
		end
	end

	stripJoints(self.clonedGun)
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

	self.viewModel:Enable()
	self:PlayHoldAnimation()
end

function gun:Unequip()
	self:_clearTracks()

	for _, motor in ipairs(self.createdJoints) do
		if motor.Parent then
			motor:Destroy()
		end
	end
	table.clear(self.createdJoints)

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
