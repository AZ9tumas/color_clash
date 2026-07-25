local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementRemotes = {}
local folder = ReplicatedStorage.Shared.Remotes
local isServer = RunService:IsServer()

local remoteNames = {
	UpdateState = "RemoteEvent"
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

function MovementRemotes.GetUpdateStateEvent() return getRemote("UpdateState") end

return MovementRemotes