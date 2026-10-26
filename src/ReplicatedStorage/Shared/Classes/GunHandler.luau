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
local HitscanUtil = require(Shared.Modules.Utils.HitscanUtil)
local FirstPersonRig = require(Shared.Classes.FirstPersonRig)
local Viewmodel = require(Shared.Classes.Viewmodel)

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local FXConfig = require(Shared.Modules.Core.FXConfig)

local function log(message, ...)
	if FXConfig.GunDebug then
		print("[Gun] " .. string.format(message, ...))
	end
end

local function logWarn(message, ...)
	if FXConfig.GunDebug then
		warn("[Gun] " .. string.format(message, ...))
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
		nextShotAt = 0,

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

-- Local gunshot. The server plays FireSFX on the third-person Handle so everyone
-- else hears the shot, but for the shooter that copy arrives a round trip late and
-- spatialised from a hidden model. So the shooter's own copy is muted locally and
-- replaced by an instant, non-spatial one. Volume set on the client stays local:
-- the server only ever calls :Play() on that sound, it never writes Volume.
-- Optional extra layers are played if they exist on the Handle.
local FIRE_LAYERS = { "FireSFX", "FireMech", "FireTail", "FireBass" }
local LOCAL_SHOT_GAIN = 1.15
local SHOT_PITCH_JITTER = 0.04

function gun:_prepareLocalAudio()
	self._fireLayers = {}
	self._mutedVolumes = {}

	local handle = self.tool:FindFirstChild("Handle")
	if not handle then return end

	for _, name in ipairs(FIRE_LAYERS) do
		local sound = handle:FindFirstChild(name)
		if sound and sound:IsA("Sound") then
			table.insert(self._fireLayers, sound)
			if name == "FireSFX" then
				self._mutedVolumes[sound] = sound.Volume
				sound.Volume = 0
			end
		end
	end
end

function gun:_restoreLocalAudio()
	for sound, volume in pairs(self._mutedVolumes or {}) do
		if sound.Parent then sound.Volume = volume end
	end
	self._mutedVolumes = {}
	self._fireLayers = {}
end

function gun:_playLocalShot()
	for _, source in ipairs(self._fireLayers or {}) do
		local shot = source:Clone()
		shot.Playing = false
		shot.Volume = (self._mutedVolumes[source] or source.Volume) * LOCAL_SHOT_GAIN
		shot.PlaybackSpeed = source.PlaybackSpeed * (1 + (math.random() * 2 - 1) * SHOT_PITCH_JITTER)
		-- parented outside any part, so it plays flat in the player's ears
		shot.Parent = SoundService
		shot:Play()

		local length = shot.TimeLength > 0 and shot.TimeLength or 2
		Debris:AddItem(shot, length / math.max(shot.PlaybackSpeed, 0.1) + 0.25)
	end
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
	local now = os.clock()
	if now < self.nextShotAt then return false end
	if self._ammo <= 0 then
		self:Reload()
		return false
	end

	self.nextShotAt = now + self.fireRate
	self._ammo -= 1
	self:updateUI()
	CrosshairController.AddBloom((self.Properties.Spread or 5) * 1.5 + 5)
	self:_playLocalShot()

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

		-- procedural kick on the gun itself, scaled by this weapon's recoil
		self.viewmodel:Kick(recoil.Pitch, recoil.Yaw, self.isAiming)
		self.viewmodel:PlayShoot()
	end
	CameraFX.Recoil(Vector3.new(
		recoil.Pitch * steady,
		recoil.Yaw * steady * (math.random() < 0.5 and -1 or 1) * math.random(),
		0
	))
	CameraFX.Shake(Vector3.new(recoil.Pitch * 0.3, 0, recoil.Pitch * 0.25), 0.18, 0.75)
	-- full-screen blur on every shot reads as smear rather than impact; opt-in only
	if FXConfig.FireBlur then
		CameraFX.FirePulse((self.Properties.Shake and self.Properties.Shake.Intensity or 1) * 2.5)
	end

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

	-- Spread is rolled here rather than on the server, so the tracer can leave the
	-- muzzle this frame instead of after a round trip. The server checks every
	-- direction against the weapon's spread cone and casts the same rays for damage.
	local directions = {}
	local aimDirection = target - origin
	if aimDirection.Magnitude > 0.01 then
		aimDirection = aimDirection.Unit
		local spread = HitscanUtil.EffectiveSpread(self.Properties, self.isAiming)
		local range = self.Properties.Range or 1000
		local muzzle = (self.viewmodel and self.viewmodel:GetMuzzlePosition())
			or FXUtil.GetMuzzlePosition(self.tool)
			or origin

		for i = 1, self.Properties.Pellets or 1 do
			local direction = HitscanUtil.ConeDirection(aimDirection, spread)
			directions[i] = direction

			local result = HitscanUtil.Cast(origin, direction, range, player.Character)
			FXUtil.BulletTracer(muzzle, result and result.Position or origin + direction * range)
		end
	end

	ToolConnections:FireServer(self.tool.Name, target, self.isAiming, origin, directions)
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
		self:_fireOnce()
		return
	end

	if self.isShooting then return end
	self.isShooting = true
	-- Fire on the input frame. The deadline survives trigger release/repress,
	-- so tapping an automatic cannot predict shots the server will rate-limit.
	self:_fireOnce()

	self.continuousFireConn = RunService.Heartbeat:Connect(function()
		if not self.isEquipped or self.isReloading then
			self:stopShoot()
			return
		end

		if os.clock() >= self.nextShotAt then
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
	self:_prepareLocalAudio()
	self.cancelReload = false

	self.viewmodel = Viewmodel.GetShared()

	if self.viewmodel then
		if not self.viewmodel:SetWeapon(self.tool.Name, nil, self.tool) then
			logWarn("%q has no authored rig - the viewmodel keeps empty hands", self.tool.Name)
		end
	else
		logWarn("no viewmodel is up - first person may not be active yet")
	end

	self:updateUI()
	CrosshairController.SetCrosshairVisible(true)

end

function gun:Unequip()
	self.isEquipped = false
	self:_restoreLocalAudio()
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
