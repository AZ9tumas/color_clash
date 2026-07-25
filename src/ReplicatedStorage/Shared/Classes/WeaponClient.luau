local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Modules.Core.Items)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local CrosshairController = require(Shared.UIControllers.CrosshairController)
local MainHudController = require(Shared.UIControllers.MainHudController)
local RaycastUtil = require(Shared.Modules.Utils.RaycastUtil)

local ToolConnections = CombatRemotes.GetToolConnections()
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local WeaponClient = {}
WeaponClient.__index = WeaponClient

function WeaponClient.new(tool, onRecoil)
	local self = setmetatable({}, WeaponClient)
	self.tool = tool
	self.data = Items[tool.Name]
	self.onRecoil = onRecoil
	self.ammo = self.data and self.data.MaxAmmo or 0
	self.isEquipped = false
	self.isReloading = false
	self.cancelReloadFlag = false
	self.isHolding = false
	self.lastUsed = 0

	self.idleTrack = nil
	self.walkTrack = nil
	self.sprintTrack = nil
	self.reloadTrack = nil
	self.swingTrack = nil
	self.shootTrack = nil
	
	self.currentMoveAnim = nil
	self.activeMoveTrack = nil
	self.moveAnimConnection = nil

	if not self.data then return self end

	self.tool.Equipped:Connect(function() self:Equip() end)
	self.tool.Unequipped:Connect(function() self:Unequip() end)
	self.tool.Activated:Connect(function()
		self.isHolding = true
		if self.data.AutoFire then
			task.spawn(function()
				while self.isHolding and self.isEquipped do
					if not self.isReloading then self:Fire() end
					task.wait(self.data.Cooldown)
				end
			end)
		else
			self:Fire()
		end
	end)
	self.tool.Deactivated:Connect(function() self.isHolding = false end)

	return self
end

local function getAnimationTrack(humanoid, animId)
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. tostring(animId)
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid
	return animator:LoadAnimation(anim)
end

function WeaponClient:Equip()
	self.isEquipped = true
	self.cancelReloadFlag = false
	self.isHolding = false

	self:UpdateUI()
	if self.data.MaxAmmo then CrosshairController.SetCrosshairVisible(true) end

	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid and self.data.Animations then
		if self.data.Animations.Idle then
			self.idleTrack = getAnimationTrack(humanoid, self.data.Animations.Idle)
			self.idleTrack.Looped = true
			self.idleTrack.Priority = Enum.AnimationPriority.Action3 
		end
		if self.data.Animations.Walk then
			self.walkTrack = getAnimationTrack(humanoid, self.data.Animations.Walk)
			self.walkTrack.Looped = true
			self.walkTrack.Priority = Enum.AnimationPriority.Action3 
		end
		if self.data.Animations.Sprint then
			self.sprintTrack = getAnimationTrack(humanoid, self.data.Animations.Sprint)
			self.sprintTrack.Looped = true
			self.sprintTrack.Priority = Enum.AnimationPriority.Action3 
		end

		if self.data.Animations.Swing then
			local handle = self.tool:FindFirstChild("Handle") or self.tool:FindFirstChildWhichIsA("BasePart", true)
			if handle and not handle:FindFirstChild("MeleeSwingSound") then
				local sfx = Instance.new("Sound")
				sfx.Name = "MeleeSwingSound"
				sfx.SoundId = string.find(self.tool.Name, "Axe") and "rbxassetid://140650136639350" or (string.find(self.tool.Name, "Bat") and "rbxassetid://79459251446203" or "rbxassetid://140553108821312")
				sfx.Volume = 1
				sfx.Parent = handle
			end
			local animId = self.data.Animations.Swing[humanoid.RigType.Name]
			if animId then self.swingTrack = getAnimationTrack(humanoid, animId) self.swingTrack.Priority = Enum.AnimationPriority.Action4 end
		end
		if self.data.Animations.Shoot then
			self.shootTrack = getAnimationTrack(humanoid, self.data.Animations.Shoot)
			self.shootTrack.Priority = Enum.AnimationPriority.Action4 
		end
		if self.data.Animations.Reload then
			self.reloadTrack = getAnimationTrack(humanoid, self.data.Animations.Reload)
			self.reloadTrack.Priority = Enum.AnimationPriority.Action4 
		end
	end

	self.moveAnimConnection = RunService.Heartbeat:Connect(function()
		local rChar = player.Character
		local root = rChar and rChar:FindFirstChild("HumanoidRootPart")
		if not root or not self.isEquipped then return end
		
		local flatSpeed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		local moveState = player:GetAttribute("MovementState") or "Walk"
		
		local desiredAnim = "Idle"
		if flatSpeed > 0.5 then
			if moveState == "Sprint" and flatSpeed > 1 then
				desiredAnim = "Sprint"
			else
				desiredAnim = "Walk"
			end
		end

		if self.currentMoveAnim ~= desiredAnim then
			if self.activeMoveTrack then self.activeMoveTrack:Stop(0.25) end
			self.currentMoveAnim = desiredAnim
			self.activeMoveTrack = nil
			
			if desiredAnim == "Walk" and self.walkTrack then
				self.activeMoveTrack = self.walkTrack
			elseif desiredAnim == "Sprint" and self.sprintTrack then
				self.activeMoveTrack = self.sprintTrack
			elseif self.idleTrack then 
				self.activeMoveTrack = self.idleTrack
			end
			
			if self.activeMoveTrack then
				self.activeMoveTrack:Play(0.25)
			end
		end
	end)
end

