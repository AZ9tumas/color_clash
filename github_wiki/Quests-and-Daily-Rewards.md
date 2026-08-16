# Quests and Daily Rewards

## Quests

Quest definitions live in `QuestConfig.Quests`. Each definition has:

| Field | Meaning |
| --- | --- |
| `Stat` | Counter key under `profile.Data.Quests.Stats` |
| `Goal` | Completion threshold |
| `Name` | Player-facing description |
| `Reward` | Table containing `Cash` and/or `Weapon` |

`QuestServer.bump()` increments a stat, scans all quest definitions using that stat, marks newly completed IDs, and grants each reward once.

Current update APIs:

- `UpdateGamesPlayed`
- `UpdateRoundWins`
- `UpdateSecondPlace`
- `UpdateEliminations`
- `UpdateShotsTaken`
- `UpdateShotsLanded`
- `UpdateFriendPlays`

Friend-play progress is checked when a player joins by comparing them with players already in the server.

There is currently no quest remote or dedicated quest frontend. `QuestServer.GetQuests(player)` returns the server-side quest state for future backend integrations.

## Adding a quest

1. Reuse an existing `Stat`, or add a clearly named update API and call it from the authoritative server event.
2. Add a stable unique quest ID to `QuestConfig.Quests`.
3. Set `Goal`, `Name`, and a supported reward.
4. Confirm a profile cannot earn it twice.
5. If a frontend is added, return definitions and progress without letting the client grant or mark completion.

Quest IDs are persisted in `Completed`; changing an ID creates a different quest for existing players.

## Daily rewards

The daily reward system is backend-only by design. Configuration is in `DailyRewardConfig`, state and claims are handled by `DailyRewardServer`, and access is through two RemoteFunctions in `DailyRewardRemotes`.

Current rules:

- reset hour is 00:00 UTC;
- missing more than one daily window resets the streak;
- rewards loop after day 7;
- the claim is server-authoritative;
- the same UTC day cannot be claimed twice.

## Reward schedule

| Day | Reward |
| ---: | --- |
| 1 | 250 cash |
| 2 | 500 cash |
| 3 | 750 cash |
| 4 | 1,000 cash |
| 5 | 1,500 cash |
| 6 | 2,000 cash |
| 7 | 3,000 cash and Metal Axe |

## State response

`GetDailyReward` returns:

```lua
{
    CanClaim = true,
    Streak = 0,
    Day = 1,
    Reward = rewardDefinition,
    TotalClaimed = 0,
    SecondsUntilReset = 12345,
    Rewards = DailyRewardConfig.Rewards,
}
```

`ClaimDailyReward` returns either a successful payload with `Claimed`, `Day`, `Streak`, `Reward`, and `SecondsUntilReset`, or a failure with `Claimed = false` and a `Reason` such as `NoProfile`, `AlreadyClaimed`, or `NoRewards`.

## Time model

The server computes a day index using `os.time()` offset by `ResetHourUTC`. It stores the integer day, not a timestamp. `SecondsUntilReset` is informational and must not be trusted as claim authority by a future client.

## Supported reward types

Daily reward granters currently support:

- `Cash`: calls `CurrencyServer.AddCash`;
- `Weapon`: marks inventory ownership.

Unknown keys in a reward definition are ignored. To add a reward type, implement a server granter, define its value schema, add a backward-compatible data field if needed, and document the client display format.

## Adding the frontend

A future UI should:

1. invoke `GetStateFunction()` when opened;
2. render the server-provided schedule and current day;
3. disable claim when `CanClaim` is false;
4. invoke `ClaimFunction()` once per click with local request debouncing;
5. render only the server response as success;
6. refresh cash/inventory presentation after a successful claim;
7. show reset time as a countdown but refresh state when it reaches zero.

Do not send reward IDs, streak values, or desired reward contents from the client. The current API intentionally accepts no claim arguments.
