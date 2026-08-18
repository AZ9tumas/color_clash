local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local QuestRemotes = {}
local folder = ReplicatedStorage.Shared.Remotes
local isServer = RunService:IsServer()

local remoteNames = {
	GetQuestState = "RemoteFunction",
	QuestUpdated = "RemoteEvent",
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

function QuestRemotes.GetStateFunction()
	return getRemote("GetQuestState")
end

function QuestRemotes.GetUpdatedEvent()
	return getRemote("QuestUpdated")
end

return QuestRemotes
