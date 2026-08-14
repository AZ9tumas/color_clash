local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local MovementConfig = require(Shared.Modules.Core.MovementConfig)
local MovementRemotes = require(Shared.Remotes.MovementRemotes)
local FXConfig = require(Shared.Modules.Core.FXConfig)
local FXUtil = require(Shared.Modules.Utils.FXUtil)

local MovementClient = {}

local player = Players.LocalPlayer
local char, hum, root, rootJoint = nil, nil, nil, nil

local wantsToSprint = false
local isSliding = false
local currentState = "Walk"
local lastSlideTime = 0
local activeSlideVel = nil

local isWallRunning = false
local wallNormal = nil
local counterGravity = nil

local isWallClimbing = false
local climbNormal = nil
local activeClimbVel = nil
local climbEndTime = 0

local isVaulting = false

local currentRoll = 0

function MovementClient.GetCameraRoll()
	return currentRoll
end

local airSpeed = nil
local wasGrounded = true
local fallSpeed = 0

local lastGroundJumpTime = 0
local lastWallJumpTime = 0
local WALL_JUMP_COOLDOWN = 0.6
local jumpsLeft = 1

local tracks = {}

local function configVal(tab, field, default)
	if type(MovementConfig) == "table" and type(MovementConfig[tab]) == "table" then
		return tonumber(MovementConfig[tab][field]) or default
	end
	return default
end

local stopWallRun, stopWallClimb, startWallClimb, performVault, performSlide

local function getDistToFloor()
	if not hum or not root then return 3 end
	local isR6 = hum.RigType == Enum.HumanoidRigType.R6
	return isR6 and 3 or (tonumber(hum.HipHeight) + (tonumber(root.Size.Y) / 2))
end

local function loadTracks()
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator") or hum

	if type(MovementConfig) == "table" and type(MovementConfig.Animations) == "table" then
		for name, idData in pairs(MovementConfig.Animations) do
			if type(idData) == "table" then
				tracks[name] = {}
				for _, id in ipairs(idData) do
					local anim = Instance.new("Animation")
					anim.AnimationId = id
					local track = animator:LoadAnimation(anim)
					track.Priority = Enum.AnimationPriority.Action4
					table.insert(tracks[name], track)
				end
			elseif type(idData) == "string" and idData ~= "" then
				local anim = Instance.new("Animation")
				anim.AnimationId = idData
				local track = animator:LoadAnimation(anim)

				if name == "Sprint" then
					track.Priority = Enum.AnimationPriority.Movement
				elseif name == "Slide" or name == "Vault" or name == "WallClimb" then
					track.Priority = Enum.AnimationPriority.Action4
				else
					track.Priority = Enum.AnimationPriority.Action3
				end

				tracks[name] = track
			end
		end
	end
end