function WeaponClient:Unequip()
	self.isEquipped = false
	self.cancelReloadFlag = true
	self.isHolding = false

	CrosshairController.SetCrosshairVisible(false)
	MainHudController.SetWeaponInfo("N/A", "N/A")

	if self.moveAnimConnection then 
		self.moveAnimConnection:Disconnect() 
		self.moveAnimConnection = nil 
	end
	if self.activeMoveTrack then 
		self.activeMoveTrack:Stop(0.2) 
		self.activeMoveTrack = nil 
	end
	self.currentMoveAnim = nil

	if self.reloadTrack then self.reloadTrack:Stop(0.25) end
	if self.swingTrack then self.swingTrack:Stop(0.25) end
	
	local handle = self.tool:FindFirstChild("Handle") or self.tool:FindFirstChildWhichIsA("BasePart", true)
	local reloadSFX = handle and handle:FindFirstChild("ReloadSFX")
	if reloadSFX then reloadSFX:Stop() end
end

function WeaponClient:GetTargetPosition()
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
	
	local ignoreList = {player.Character}
	local debrisFolder = Workspace:FindFirstChild("WallDebrisFolder")
	if debrisFolder then table.insert(ignoreList, debrisFolder) end
	local baseModel = Workspace:FindFirstChild("Base")
	if baseModel then table.insert(ignoreList, baseModel) end

	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj:IsA("Model") and (string.find(obj.Name, "Turret") or string.find(obj.Name, "Trap")) then 
			table.insert(ignoreList, obj) 
		end
	end

	local result = RaycastUtil.CastWithIgnore(origin, direction, 1000, ignoreList, {"RepairP", "Repair"})
	if result then
		return result.Position
	else
		return origin + (direction * 1000)
	end
end

function WeaponClient:UpdateUI()
	if self.data.MaxAmmo then
		MainHudController.SetWeaponInfo(self.tool.Name, tostring(self.ammo) .. "/" .. tostring(self.data.MaxAmmo))
	else
		MainHudController.SetWeaponInfo(self.tool.Name, "N/A")
	end
end

function WeaponClient:Reload()
	if not self.data.MaxAmmo or self.isReloading or self.ammo == self.data.MaxAmmo then return end
	self.isReloading = true
	self.cancelReloadFlag = false

	local handle = self.tool:FindFirstChild("Handle") or self.tool:FindFirstChildWhichIsA("BasePart", true)
	local reloadSFX = handle and handle:FindFirstChild("ReloadSFX")
	
	local animDuration = self.data.ReloadTime or 2.5

	if self.reloadTrack then
		local attempts = 0
		while self.reloadTrack.Length == 0 and attempts < 10 do
			attempts += 1
			task.wait(0.05)
		end
		
		if self.reloadTrack.Length > 0 then
			animDuration = self.reloadTrack.Length
		end
	end

	if self.data.ReloadPerShell then
		local missing = self.data.MaxAmmo - self.ammo
		for i = 1, missing do
			if not self.isEquipped or self.cancelReloadFlag then break end
			
			if self.reloadTrack then 
				self.reloadTrack:Stop(0)
				self.reloadTrack:Play(0.1)
			end
			
			if reloadSFX then
				reloadSFX.TimePosition = 0
				reloadSFX:Play() 
			end
			
			local t = 0
			while t < animDuration and self.isEquipped and not self.cancelReloadFlag do
				t += task.wait(0.05)
			end
			
			if not self.isEquipped or self.cancelReloadFlag then break end
			self.ammo += 1
			self:UpdateUI()
		end
	else
		if self.reloadTrack then 
			self.reloadTrack:Stop(0)
			self.reloadTrack:Play(0.1)
		end
		
		if reloadSFX then
			reloadSFX.TimePosition = 0
			reloadSFX:Play()
		end
		
		local t = 0
		while t < animDuration and self.isEquipped and not self.cancelReloadFlag do 
			t += task.wait(0.05) 
		end
		
		if reloadSFX then
			reloadSFX:Stop()
		end
		
		if self.isEquipped and not self.cancelReloadFlag then
			self.ammo = self.data.MaxAmmo
			self:UpdateUI()
		end
	end

	if self.reloadTrack then self.reloadTrack:Stop(0.2) end
	self.isReloading = false
end

function WeaponClient:Fire()
	if self.isReloading then return end
	local actualCooldown = self.data.Cooldown
	if self.swingTrack and self.swingTrack.Length > 0 then actualCooldown = self.swingTrack.Length + 0.2 end

	if (tick() - self.lastUsed) >= actualCooldown then
		if self.data.MaxAmmo then
			if self.ammo <= 0 then self:Reload(); return end
			self.ammo -= 1
			CrosshairController.AddBloom((self.data.Spread or 5) * 1.5 + 5)
			self:UpdateUI()
		end

		self.lastUsed = tick()
		
		if self.swingTrack then self.swingTrack:Play(0.1) end
		if self.shootTrack then self.shootTrack:Play(0.1) end
		
		local handle = self.tool:FindFirstChild("Handle") or self.tool:FindFirstChildWhichIsA("BasePart", true)
		if self.data.Animations and self.data.Animations.Swing and handle and handle:FindFirstChild("MeleeSwingSound") then
			handle.MeleeSwingSound:Play()
		end

		local amount = self.data.Shake and self.data.Shake.Intensity and (self.data.Shake.Intensity * 0.015) or 0.03
		if self.onRecoil then self.onRecoil(amount) end

		ToolConnections:FireServer(self.tool.Name, self:GetTargetPosition())
	end
end

return WeaponClient