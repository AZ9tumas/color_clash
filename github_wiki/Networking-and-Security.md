# Networking and Security

Remote wrapper modules under `Shared.Remotes` create their Instances when required on the server and return them with `FindFirstChild` server-side or `WaitForChild` client-side. Add remotes through the appropriate wrapper instead of creating them in unrelated services.

## Combat remotes

| Remote | Direction | Payload | Server/client behavior |
| --- | --- | --- | --- |
| `ToolConnections` | client → server | `toolName: string, mousePos: Vector3, isAiming: boolean` | `CombatServer` rate-limits and dispatches gun/melee |
| `ShowBulletTracer` | server → all clients | `origin: Vector3, targetPos: Vector3` | cosmetic tracer and muzzle flash |
| `DamageVFX` | server → shooter | `position, damage, hitPart, hitNormal, killed` | hit marker, damage number, blood, melee impact, kill flash |
| `PushRequest` | client → server | no arguments | validated push search and force |
| `AimPitch` | client → server | `pitch: number` | finite check, clamp to `[-1.4, 1.4]`, store attribute |

## Round remotes

| Remote | Direction | Payload |
| --- | --- | --- |
| `RoundUpdate` | server → clients | `newState, timeLeft` |
| `ColorSelected` | server → clients | `colorName or "Next", duration` |
| `ClientVote` | client → server | `modeName` |
| `UpdateVotes` | server → clients | `{ [userIdString] = modeName }` |
| `KillFeedEvent` | server → clients | kill entry table |
| `DeathScreenEvent` | server → one client | killer, weapon, victim count, placement, reward, round kills |
| `PlayGameEvent` | client → server | no arguments |
| `ResetEvent` | client → server | no arguments |
| `MainMenuEvent` | client → server | no arguments |
| `SelectTeamEvent` | client → server | `teamName` |

## Economy and settings remotes

| Wrapper | Remote | Type | Request/response |
| --- | --- | --- | --- |
| `ShopRemotes` | `GetInventory` | RemoteFunction | no args → inventory/equipped table |
| `ShopRemotes` | `BuyItem` | RemoteFunction | category, itemName → Boolean |
| `ShopRemotes` | `EquipItem` | RemoteFunction | category, itemName → success, slot |
| `SettingsRemotes` | `GetSettings` | RemoteFunction | no args → saved settings table |
| `SettingsRemotes` | `UpdateSetting` | RemoteEvent | settingName, value |
| `DailyRewardRemotes` | `GetDailyReward` | RemoteFunction | no args → daily state |
| `DailyRewardRemotes` | `ClaimDailyReward` | RemoteFunction | no args → claim result |

## Other remotes

- `MovementRemotes.UpdateState`: client → server, `state, speed`.
- `SpectateRemotes.SpectateRequest`: client → server, action `Start`, `Stop`, `Next`, or `Prev`.
- `SpectateRemotes.SpectateUpdate`: server → client, target Player or nil and spectator count.

## Server validation checklist

For every client-to-server remote, validate:

1. argument types and finite numbers;
2. string membership in a server-owned config;
3. player lifecycle (`InMenu`, `IsPlaying`, ragdoll, alive);
4. ownership/equipment of referenced content;
5. range, direction, line of sight, or phase where relevant;
6. cooldown/rate limit using server time;
7. persisted ownership and sufficient currency for economic actions;
8. response payload contains no internal profile object or mutable server reference.

The client may predict presentation, but it must not decide damage, rewards, ownership, purchases, placement, or daily-claim eligibility.

## Current validation strengths

- Combat requires participation, Shoot phase, a configured item, server cooldown, and an actually equipped Tool.
- Damage and friendly-fire decisions are server-owned.
- Push repeats lifecycle, team, range, direction, and cooldown checks on the server.
- Shop derives price and category from server config and uses server cash.
- Daily reward state and reward contents are fully server-selected.
- Spectate actions resolve targets from a server-owned active-player list.

## Current hardening gaps

- Gun ammo is local only; the server does not reject firing beyond a magazine/reload model.
- Combat target `mousePos` is client-provided. Range is bounded, but camera-to-target plausibility is not validated.
- Movement speed is accepted from the client up to a global maximum, without strict state-to-speed validation.
- Settings validate the name but not the type or configured slider bounds.
- RemoteFunction handlers have no explicit per-player request throttles for shop/settings/daily state calls.
- PushServer does not check `ArenaPhase == "Push"`.

These are documented facts, not permission to move authority client-side. See [Known Limitations](Known-Limitations) for prioritization.

## Adding a remote

1. Add its name/class to the smallest relevant remote wrapper.
2. Add a getter with a stable API.
3. Require the wrapper from the owning server service so creation happens during startup.
4. Define the direction and payload in this page.
5. Implement server validation before client presentation.
6. Add rate limiting for repeatable actions.
7. Test malformed type, missing object, wrong lifecycle, spam, and normal behavior with two clients.

Changing a remote signature is a cross-system migration. Update every sender, listener, this page, and the test matrix in one change.
