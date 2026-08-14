local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage.Shared
local RagdollHandler = require(Shared.Modules.Utils.RagdollHandler)

local PlayerUtil = {}

function PlayerUtil.GetActivePlayerCount()
	local count = 0
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("IsPlaying") then count += 1 end
	end
	return count
end

function PlayerUtil.RemoveWeapons(player)
	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid:UnequipTools() end
		for _, item in player.Character:GetChildren() do if item:IsA("Tool") then item:Destroy() end end
	end
	for _, item in player.Backpack:GetChildren() do if item:IsA("Tool") then item:Destroy() end end
end

function PlayerUtil.GiveWeapons(player)
	local assetsFolder = Shared:FindFirstChild("Assets")
	local weaponsFolder = assetsFolder and assetsFolder:FindFirstChild("Weapons")
	if not weaponsFolder then return end

	if RunService:IsServer() then
		local DataServer = require(game:GetService("ServerScriptService").Server.Services.DataService.DataServer)
		local profile = DataServer.GetProfile(player)

		if profile and profile.Data.Equipped then
			local mainWep = profile.Data.Equipped.Main
			local meleeWep = profile.Data.Equipped.Melee

			local function giveTool(name)
				if name then
					local tool = weaponsFolder:FindFirstChild(name)
					if tool and not player.Backpack:FindFirstChild(name) and (not player.Character or not player.Character:FindFirstChild(name)) then
						tool:Clone().Parent = player.Backpack
					end
				end
			end

			giveTool(mainWep)
			giveTool(meleeWep)
		end
	end
end

function PlayerUtil.TeleportEntity(entity, targetPart)
	if targetPart and entity then
		entity:PivotTo(CFrame.new(targetPart.Position + Vector3.new(math.random(-5, 5), 5, math.random(-5, 5))))
	end
end

local function distanceToFloor(entity)
	local hum = entity:FindFirstChildOfClass("Humanoid")
	local root = entity:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return 3 end
	if hum.RigType == Enum.HumanoidRigType.R6 then return 3 end
	return hum.HipHeight + (root.Size.Y / 2)
end

local MIN_SPAWN_SEPARATION = 8

local SPAWN_DROP_HEIGHT = 10

function PlayerUtil.TeleportOntoMap(entity, targetPart, spread, claimed, minSeparation)
	if not entity or not targetPart then return false, nil end

	local map = workspace:FindFirstChild("Map")
	if not map then
		PlayerUtil.TeleportEntity(entity, targetPart)
		return false, nil
	end

	spread = spread or 12
	minSeparation = minSeparation or MIN_SPAWN_SEPARATION

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }

	local lift = distanceToFloor(entity) + 0.5
	local origin = targetPart.Position

	local function clearanceFrom(position)
		if not claimed or #claimed == 0 then return math.huge end
		local worst = math.huge
		for _, used in claimed do
			local dx, dz = position.X - used.X, position.Z - used.Z
			worst = math.min(worst, math.sqrt(dx * dx + dz * dz))
		end
		return worst
	end

	local function place(position)
		entity:PivotTo(CFrame.new(position + Vector3.new(0, lift + SPAWN_DROP_HEIGHT, 0)))
		local root = entity:FindFirstChild("HumanoidRootPart")
		if root then

			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end

	local bestPosition, bestClearance = nil, -1

	for attempt = 1, 24 do

		local centred = attempt == 1 and (not claimed or #claimed == 0)
		local offsetX = centred and 0 or math.random(-spread, spread)
		local offsetZ = centred and 0 or math.random(-spread, spread)
		local from = Vector3.new(origin.X + offsetX, origin.Y + 200, origin.Z + offsetZ)

		local hit = workspace:Raycast(from, Vector3.new(0, 500, 0) * -1, params)
		if hit then
			local clearance = clearanceFrom(hit.Position)
			if clearance >= minSeparation then
				place(hit.Position)
				return true, hit.Position
			end
			if clearance > bestClearance then
				bestClearance, bestPosition = clearance, hit.Position
			end
		end
	end

	if bestPosition then
		place(bestPosition)
		return true, bestPosition
	end

	PlayerUtil.TeleportEntity(entity, targetPart)
	return false, nil
end

function PlayerUtil.RagdollAndTeleport(player, lobbySpawn, kbVelocity)
	if not player.Character then return end
	local char = player.Character
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")

	PlayerUtil.RemoveWeapons(player)

	if hrp then
		pcall(function() hrp:SetNetworkOwner(nil) end)
	end

	RagdollHandler.apply(char, nil, kbVelocity)

	task.delay(2, function()
		if player.Character and player.Character == char and char:IsDescendantOf(workspace) then
			RagdollHandler.remove(char)

			if hrp then
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end

			if hum then hum.Health = hum.MaxHealth end

			task.wait(0.05)
			PlayerUtil.TeleportEntity(char, lobbySpawn)

			if hrp then
				pcall(function() hrp:SetNetworkOwner(player) end)
			end
		elseif player.Parent == Players then
			player:LoadCharacter()
		end
	end)
end

return PlayerUtil