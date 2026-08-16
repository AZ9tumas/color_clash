# Glossary

| Term | Meaning in Color Clash |
| --- | --- |
| Active player | A Player with `IsPlaying == true` and a living Humanoid |
| Arena phase | `Workspace.ArenaPhase`; currently `Push` or `Shoot` |
| Core config | Tunable shared module under `Shared.Modules.Core` |
| Handler | Per-Tool client object, currently `GunHandler` or `MeleeHandler` |
| In lobby | Usually `InMenu == false` and `IsPlaying ~= true`; eligible to wait or spectate |
| In menu | `InMenu == true`; menu camera/UI owns the local presentation |
| Item | Entry in `Items` keyed by exact Tool name |
| Mechanic | Reusable server domain object used by a service, such as `RoundMechanic` |
| Real-arm viewmodel | Local first-person presentation using actual character arm joints rather than a cloned stock arm rig |
| Remote wrapper | Shared module that creates and returns named RemoteEvents/RemoteFunctions |
| Round mode | FFA or Teams, stored in `Workspace.RoundMode` and resolved through `RoundConfig` |
| Service | Convention-loaded client/server module with `Init()` and optional `Start()` |
| Shoot phase | Arena phase where weapons are granted and combat requests are accepted |
| Push phase | Arena phase where weapons are removed and players use shove gameplay |
| Studio-owned instance | Asset preserved in the place by Rojo’s `ignoreUnknownInstances` behavior |
| Viewmodel data | Serialized per-weapon model, joints, hold, and reload content under `WeaponViewmodelData` |

## Naming rules worth remembering

- Weapon Tool name = `Items` key = shop item name = inventory key = equipped slot value = optional viewmodel-data folder name.
- Service folder `ExampleService` expects `ExampleClient` or `ExampleServer`.
- Animation IDs are complete string URIs: `rbxassetid://<id>`.
- Muzzle content uses an Attachment named `MuzzlePoint`/`Muzzle` or a BasePart name containing `muzzle`.
- Team names and colors come from `RoundConfig`; do not hard-code new team strings in isolated UI code.