local function playTrack(name)
	for tName, trackData in pairs(tracks) do
		if tName == name then
			if type(trackData) == "table" then
				local isPlayingAny = false
				for _, t in ipairs(trackData) do
					if t.IsPlaying then
						isPlayingAny = true
						break
					end
				end
				if not isPlayingAny and #trackData > 0 then
					trackData[math.random(1, #trackData)]:Play(0.2)
				end
			else
				if not trackData.IsPlaying then trackData:Play(0.2) end
			end
		else
			if type(trackData) == "table" then
				for _, t in ipairs(trackData) do
					if t.IsPlaying then t:Stop(0.2) end
				end
			else
				if trackData.IsPlaying then trackData:Stop(0.2) end
			end
		end
	end
end

local function stopAllTracks()
	for _, trackData in pairs(tracks) do
		if type(trackData) == "table" then
			for _, t in ipairs(trackData) do
				if t.IsPlaying then t:Stop(0.25) end
			end
		else
			if trackData.IsPlaying then trackData:Stop(0.25) end
		end
	end
end

local function airOptions()
	if type(MovementConfig) == "table" and type(MovementConfig.Air) == "table" then
		return MovementConfig.Air
	end
	return {}
end

local function groundSpeedForState()
	if currentState == "Sprint" then return configVal("Speeds", "Sprint", 34) end
	if string.find(currentState, "WallRun") then return configVal("Speeds", "WallRun", 45) end
	return configVal("Speeds", "Walk", 22)
end

local function applyMoveSpeed()
	if not hum then return end

	local speed = airSpeed or groundSpeedForState()

	local aimSlow = player:GetAttribute("AimSlowMultiplier")
	if type(aimSlow) == "number" then
		speed = speed * math.clamp(aimSlow, 0.2, 1)
	end

	hum.WalkSpeed = speed

	local remoteState = string.find(currentState, "WallRun") and "WallRun" or currentState
	MovementRemotes.GetUpdateStateEvent():FireServer(remoteState, speed)
end

local function horizontalSpeed()
	if not root then return 0 end
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

local function beginAirMomentum(fromSpeed)
	if airOptions().PreserveMomentum == false then return end

	local retention = configVal("Air", "MomentumRetention", 1)
	local minSpeed = configVal("Air", "MinAirSpeed", configVal("Speeds", "Sprint", 34))
	local maxSpeed = configVal("Air", "MaxAirSpeed", 120)

	airSpeed = math.clamp((fromSpeed or horizontalSpeed()) * retention, minSpeed, maxSpeed)
	applyMoveSpeed()
end

local function endAirMomentum()
	if airSpeed == nil then return end
	airSpeed = nil
	applyMoveSpeed()
end

local function setState(newState)
	if currentState == newState then return end
	currentState = newState
	player:SetAttribute("MovementState", newState)

	if string.find(newState, "WallRun") then airSpeed = nil end

	applyMoveSpeed()

	if hum then
		if newState == "Sprint" then
			playTrack("Sprint")
		elseif newState == "Walk" then
			if not isWallRunning and not isSliding and not isWallClimbing and not isVaulting then stopAllTracks() end
		elseif string.find(newState, "WallRun") then
			playTrack(newState)
		elseif newState == "WallClimb" then
			playTrack("WallClimb")
		elseif newState == "Vault" then
			playTrack("Vault")
		elseif newState == "Slide" then
			playTrack("Slide")
		end
	end
end

stopWallClimb = function()
	if not isWallClimbing then return end
	isWallClimbing = false
	climbNormal = nil
	if activeClimbVel then
		activeClimbVel:Destroy()
		activeClimbVel = nil
	end
	stopAllTracks()

	if wantsToSprint and hum and hum.MoveDirection.Magnitude > 0.1 then
		setState("Sprint")
	else
		setState("Walk")
	end
end

startWallClimb = function(hitNormal)
	isWallClimbing = true
	climbNormal = hitNormal

	local climbDur = configVal("WallClimb", "Duration", 0.45)
	climbEndTime = tick() + climbDur
	setState("WallClimb")

	local climbSpd = configVal("WallClimb", "Speed", 45)
	root.AssemblyLinearVelocity = Vector3.new(0, climbSpd, 0)

	if activeClimbVel then activeClimbVel:Destroy() end

	local att = root:FindFirstChild("RootRigAttachment") or root:FindFirstChild("RootAttachment")
	activeClimbVel = Instance.new("LinearVelocity")
	activeClimbVel.Name = "ClimbVelocity"
	activeClimbVel.Attachment0 = att
	activeClimbVel.RelativeTo = Enum.ActuatorRelativeTo.World
	activeClimbVel.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	activeClimbVel.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	activeClimbVel.MaxAxesForce = Vector3.new(100000, 100000, 100000)
	activeClimbVel.VectorVelocity = Vector3.new(0, climbSpd, 0)
	activeClimbVel.Parent = root
end

performVault = function(targetPos)
	isVaulting = true
	setState("Vault")

	if isWallRunning then stopWallRun() end
	if isWallClimbing then stopWallClimb() end

	stopAllTracks()
	playTrack("Vault")

	local startPos = root.Position
	local endCFrame = CFrame.lookAt(targetPos + Vector3.new(0, getDistToFloor() + 0.15, 0), targetPos + Vector3.new(0, getDistToFloor() + 0.15, 0) + root.CFrame.LookVector)

	root.Anchored = true

	local vaultDur = configVal("Vault", "Duration", 0.18)
	local t = TweenService:Create(root, TweenInfo.new(vaultDur, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {CFrame = endCFrame})
	t:Play()

	task.delay(vaultDur, function()
		if not root then return end
		root.Anchored = false
		isVaulting = false
		jumpsLeft = 1

		local spntSpd = configVal("Speeds", "Sprint", 34)
		local wlkSpd = configVal("Speeds", "Walk", 22)
		local walkSpd = wantsToSprint and spntSpd or wlkSpd

		local fVec = endCFrame.LookVector
		local pushFlatDir = Vector3.new(fVec.X, 0, fVec.Z).Unit
		root.AssemblyLinearVelocity = Vector3.new(pushFlatDir.X * walkSpd, -5, pushFlatDir.Z * walkSpd)

		if wantsToSprint and hum and hum.MoveDirection.Magnitude > 0 then
			setState("Sprint")
		else
			setState("Walk")
		end
	end)
end

performSlide = function()
	local slideCd = configVal("Slide", "Cooldown", 0.3)
	if isSliding or isWallRunning or isWallClimbing or isVaulting or (tick() - lastSlideTime) < slideCd then return end
	if not hum or not root then return end
	if hum.FloorMaterial == Enum.Material.Air then return end

	local moveDir = hum.MoveDirection
	if moveDir.Magnitude < 0.1 then return end

	isSliding = true
	lastSlideTime = tick()

	setState("Slide")
	FXUtil.SlideStart(root)

	local pBase = configVal("Slide", "BasePower", 80)
	local pSprint = configVal("Slide", "SprintPower", 110)
	local power = wantsToSprint and pSprint or pBase

	if activeSlideVel then activeSlideVel:Destroy() end

	activeSlideVel = Instance.new("LinearVelocity")
	activeSlideVel.Name = "SlideVelocity"
	activeSlideVel.Attachment0 = root:FindFirstChild("RootRigAttachment") or root:FindFirstChild("RootAttachment")

	if not activeSlideVel.Attachment0 then
		local att = Instance.new("Attachment", root)
		att.Name = "SlideAttachment"
		activeSlideVel.Attachment0 = att
	end

	activeSlideVel.RelativeTo = Enum.ActuatorRelativeTo.World
	activeSlideVel.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	activeSlideVel.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	activeSlideVel.MaxAxesForce = Vector3.new(100000, 0, 100000)
	activeSlideVel.VectorVelocity = moveDir * power
	activeSlideVel.Parent = root

	local sWalk = configVal("Speeds", "Walk", 22)
	local sSprint = configVal("Speeds", "Sprint", 34)
	local targetSpeed = wantsToSprint and sSprint or sWalk
	local slideDur = configVal("Slide", "Duration", 0.9)

	local tween = TweenService:Create(activeSlideVel, TweenInfo.new(slideDur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		VectorVelocity = moveDir * targetSpeed
	})
	tween:Play()

	task.delay(slideDur, function()
		if not isSliding then return end
		if activeSlideVel and activeSlideVel.Parent then activeSlideVel:Destroy() end
		isSliding = false

		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			wantsToSprint = true
		end

		if wantsToSprint and hum.MoveDirection.Magnitude > 0.1 then
			setState("Sprint")
		else
			setState("Walk")
		end
	end)
end

stopWallRun = function()
	if not isWallRunning then return end
	isWallRunning = false
	wallNormal = nil

	if counterGravity then
		counterGravity.Force = Vector3.zero
	end

	stopAllTracks()

	if wantsToSprint and hum and hum.MoveDirection.Magnitude > 0.1 then
		setState("Sprint")
	else
		setState("Walk")
	end

	if hum and hum.FloorMaterial == Enum.Material.Air then
		beginAirMomentum()
	end
end

local function measureWallHeight(hitPosition, hitNormal, raycastParams)
	local sampleOrigin = hitPosition + hitNormal * 0.15
	local UP_PROBE = 25
	local DOWN_PROBE = 25

	local upHit = Workspace:Raycast(sampleOrigin, Vector3.new(0, UP_PROBE, 0), raycastParams)
	local downHit = Workspace:Raycast(sampleOrigin, Vector3.new(0, -DOWN_PROBE, 0), raycastParams)

	local topY = upHit and upHit.Position.Y or (sampleOrigin.Y + UP_PROBE)
	local bottomY = downHit and downHit.Position.Y or (sampleOrigin.Y - DOWN_PROBE)

	return topY - bottomY
end

function MovementClient.Init()
	player:SetAttribute("MovementState", "Walk")

	local function onCharacterAdded(c)
		char = c
		hum = char:WaitForChild("Humanoid") :: Humanoid
		root = char:WaitForChild("HumanoidRootPart")

		rootJoint = root:FindFirstChild("RootJoint")
		if not rootJoint then
			local lowerTorso = char:WaitForChild("LowerTorso", 3)
			if lowerTorso then rootJoint = lowerTorso:FindFirstChild("Root") end
		end

		airSpeed = nil
		wasGrounded = true

		hum.WalkSpeed = configVal("Speeds", "Walk", 22)

		hum.UseJumpPower = false
		hum.JumpHeight = configVal("Air", "JumpHeight", 7.2)
		loadTracks()

		local rootAtt = root:FindFirstChild("RootRigAttachment") or root:FindFirstChild("RootAttachment")
		if not rootAtt then
			rootAtt = Instance.new("Attachment", root)
			rootAtt.Name = "RootAttachment"
		end

		counterGravity = Instance.new("VectorForce")
		counterGravity.Name = "WallRunAntiGravity"
		counterGravity.Attachment0 = rootAtt
		counterGravity.Force = Vector3.zero
		counterGravity.RelativeTo = Enum.ActuatorRelativeTo.World
		counterGravity.Parent = root

		hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping then
				lastGroundJumpTime = tick()
			end
		end)

		hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
			if isSliding or isWallRunning or isWallClimbing or isVaulting then return end
			if hum.MoveDirection.Magnitude > 0.1 then
				if wantsToSprint then
					setState("Sprint")
				end
			else
				if currentState == "Sprint" then
					setState("Walk")
				end
			end
		end)
	end

	player.CharacterAdded:Connect(onCharacterAdded)

	if player.Character then
		onCharacterAdded(player.Character)
	end

	player:GetAttributeChangedSignal("AimSlowMultiplier"):Connect(applyMoveSpeed)

	player:GetAttributeChangedSignal("IsPlaying"):Connect(function()
		if player:GetAttribute("IsPlaying") ~= true then
			wantsToSprint = false
			endAirMomentum()
			if activeSlideVel then activeSlideVel:Destroy() end
			isSliding = false
			stopWallRun()
			stopWallClimb()
			if isVaulting and root then
				root.Anchored = false
				isVaulting = false
			end
			if currentState ~= "Walk" then
				setState("Walk")
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if player:GetAttribute("InMenu") ~= false then return end
		if char and char:GetAttribute("Ragdolled") then return end

		if input.KeyCode == Enum.KeyCode.LeftShift then
			wantsToSprint = true
			if not isSliding and not isWallRunning and not isWallClimbing and not isVaulting and hum and hum.MoveDirection.Magnitude > 0.1 then
				setState("Sprint")
			end
		elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C then
			if player:GetAttribute("IsPlaying") == true then
				if not isSliding and not isWallRunning and not isWallClimbing and not isVaulting then
					if hum and hum.MoveDirection.Magnitude > 0.1 then
						performSlide()
					end
				end
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			wantsToSprint = false
			if currentState == "Sprint" and not isSliding and not isWallRunning and not isWallClimbing and not isVaulting then
				setState("Walk")
			end
		end
	end)

	UserInputService.JumpRequest:Connect(function()
		if char and char:GetAttribute("Ragdolled") then return end
		if isVaulting then return end

		if isWallClimbing and climbNormal then
			stopWallClimb()
			local jumpOffForce = configVal("WallClimb", "JumpOffForce", 45)
			local jumpUpForce = configVal("WallClimb", "JumpUpForce", 65)
			root.AssemblyLinearVelocity = (climbNormal * jumpOffForce) + Vector3.new(0, jumpUpForce, 0)
			beginAirMomentum(Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude)
			lastWallJumpTime = tick()
			jumpsLeft = 1

			if hum then
				hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
				task.delay(0.1, function()
					if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end
				end)
			end
		elseif isWallRunning and wallNormal then
			local flatLook = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit

			local forwardDotRest = configVal("WallRun", "ForwardRestrictionDot", -0.9)
			if flatLook:Dot(wallNormal) > forwardDotRest then
				local currentVel = root.AssemblyLinearVelocity
				local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)

				local maxSpd = configVal("WallRun", "MaxSpeed", 90)
				local speedRatio = math.clamp(horizontalVel.Magnitude / maxSpd, 0, 1)

				local maxF = configVal("WallRun", "MaxForce", 90)
				local jOff = configVal("WallRun", "JumpOffForce", 50)
				local dynamicForceRange = maxF - jOff
				local finalOffForce = jOff + (dynamicForceRange * speedRatio)

				local parallelVelocity = horizontalVel - (wallNormal * horizontalVel:Dot(wallNormal))
				local jumpH = configVal("WallRun", "JumpHeight", 55)
				local jumpVector = (wallNormal * finalOffForce) + Vector3.new(0, jumpH, 0)

				stopWallRun()
				root.AssemblyLinearVelocity = parallelVelocity + jumpVector
				beginAirMomentum(Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude)
				lastWallJumpTime = tick()
				jumpsLeft = 1

				if hum then
					hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
					task.delay(0.1, function()
						if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end
					end)
				end
			end
		elseif isSliding then

			local slideVelocity = activeSlideVel and activeSlideVel.VectorVelocity or root.AssemblyLinearVelocity

			if activeSlideVel then activeSlideVel:Destroy() end
			activeSlideVel = nil
			isSliding = false
			stopAllTracks()

			local flat = Vector3.new(slideVelocity.X, 0, slideVelocity.Z)
			if flat.Magnitude > 0.1 then
				root.AssemblyLinearVelocity = Vector3.new(flat.X, root.AssemblyLinearVelocity.Y, flat.Z)
				beginAirMomentum(flat.Magnitude)
			end

			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				wantsToSprint = true
			end

			if wantsToSprint and hum and hum.MoveDirection.Magnitude > 0.1 then
				setState("Sprint")
			else
				setState("Walk")
			end
		else
			if hum and hum.FloorMaterial == Enum.Material.Air and (tick() - lastGroundJumpTime) > 0.2 then
				if jumpsLeft > 0 then
					jumpsLeft -= 1
					local currentVel = root.AssemblyLinearVelocity
					local djPwr = configVal("Speeds", "DoubleJumpPower", 45)

					root.AssemblyLinearVelocity = Vector3.new(currentVel.X, djPwr, currentVel.Z)
					hum:ChangeState(Enum.HumanoidStateType.Jumping)

					FXUtil.DoubleJumpBurst(root.Position - Vector3.new(0, getDistToFloor(), 0))
				end
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		if not hum or not root then return end

		if counterGravity and not isWallRunning then

			local state = hum:GetState()
			local airborne = (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping)
				and hum.Health > 0
				and not (char and char:GetAttribute("Ragdolled"))
				and not isSliding and not isVaulting and not isWallClimbing

			local airScale = configVal("Air", "GravityScale", 1)
			if airborne and airScale < 1 then
				counterGravity.Force = Vector3.new(0, Workspace.Gravity * root.AssemblyMass * (1 - airScale), 0)
			else
				counterGravity.Force = Vector3.zero
			end
		end

		if hum.Health <= 0 then return end
		if char and char:GetAttribute("Ragdolled") then return end

		local speedTrail = FXUtil.EnsureSpeedTrail(root)
		if speedTrail then
			speedTrail.Enabled = player:GetAttribute("IsPlaying") == true
				and horizontalSpeed() >= (FXConfig.SpeedTrail.MinSpeed or 50)
		end

		local grounded = hum.FloorMaterial ~= Enum.Material.Air
		if not grounded then

			fallSpeed = math.min(fallSpeed, root.AssemblyLinearVelocity.Y)
		end

		if grounded ~= wasGrounded then
			wasGrounded = grounded
			if grounded then
				endAirMomentum()
				if fallSpeed <= -FXConfig.Land.MinFallSpeed then
					FXUtil.LandImpact(root.Position - Vector3.new(0, getDistToFloor(), 0))
				end
				fallSpeed = 0
			elseif airSpeed == nil and not isWallRunning and not isWallClimbing and not isVaulting then
				beginAirMomentum()
			end
		end

		if player:GetAttribute("IsPlaying") ~= true then
			if isWallRunning then stopWallRun() end
			if isWallClimbing then stopWallClimb() end
			return
		end

		if isSliding or isVaulting then return end

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude

		local ignoreList = {char}
		local debrisFolder = Workspace:FindFirstChild("WallDebrisFolder")
		if debrisFolder then table.insert(ignoreList, debrisFolder) end
		params.FilterDescendantsInstances = ignoreList

		local rootVec = root.CFrame.LookVector
		local flatLookDir = Vector3.new(rootVec.X, 0, rootVec.Z)
		if flatLookDir.Magnitude > 0 then flatLookDir = flatLookDir.Unit else flatLookDir = Vector3.new(0, 0, -1) end

		if isWallClimbing then
			if tick() > climbEndTime then
				stopWallClimb()
				return
			end

			local headPos = root.Position + Vector3.new(0, 1.5, 0)
			local hit = Workspace:Raycast(headPos, flatLookDir * 3.5, params)
			if not hit then
				local downRayOrigin = headPos + (flatLookDir * 1.5) + Vector3.new(0, 3, 0)
				local downHit = Workspace:Raycast(downRayOrigin, Vector3.new(0, -6, 0), params)
				if downHit then
					performVault(downHit.Position)
				else
					stopWallClimb()
				end
			end
			return
		end

		local moveX, moveZ = hum.MoveDirection.X, hum.MoveDirection.Z
		local flatMoveDir = Vector3.new(moveX, 0, moveZ)
		local isMovingForward = false

		if flatMoveDir.Magnitude > 0.1 and wantsToSprint then
			if flatMoveDir.Unit:Dot(flatLookDir) > 0.4 then
				isMovingForward = true
			end
		end

		if isMovingForward then
			local heightsToTest = {
				root.Position - Vector3.new(0, 1.5, 0),
				root.Position - Vector3.new(0, 0.5, 0),
				root.Position + Vector3.new(0, 1.0, 0),
			}

			local forwardHit = nil
			for _, testPos in ipairs(heightsToTest) do
				local tempHit = Workspace:Raycast(testPos, flatLookDir * 2.5, params)

				if tempHit then
					if math.abs(tempHit.Normal.Y) < 0.25 then
						forwardHit = tempHit
						break
					end
				end
			end

			if forwardHit then
				local vMin = configVal("Vault", "MinHeight", 0.5)
				local vMax = configVal("Vault", "MaxHeight", 5.5)
				local cMax = configVal("WallClimb", "MaxHeight", 12)

				local antiNormDepth = Vector3.new(-forwardHit.Normal.X, 0, -forwardHit.Normal.Z).Unit
				local topTestStart = forwardHit.Position + (antiNormDepth * 0.4) + Vector3.new(0, cMax + 3, 0)
				local testFloorHit = Workspace:Raycast(topTestStart, Vector3.new(0, -(cMax + 5), 0), params)

				if testFloorHit then
					if math.abs(testFloorHit.Normal.Y) > 0.75 then
						local trueFloor = getDistToFloor()
						local targetDiffY = testFloorHit.Position.Y - (root.Position.Y - trueFloor)

						if targetDiffY >= vMin and targetDiffY <= vMax then
							performVault(testFloorHit.Position)
							return
						elseif targetDiffY > vMax and targetDiffY <= cMax and hum.FloorMaterial == Enum.Material.Air then
							startWallClimb(forwardHit.Normal)
							return
						end
					end
				end
			end
		end

		if hum.FloorMaterial == Enum.Material.Air then
			if (tick() - lastGroundJumpTime) < 0.1 then
				stopWallRun()
				return
			end

			if (tick() - lastWallJumpTime) < WALL_JUMP_COOLDOWN then
				return
			end

			local minWallHeight = (getDistToFloor() * 2) + 1.5

			local function checkWall(dir)
				local origin = root.Position
				return Workspace:Raycast(origin, dir * 3.5, params)
					or Workspace:Raycast(origin - Vector3.new(0, 1.5, 0), dir * 3.5, params)
					or Workspace:Raycast(origin + Vector3.new(0, 1.5, 0), dir * 3.5, params)
			end

			local wallFound = false
			local hitNormal = Vector3.zero

			local directions = {root.CFrame.RightVector, -root.CFrame.RightVector}
			if hum.MoveDirection.Magnitude > 0.1 then
				table.insert(directions, hum.MoveDirection.Unit)
			else
				table.insert(directions, flatLookDir)
			end

			for _, dir in ipairs(directions) do
				local hit = checkWall(dir)
				if hit and math.abs(hit.Normal.Y) < 0.25 then
					local heightRay = Workspace:Raycast(root.Position, Vector3.new(0, -500, 0), params)
					local height = heightRay and (root.Position.Y - heightRay.Position.Y) or math.huge

					local wallRunMinH = configVal("WallRun", "MinHeight", 2.0)
					if height > wallRunMinH then
						local wallHeight = measureWallHeight(hit.Position, hit.Normal, params)
						if wallHeight >= minWallHeight then
							wallFound = true
							hitNormal = hit.Normal
							break
						end
					end
				end
			end

			if wallFound then
				local wasOnWall = (wallNormal ~= nil)
				wallNormal = hitNormal

				if not wasOnWall then
					local vel = root.AssemblyLinearVelocity
					root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)

					local rightDot = root.CFrame.RightVector:Dot(wallNormal)
					if rightDot < -0.5 then setState("WallRunRight")
					elseif rightDot > 0.5 then setState("WallRunLeft")
					else setState("WallRunRight") end

					isWallRunning = true
				end

				if counterGravity then
					local gravScale = configVal("WallRun", "GravityScale", 0.1)
					counterGravity.Force = Vector3.new(0, Workspace.Gravity * root.AssemblyMass * (1 - gravScale), 0)
				end
			else
				stopWallRun()
			end
		else
			jumpsLeft = 1
			stopWallRun()
			stopWallClimb()
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not hum or not root then return end
		if char and char:GetAttribute("Ragdolled") then return end

		local isPlaying = player:GetAttribute("IsPlaying") == true
		local isAlive = hum.Health > 0

		local camera = Workspace.CurrentCamera
		local cameraDist = (camera.Focus.Position - camera.CFrame.Position).Magnitude
		local isFirstPerson = (camera.CameraType == Enum.CameraType.Custom and cameraDist < 1.25)

		local targetRoll = 0
		local rightVector = camera.CFrame.RightVector

		if isPlaying and isAlive then
			if isWallRunning and wallNormal then
				local rightDot = rightVector:Dot(wallNormal)
				targetRoll = rightDot > 0 and 12 or -12
			elseif isSliding then
				local slideDir = activeSlideVel and activeSlideVel.VectorVelocity.Unit or hum.MoveDirection
				if slideDir.Magnitude > 0 then
					targetRoll = -math.clamp(rightVector:Dot(slideDir) * 5, -5, 5)
				end
			elseif not isVaulting and not isWallClimbing then
				if hum.MoveDirection.Magnitude > 0.1 then
					targetRoll = -math.clamp(rightVector:Dot(hum.MoveDirection) * 2.5, -2.5, 2.5)
				end
			end
		end

		currentRoll = currentRoll + (targetRoll - currentRoll) * math.min(1, dt * 8)

		if math.abs(currentRoll) > 0.01 then
			camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, math.rad(currentRoll))
		end

		local isEquipped = player:GetAttribute("GunCameraActive") == true
			or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter

		if isPlaying and isAlive then
			if isVaulting then
				hum.AutoRotate = false
			elseif isWallClimbing and climbNormal then
				hum.AutoRotate = false
				local targetRot = CFrame.lookAt(Vector3.zero, -climbNormal)
				local currentRot = root.CFrame - root.Position
				root.CFrame = CFrame.new(root.Position) * currentRot:Lerp(targetRot, math.min(1, dt * 25))
			elseif isWallRunning and wallNormal then
				hum.AutoRotate = false
				local cross = Vector3.new(0, 1, 0):Cross(wallNormal)
				if cross.Magnitude > 0.001 then
					cross = cross.Unit
					if root.AssemblyLinearVelocity:Dot(cross) < 0 then cross = -cross end
					local targetRot = CFrame.lookAt(Vector3.zero, cross)
					local currentRot = root.CFrame - root.Position
					root.CFrame = CFrame.new(root.Position) * currentRot:Lerp(targetRot, math.min(1, dt * 15))
				end
			elseif isSliding then
				hum.AutoRotate = false
				if activeSlideVel and activeSlideVel.VectorVelocity.Magnitude > 0.1 then
					local slideDir = activeSlideVel.VectorVelocity.Unit
					local targetRot = CFrame.lookAt(Vector3.zero, Vector3.new(slideDir.X, 0, slideDir.Z).Unit)
					local currentRot = root.CFrame - root.Position
					root.CFrame = CFrame.new(root.Position) * currentRot:Lerp(targetRot, math.min(1, dt * 18))
				end
			else
				if not isEquipped then
					if hum.MoveDirection.Magnitude > 0.1 and not isFirstPerson then
						hum.AutoRotate = false
						local targetRot = CFrame.lookAt(Vector3.zero, hum.MoveDirection)
						local currentRot = root.CFrame - root.Position
						root.CFrame = CFrame.new(root.Position) * currentRot:Lerp(targetRot, math.min(1, dt * 18))
					else
						hum.AutoRotate = true
					end
				end
			end
		else
			hum.AutoRotate = true
		end

		if rootJoint then
			if not rootJoint:GetAttribute("OriginalC0") then
				rootJoint:SetAttribute("OriginalC0", rootJoint.C0)
			end
			local origC0 = rootJoint:GetAttribute("OriginalC0")

			local targetTiltX = 0
			local targetTiltZ = 0

			if isPlaying and isAlive then
				local localVel = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
				if not isWallRunning and not isSliding and not isWallClimbing and not isVaulting and hum.FloorMaterial ~= Enum.Material.Air and hum.MoveDirection.Magnitude > 0.1 then
					targetTiltX = math.clamp(-localVel.Z / 60, -0.15, 0.15)
					targetTiltZ = math.clamp(-localVel.X / 60, -0.15, 0.15)
				end
			end

			local currentTiltX = rootJoint:GetAttribute("TiltX") or 0
			local currentTiltZ = rootJoint:GetAttribute("TiltZ") or 0

			currentTiltX = currentTiltX + (targetTiltX - currentTiltX) * math.min(1, dt * 10)
			currentTiltZ = currentTiltZ + (targetTiltZ - currentTiltZ) * math.min(1, dt * 10)

			rootJoint:SetAttribute("TiltX", currentTiltX)
			rootJoint:SetAttribute("TiltZ", currentTiltZ)

			if math.abs(currentTiltX) > 0.001 or math.abs(currentTiltZ) > 0.001 then
				rootJoint.C0 = origC0 * CFrame.Angles(currentTiltX, 0, currentTiltZ)
			else
				rootJoint.C0 = origC0
			end
		end
	end)
end

return MovementClient