local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared.Modules.Gunsystem
local Assets = Shared.Assets
local SpringHandler = require(Modules.SpringModule)
local ViewmodelSettings = require(Modules.ViewmodelSettings)

local handler = {}
local viewmodel = {}

local VIEWMODEL_DEFAULT_POS = Vector3.new(0, 0, 0)
local VIEWMODEL_COLLISION_GROUP = "Viewmodel"
local CHARACTER_MESH_MARKER = "ViewmodelCharacterMesh"

local function stabilizeViewmodel(model)
	local root = model:WaitForChild("HumanoidRootPart")
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == root
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.CollisionGroup = VIEWMODEL_COLLISION_GROUP
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.EvaluateStateMachine = false
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function createOffsetSpring(initialPosition)
	if ViewmodelSettings.SpringsEnabled then
		return SpringHandler.new(initialPosition)
	end

	-- Preserve the renderer interface without starting a Heartbeat connection.
	return {
		Position = initialPosition,
		Target = initialPosition,
		Destroy = function() end,
	}
end

function handler.new(_viewmodelOffset: Vector3)
	local model = Assets:WaitForChild("Viewmodel"):Clone()
	stabilizeViewmodel(model)

	local newmodel = {
		model = model,
		rbxConn = nil,
		baseAnimationTrack = nil,

		-- viewmodel recoil
		springPosition = Vector3.new(),
		springVelocity = Vector3.new(),
		isSpringActive = false,
		viewModel_Offset = _viewmodelOffset or VIEWMODEL_DEFAULT_POS,

		offsetSpring = createOffsetSpring(_viewmodelOffset or VIEWMODEL_DEFAULT_POS)
	}

	if not newmodel.model.PrimaryPart then
		newmodel.model.PrimaryPart = newmodel.model:FindFirstChild("HumanoidRootPart")
		warn("ViewModel's PrimaryPart was not set in Studio. Defaulting to HumanoidRootPart.")
	end

	assert(newmodel.model:FindFirstChild("Right Arm"), "Viewmodel is missing Right Arm")
	return setmetatable(newmodel, {__index = viewmodel})
end

function viewmodel:_ensureBaseAnimation()
	if not ViewmodelSettings.AnimationsEnabled then
		return false
	end
	if self.baseAnimationTrack and self.baseAnimationTrack.IsPlaying then
		return true
	end

	local humanoid = self.model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		warn("[ViewmodelAnimation] Cannot play base animation: no Animator")
		return false
	end

	if self.baseAnimationTrack then
		self.baseAnimationTrack:Destroy()
		self.baseAnimationTrack = nil
	end

	local animation = Instance.new("Animation")
	animation.Name = "ViewmodelBaseAnimation"
	animation.AnimationId = ViewmodelSettings.AnimationIds.ViewmodelLoad
	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()

	if not success then
		warn("[ViewmodelAnimation] Unable to load base viewmodel animation:", track)
		return false
	end

	track.Priority = Enum.AnimationPriority.Idle
	track.Looped = true
	track:Play()
	self.baseAnimationTrack = track

	print(string.format(
		"[ViewmodelAnimation] Playing persistent base animation | AnimationId=%s",
		ViewmodelSettings.AnimationIds.ViewmodelLoad
	))
	return true
end

function viewmodel:SyncCharacterMeshes(character)
	for _, child in ipairs(self.model:GetChildren()) do
		if child:IsA("CharacterMesh") and child:GetAttribute(CHARACTER_MESH_MARKER) then
			child:Destroy()
		end
	end

	if not ViewmodelSettings.ShowCharacterMeshes then return end
	if not character then return end

	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("CharacterMesh")
			and (child.BodyPart == Enum.BodyPart.LeftArm or child.BodyPart == Enum.BodyPart.RightArm) then
			local clone = child:Clone()
			clone:SetAttribute(CHARACTER_MESH_MARKER, true)
			clone.Parent = self.model
		end
	end
end

function viewmodel:applyRecoilImpulse(impulse)
	if not ViewmodelSettings.SpringsEnabled then return end

	local impRad = Vector3.new(
		math.rad(impulse.X),
		math.rad(impulse.Y),
		math.rad(impulse.Z)
	)
	self.springVelocity = self.springVelocity + impRad
	self.isSpringActive = true
end

function viewmodel:StartADS(adsOffset)
	if ViewmodelSettings.SpringsEnabled then
		self.offsetSpring.Target = adsOffset
	end
end

function viewmodel:StopADS()
	if ViewmodelSettings.SpringsEnabled then
		self.offsetSpring.Target = self.viewModel_Offset
	end
end

function viewmodel:ResetAnimationPose()
	local root = self.model:FindFirstChild("HumanoidRootPart")
	if root then
		local rightArmMotor = root:FindFirstChild("Right Arm")
		if rightArmMotor and rightArmMotor:IsA("Motor6D") then
			rightArmMotor.Transform = CFrame.new()
		end

		local leftArmMotor = root:FindFirstChild("Left Arm")
		if leftArmMotor and leftArmMotor:IsA("Motor6D") then
			leftArmMotor.Transform = CFrame.new()
		end
	end

	local rightArm = self.model:FindFirstChild("Right Arm")
	local gripMotor = rightArm and rightArm:FindFirstChild("GunGrip")
	if gripMotor and gripMotor:IsA("Motor6D") then
		gripMotor.Transform = CFrame.new()
	end
end

function viewmodel:Enable()
	if not ViewmodelSettings.AnimationsEnabled and not self.rbxConn then
		self:ResetAnimationPose()
	end

	local camera = workspace.CurrentCamera
	if camera then
		self.model.Parent = camera
		self:_ensureBaseAnimation()
	end
	if self.rbxConn then return end

	self.rbxConn = RunService.RenderStepped:Connect(function(dt)
		camera = workspace.CurrentCamera
		if not camera then return end

		if self.model.Parent ~= camera then
			self.model.Parent = camera
			self:_ensureBaseAnimation()
		end

		local finalCFrame = camera.CFrame * ViewmodelSettings.PositionOffset

		if ViewmodelSettings.SpringsEnabled then
			if self.isSpringActive then
				local stiffness, damping = 300, 30

				if self.springPosition.Magnitude < 0.001 and self.springVelocity.Magnitude < 0.001 then
					self.isSpringActive = false
					self.springPosition = Vector3.new()
					self.springVelocity = Vector3.new()
				else
					local springForce = -stiffness * self.springPosition
					local dampingForce = -damping * self.springVelocity
					local totalForce = springForce + dampingForce

					self.springVelocity = self.springVelocity + totalForce * dt
					self.springPosition = self.springPosition + self.springVelocity * dt
				end
			end

			local positionalOffset = CFrame.new(self.offsetSpring.Position)
			local recoilRotation = CFrame.Angles(self.springPosition.X, self.springPosition.Y, self.springPosition.Z)
			finalCFrame = finalCFrame * positionalOffset * recoilRotation
		end

		self.model:PivotTo(finalCFrame)
	end)
end

function viewmodel:Disable()
	if not self.rbxConn then return end
	if not self.model then return end

	self.model.Parent = ReplicatedStorage

	self.rbxConn:Disconnect()
	self.rbxConn = nil

	self.isSpringActive = false
	self.springPosition = Vector3.new()
	self.springVelocity = Vector3.new()
	self:ResetAnimationPose()
end

return handler
