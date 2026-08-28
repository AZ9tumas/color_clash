local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local RoundConfig = require(Shared.Modules.Core.RoundConfig)
local PlayerUtil = require(Shared.Modules.Utils.PlayerUtil)
local RaycastUtil = require(Shared.Modules.Utils.RaycastUtil)
local FXUtil = require(Shared.Modules.Utils.FXUtil)
local QuestServer = require(ServerScriptService.Server.Services.QuestService.QuestServer)
local RewardManager = require(Shared.Modules.Game.RewardManager)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local RoundRemotes = require(Shared.Remotes.RoundRemotes)

local ShowBulletTracer = CombatRemotes.GetBulletTracer()
local DamageVFX = CombatRemotes.GetDamageVFX()
local KillFeedEvent = RoundRemotes.GetKillFeedEvent()

local WeaponServer = {}

-- How far the client-reported eye may sit from the character's head before it is
-- rejected as bogus and the head is used instead.
local MAX_EYE_OFFSET = 14

-- Spread is authored in milliradians (Items.Spread), matching the tuning the
-- previous per-axis jitter produced. Keep the scale so weapon feel is unchanged.
local SPREAD_TO_RADIANS = 1 / 1000

local function coneDirection(direction, spread)
	if spread <= 0 then return direction end

	local basis = CFrame.lookAt(Vector3.zero, direction)
	local theta = math.random() * math.pi * 2
	local radius = math.tan(spread * SPREAD_TO_RADIANS) * math.sqrt(math.random())
	local offset = basis.RightVector * (math.cos(theta) * radius)
		+ basis.UpVector * (math.sin(theta) * radius)

	local jittered = direction + offset
	if jittered.Magnitude < 1e-4 then return direction end
	return jittered.Unit
end

local function announceKill(sourceName, sourcePlayer, victimName, victimPlayer, toolName, isHeadshot, reward)
	KillFeedEvent:FireAllClients({
		Killer = sourceName,
		KillerTeam = sourcePlayer and sourcePlayer:GetAttribute("Team") or nil,
		Victim = victimName,
		VictimTeam = victimPlayer and victimPlayer:GetAttribute("Team") or nil,
		Weapon = toolName or "Unknown Weapon",
		Headshot = isHeadshot == true,
		Reward = reward,
	})
end

function WeaponServer.ProcessDamage(targetCharacter, damage, sourceName, sourcePlayer, toolName, isHeadshot)
	local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")

	if not humanoid or humanoid.Health <= 0 then return false end

	local mode = RoundConfig.CurrentMode
	if mode.TeamBased and not mode.FriendlyFire and sourcePlayer and targetPlayer then
		local sourceTeam = sourcePlayer:GetAttribute("Team")
		if sourceTeam and sourceTeam == targetPlayer:GetAttribute("Team") then return false end
	end

	if targetPlayer then
		if targetPlayer:GetAttribute("IsPlaying") then
			QuestServer.UpdateShotsTaken(targetPlayer)
			if sourcePlayer and sourcePlayer ~= targetPlayer then
				QuestServer.UpdateShotsLanded(sourcePlayer)
			end

			if humanoid.Health - damage <= 0 then
				targetPlayer:SetAttribute("IsPlaying", false)
				humanoid.Health = humanoid.MaxHealth

				local currentKills = 1
				local killReward = nil
				if sourcePlayer then
					currentKills, killReward = RewardManager.ProcessKill(sourcePlayer)
				end

				local hrp = targetCharacter:FindFirstChild("HumanoidRootPart")
				local sourceHRP = sourcePlayer and sourcePlayer.Character and sourcePlayer.Character:FindFirstChild("HumanoidRootPart")
				local kbVelocity = Vector3.new(0, 80, 0)

				if hrp and sourceHRP then
					local diff = hrp.Position - sourceHRP.Position
					local flatDir = Vector3.new(diff.X, 0, diff.Z)
					if flatDir.Magnitude > 0 then
						flatDir = flatDir.Unit
					else
						flatDir = Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)).Unit
					end

					kbVelocity = (flatDir * 60) + Vector3.new(0, 80, 0)
				end

				local lobbySpawn = Workspace:FindFirstChild("Spawnlocation")
				PlayerUtil.RagdollAndTeleport(targetPlayer, lobbySpawn, kbVelocity)

				RewardManager.ProcessDeath(targetPlayer, sourceName, toolName or "Unknown Weapon", currentKills)
				announceKill(sourceName, sourcePlayer, targetPlayer.Name, targetPlayer, toolName, isHeadshot, killReward)
				return true
			else
				humanoid:TakeDamage(damage)
			end
		end
	else
		if humanoid.Health - damage <= 0 then
			humanoid.Health = 0
			if sourcePlayer then
				local _, killReward = RewardManager.ProcessKill(sourcePlayer)
				announceKill(sourceName, sourcePlayer, targetCharacter.Name, nil, toolName, isHeadshot, killReward)
			end
			return true
		else
			humanoid:TakeDamage(damage)
		end
	end

	return false
