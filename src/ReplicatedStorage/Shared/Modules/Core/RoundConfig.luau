local RoundConfig = {}

RoundConfig.States = {
    WaitingForPlayers = "WaitingForPlayers",
    PostRound = "PostRound",
    Voting = "Voting",
    TeamSelect = "TeamSelect",
    Intermission = "Intermission",
    InGame = "InGame"
}

RoundConfig.Modes = {
    FFA = {
        Name = "FFA",
        MinimumPlayers = 1,
        IntermissionDuration = 3,
        GameDuration = 120
    },
    Teams = {
        Name = "Teams",
        MinimumPlayers = 2,
        IntermissionDuration = 3,
        GameDuration = 120,
        TeamBased = true,
        FriendlyFire = false
    }
}

-- The two sides in TeamBased modes. Stored on players as the "Team" attribute, which
-- replicates, so clients can read team membership without a remote.
RoundConfig.TeamNames = { "Red", "Blue" }

-- Which half of MainHUD.Top each team occupies, and the colour used for that side's
-- stroke plus the in-world character highlights. Shared so the scoreboard and the
-- highlights can never disagree about which colour means which team.
RoundConfig.TeamSides = { Red = "Left", Blue = "Right" }

RoundConfig.TeamColors = {
	Red = Color3.fromRGB(196, 40, 28),
	Blue = Color3.fromRGB(13, 105, 172),
}

-- How long the team picker stays up after voting, in TeamBased modes only. Players who
-- do not pick within the window sit the round out in the lobby.
RoundConfig.TeamSelectDuration = 10

-- One cycle of the arena. Weapons only exist during Hidden; the two visible phases are
-- push-only, which is what Workspace:GetAttribute("ArenaPhase") reports to the client.
RoundConfig.Phases = {
	PushDuration = 10, -- all platforms up, no colour called yet
	AnnounceDuration = 5, -- all platforms up, colour called, run for it
	HiddenDuration = 15, -- wrong platforms gone, weapons live
}

RoundConfig.Push = {
	Cooldown = 0.6,
	Radius = 12, -- studs from the pusher
	Force = 90, -- horizontal shove
	Lift = 25, -- upward component, so players pop off rather than slide
	MinDot = 0.35, -- how far in front a target must be; 1 = dead ahead, 0 = anywhere in a half circle
	Duration = 0.2, -- how long the LinearVelocity stays attached, making the shove an impulse
	MaxForce = 100000, -- per-axis force cap on the mover, matching MovementClient's constraints
	Debug = true, -- prints [Push] lines on both client and server; set false to silence
}

RoundConfig.VotingDuration = 10
RoundConfig.CurrentMode = RoundConfig.Modes.FFA

-- CurrentMode is only ever assigned on the server, and module state does not replicate,
-- so a client reading it directly would always see FFA. RoundServer mirrors the active
-- mode onto a Workspace attribute, which does replicate; read it through here.
function RoundConfig.GetActiveMode()
	local name = workspace:GetAttribute("RoundMode")
	return (name and RoundConfig.Modes[name]) or RoundConfig.CurrentMode
end

return RoundConfig