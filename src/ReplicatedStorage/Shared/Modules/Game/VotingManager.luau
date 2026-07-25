local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local RoundRemotes = require(Shared.Remotes.RoundRemotes)
local RoundConfig = require(Shared.Modules.Core.RoundConfig)

local VotingManager = {}
VotingManager.CurrentVotes = {}

function VotingManager.StartVoting()
	VotingManager.CurrentVotes = {}
	RoundRemotes.GetUpdateVotesEvent():FireAllClients(VotingManager.CurrentVotes)
end

function VotingManager.CastVote(player, modeName)
	if not RoundConfig.Modes[modeName] then return end
	local userIdStr = tostring(player.UserId)
	if VotingManager.CurrentVotes[userIdStr] == modeName then
		VotingManager.CurrentVotes[userIdStr] = nil
	else
		VotingManager.CurrentVotes[userIdStr] = modeName
	end
	RoundRemotes.GetUpdateVotesEvent():FireAllClients(VotingManager.CurrentVotes)
end

function VotingManager.GetWinner(defaultMode)
	local voteCounts = {}
	for _, mode in pairs(VotingManager.CurrentVotes) do 
		voteCounts[mode] = (voteCounts[mode] or 0) + 1 
	end
	
	local bestMode, maxVotes = defaultMode.Name, -1
	for mode, count in pairs(voteCounts) do 
		if count > maxVotes then 
			maxVotes = count
			bestMode = mode 
		end 
	end
	return RoundConfig.Modes[bestMode] or RoundConfig.Modes.FFA
end

return VotingManager