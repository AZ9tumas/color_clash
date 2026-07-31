local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatRemotes = {}
local folder = ReplicatedStorage.Shared.Remotes
local isServer = RunService:IsServer()

local remoteNames = {
	ToolConnections = "RemoteEvent",
	ShowBulletTracer = "RemoteEvent",
	DamageVFX = "RemoteEvent",
	PushRequest = "RemoteEvent"
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

function CombatRemotes.GetToolConnections() return getRemote("ToolConnections") end
function CombatRemotes.GetBulletTracer() return getRemote("ShowBulletTracer") end
function CombatRemotes.GetDamageVFX() return getRemote("DamageVFX") end
function CombatRemotes.GetPushRequest() return getRemote("PushRequest") end

return CombatRemotes