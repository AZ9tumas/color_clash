local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PlayerUtil = require(Shared.Modules.Utils.PlayerUtil)
local RewardManager = require(Shared.Modules.Game.RewardManager)

local HitPartMechanic = {}

local PART_NAME = "hit part"
local THICKNESS = 1

-- How far below the arena's lowest point the pad sits.
--
-- It used to sit at y = 0, level with the bottom of the map, which made "slightly below the
-- floor" and "fell off the map" the same event. A player wedged between two cells, or
-- clipped a stud under one by the solver, was eliminated while still standing on the arena.
-- With a 50 stud gap only an actual fall reaches it - roughly 0.7s of falling under default
-- gravity, which also reads better than blinking out the instant a cell disappears.
--
-- Measured from the map rather than hardcoded, so it stays correct if the arena is ever
-- built at a different height.
local DROP_CLEARANCE = 50

-- Falling 50 studs further is 50 studs more horizontal drift, so the pad grows to keep the
-- coverage it had when it sat directly under the map. Anything that still misses it is
-- caught by the Died/destroyed-root recovery in RoundServer.
local EDGE_MARGIN = 60

-- Axis-aligned world bounds across every BasePart under the map. Works for any grid
-- size and stays correct if individual cells are rotated, since each part contributes
-- its projected half-extents rather than its raw Size.
local function measureMap(map)
	local minX, maxX, minZ, maxZ, minY

	for _, part in map:GetDescendants() do
		if part:IsA("BasePart") then
			local cf, size = part.CFrame, part.Size
			local pos = cf.Position

			local halfX = math.abs(cf.RightVector.X) * size.X / 2
				+ math.abs(cf.UpVector.X) * size.Y / 2
				+ math.abs(cf.LookVector.X) * size.Z / 2
			local halfY = math.abs(cf.RightVector.Y) * size.X / 2
				+ math.abs(cf.UpVector.Y) * size.Y / 2
				+ math.abs(cf.LookVector.Y) * size.Z / 2
			local halfZ = math.abs(cf.RightVector.Z) * size.X / 2
				+ math.abs(cf.UpVector.Z) * size.Y / 2
				+ math.abs(cf.LookVector.Z) * size.Z / 2

			minX = math.min(minX or (pos.X - halfX), pos.X - halfX)
			maxX = math.max(maxX or (pos.X + halfX), pos.X + halfX)
			minZ = math.min(minZ or (pos.Z - halfZ), pos.Z - halfZ)
			maxZ = math.max(maxZ or (pos.Z + halfZ), pos.Z + halfZ)
			minY = math.min(minY or (pos.Y - halfY), pos.Y - halfY)
		end
	end

	if not minX then return nil end
	return minX, maxX, minZ, maxZ, minY
end

local function eliminate(player)
	if not player:GetAttribute("IsPlaying") then return end
	player:SetAttribute("IsPlaying", false)

	local lobbySpawn = Workspace:FindFirstChild("Spawnlocation")
	local kbVelocity = Vector3.new(math.random(-30, 30), 80, math.random(-30, 30))

	PlayerUtil.RagdollAndTeleport(player, lobbySpawn, kbVelocity)
	RewardManager.ProcessDeath(player, "The Map", "Stood On The Wrong Color", -1)
end

local function onTouched(hit)
	-- Walk up to the model that actually owns the Humanoid: a hit can land on a limb,
	-- an accessory handle, or one of the ragdoll colliders parented under a limb.
	local character = hit:FindFirstAncestorWhichIsA("Model")
	while character and not character:FindFirstChildOfClass("Humanoid") do
		character = character:FindFirstAncestorWhichIsA("Model")
	end
	if not character then return end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	eliminate(player)
end

-- Rebuilt every intermission so it always matches the map currently in Workspace.
function HitPartMechanic.Build()
	local map = Workspace:FindFirstChild("Map")
	if not map then
		warn("[HitPart] Workspace.Map not found, hit part not created")
		return nil
	end

	local existing = Workspace:FindFirstChild(PART_NAME)
	while existing do
		existing:Destroy()
		existing = Workspace:FindFirstChild(PART_NAME)
	end

	local minX, maxX, minZ, maxZ, minY = measureMap(map)
	if not minX then
		warn("[HitPart] Workspace.Map contains no BaseParts, hit part not created")
		return nil
	end

	local part = Instance.new("Part")
	part.Name = PART_NAME
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = true
	-- Invisible to raycasts so it cannot be hit by bullets or confuse MovementClient's
	-- wall-run / vault probes. Touched is physics-driven, so this does not affect it.
	part.CanQuery = false
	part.Size = Vector3.new(
		(maxX - minX) + EDGE_MARGIN * 2,
		THICKNESS,
		(maxZ - minZ) + EDGE_MARGIN * 2
	)
	part.Position = Vector3.new((minX + maxX) / 2, minY - DROP_CLEARANCE, (minZ + maxZ) / 2)
	part.Transparency = 1
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = Workspace

	part.Touched:Connect(onTouched)

	return part
end

return HitPartMechanic
