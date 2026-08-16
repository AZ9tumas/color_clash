# Testing, Debugging, and Release

The repository has vendored package tests but no game-level automated test suite or CI configuration. `test.luau` is an exporter, not a test runner. Game verification is therefore primarily Studio playtesting plus static review.

## Minimum local validation

1. Run `rojo serve default.project.json` and connect Studio.
2. Start a two-client local server.
3. Keep both server and client Output windows visible.
4. Exercise the changed feature and its lifecycle exit paths.
5. Stop the session and inspect warnings/errors before saving or committing.

## Full regression matrix

### Startup and menu

- New client loads without infinite yields.
- Menu camera stays on `Workspace.Cam`.
- Play transitions out of menu once.
- Shop, leaderboard, and settings open and close.
- `M` and Main Menu button start a five-second countdown; a second activation cancels it.
- Return-to-menu removes round participation, tools, spectating, and combat camera ownership.

### Rounds

- FFA starts with one eligible player.
- Teams requires the configured minimum and balances selection.
- Voting toggles and broadcasts avatars.
- First color announcement waits five seconds.
- Later cycles do not add the removed inter-color wait.
- Wrong-color tiles hide and all tiles restore.
- Push/Shoot phase weapon grant/removal is correct.
- Timer, team wipe, FFA last player, reset, fall, disconnect, and menu return all end participation correctly.

### Combat

- Test Pistol, an automatic rifle/SMG, Shotgun per-shell reload, and Sniper.
- Verify ammo UI, dry fire, semi/auto cadence, reload cancellation, equip during reload, and weapon swap.
- Verify hip fire, ADS FOV, vignette, movement slow, recoil layers, muzzle flash, sound, shells, and tracers.
- Verify body shot, headshot, friendly-fire rejection, damage number, kill feed, reward, and death screen.
- Test Knife, Axe, and Bat families for animation, sound, cooldown, overlap hit, and impact feedback.
- Repeat representative gun and melee tests on both R6 and R15.

### Camera and character lifecycle

- Scriptable first-person camera activates only during `IsPlaying`.
- Real arms render without body/head obstruction.
- Ragdoll and death release combat camera control.
- ADS clears on unequip, elimination, and menu return.
- Perform three elimination/respawn or round-entry cycles and check for duplicate `ViewmodelWeapon`, ScreenGuis, render bindings, and stuck transparency.
- Observe the other client’s aim-pitch movement.

### Movement and push

- Walk, sprint, slide, slide jump, jump, double jump, wall run on both sides, wall jump, wall climb, and vault.
- Check camera roll, body tilt, speed trail, landing, and double-jump effects.
- ADS applies movement slow and releases it.
- Every active mover/constraint clears on elimination and menu return.
- Push checks radius, facing, cooldown, teammate filtering, and ragdolled targets.

### Data and progression

- Fresh profile receives starter weapons and stats.
- Cash, wins, and lifetime kills update persistent and runtime values.
- Purchase rejects insufficient funds and duplicate ownership.
- Equipped Main/Melee persist and are granted in Shoot.
- Quest counters complete once and grant the configured reward.
- Daily state, successful claim, duplicate same-day claim, missed-day reset, loop behavior, cash, and weapon reward all work.
- Settings load, save, and apply after reconnect.

### UI and audio

- HUD visibility follows menu/active/eliminated state.
- Keys 1/2 and slot buttons equip the correct class.
- Crosshair toggles and dynamic bloom work.
- FPS/ping/performance visibility respects settings and menu state.
- Lobby/Calm/Action music transitions without overlapping at full volume.
- Missing optional sound templates fail silently rather than throwing.
- Spectate start/next/previous/exit works as targets die or leave.

## Static checks

Before commit:

```sh
git status --short
git diff --check
rg -n 'WeaponClient|ReplicatedStorage\.Viewmodel|WeaponRigData' src
rg -n 'rbxassetid://rbxassetid://' src
rg -n 'Animations\s*=|AnimationId' src/ReplicatedStorage/Shared src/ServerScriptService/Server
```

Interpret search results; not every match is an error. The first command should not reveal unrelated generated files or accidental place exports.

## Debugging guide

| Symptom | First checks |
| --- | --- |
| Client hangs at startup | Output for infinite yield; verify required GUI and `Workspace.Cam` names |
| No weapons | `InMenu`, `IsPlaying`, `ArenaPhase`, profile `Equipped`, matching Tool under `Shared.Assets.Weapons` |
| Gun input does nothing | Tool is in character, `GunClient` controller exists, Shoot phase, server cooldown/output |
| Hits show no damage | Tool name in `Items`, server raycast filters, team mode, target `IsPlaying`, payload type |
| Wrong tracer origin | muzzle Attachment/part name, 15-stud handle guard, viewmodel data joint alignment |
| Arms/body invisible after round | `GunCameraActive`, `IsPlaying`, ragdoll state, `FirstPersonRig.Disable()` path |
| Camera stuck Scriptable | menu vs first-person ownership, player/character attributes, render-step errors |
| Movement stuck | `MovementState`, temporary LinearVelocity/VectorForce, root anchored, ragdoll cleanup |
| Data unavailable | ProfileStore session/output, API access, `WaitForProfile`, player still parented |
| UI missing | exact Studio hierarchy and `WaitForChild` names, controller initialization errors |
| Daily claim denied | UTC day, `LastClaimedDay`, profile load, returned `Reason` |

## Release checklist

- Scope matches the requested feature.
- No unrelated Studio/source changes are included.
- Config and content names agree across systems.
- Client requests have server validation and rate limiting.
- Fresh and legacy data paths were tested for schema changes.
- Two-client test passed.
- R6 and R15 passed when character presentation changed.
- Three lifecycle repetitions passed when camera, Tools, UI, or connections changed.
- Output is free of new errors and actionable warnings.
- `FXConfig.GunDebug` and `RoundConfig.Push.Debug` are set intentionally.
- Place is saved for Studio-owned changes.
- Serialized `.rbxm` assets are regenerated when required.
- Wiki pages and Module Reference reflect changed contracts.
- `git diff --check` passes and the final diff is reviewed.
