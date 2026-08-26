local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VIEWMODEL_COLLISION_GROUP = "Viewmodel"

if not PhysicsService:IsCollisionGroupRegistered(VIEWMODEL_COLLISION_GROUP) then
	PhysicsService:RegisterCollisionGroup(VIEWMODEL_COLLISION_GROUP)
end

local function disableViewmodelCollisionWith(groupName)
	if PhysicsService:IsCollisionGroupRegistered(groupName) then
		PhysicsService:CollisionGroupSetCollidable(VIEWMODEL_COLLISION_GROUP, groupName, false)
	end
end

-- A first-person viewmodel should never physically interact with the world,
-- including player-specific collision groups already registered in this place.
for _, group in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
	disableViewmodelCollisionWith(group.name)
end

local function watchCharacterPart(instance)
	if not instance:IsA("BasePart") then return end

	disableViewmodelCollisionWith(instance.CollisionGroup)
	instance:GetPropertyChangedSignal("CollisionGroup"):Connect(function()
		disableViewmodelCollisionWith(instance.CollisionGroup)
	end)
end

local function watchCharacter(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		watchCharacterPart(descendant)
	end
	character.DescendantAdded:Connect(watchCharacterPart)
end

local function watchPlayer(player)
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end
Players.PlayerAdded:Connect(watchPlayer)

-- Assign the saved template as well as runtime clones.
local viewmodelTemplate = ReplicatedStorage.Shared.Assets:WaitForChild("Viewmodel")
for _, descendant in ipairs(viewmodelTemplate:GetDescendants()) do
	if descendant:IsA("BasePart") then
		descendant.CollisionGroup = VIEWMODEL_COLLISION_GROUP
	end
end

-- The first-person rig sends aim pitch through this remote. Requiring the
-- server-side remote registry creates the small set of RemoteEvents it needs.
require(ReplicatedStorage.Shared.Remotes.CombatRemotes)
