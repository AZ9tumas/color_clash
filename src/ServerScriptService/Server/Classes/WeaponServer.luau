local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local RoundConfig = require(Shared.Modules.Core.RoundConfig)
local PlayerUtil = require(Shared.Modules.Utils.PlayerUtil)
local FXUtil = require(Shared.Modules.Utils.FXUtil)
local HitscanUtil = require(Shared.Modules.Utils.HitscanUtil)
local CombatConfig = require(Shared.Modules.Core.CombatConfig)
local LagCompensation = require(ServerScriptService.Server.Classes.LagCompensation)
local QuestServer = require(ServerScriptService.Server.Services.QuestService.QuestServer)
local RewardManager = require(Shared.Modules.Game.RewardManager)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local RoundRemotes = require(Shared.Remotes.RoundRemotes)

local ShowBulletTracer = CombatRemotes.GetBulletTracer()
local DamageVFX = CombatRemotes.GetDamageVFX()
local DamageIndicator = CombatRemotes.GetDamageIndicator()
local KillFeedEvent = RoundRemotes.GetKillFeedEvent()

local WeaponServer = {}

-- How far the client-reported eye may sit from the character's head before it is
-- rejected as bogus and the head is used instead.
local MAX_EYE_OFFSET = 14

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

-- Tells the victim where the damage came from (CombatConfig.CombatFeedback).
local function notifyHit(targetPlayer, sourcePlayer, sourcePosition: Vector3?)
	if not sourcePlayer or sourcePlayer == targetPlayer or not CombatConfig.IsEnabled("CombatFeedback") then return end
	if not sourcePosition then
		local root = sourcePlayer.Character and sourcePlayer.Character:FindFirstChild("HumanoidRootPart")
		sourcePosition = root and root.Position
	end
	if sourcePosition then
		DamageIndicator:FireClient(targetPlayer, sourcePosition)
	end
end

-- sourcePosition is optional: where the damage came from when that is not the
-- attacker's body (an explosion), for the victim's hit-direction indicator.
function WeaponServer.ProcessDamage(targetCharacter, damage, sourceName, sourcePlayer, toolName, isHeadshot, sourcePosition)
	-- Shared damage entry point: replicated asset templates are never targets.
	if not targetCharacter:IsDescendantOf(Workspace) then return false end
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
			notifyHit(targetPlayer, sourcePlayer, sourcePosition)
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

