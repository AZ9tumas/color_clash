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
local CameraFX = require(Shared.Modules.Utils.CameraFX)
local FXUtil = require(Shared.Modules.Utils.FXUtil)
local HitscanUtil = require(Shared.Modules.Utils.HitscanUtil)
local CombatConfig = require(Shared.Modules.Core.CombatConfig)
local CombatClient = require(Shared.Services.CombatService.CombatClient)
local WeaponHandling = require(Shared.Modules.Gunsystem.WeaponHandling)
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
local ReloadRemote = CombatRemotes.GetReload()
local AmmoSync = CombatRemotes.GetAmmoSync()

-- Live controllers by Tool, so a server ammo correction finds its gun.
local controllersByTool = {}

AmmoSync.OnClientEvent:Connect(function(tool, ammo)
	local controller = controllersByTool[tool]
	if not controller or type(ammo) ~= "number" or controller.isReloading then return end
	controller._ammo = math.clamp(math.floor(ammo), 0, controller.Properties.MaxAmmo)
	if controller.isEquipped then controller:updateUI() end
end)

-- The character a pellet hit, if the server would damage it. Mirrors the
-- checks in CombatServer and WeaponServer.ProcessDamage, so hits are only
-- predicted where the server will agree.
local function damageableTarget(part: BasePart): Model?
	local model = part:FindFirstAncestorWhichIsA("Model")
	if not model or model == player.Character or model:IsDescendantOf(camera) then return nil end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end

	local target = Players:GetPlayerFromCharacter(model)
	if target then
		if not target:GetAttribute("IsPlaying") then return nil end
		local team = player:GetAttribute("Team")
		if team ~= nil and team == target:GetAttribute("Team") then return nil end
	end
	return model
end

local function isCharacterPart(part: Instance): boolean
	local model = part:FindFirstAncestorWhichIsA("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- Sniper scope (Items.Handling.Scope, under GunHandling): a round lens whose
-- oversized stroke blacks out the rest of the screen, with a thin reticle.
local scopeGui: ScreenGui? = nil

local function scopeOverlay(): ScreenGui?
	if scopeGui and scopeGui.Parent then return scopeGui end
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return nil end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SniperScope"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.ResetOnSpawn = false
	gui.Enabled = false

	local lens = Instance.new("Frame")
	lens.Name = "Lens"
	lens.AnchorPoint = Vector2.new(0.5, 0.5)
	lens.Position = UDim2.fromScale(0.5, 0.5)
	lens.Size = UDim2.fromScale(0.86, 0.86)
	lens.SizeConstraint = Enum.SizeConstraint.RelativeYY
	lens.BackgroundTransparency = 1
	lens.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = lens

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 2500
	stroke.Parent = lens

	for _, size in { UDim2.new(1, 0, 0, 2), UDim2.new(0, 2, 1, 0) } do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = size
		line.BackgroundColor3 = Color3.new(0, 0, 0)
		line.BackgroundTransparency = 0.2
		line.BorderSizePixel = 0
		line.Parent = lens
	end

	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(5, 5)
	dot.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
	dot.BorderSizePixel = 0
	dot.Parent = lens
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(0.5, 0)
	dotCorner.Parent = dot

	gui.Parent = playerGui
	scopeGui = gui
	return gui
end

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

		handling = WeaponHandling.new(gunData),
		handlingConn = nil,
		handlingFlagConn = nil,
		scoped = false,
		_reloadToken = 0,
		_reloadSound = nil,

	}, gun)

	controllersByTool[tool] = self
	self.handlingFlagConn = Workspace:GetAttributeChangedSignal("GunHandling"):Connect(function()
		if self.isEquipped then self:_syncHandling() end
	end)
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
	if CombatConfig.IsEnabled("CombatFeedback") then
		MainHudController.SetAmmoWarning(self._ammo / self.Properties.MaxAmmo)
	end
end