end

function WeaponServer.FireMelee(player, toolName, data)
	local character = player.Character
	if not character then return end
	local tool = character:FindFirstChild(toolName)
	if not tool then return end
	local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true)
	if not handle then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and data.Animations and data.Animations.Swing then
		local animId = data.Animations.Swing[humanoid.RigType.Name]
		if animId then
			local anim = Instance.new("Animation")
			anim.AnimationId = animId
			local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid
			animator:LoadAnimation(anim):Play()
		end
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	local ignoreList = {character}
	local debrisFolder = Workspace:FindFirstChild("WallDebrisFolder")
	if debrisFolder then table.insert(ignoreList, debrisFolder) end
	local baseModel = Workspace:FindFirstChild("Base")
	if baseModel then table.insert(ignoreList, baseModel) end
	overlapParams.FilterDescendantsInstances = ignoreList

	local hitTargets = {}
	for _, hitPart in Workspace:GetPartBoundsInRadius(handle.Position, 3.5, overlapParams) do
		local targetChar = hitPart:FindFirstAncestorWhichIsA("Model")
		if targetChar and targetChar:FindFirstChildOfClass("Humanoid") and not hitTargets[targetChar] then
			hitTargets[targetChar] = true
			local killed = WeaponServer.ProcessDamage(targetChar, data.Damage, player.Name, player, toolName)

			local diff = handle.Position - hitPart.Position
			local fakeNormal = diff.Magnitude > 0.001 and diff.Unit or Vector3.new(0, 1, 0)
			DamageVFX:FireClient(player, hitPart.Position, tostring(data.Damage), hitPart, fakeNormal, killed == true)
		end
	end
end

function WeaponServer.FireHitscan(player, toolName, data, mousePos, isAiming, eyeOrigin)
	local character = player.Character
	if not character or typeof(mousePos) ~= "Vector3" then return end
	local tool = character:FindFirstChild(toolName)
	if not tool then return end
	local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true)
	if not handle then return end

	-- The local camera viewmodel owns gun animation. The current published gun
	-- tracks contain full-body/root poses and must not run on the real Humanoid.
	if handle:FindFirstChild("FireSFX") then handle.FireSFX:Play() end

	-- Hit resolution casts from the shooter's eye, reproducing the exact ray the
	-- crosshair described. Casting from the muzzle instead sits it well below and
	-- right of the camera, so shots clip cover the player could see past and miss
	-- targets that were dead centre - even on Pistol and Sniper, which have no
	-- spread at all. The muzzle stays a purely visual anchor.
	local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	local rayOrigin = head and head.Position
	if typeof(eyeOrigin) == "Vector3" and eyeOrigin == eyeOrigin then
		if not rayOrigin or (eyeOrigin - rayOrigin).Magnitude <= MAX_EYE_OFFSET then
			rayOrigin = eyeOrigin
		end
	end
	if not rayOrigin then return end

	local aimDirection = mousePos - rayOrigin
	if aimDirection.Magnitude < 0.01 then return end
	aimDirection = aimDirection.Unit

	local visualOrigin = FXUtil.GetMuzzlePosition(tool) or handle.Position
	local range = data.Range or 1000

	local spread = data.Spread or 0
	if isAiming and spread > 0 then
		local aimMultiplier = (data.Aim and data.Aim.SpreadMultiplier) or 0.5
		spread = spread * math.clamp(aimMultiplier, 0, 1)
	end

	for _ = 1, data.Pellets or 1 do
		local direction = coneDirection(aimDirection, spread)

		local currentIgnore = {character}
		local debrisFolder = Workspace:FindFirstChild("WallDebrisFolder")
		if debrisFolder then table.insert(currentIgnore, debrisFolder) end
		local baseModel = Workspace:FindFirstChild("Base")
		if baseModel then table.insert(currentIgnore, baseModel) end

		local result = RaycastUtil.CastWithIgnore(rayOrigin, direction, range, currentIgnore, {"RepairP", "Repair"})

		local visualTarget = rayOrigin + (direction * range)
		if result and result.Instance then
			visualTarget = result.Position
			local targetChar = result.Instance:FindFirstAncestorWhichIsA("Model")
			if targetChar and targetChar:FindFirstChildOfClass("Humanoid") then
				local isHeadshot = result.Instance.Name == "Head"
				local damage = isHeadshot and data.Damage * 2 or data.Damage
				local killed = WeaponServer.ProcessDamage(targetChar, damage, player.Name, player, toolName, isHeadshot)
				DamageVFX:FireClient(player, visualTarget, tostring(damage), result.Instance, result.Normal, killed == true)
			end
		end

		-- The shooter redirects its tracer to its own viewmodel muzzle; everyone
		-- else sees it leave the third-person weapon.
		for _, other in ipairs(Players:GetPlayers()) do
			ShowBulletTracer:FireClient(other, visualOrigin, visualTarget, other == player)
		end
	end
end

return WeaponServer
