local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local RoundRemotes = require(Shared.Remotes.RoundRemotes)
local signal = require(Shared.Packages.signal)

local RoundClient = {}

RoundClient.StateChanged = signal.new()
RoundClient.CurrentState = nil
RoundClient.TimeLeft = 0

function RoundClient.Init()
    local updateEvent = RoundRemotes.GetUpdateEvent()
    
    updateEvent.OnClientEvent:Connect(function(newState, timeLeft)
        RoundClient.CurrentState = newState
        RoundClient.TimeLeft = timeLeft
        RoundClient.StateChanged:Fire(newState, timeLeft)
    end)
end

return RoundClient