# Known Limitations

This page records verified current behavior that future work should account for. It is not a speculative backlog.

## High-priority authority and correctness

### Server ammunition is not authoritative

`GunHandler` tracks ammunition locally. `CombatServer` validates cooldown, phase, item, and equipped Tool, but does not maintain magazine or reload state. An exploit client could request valid-cadence shots without honoring local ammunition.

Recommended direction: server-side per-player/per-Tool magazine state with equip, fire, reload, shell reload, round cleanup, and replication contracts.

### Client target position has limited plausibility validation

Gun requests contain a client-provided Vector3. The server derives a ray from the muzzle and clamps it to weapon range, but does not compare the target direction with replicated aim/camera limits.

### Movement speed request is broadly trusted

`MovementServer` accepts any finite client speed up to the largest configured movement ceiling, regardless of the reported state. Tighten state-to-speed and lifecycle validation before treating this as anti-cheat enforcement.

### Settings values are not type/range validated server-side

The server checks only that a setting name exists. Malformed types or out-of-range values can be persisted by a custom client.

## Presentation and rig gaps

### Remote aim pose is R6-neck-only

`AimPoseController` looks for `Torso.Neck`, so it does not apply equivalent remote pitch to R15 arm/neck chains. Local first-person posing supports both R6 and R15.

### ThirdPersonRig is unused legacy code

No current game-owned module requires `ThirdPersonRig`. It duplicates camera/recoil/aim logic with R6-only pose definitions and should not be treated as an active pipeline.

### Viewmodel content remains separately authored for weapon geometry

Arms and root are real-character driven, but gun geometry, joint offsets, hold, and reload sequences can come from `WeaponViewmodelData.rbxm`. Adding a fully authored gun therefore requires both the Tool asset and this optional data pipeline.

### Item `Animations.Reload` is not the first-person reload source

`GunHandler` loads Idle, Walk, and Shoot on the Humanoid. `Viewmodel.PlayReload()` uses a KeyframeSequence from `WeaponViewmodelData`, not `Items.Animations.Reload`. Keep both declarations aligned when changing reload content.

## Feature completeness

### Daily rewards have no frontend

State, persistence, configuration, and claim remotes exist. No player-facing ScreenGui/controller has been implemented.

### Quests have no frontend or client API

Progress and rewards work server-side. There is no quest UI or dedicated remote for reading quest definitions/progress.

### Chests are placeholders

`ChestServer` creates ProximityPrompts, prints an open message, disables the prompt for five seconds, then re-enables it. It does not grant loot, persist state, animate a chest, or validate a reward table.

### Skins and Effects shop categories are empty

The UI exposes tabs, but `ShopConfig` has no entries and `ShopServer` only implements weapon equip semantics.

### Some settings are declarative only

SFX Volume, Ambient Volume, 3D Spatial Audio, Thumbstick Deadzone, Gamepad Look Sensitivity, and High Res Textures have no runtime consumer.

## Lifecycle and maintenance risks

### Tool watcher connections are not centrally cleaned

`GunClient.watchContainer()` connects `ChildAdded` each time character setup runs, and per-Tool ancestry/destroying connections are not stored in a Janitor. Normal character replacement limits impact, but long Studio sessions and unusual Backpack lifecycle changes deserve leak testing.

### Movement creates duplicate root attachments in one fallback path

When no root attachment exists, `MovementClient` assigns two newly created Attachments in sequence before naming the second. The first remains unnamed and unused. This should be cleaned in a focused fix with R6/R15 regression testing.

### Vote tie behavior is not explicitly deterministic

`VotingManager.GetWinner()` iterates vote counts and uses strictly greater comparisons. Equal counts do not have an authored tie-break policy.

### Game tests are manual

There is no game-level automated test suite or CI. Regression confidence depends on disciplined local-server tests and Output inspection.

## Documentation rule

When one of these limitations is fixed, remove or rewrite the entry in the same change and update the relevant system page and test matrix.
