local rs = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MovementConfig = require(ReplicatedStorage.Shared.Modules.Core.MovementConfig)

local rh = {}

local function createCollider(part)
	local collider = Instance.new("Part")
	collider.Name = "RagdollCollider"
	collider.Size = part.Size - Vector3.new(0.1, 0.1, 0.1)
	collider.CFrame = part.CFrame
	collider.Transparency = 1
	collider.CanCollide = true
	collider.Massless = true
	collider.CustomPhysicalProperties = PhysicalProperties.new(1.5, 0.7, 0.5)
	
	local weld = Instance.new("WeldConstraint")
	weld.Name = "RagdollWeld"
	weld.Part0 = part
	weld.Part1 = collider
	weld.Parent = collider
	
	collider.Parent = part
	return collider
end

function rh.apply(char, duration, kbVelocity)
	-- Re-entrancy guard. A second apply while already ragdolled captured WalkSpeed 0 into
	-- OldWalkSpeed, so remove() restored 0 and the player stood up permanently unable to
	-- move. Both the reset button and void-falls during knockback could trigger it.
	if char:GetAttribute("Ragdolled") then return end

	char:SetAttribute("Ragdolled", true)
	
	local hum = char:FindFirstChildOfClass("Humanoid")
	local isDead = hum and hum.Health <= 0
	
	if hum then
		char:SetAttribute("OldWalkSpeed", hum.WalkSpeed)
		char:SetAttribute("OldJumpPower", hum.JumpPower)
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		
		hum.RequiresNeck = false
		hum.AutoRotate = false
		hum.PlatformStand = true
		hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		hum:ChangeState(Enum.HumanoidStateType.Physics)
	end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CanCollide = false
		hrp.Massless = true
	end

	for _, pt in ipairs(char:GetDescendants()) do
		if pt:IsA("BasePart") and pt.Name ~= "HumanoidRootPart" then
			pt.CanCollide = true
			pt.Massless = false
			pt.CustomPhysicalProperties = PhysicalProperties.new(1.5, 0.7, 0.5)
			
			if pt.Name == "Left Arm" or pt.Name == "Right Arm" or pt.Name == "Left Leg" or pt.Name == "Right Leg" then
				createCollider(pt)
			end
		end
		
		if pt:IsA("Motor6D") and pt.Name ~= "RootJoint" then
			local a0 = Instance.new("Attachment")
			local a1 = Instance.new("Attachment")
			local socket = Instance.new("BallSocketConstraint")
			
			a0.Name = "rdA0"
			a0.CFrame = pt.C0
			
			a1.Name = "rdA1"
			a1.CFrame = pt.C1
			
			socket.Name = "rdSock"
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			
			socket.LimitsEnabled = false
			socket.TwistLimitsEnabled = false
			
			a0.Parent = pt.Part0
			a1.Parent = pt.Part1
			socket.Parent = pt.Parent

			pt.Enabled = false 
		end
	end
	
	if kbVelocity then
		task.defer(function()
			for _, pt in ipairs(char:GetChildren()) do
				if pt:IsA("BasePart") then
					pt.AssemblyLinearVelocity = kbVelocity
				end
			end
		end)
	end
	
	if duration and not isDead then
		task.delay(duration, function()
			if char:GetAttribute("Ragdolled") then
				rh.remove(char)
			end
		end)
	end
end

function rh.remove(char)
	char:SetAttribute("Ragdolled", false)
	
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		-- Floored at walking speed as a belt-and-braces backstop: even if a corrupt
		-- OldWalkSpeed ever gets captured again, nobody stands up frozen.
		local baseWalk = MovementConfig.Speeds.Walk
		hum.WalkSpeed = math.max(char:GetAttribute("OldWalkSpeed") or baseWalk, baseWalk)
		hum.JumpPower = char:GetAttribute("OldJumpPower") or 50
		hum.AutoRotate = true
		hum.PlatformStand = false
		hum.Sit = false
		
		hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		hum:ChangeState(Enum.HumanoidStateType.Running)
		
		task.delay(0.1, function()
			if hum then hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true) end
		end)
	end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CanCollide = true
		hrp.Massless = false
	end

	for _, pt in ipairs(char:GetDescendants()) do
		if pt.Name == "rdSock" or pt.Name == "rdA0" or pt.Name == "rdA1" or pt.Name == "RagdollCollider" then
			pt:Destroy()
		end
		if pt:IsA("Motor6D") and pt.Name ~= "RootJoint" then
			pt.Enabled = true
		end
		if pt:IsA("BasePart") then
			pt.CustomPhysicalProperties = nil
		end
	end
end

return rh