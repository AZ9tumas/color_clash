local gunInfo = require(script.Parent.GunInfo)
local viewmodelOffsets = require(script.Parent.ViewmodelOffsets)
local viewmodelHandler = require(script.Parent.ViewModelHandler)

local handler = {}
local gun = {}
local controllers = setmetatable({}, {__mode = "k"})
local VIEWMODEL_COLLISION_GROUP = "Viewmodel"

function handler.New(gunModel: Tool, sharedViewModel)
	local info = gunInfo[gunModel.Name]
	local offset = viewmodelOffsets[gunModel.Name]
	if not info or not offset then
		warn("Missing viewmodel metadata or offset for", gunModel.Name)
		return nil
	end

	local newgun = {
		gunModel = gunModel,
		clonedGun = nil,
		viewModel = sharedViewModel or viewmodelHandler.new(Vector3.zero),
		ownsViewModel = sharedViewModel == nil,
		Properties = info,
		ViewmodelOffset = offset,
		animationTrack = nil,
	}

	controllers[newgun] = true
	return setmetatable(newgun, {__index = gun})
end

function gun:_stopAnimation()
	if self.animationTrack then
		self.animationTrack:Stop(0.08)
		self.animationTrack:Destroy()
		self.animationTrack = nil
	end
	self.viewModel:ResetAnimationPose()
end

function gun:_playAnimation(animation, actionName)
	if not self.clonedGun then
		return false, "EQUIP A WEAPON"
	end
	if not animation or not animation:IsA("Animation") or animation.AnimationId == "" then
		return false, "UNAVAILABLE"
	end

	local humanoid = self.viewModel.model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false, "NO ANIMATOR"
	end

	self:_stopAnimation()
	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not success then
		warn("Unable to load viewmodel animation for", self.gunModel.Name, track)
		return false, "LOAD FAILED"
	end

	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = false
	track:Play(0.08)
	self.animationTrack = track

	print(string.format(
		"[ViewmodelAnimation] Playing %s for %s | AnimationId=%s",
		actionName,
		self.gunModel.Name,
		animation.AnimationId
	))
	return true, "PLAYING"
end

function gun:PlayConfiguredAnimation()
	local animationId = self.Properties.HoldAnimationId
	if not animationId then
		return false, "UNAVAILABLE"
	end

	local animation = Instance.new("Animation")
	animation.Name = "ViewmodelAnimation"
	animation.AnimationId = animationId
	local success, message = self:_playAnimation(animation, "weapon animation")
	animation:Destroy()
	return success, message
end

function gun:PlayReloadAnimation()
	if not self.clonedGun then
		return false, "EQUIP A WEAPON"
	end

	local animation = self.clonedGun:FindFirstChild("Reload")
		or self.gunModel:FindFirstChild("Reload")
	if not animation or not animation:IsA("Animation") then
		return false, "UNAVAILABLE"
	end

	return self:_playAnimation(animation, "reload animation")
end

function gun:HasReloadAnimation()
	local source = self.clonedGun or self.gunModel
	local animation = source and source:FindFirstChild("Reload")
	return animation ~= nil and animation:IsA("Animation") and animation.AnimationId ~= ""
end

function gun:Equip()
	self.clonedGun = self.gunModel:Clone()
	self.clonedGun.Parent = self.viewModel.model

	for _, v in pairs(self.clonedGun:GetChildren()) do
		if v:IsA("BasePart") then
			v.Transparency = 0
		end
	end

	for _, descendant in ipairs(self.clonedGun:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = VIEWMODEL_COLLISION_GROUP
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	local rightArm = self.viewModel.model:WaitForChild("Right Arm")
	local gripMotor = rightArm:FindFirstChildWhichIsA("Motor6D") or Instance.new("Motor6D")
	gripMotor.Name = "GunGrip"
	gripMotor.Part0 = rightArm
	gripMotor.Part1 = self.clonedGun.Handle
	gripMotor.C0 = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, 0)
	gripMotor.C1 = self.ViewmodelOffset.Position * self.ViewmodelOffset.Angles
	gripMotor.Parent = rightArm
	
	print("Final offset for", self.gunModel.Name, gripMotor.C1)

	self.viewModel:Enable()
end

function gun:Unequip()
	self:_stopAnimation()

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
	return controller:PlayConfiguredAnimation()
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
