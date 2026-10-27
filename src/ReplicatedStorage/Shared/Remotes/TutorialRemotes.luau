local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TutorialRemotes = {}
local folder = ReplicatedStorage.Shared.Remotes
local isServer = RunService:IsServer()

local remoteNames = {
	GetTutorialDone = "RemoteFunction",
	TutorialFinished = "RemoteEvent",
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

-- Returns true when this player has finished or skipped the tutorial.
function TutorialRemotes.GetDoneFunction()
	return getRemote("GetTutorialDone")
end

-- Client -> server: the tutorial was finished or skipped.
function TutorialRemotes.GetFinishedEvent()
	return getRemote("TutorialFinished")
end

return TutorialRemotes
