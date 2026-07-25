local RoundConfig = {}

RoundConfig.States = {
    WaitingForPlayers = "WaitingForPlayers",
    PostRound = "PostRound",
    Voting = "Voting",
    Intermission = "Intermission",
    InGame = "InGame"
}

RoundConfig.Modes = {
    FFA = {
        Name = "FFA",
        MinimumPlayers = 1,
        IntermissionDuration = 3,
        GameDuration = 120
    }
}

RoundConfig.VotingDuration = 10
RoundConfig.CurrentMode = RoundConfig.Modes.FFA

return RoundConfig