-- Hit claims arrive as { pelletIndex, part } pairs. Anything malformed is
-- dropped, which only turns that pellet into a miss.
local function readClaims(claims, pellets: number)
	local byPellet = {}
	if type(claims) ~= "table" then return byPellet end

	for n = 1, math.min(#claims, pellets) do
		local claim = claims[n]
		if type(claim) == "table" then
			local index, part = claim[1], claim[2]
			if type(index) == "number" and index % 1 == 0 and index >= 1 and index <= pellets
				and byPellet[index] == nil and typeof(part) == "Instance" and part:IsA("BasePart") then
				byPellet[index] = part
			end
		end
	end
	return byPellet
end

-- Damages the target of one pellet the shooter's client says hit `part`, if the
-- server agrees it could have: the part sat on that ray inside the shooter's
-- rewind window, and no wall stands in between. Returns where the tracer ends.
local function resolveClaim(player, toolName, data, origin, direction, range, part)
	local character = player.Character
	local targetChar = part and LagCompensation.ModelOf(part)
	if targetChar and targetChar ~= character then
		local hitPosition, struck = LagCompensation.FindHit(player, part, origin, direction, range)
		if hitPosition and LagCompensation.IsClear(origin, hitPosition, targetChar) then
			local isHeadshot = struck.Name == "Head"
			local damage = isHeadshot and data.Damage * 2 or data.Damage
			if CombatConfig.IsEnabled("GunHandling") then
				damage = HitscanUtil.HandlingDamage(data, (hitPosition - origin).Magnitude, isHeadshot)
			end
			local killed = WeaponServer.ProcessDamage(targetChar, damage, player.Name, player, toolName, isHeadshot)
			-- The shooter already showed this hit when it fired; only a kill is news.
			if killed then
				DamageVFX:FireClient(player, hitPosition, tostring(damage), struck, nil, true, true)
			end
			return hitPosition
		end
	end

	local result = HitscanUtil.Cast(origin, direction, range, character)
	return result and result.Position or origin + direction * range
end

function WeaponServer.FireHitscan(player, toolName, data, mousePos, isAiming, eyeOrigin, clientDirections, claims)
	local character = player.Character
	if not character or not HitscanUtil.IsFiniteVector(mousePos) then return end
	local tool = character:FindFirstChild(toolName)
	if not tool then return end
	local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true)
	if not handle then return end

	-- Hit resolution casts from the shooter's eye, reproducing the exact ray the
	-- crosshair described. Casting from the muzzle instead sits it well below and
	-- right of the camera, so shots clip cover the player could see past and miss
	-- targets that were dead centre - even on Pistol and Sniper, which have no
	-- spread at all. The muzzle stays a purely visual anchor.
	local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	local rayOrigin = head and head.Position
	if HitscanUtil.IsFiniteVector(eyeOrigin) then
		if rayOrigin and (eyeOrigin - rayOrigin).Magnitude <= MAX_EYE_OFFSET then
			rayOrigin = eyeOrigin
		end
	end
	if not rayOrigin then return end

	local aimDirection = mousePos - rayOrigin
	if not HitscanUtil.IsFiniteVector(aimDirection)
		or aimDirection.Magnitude < 0.01 or aimDirection.Magnitude == math.huge then return end
	aimDirection = aimDirection.Unit

	local visualOrigin = FXUtil.GetMuzzlePosition(tool) or handle.Position
	local range = data.Range or 1000

	local spread = HitscanUtil.EffectiveSpread(data, isAiming)
	local pellets = data.Pellets or 1
	-- Under GunHandling the client's cone depends on movement the server cannot
	-- see exactly at the moment of firing, so directions are checked against the
	-- widest cone that gun can produce.
	local spreadLimit = CombatConfig.IsEnabled("GunHandling") and HitscanUtil.SpreadBound(data) or spread
	local directions = HitscanUtil.ValidateDirections(clientDirections, aimDirection, spreadLimit, pellets)
	-- Missing directions retain support for older senders; malformed predictions
	-- are rejected instead of turning into a different, late shot.
	if clientDirections ~= nil and not directions then return end
	local shooterDrewTracers = directions ~= nil

	-- Under ClientHitReg the shooter's client reports what each pellet hit, so its
	-- spread rolls are required; pellets without a claim are misses.
	local claimed = nil
	if CombatConfig.IsEnabled("ClientHitReg") then
		if not directions then return end
		claimed = readClaims(claims, pellets)
	end

	-- Local presentation already ran; this replicated sound is for other players.
	local fireSound = handle:FindFirstChild("FireSFX")
	if fireSound and fireSound:IsA("Sound") then fireSound:Play() end

	for i = 1, pellets do
		local direction = directions and directions[i] or HitscanUtil.ConeDirection(aimDirection, spread)

		local visualTarget
		if claimed then
			visualTarget = resolveClaim(player, toolName, data, rayOrigin, direction, range, claimed[i])
		else
			local result = HitscanUtil.Cast(rayOrigin, direction, range, character)

			visualTarget = rayOrigin + (direction * range)
			if result and result.Instance then
				visualTarget = result.Position
				local targetChar = result.Instance:FindFirstAncestorWhichIsA("Model")
				if targetChar and targetChar:FindFirstChildOfClass("Humanoid") then
					local isHeadshot = result.Instance.Name == "Head"
					local damage = isHeadshot and data.Damage * 2 or data.Damage
					if CombatConfig.IsEnabled("GunHandling") then
						damage = HitscanUtil.HandlingDamage(data, (result.Position - rayOrigin).Magnitude, isHeadshot)
					end
					local killed = WeaponServer.ProcessDamage(targetChar, damage, player.Name, player, toolName, isHeadshot)
					DamageVFX:FireClient(player, visualTarget, tostring(damage), result.Instance, result.Normal, killed == true)
				end
			end
		end

		-- The shooter already drew this tracer from its viewmodel muzzle the moment
		-- it fired; everyone else sees it leave the third-person weapon.
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player or not shooterDrewTracers then
				ShowBulletTracer:FireClient(other, visualOrigin, visualTarget, other == player)
			end
		end
	end
end

return WeaponServer
