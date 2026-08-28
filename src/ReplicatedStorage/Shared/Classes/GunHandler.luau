local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Items: Types.WeaponCatalog = require(Shared.Modules.Core.Items)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local CrosshairController = require(Shared.UIControllers.CrosshairController)
local MainHudController = require(Shared.UIControllers.MainHudController)
local RaycastUtil = require(Shared.Modules.Utils.RaycastUtil)
local CameraFX = require(Shared.Modules.Utils.CameraFX)
local FXUtil = require(Shared.Modules.Utils.FXUtil)
local FirstPersonRig = require(Shared.Classes.FirstPersonRig)
local Viewmodel = require(Shared.Classes.Viewmodel)

local SoundService = game:GetService("SoundService")
local FXConfig = require(Shared.Modules.Core.FXConfig)

local function log(message, ...)
	if FXConfig.GunDebug then
		print("[Gun] " .. string.format(message, ...))
	end
end

local GunHandler = {}
local gun = {}
gun.__index = gun

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local ToolConnections = CombatRemotes.GetToolConnections()

function GunHandler.New(tool: Tool?)
	if not tool then return nil end
	local data = Items[tool.Name]
	if not data or not data.MaxAmmo then return nil end

	local gunData = data :: Types.GunDefinition
	local self = setmetatable({
		tool = tool,
		Properties = gunData,

		_ammo = gunData.MaxAmmo,
		fireRate = gunData.Cooldown,
		fireCooldown = 0,

		isEquipped = false,
		isShooting = false,
		isReloading = false,
		isAiming = false,
		cancelReload = false,

		rig = FirstPersonRig.GetShared(),
		viewmodel = nil,
		continuousFireConn = nil,

	}, gun)

	return self
end

local function playHandleSound(tool, name)
	local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true)
	local sound = handle and handle:FindFirstChild(name)
	if sound and sound:IsA("Sound") then
		sound.TimePosition = 0
		sound:Play()
	end
	return sound
end

function gun:updateUI()
	MainHudController.SetWeaponInfo(self.tool.Name, tostring(self._ammo) .. "/" .. tostring(self.Properties.MaxAmmo))
end

function gun:getAimRay()
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector

	local ignoreList = { player.Character }
	local debrisFolder = Workspace:FindFirstChild("WallDebrisFolder")
	if debrisFolder then table.insert(ignoreList, debrisFolder) end

	local result = RaycastUtil.CastWithIgnore(origin, direction, 1000, ignoreList, {"RepairP", "Repair"})
	return origin, result and result.Position or origin + direction * 1000
end

function gun:getTargetPosition()
	local _, target = self:getAimRay()
	return target
end

function gun:_fireOnce()
	if self._ammo <= 0 then
		self:Reload()
		return false
	end

	self._ammo -= 1
	self:updateUI()
	CrosshairController.AddBloom((self.Properties.Spread or 5) * 1.5 + 5)

	local recoil = self.Properties.Recoil or { Pitch = 1.5, Yaw = 0.5 }
	local steady = self.isAiming and 0.5 or 1

	self.rig:ApplyAimKick(
		recoil.Pitch * 0.4 * steady,
		recoil.Yaw * 0.4 * steady * (math.random() * 2 - 1)
	)
	self.rig:applyRecoilImpulse(Vector3.new(
		recoil.Pitch * 8 * steady,
		recoil.Yaw * 8 * steady * (math.random() < 0.5 and -1 or 1),
		0
	))
	if self.viewmodel then

		self.viewmodel:applyRecoilImpulse(Vector3.new(
			recoil.Pitch * 10 * steady,
			recoil.Yaw * 8 * steady * (math.random() * 2 - 1),
			0
		))
		self.viewmodel:PlayShoot()
	end
	CameraFX.Recoil(Vector3.new(
		recoil.Pitch * steady,
		recoil.Yaw * steady * (math.random() < 0.5 and -1 or 1) * math.random(),
		0
	))
	CameraFX.Shake(Vector3.new(recoil.Pitch * 0.3, 0, recoil.Pitch * 0.25), 0.18, 0.75)
	CameraFX.FirePulse((self.Properties.Shake and self.Properties.Shake.Intensity or 1) * 2.5)

	local intensity = self.Properties.Shake and self.Properties.Shake.Intensity or 1

	if self.viewmodel then
		-- The flash lives on the viewmodel gun, so it tracks the weapon rather
		-- than being stamped into the world where the muzzle was this frame.
		self.viewmodel:MuzzleFlash(math.clamp(0.75 + intensity * 0.25, 0, 1))
		FXUtil.EjectShell(self.viewmodel:GetEjectPosition(), camera.CFrame.RightVector)
	else
		local toolMuzzle = FXUtil.GetMuzzlePosition(self.tool)
		FXUtil.MuzzleFlash(toolMuzzle, 0.8 + intensity * 0.35)
		FXUtil.EjectShell(toolMuzzle, camera.CFrame.RightVector)
	end

	-- The server resolves the hit from this exact ray. Sending the eye origin as
	-- well as the endpoint keeps its raycast identical to the one the crosshair
	-- described; casting from the muzzle instead introduces parallax error.
	local origin, target = self:getAimRay()
	ToolConnections:FireServer(self.tool.Name, target, self.isAiming, origin)
	return true
