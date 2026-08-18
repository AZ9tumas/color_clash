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

`QuestRemotes.GetQuestState` exposes a read-only snapshot containing `Stats` and `Completed`. `QuestUpdated` is pushed after every authoritative stat increment. `RewardsController` consumes both paths: it fetches on panel selection and applies pushed snapshots while the Quests panel is open.

Quest rewards remain automatic. Crossing a goal marks the quest complete and grants its reward on the server; the frontend displays progress and completion but never sends a claim request.

## Adding a quest

1. Reuse an existing `Stat`, or add a clearly named update API and call it from the authoritative server event.
2. Add a stable unique quest ID to `QuestConfig.Quests`.
3. Add the same ID to `QuestConfig.Order` at the intended display position.
4. Set `Goal`, `Name`, and a supported reward.
5. Confirm a profile cannot earn it twice.
6. Confirm the Rewards screen renders the new card and updates after the authoritative stat event.

Quest IDs are persisted in `Completed`; changing an ID creates a different quest for existing players.

## Daily rewards

Configuration is in `DailyRewardConfig`, state and claims are handled by `DailyRewardServer`, and access is through two RemoteFunctions in `DailyRewardRemotes`. `RewardsController` renders the schedule from the existing `StarterGui.Rewards` templates, invokes claims, and maintains the visible reset countdown.

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

## Rewards frontend

`RewardsController` is auto-loaded with the other UI controllers. It expects this Studio-owned hierarchy:

```text
PlayerGui.Rewards.Frame
├── Category.ScrollingFrame
│   ├── DailyRewards.btn
│   └── Quests.btn
├── MainFrame.Container
│   ├── Section
│   └── Template
└── ExitButton.btn
```

The controller hides `Section` and `Template`, then clones them at runtime in the same style as `ShopController`.

The Daily Rewards panel:

- renders every schedule entry supplied by the server;
- enables only the currently claimable card;
- debounces the claim RemoteFunction;
- trusts only the server result before showing `Claimed`;
- displays the next reset countdown and refreshes state at zero.

The Quests panel:

- renders definitions in `QuestConfig.Order`;
- combines replicated definitions with server-owned progress;
- displays progress or `Completed` without a client claim action;
- refreshes from `QuestUpdated` while visible.

The main-menu button is named `DailyRewards`, but it opens the complete Rewards screen containing both panels.

## Frontend verification

In a local Studio playtest:

1. Open Daily Rewards from the main menu and confirm seven cards are generated.
2. Claim an available day and confirm the button changes to `Claimed` only after the server response.
3. Confirm the next reward displays a live reset countdown.
4. Switch to Quests and confirm all IDs in `QuestConfig.Order` render.
5. Trigger a quest stat from its authoritative server path and confirm progress updates without reopening the panel.
6. Exit and reopen Rewards to confirm both panels re-fetch persisted state.

Do not send reward IDs, streak values, or desired reward contents from the client. The current API intentionally accepts no claim arguments.
