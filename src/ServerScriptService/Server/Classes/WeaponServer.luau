local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local RoundConfig = require(Shared.Modules.Core.RoundConfig)
local PlayerUtil = require(Shared.Modules.Utils.PlayerUtil)
local RaycastUtil = require(Shared.Modules.Utils.RaycastUtil)
local QuestServer = require(ServerScriptService.Server.Services.QuestService.QuestServer)
local RewardManager = require(Shared.Modules.Game.RewardManager)
local CombatRemotes = require(Shared.Remotes.CombatRemotes)
local RoundRemotes = require(Shared.Remotes.RoundRemotes)

local ShowBulletTracer = CombatRemotes.GetBulletTracer()
local DamageVFX = CombatRemotes.GetDamageVFX()
local KillFeedEvent = RoundRemotes.GetKillFeedEvent()

local WeaponServer = {}

function WeaponServer.ProcessDamage(targetCharacter, damage, sourceName, sourcePlayer, toolName)
	local targetPlayer = Players:GetPlayerFromCharacter(targetCharacter)
	local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
	
	if not humanoid or humanoid.Health <= 0 then return end

	-- Friendly fire. ProcessDamage is the single funnel for melee and hitscan alike, so
	-- this one gate covers every weapon. Gated on the mode so FFA is unaffected.
	local mode = RoundConfig.CurrentMode
	if mode.TeamBased and not mode.FriendlyFire and sourcePlayer and targetPlayer then
		local sourceTeam = sourcePlayer:GetAttribute("Team")
		if sourceTeam and sourceTeam == targetPlayer:GetAttribute("Team") then return end
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
				if sourcePlayer then
					currentKills = RewardManager.ProcessKill(sourcePlayer)
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
				KillFeedEvent:FireAllClients(sourceName, targetPlayer.Name)
			else
				humanoid:TakeDamage(damage)
			end
		end
	else
		if humanoid.Health - damage <= 0 then
			humanoid.Health = 0
			if sourcePlayer then
				RewardManager.ProcessKill(sourcePlayer)
				KillFeedEvent:FireAllClients(sourceName, targetCharacter.Name)
			end
		else
			humanoid:TakeDamage(damage)
		end
	end
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
			WeaponServer.ProcessDamage(targetChar, data.Damage, player.Name, player, toolName)
			
			local diff = handle.Position - hitPart.Position
			local fakeNormal = diff.Magnitude > 0.001 and diff.Unit or Vector3.new(0, 1, 0)
			DamageVFX:FireClient(player, hitPart.Position, tostring(data.Damage), hitPart, fakeNormal)
		end
	end
end

function WeaponServer.FireHitscan(player, toolName, data, mousePos)
	local character = player.Character
	if not character or not mousePos then return end
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

	local origin = handle.Position

	for i = 1, data.Pellets or 1 do
		local direction = (mousePos - origin).Unit
		local range = data.Range or 1000

		if data.Spread and data.Spread > 0 then
			direction = (direction + Vector3.new(math.random(-data.Spread, data.Spread)/1000, math.random(-data.Spread, data.Spread)/1000, math.random(-data.Spread, data.Spread)/1000)).Unit
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
				local damage = (result.Instance.Name == "Head") and data.Damage * 2 or data.Damage
				WeaponServer.ProcessDamage(targetChar, damage, player.Name, player, toolName)
				DamageVFX:FireClient(player, visualTarget, tostring(damage), result.Instance, result.Normal)
			end
		end
		ShowBulletTracer:FireAllClients(origin, visualTarget)
	end
end

return WeaponServer