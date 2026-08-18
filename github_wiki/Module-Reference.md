# Module Reference

This is the quick ownership and public-API index. Private local functions are intentionally omitted.

## Shared classes

| Module | Responsibility | Public API |
| --- | --- | --- |
| `FirstPersonRig` | Singleton real-arm camera/aim rig | `new`, `GetShared`, `GetPosePitch`; rig `Enable`, `Disable`, `Destroy`, `StartADS`, `StopADS`, `ApplyAimKick`, `applyRecoilImpulse` |
| `Viewmodel` | Singleton root-attached first-person weapon geometry | `new`, `GetShared`, `ClearShared`; instance `SetWeapon`, `ClearWeapon`, `Enable`, `Disable`, `Destroy`, `GetMuzzlePosition`, `MuzzleFlash`, `PlayReload`, `StopReload`, recoil/ADS hooks |
| `GunHandler` | Per-Tool ranged controller | `New`; instance `Equip`, `Unequip`, `Destroy`, `shoot`, `stopShoot`, `ADS`, `stopADS`, `Reload` |
| `MeleeHandler` | Per-Tool melee controller | `New`; instance `Equip`, `Unequip`, `Destroy`, `Swing` |
| `ThirdPersonRig` | Legacy/unused per-Tool third-person combat camera rig | `new`; same core rig methods as first person |

`ThirdPersonRig` has no require call in current game-owned source. Do not build new work on it without deciding whether it should be revived or removed.

## Core configuration

| Module | Owns |
| --- | --- |
| `Items` | Weapon stats, classification, recoil, ADS, and animation URIs |
| `RoundConfig` | states, modes, teams, voting/team timing, phase timing, push config |
| `MapConfig` | grid dimensions, spacing, center, colors, layout attempts |
| `MovementConfig` | movement speeds, forces, timing, wall/vault rules, animations |
| `DataTemplate` | new profile schema |
| `RewardConfig` | placement and kill cash |
| `ShopConfig` | categories, prices, descriptions, ranged/melee classification |
| `QuestConfig` | quest definitions, display order, and rewards |
| `DailyRewardConfig` | UTC reset, streak/loop rules, reward schedule |
| `SettingsConfig` | settings UI schema and defaults |
| `FXConfig` | shared sound folder, debug flags, and movement/weapon visual tuning |
| `UIIcons` | asset URI helpers and categorized icon IDs |

## Game and utility modules

| Module | Public API / role |
| --- | --- |
| `RewardManager` | `ProcessKill`, `ProcessDeath`, `ProcessWin` |
| `VotingManager` | `StartVoting`, `CastVote`, `GetWinner` |
| `CameraFX` | `Recoil`, `Shake`, `SetAim`, `ClearAim`, `IsAiming`, `FirePulse` |
| `FXUtil` | shared sound, body-hit, muzzle, shell, speed, slide, landing, double-jump effects |
| `PlayerUtil` | active count, give/remove weapons, teleport, map placement, ragdoll-return |
| `RagdollHandler` | `apply`, `remove` |
| `RaycastUtil` | `CastWithIgnore` repeated-name filter raycast |
| `Spring` | `new`, `Impulse`, `Destroy`; exposes spring position/target behavior |
| `UIAnimations` | settings-aware UI sound and transition helpers |
| `Typewriter` | `Typewrite`, `CountUp` |
| `FormatUtil` | `Comma`, `Suffix` |

## Client services

| Module | Responsibility |
| --- | --- |
| `GunClient` | watches Tools, selects gun/melee handler, routes Mouse 1/2 and R |
| `CombatClient` | hit/tracer/blood/kill feedback, local camera sway and visibility support |
| `MovementClient` | movement state machine and local movement physics; `GetCameraRoll`, `Init` |
| `PushClient` | validated local push request input |
| `RoundClient` | caches round state/time and exposes `StateChanged` signal |

## UI controllers

| Module | Public API / role |
| --- | --- |
| `AimPoseController` | applies remote `AimPitch` presentation |
| `CrosshairController` | `ShowHitMarker`, `AddBloom`, `SetCrosshairVisible`, `Init` |
| `FirstPersonController` | enables/disables singleton rig and viewmodel from `IsPlaying` |
| `KillfeedController` | kill feed and death/win screen |
| `MainHudController` | `SetWeaponInfo`, health and weapon slots |
| `MainMenuController` | return-to-menu countdown, `M` input, and admission-lock presentation |
| `MenuController` | `ReturnToMenu`, menu camera and navigation |
| `MusicController` | state-based music crossfade |
| `PromptController` | custom ProximityPrompt UI |
| `RoundUIController` | state, timer, vote, color, scoreboard UI |
| `SettingsController` | `GetValue`, dynamic UI, persistence, runtime application |
| `ShopController` | shop list, purchase/equip, physical zones |
| `RewardsController` | daily schedule/claim/countdown and quest progress rendering |
| `SpectateController` | spectator controls and camera subject |
| `TeamVisualsController` | team Highlights |
| `TeamsController` | team selection GUI |

## Server classes

| Module | Public API / role |
| --- | --- |
| `WeaponServer` | `ProcessDamage`, `FireMelee`, `FireHitscan` |
| `RoundMechanic` | `new`, instance `Start`, `Stop` |
| `MapMechanic` | `Init`, `BuildLayout`, `Generate` |
| `HitPartMechanic` | `Build` fall detector |
| `SpectateMechanic` | `GetActive`, `Start`, `Stop`, `Cycle`, `Refresh` |

## Server services

| Module | Public API / role |
| --- | --- |
| `DataServer` | profile lifecycle; `ProfileLoaded`, `GetProfile`, `WaitForProfile`, `GetData` |
| `CurrencyServer` | cash/win/kill mutation and reads |
| `RoundServer` | round loop, admission lock, and round remote listeners |
| `CombatServer` | combat cooldown/phase validation and aim-pitch receiver |
| `MovementServer` | movement state/speed receiver and speed clamp |
| `PushServer` | authoritative push target/force logic |
| `QuestServer` | quest stat update APIs and `GetQuests` |
| `DailyRewardServer` | `GetState`, `Claim`, remote bindings |
| `ShopServer` | inventory, buy, and equip RemoteFunctions |
| `SettingsServer` | saved settings read/update |
| `SpectateServer` | spectate action routing |
| `ChestServer` | creates prompts on chest models; reward behavior is not implemented |

## Remote wrappers

`CombatRemotes`, `RoundRemotes`, `MovementRemotes`, `ShopRemotes`, `SettingsRemotes`, `DailyRewardRemotes`, `QuestRemotes`, and `SpectateRemotes` expose getter functions for the remote Instances they own. Exact payloads are in [Networking and Security](Networking-and-Security).
