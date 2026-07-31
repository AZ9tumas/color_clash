local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RoundRemotes = {}
local folder = ReplicatedStorage.Shared.Remotes
local isServer = RunService:IsServer()

local remoteNames = {
	RoundUpdate = "RemoteEvent",
	ColorSelected = "RemoteEvent",
	ClientVote = "RemoteEvent",
	UpdateVotes = "RemoteEvent",
	KillFeedEvent = "RemoteEvent",
	DeathScreenEvent = "RemoteEvent",
	PlayGameEvent = "RemoteEvent",
	ResetEvent = "RemoteEvent",
	MainMenuEvent = "RemoteEvent",
	SelectTeamEvent = "RemoteEvent"
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

function RoundRemotes.GetUpdateEvent() return getRemote("RoundUpdate") end
function RoundRemotes.GetColorEvent() return getRemote("ColorSelected") end
function RoundRemotes.GetClientVoteEvent() return getRemote("ClientVote") end
function RoundRemotes.GetUpdateVotesEvent() return getRemote("UpdateVotes") end
function RoundRemotes.GetKillFeedEvent() return getRemote("KillFeedEvent") end
function RoundRemotes.GetDeathScreenEvent() return getRemote("DeathScreenEvent") end
function RoundRemotes.GetPlayGameEvent() return getRemote("PlayGameEvent") end
function RoundRemotes.GetResetEvent() return getRemote("ResetEvent") end
function RoundRemotes.GetMainMenuEvent() return getRemote("MainMenuEvent") end
function RoundRemotes.GetSelectTeamEvent() return getRemote("SelectTeamEvent") end

return RoundRemotes