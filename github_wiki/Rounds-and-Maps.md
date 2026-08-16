# Rounds and Maps

## Main components

| Component | Responsibility |
| --- | --- |
| `RoundServer` | Global loop, state replication, player enrollment, voting, team selection, win conditions, cleanup |
| `RoundMechanic` | Color/push/shoot phase loop, tile hiding/restoration, weapon grant/removal |
| `MapMechanic` | Template harvesting, balanced 8×8 layout generation, cell placement |
| `HitPartMechanic` | Invisible fall detector below the generated map |
| `VotingManager` | Toggle votes and choose the winning mode |
| `RewardManager` | Kill, placement, death-screen, and win rewards |
| `SpectateMechanic` | Server-owned spectator target list |

## State machine and timing

States are declared in `RoundConfig.States`. Modes are in `RoundConfig.Modes`.

Current mode values:

| Mode | Minimum players | Round duration | Team behavior |
| --- | ---: | ---: | --- |
| FFA | 1 | 120 seconds | Last active player wins |
| Teams | 2 | 120 seconds | Red vs Blue, friendly fire disabled |

Global pre-round values:

- `PostRound` countdown: 15 seconds in `RoundServer`
- voting: 10 seconds
- team selection: 10 seconds

Color mechanic values:

| Phase value | Initial | Ramp factor | Minimum |
| --- | ---: | ---: | ---: |
| First push before first color | 5 s | not ramped | 5 s |
| Push between later colors | 0 s | not used when zero | 4 s configured |
| Color announcement | 5 s | 0.85 per cycle | 2 s |
| Hidden/shoot phase | 15 s | 0.85 per cycle | 10 s |

`RoundMechanic.scaled()` returns zero immediately for a nonpositive base value. Therefore `PushDuration = 0` removes the inter-color “Next color” wait for later cycles; it does not clamp to the configured minimum.

## Starting a round

`RoundServer` waits until the selected/default mode’s minimum player count is met. It then runs post-round, voting, and optional team selection. At game start it:

1. generates a new map;
2. builds the fall detector;
3. resets `Kills` and `RoundCash`;
4. selects players with `InMenu == false` and a valid team when required;
5. places them on the map with retry and separation logic;
6. sets `IsPlaying = true`;
7. increments the games-played quest stat;
8. starts `RoundMechanic` and the round timer.

## Ending a round

FFA ends when time expires or at most one active player remains. Team mode can end on a team wipe or timer expiry. Team winner calculation compares team kills first, then alive player count, otherwise producing a draw.

At cleanup the server awards wins/deaths, removes tools, heals characters, teleports players to the lobby, stops the mechanic, restores map tiles, clears phase state, waits two seconds, and resets the active mode to FFA.

## Map generation contract

`MapConfig` currently defines:

- 8 rows × 8 columns;
- X pitch `42.7147` studs;
- Z pitch `45.8270` studs;
- center `Vector3.new(429.385, 0, 224.570)`;
- colors `Green`, `Blue`, `Yellow`, and `Red`;
- up to 8 layout attempts.

Before generation, `MapMechanic.Init()` scans `Workspace.Map` for color-named folders and moves their Model children into `ServerStorage.MapTemplates`. Each color folder must therefore contain at least one valid cell Model in the authored place.

Layout generation balances colors within 2×2 blocks and scores attempts to reduce adjacent equal colors. For each grid cell, the mechanic clones a random template for the assigned color, tints its BaseParts, positions it, and writes `GridRow`, `GridCol`, and `GridColor`.

## Adding a color

1. Add the color name and `Color3` to `MapConfig` using the table’s existing schema.
2. Add a matching folder under `Workspace.Map`.
3. Add at least one Model cell template to that folder.
4. Update `RoundUIController` color-to-text-color mapping.
5. Test generation balance, announcement text, tile hiding, and restoration.

Do not add the config entry without a template folder. Random template selection will have no valid model to clone.

## Spawn and fall handling

`PlayerUtil.TeleportOntoMap()` raycasts against `Workspace.Map`, retries up to 24 times, maintains an 8-stud separation target, and places characters above a valid surface. `Workspace.Game` is the preferred entry marker.

`HitPartMechanic.Build()` places an invisible touch part 50 studs below the map bounds with a 60-stud edge margin. Touching it retires an active player, ragdolls and returns them to `Workspace.Spawnlocation`, and processes placement/death rewards.

## Voting and teams

Votes are stored by stringified UserId. Clicking the selected mode again removes the vote. Ties depend on iteration order after the default is initialized, so do not treat tie resolution as a deterministic design guarantee.

Team selection enforces balancing. The UI marks teams above the lowest other-player count as locked, and the server remains the authority on whether a selection is accepted.
