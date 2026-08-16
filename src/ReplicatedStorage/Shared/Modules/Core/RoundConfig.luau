local RoundConfig = {}

RoundConfig.States = {
    WaitingForPlayers = "WaitingForPlayers",
    PostRound = "PostRound",
    Voting = "Voting",
    TeamSelect = "TeamSelect",
    InGame = "InGame"
}

RoundConfig.Modes = {
    FFA = {
        Name = "FFA",
        MinimumPlayers = 1,
        GameDuration = 120
    },
    Teams = {
        Name = "Teams",
        MinimumPlayers = 2,
        GameDuration = 120,
        TeamBased = true,
        FriendlyFire = false
    }
}

RoundConfig.TeamNames = { "Red", "Blue" }

RoundConfig.TeamSides = { Red = "Left", Blue = "Right" }

RoundConfig.TeamColors = {
	Red = Color3.fromRGB(196, 40, 28),
	Blue = Color3.fromRGB(13, 105, 172),
}

RoundConfig.TeamSelectDuration = 10

RoundConfig.Phases = {
	FirstPushDuration = 5,
	PushDuration = 0,
	AnnounceDuration = 5,
	HiddenDuration = 15,

	Ramp = {
		Enabled = true,
		Factor = 0.85,
		Min = {
			Push = 4,
			Announce = 2,
			Hidden = 10,
		},
	},
}

RoundConfig.Push = {
	Cooldown = 0.6,
	Radius = 12,
	Force = 90,
	Lift = 25,
	MinDot = 0.35,
	Duration = 0.2,
	MaxForce = 100000,
	Debug = false,
}

RoundConfig.VotingDuration = 10
RoundConfig.CurrentMode = RoundConfig.Modes.FFA

function RoundConfig.GetActiveMode()
	local name = workspace:GetAttribute("RoundMode")
	return (name and RoundConfig.Modes[name]) or RoundConfig.CurrentMode
end

return RoundConfig