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

-- The kill feed is fed from here rather than from the death flow because this is where
-- the shot's own context still exists - which gun, and whether it was a headshot. Teams
-- ride along so each client can colour the row from its own point of view.
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

	-- Friendly fire. ProcessDamage is the single funnel for melee and hitscan alike, so
	-- this one gate covers every weapon. Gated on the mode so FFA is unaffected.
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
			anim.AnimationId = "rbxassetid://" .. tostring(animId)
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

function WeaponServer.FireHitscan(player, toolName, data, mousePos, isAiming)
	local character = player.Character
	if not character or not mousePos then return end
	if typeof(mousePos) ~= "Vector3" then return end
	local tool = character:FindFirstChild(toolName)
	if not tool then return end
	local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart", true)
	if not handle then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and data.Animations and data.Animations.Shoot then
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. tostring(data.Animations.Shoot)
		local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid
		animator:LoadAnimation(anim):Play()
	end
	if handle:FindFirstChild("FireSFX") then handle.FireSFX:Play() end

	-- Tracers and flashes start at the actual muzzle when one can be found; the handle
	-- is only the fallback. The multiplier comes from the server's own config, so a
	-- client saying "I'm aiming" can only ever get the reduction this gun defines.
	local origin = FXUtil.GetMuzzlePosition(tool) or handle.Position

	local spread = data.Spread or 0
	if isAiming and spread > 0 then
		local aimMultiplier = (data.Aim and data.Aim.SpreadMultiplier) or 0.5
		spread = spread * math.clamp(aimMultiplier, 0, 1)
	end

	for i = 1, data.Pellets or 1 do
		local direction = (mousePos - origin).Unit
		local range = data.Range or 1000

		if spread > 0 then
			-- Float form: aim-reduced spread is fractional, and integer math.random(a, b)
			-- errors on non-integer bounds.
			local function jitter()
				return (math.random() * 2 - 1) * spread / 1000
			end
			direction = (direction + Vector3.new(jitter(), jitter(), jitter())).Unit
		end

		local currentIgnore = {character}
		local debrisFolder = Workspace:FindFirstChild("WallDebrisFolder")
		if debrisFolder then table.insert(currentIgnore, debrisFolder) end
		local baseModel = Workspace:FindFirstChild("Base")
		if baseModel then table.insert(currentIgnore, baseModel) end
		
		local result = RaycastUtil.CastWithIgnore(origin, direction, range, currentIgnore, {"RepairP", "Repair"})

		local visualTarget = origin + (direction * range)
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
		ShowBulletTracer:FireAllClients(origin, visualTarget)
	end
end

return WeaponServer