function gun:getAimRay()
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector

	local result = HitscanUtil.Cast(origin, direction, 1000, player.Character)
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

	-- Under GunHandling the crosshair draws the real cone instead of a per-shot
	-- bloom, the shot's spread is read before it adds its own bloom, and the aim
	-- kick follows the gun's recoil pattern instead of a random yaw.
	local handlingOn = CombatConfig.IsEnabled("GunHandling")
	local shotSpread, patternUp, patternRight = nil, nil, nil
	if handlingOn then
		shotSpread = self.handling:Spread(self.isAiming)
		patternUp, patternRight = self.handling:Shot(self.isAiming)
	else
		CrosshairController.AddBloom((self.Properties.Spread or 5) * 1.5 + 5)
	end
	self:_playLocalShot()

	local recoil = self.Properties.Recoil or { Pitch = 1.5, Yaw = 0.5 }
	local steady = self.isAiming and 0.5 or 1
	-- The visual camera springs lean the way the pattern pushes (their +yaw turns
	-- left); without a pattern they pick a side at random as before.
	local lean = patternRight and (patternRight >= 0 and -1 or 1) or nil

	if patternUp then
		self.rig:ApplyAimKick(patternUp, patternRight)
	else
		self.rig:ApplyAimKick(
			recoil.Pitch * 0.4 * steady,
			recoil.Yaw * 0.4 * steady * (math.random() * 2 - 1)
		)
	end
	self.rig:applyRecoilImpulse(Vector3.new(
		recoil.Pitch * 8 * steady,
		recoil.Yaw * 8 * steady * (lean or (math.random() < 0.5 and -1 or 1)),
		0
	))
	if self.viewmodel then

		-- procedural kick on the gun itself, scaled by this weapon's recoil
		self.viewmodel:Kick(recoil.Pitch, recoil.Yaw, self.isAiming)
		self.viewmodel:PlayShoot()
	end
	CameraFX.Recoil(Vector3.new(
		recoil.Pitch * steady,
		recoil.Yaw * steady * (lean and lean * 0.5 or (math.random() < 0.5 and -1 or 1) * math.random()),
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

	-- Under ClientHitReg this client decides what each pellet hit and tells the
	-- server, which checks each claim against where the target was when we fired.
	local claims = CombatConfig.IsEnabled("ClientHitReg") and {} or nil

	-- Spread is rolled here rather than on the server, so the tracer can leave the
	-- muzzle this frame instead of after a round trip. The server checks every
	-- direction against the weapon's spread cone and casts the same rays for damage.
	local directions = {}
	local aimDirection = target - origin
	if aimDirection.Magnitude > 0.01 then
		aimDirection = aimDirection.Unit
		local spread = shotSpread or HitscanUtil.EffectiveSpread(self.Properties, self.isAiming)
		local range = self.Properties.Range or 1000
		local impacts = CombatConfig.IsEnabled("CombatFeedback")
		local muzzle = (self.viewmodel and self.viewmodel:GetMuzzlePosition())
			or FXUtil.GetMuzzlePosition(self.tool)
			or origin

		for i = 1, self.Properties.Pellets or 1 do
			local direction = HitscanUtil.ConeDirection(aimDirection, spread)
			directions[i] = direction

			local result = HitscanUtil.Cast(origin, direction, range, player.Character)
			FXUtil.BulletTracer(muzzle, result and result.Position or origin + direction * range)

			if claims and result then
				self:_claimHit(claims, i, result, origin)
			end
			if impacts and result and not isCharacterPart(result.Instance) then
				FXUtil.BulletImpact(result.Position, result.Normal, result.Instance)
			end
		end
	end

	ToolConnections:FireServer(self.tool.Name, target, self.isAiming, origin, directions, claims)
	return true
end

-- Records a pellet that hit someone the server would damage, and plays the
-- hit marker, number and blood now rather than a round trip later.
function gun:_claimHit(claims, index: number, result: RaycastResult, origin: Vector3)
	local part = result.Instance
	if not damageableTarget(part) then return end
	table.insert(claims, { index, part })

	-- CombatServer drops the whole shot outside a live round.
	if not player:GetAttribute("IsPlaying") or Workspace:GetAttribute("ArenaPhase") ~= "Shoot" then return end
	if CombatClient.ShowPredictedHit then
		local isHeadshot = part.Name == "Head"
		local damage = isHeadshot and self.Properties.Damage * 2 or self.Properties.Damage
		if CombatConfig.IsEnabled("GunHandling") then
			damage = HitscanUtil.HandlingDamage(self.Properties, (result.Position - origin).Magnitude, isHeadshot)
		end
		CombatClient.ShowPredictedHit(result.Position, tostring(damage), part, result.Normal)
	end
end

function gun:shoot()
	if not self.isEquipped then return end
	if self.isReloading then
		-- Under GunHandling a shell-by-shell reload can be cut short by firing.
		if not (CombatConfig.IsEnabled("GunHandling") and self.Properties.ReloadPerShell and self._ammo > 0) then
			return
		end
		self:_interruptReload()
	end

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
	if CombatConfig.IsEnabled("GunHandling") and self.Properties.Handling and self.Properties.Handling.Scope then
		self:_setScoped(true)
	end

	player:SetAttribute("AimSlowMultiplier", 0.55)
end

-- Sniper scope: lens overlay on, viewmodel and crosshair hidden behind it.
function gun:_setScoped(scoped: boolean)
	if self.scoped == scoped then return end
	self.scoped = scoped
	local overlay = scopeOverlay()
	if overlay then overlay.Enabled = scoped end
	if self.viewmodel then self.viewmodel:SetHidden(scoped) end
	CrosshairController.SetSuppressed(scoped)
end

function gun:stopADS()
	if not self.isAiming then return end
	self.isAiming = false
	self:_setScoped(false)
	self.rig:StopADS()
	if self.viewmodel then self.viewmodel:StopADS() end
	CameraFX.ClearAim()
	FXUtil.PlaySoundAt("AimIn", SoundService, 0.6)
	player:SetAttribute("AimSlowMultiplier", nil)
end

-- Seconds this reload takes. Under GunHandling a magazine reload with rounds
-- still in it uses the gun's faster TacticalReloadTime (AmmoServer agrees).
function gun:_reloadDuration(): number
	local handling = self.Properties.Handling
	if CombatConfig.IsEnabled("GunHandling") and handling and handling.TacticalReloadTime
		and not self.Properties.ReloadPerShell and self._ammo > 0 then
		return handling.TacticalReloadTime
	end
	return self.Properties.ReloadTime or 2
end

-- Ends a shell-by-shell reload early, keeping the shells already loaded.
function gun:_interruptReload()
	self._reloadToken += 1
	self.isReloading = false
	if self._reloadSound then self._reloadSound:Stop() end
	if self.viewmodel then self.viewmodel:StopReload() end
end

function gun:Reload()
	if self.isReloading or self._ammo == self.Properties.MaxAmmo then return end
	log("%s reloading (%d/%d)", self.tool.Name, self._ammo, self.Properties.MaxAmmo)
	self.isReloading = true
	self.cancelReload = false
	self._reloadToken += 1
	local token = self._reloadToken
	self:stopADS()
	if CombatConfig.IsEnabled("ClientHitReg") then
		ReloadRemote:FireServer(self.tool.Name)
	end

	-- False once this reload is cancelled, interrupted or replaced by a newer one.
	local function current(): boolean
		return self._reloadToken == token and self.isEquipped and not self.cancelReload
	end

	task.spawn(function()
		local reloadSound = playHandleSound(self.tool, "ReloadSFX")
		self._reloadSound = reloadSound
		local duration = self:_reloadDuration()

		if self.Properties.ReloadPerShell then
			while self._ammo < self.Properties.MaxAmmo and current() do

				if self.viewmodel then self.viewmodel:PlayReload(duration) end
				task.wait(duration)
				if not current() then break end
				self._ammo += 1
				self:updateUI()
				playHandleSound(self.tool, "ReloadSFX")
			end
		else
			if self.viewmodel then self.viewmodel:PlayReload(duration) end
			local elapsed = 0
			while elapsed < duration and current() do
				elapsed += task.wait(0.05)
			end
			if current() then
				self._ammo = self.Properties.MaxAmmo
				self:updateUI()
			end
		end

		-- An interrupt or a newer reload already owns the gun's state.
		if self._reloadToken ~= token then return end
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

	-- Under QuickSwap the gun has to be drawn before it fires; the auto-fire loop
	-- simply waits for nextShotAt, so holding the trigger fires once it is up.
	if CombatConfig.IsEnabled("QuickSwap") then
		local equipTime = self.Properties.Handling and self.Properties.Handling.EquipTime or 0
		self.nextShotAt = math.max(self.nextShotAt, os.clock() + equipTime)
		if self.viewmodel and equipTime > 0 then
			self.viewmodel:Draw(equipTime)
		end
	end

	self:_syncHandling()
end

-- Reconcile live flag changes as well as equips. Stale spray state must not
-- survive a toggle, and ADS must gain/lose its scope without a re-equip.
function gun:_syncHandling()
	self.handling:Reset()
	local enabled = CombatConfig.IsEnabled("GunHandling")
	if self.isEquipped and enabled then
		self:_startHandling()
	else
		self:_stopHandling()
	end
	self:_setScoped(self.isEquipped and enabled and self.isAiming
		and self.Properties.Handling ~= nil and self.Properties.Handling.Scope == true)
end

-- Per frame under GunHandling: bloom decays, the aim drifts back after a spray
-- and the crosshair is drawn on the real spread cone.
function gun:_startHandling()
	self:_stopHandling()
	local function recover(up: number, right: number)
		self.rig:ApplyAimKick(up, right)
	end
	self.handlingConn = RunService.RenderStepped:Connect(function(dt)
		if not CombatConfig.IsEnabled("GunHandling") then return end
		self.handling:Update(dt, recover)
		local spread = self.handling:Spread(self.isAiming) / 1000
		local halfHeight = camera.ViewportSize.Y / 2
		local pixels = math.tan(spread) / math.tan(math.rad(camera.FieldOfView) / 2) * halfHeight
		CrosshairController.SetSpreadGap(pixels)
	end)
end

function gun:_stopHandling()
	if self.handlingConn then
		self.handlingConn:Disconnect()
		self.handlingConn = nil
	end
	CrosshairController.SetSpreadGap(nil)
end

function gun:Unequip()
	self.isEquipped = false
	self:_restoreLocalAudio()
	self.cancelReload = true

	self:stopShoot()
	self:stopADS()
	self:_stopHandling()
	self.handling:Reset()

	if self.viewmodel then
		self.viewmodel:ClearWeapon()
		self.viewmodel = nil
	end

	CrosshairController.SetCrosshairVisible(false)
	MainHudController.SetWeaponInfo("N/A", "N/A")
	MainHudController.SetAmmoWarning(nil)
end

function gun:Destroy()
	if self.handlingFlagConn then
		self.handlingFlagConn:Disconnect()
		self.handlingFlagConn = nil
	end
	self:Unequip()
	if controllersByTool[self.tool] == self then
		controllersByTool[self.tool] = nil
	end
end

return GunHandler
