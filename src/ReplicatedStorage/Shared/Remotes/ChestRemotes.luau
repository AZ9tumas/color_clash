local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ChestRemotes = {}
local folder = ReplicatedStorage.Shared.Remotes
local isServer = RunService:IsServer()

local remoteNames = {
	GetChestState = "RemoteFunction",
	ChestOpened = "RemoteEvent",
}

if isServer then
	for name, className in pairs(remoteNames) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
end

local function getRemote(name)
	if isServer then
		return folder:FindFirstChild(name)
	end
	return folder:WaitForChild(name)
end

-- Returns { [chestId] = seconds until this player can open it again }.
function ChestRemotes.GetStateFunction()
	return getRemote("GetChestState")
end

-- Server -> client: { ChestId, SecondsLeft, Coins? } after an open attempt.
function ChestRemotes.GetOpenedEvent()
	return getRemote("ChestOpened")
end

return ChestRemotes
