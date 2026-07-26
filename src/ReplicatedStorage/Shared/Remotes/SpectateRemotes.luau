local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpectateRemotes = {}
local folder = ReplicatedStorage.Shared.Remotes
local isServer = RunService:IsServer()

local remoteNames = {
	SpectateRequest = "RemoteEvent",
	SpectateUpdate = "RemoteEvent"
}

if isServer then
	for name, className in pairs(remoteNames) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new(className)
			r.Name = name
			r.Parent = folder
		end
	end
end

local function getRemote(name)
	if isServer then
		return folder:FindFirstChild(name)
	else
		return folder:WaitForChild(name)
	end
end

function SpectateRemotes.GetRequestEvent() return getRemote("SpectateRequest") end
function SpectateRemotes.GetUpdateEvent() return getRemote("SpectateUpdate") end

return SpectateRemotes