end

function gun:shoot()
	if not self.isEquipped or self.isReloading then return end

	if self._ammo <= 0 then
		log("%s dry fire, reloading", self.tool.Name)
		FXUtil.PlaySoundAt("DryFire", SoundService)
		self:Reload()
		return
	end

	if not self.Properties.AutoFire then
		if self.fireCooldown <= 0 then
			self:_fireOnce()
			self.fireCooldown = self.fireRate
			task.delay(self.fireRate, function()
				self.fireCooldown = 0
			end)
		end
		return
	end

	if self.isShooting then return end
	self.isShooting = true
	self.fireCooldown = 0

	self.continuousFireConn = RunService.Heartbeat:Connect(function(dt)
		if not self.isEquipped or self.isReloading then
			self:stopShoot()
			return
		end

		self.fireCooldown -= dt
		if self.fireCooldown <= 0 then
			self.fireCooldown = self.fireRate
			if not self:_fireOnce() then
				self:stopShoot()
			end
		end
	end)
end

function gun:stopShoot()
	self.isShooting = false
	if self.continuousFireConn then
		self.continuousFireConn:Disconnect()
		self.continuousFireConn = nil
	end
end

function gun:ADS()
	if not self.isEquipped or self.isReloading then return end
	log("%s ADS in (FOV %s)", self.tool.Name, tostring(self.Properties.Aim and self.Properties.Aim.FOV or 55))
	self.isAiming = true
	self.rig:StartADS()
	if self.viewmodel then self.viewmodel:StartADS() end
	CameraFX.SetAim(self.Properties.Aim and self.Properties.Aim.FOV or 55)
	FXUtil.PlaySoundAt("AimIn", SoundService)

	player:SetAttribute("AimSlowMultiplier", 0.55)
end

function gun:stopADS()
	if not self.isAiming then return end
	self.isAiming = false
	self.rig:StopADS()
	if self.viewmodel then self.viewmodel:StopADS() end
	CameraFX.ClearAim()
	FXUtil.PlaySoundAt("AimIn", SoundService, 0.6)
	player:SetAttribute("AimSlowMultiplier", nil)
end

function gun:Reload()
	if self.isReloading or self._ammo == self.Properties.MaxAmmo then return end
	log("%s reloading (%d/%d)", self.tool.Name, self._ammo, self.Properties.MaxAmmo)
	self.isReloading = true
	self.cancelReload = false
	self:stopADS()

	task.spawn(function()
		local reloadSound = playHandleSound(self.tool, "ReloadSFX")
		local duration = self.Properties.ReloadTime or 2

		if self.Properties.ReloadPerShell then
			while self._ammo < self.Properties.MaxAmmo and self.isEquipped and not self.cancelReload do

				if self.viewmodel then self.viewmodel:PlayReload(duration) end
				task.wait(duration)
				if not self.isEquipped or self.cancelReload then break end
				self._ammo += 1
				self:updateUI()
				playHandleSound(self.tool, "ReloadSFX")
			end
		else
			if self.viewmodel then self.viewmodel:PlayReload(duration) end
			local elapsed = 0
			while elapsed < duration and self.isEquipped and not self.cancelReload do
				elapsed += task.wait(0.05)
			end
			if self.isEquipped and not self.cancelReload then
				self._ammo = self.Properties.MaxAmmo
				self:updateUI()
			end
		end

		if reloadSound then reloadSound:Stop() end
		if (self.cancelReload or not self.isEquipped) and self.viewmodel then
			self.viewmodel:StopReload()
		end
		self.isReloading = false
	end)
end

function gun:Equip()
	self.isEquipped = true
	self.cancelReload = false

	self.viewmodel = Viewmodel.GetShared()

	if self.viewmodel then
		if not self.viewmodel:SetWeapon(self.tool.Name, nil, self.tool) then
			warn(string.format("[Gun] %q has no authored rig - the viewmodel keeps empty hands", self.tool.Name))
		end
	else
		warn("[Gun] no viewmodel is up - first person may not be active yet")
	end

	self:updateUI()
	CrosshairController.SetCrosshairVisible(true)

end

function gun:Unequip()
	self.isEquipped = false
	self.cancelReload = true

	self:stopShoot()
	self:stopADS()

	if self.viewmodel then
		self.viewmodel:ClearWeapon()
		self.viewmodel = nil
	end

	CrosshairController.SetCrosshairVisible(false)
	MainHudController.SetWeaponInfo("N/A", "N/A")
end

function gun:Destroy()
	self:Unequip()
end

return GunHandler
