# Feature Recipes

These recipes describe where a feature belongs and the minimum integration work expected.

## Add a new service

1. Choose client, server, or both based on authority.
2. Follow the `NameService/NameClient` or `NameService/NameServer` convention.
3. Return a module with `Init()` and optional `Start()`.
4. Keep initialization independent of sibling iteration order.
5. Put shared tunables in a Core config module.
6. Put remotes in a wrapper module.
7. Update [Architecture](Architecture), [Networking and Security](Networking-and-Security), and [Module Reference](Module-Reference).

Use `Init()` for creating state and connecting stable listeners. Use `Start()` for work that expects all services to have initialized.

## Add a new round mode

1. Add the mode to `RoundConfig.Modes` with `Name`, `MinPlayers`, `Duration`, and team flags.
2. Extend `RoundServer` win/termination logic if it differs from FFA/Teams.
3. Add a voting UI frame mapping in `RoundUIController`; the current UI maps only FFA and Teams.
4. Decide team selection, highlights, friendly fire, spawn behavior, rewards, and scoreboard layout.
5. Test zero/one/many players, ties, timeout, elimination, disconnect, and menu-return behavior.

## Add a new arena phase

1. Define the phase’s server behavior in `RoundMechanic`.
2. Set `Workspace.ArenaPhase` centrally.
3. Decide whether weapons exist, push is accepted, movement is restricted, and music changes.
4. Update UI messaging and state cleanup.
5. Ensure `RoundMechanic.Stop()` can interrupt it at any yield point.

## Add a damage source

Route final damage through `WeaponServer.ProcessDamage()` or extract a more general authoritative damage service if the source is not a weapon. Preserve friendly-fire, quest, reward, retirement, ragdoll, kill-feed, and spectate behavior. Never duplicate only `Humanoid:TakeDamage()` client-side.

## Add hit feedback

1. Keep hit truth on the server.
2. Extend the validated server response payload if needed.
3. Present it in `CombatClient`, `CrosshairController`, and `CameraFX` as appropriate.
4. Respect `Camera Shake`, `Blood Effects`, sound toggles, and Reduce Motion where applicable.
5. Keep feedback readable during sustained fire.

## Add a movement ability

1. Add configuration to `MovementConfig`.
2. Add a distinct `MovementState` and transitions in `MovementClient`.
3. Clean temporary physics and animation state on every exit path.
4. Tell camera/rig systems whether movement owns root rotation.
5. Validate server-visible speed or action requests.
6. Test interactions with slide, jump, wall run, vault, ADS, ragdoll, death, and respawn.

## Add a persistent reward system

1. Extend `DataTemplate` with backwards-compatible state.
2. Build a server service around `DataServer.WaitForProfile`.
3. Grant cash through `CurrencyServer` and weapon ownership through the inventory schema.
4. Keep eligibility and claim mutation in one server operation.
5. Expose a read/claim API through a dedicated remote wrapper.
6. Debounce client requests but rely on server idempotency.
7. Test fresh, legacy, repeated, reconnect, and boundary-time profiles.

## Add a UI screen

1. Build the GUI in Studio or map it explicitly through Rojo.
2. Create one UI controller and let the bootstrap auto-load it.
3. Resolve lifecycle from attributes/remotes instead of inferred visibility.
4. Use `UIAnimations` and settings-aware sound volume.
5. Avoid long work at module load time.
6. Test menu, play, death, spectate, respawn, and re-entry.

## Change a remote signature

1. Find all wrapper getters, senders, and listeners with `rg`.
2. Change server validation first in the working branch.
3. Update all clients and server callers atomically.
4. Update [Networking and Security](Networking-and-Security).
5. Test malformed old/new payloads and high-frequency use.

## Refactor shared state

Before replacing an attribute, search all `GetAttribute`, `SetAttribute`, and changed-signal uses. Attributes often coordinate UI, camera, movement, round, and server code at once. Migrate all readers/writers together and test the entire lifecycle, not only the initiating feature.
