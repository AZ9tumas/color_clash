# Getting Started

## Prerequisites

- Roblox Studio with the Rojo plugin installed
- Aftman for the pinned Rojo version
- Rokit for the pinned Lune version when running extraction utilities
- Git

The repository pins Rojo `7.7.0-rc.1` in `aftman.toml` and Lune `0.10.5` in `rokit.toml`.

## First setup

From the `color_clash` repository root:

```sh
aftman install
rokit install
rojo serve default.project.json
```

Open `color_clash.rbxl` in Roblox Studio, open the Rojo plugin, and connect to the server printed by `rojo serve`.

## What Rojo owns

`default.project.json` maps these filesystem locations:

| Studio service | Filesystem path |
| --- | --- |
| `ReplicatedStorage` | `src/ReplicatedStorage` |
| `ServerScriptService` | `src/ServerScriptService` |
| `ServerStorage` | `src/ServerStorage` |
| `StarterGui` | `src/StarterGui` |
| `StarterPlayer.StarterCharacterScripts` | `src/StarterPlayer/StarterCharacterScripts` |
| `StarterPlayer.StarterPlayerScripts` | `src/StarterPlayer/StarterPlayerScripts` |

All mapped roots use `$ignoreUnknownInstances: true`. This matters: Studio-only children such as GUI objects, map geometry, sounds, tool parts, and world markers survive a Rojo sync even when they do not appear under `src`.

Treat the repository as authoritative for mapped scripts and serialized model files. Treat the place file as authoritative for Studio-authored instances that are intentionally preserved outside Rojo.

## Normal workflow

1. Pull the latest repository state.
2. Start `rojo serve default.project.json`.
3. Open `color_clash.rbxl` and connect the plugin.
4. Change mapped scripts in the filesystem.
5. Change Studio-owned assets in Studio.
6. Run a local server test with at least two players for multiplayer behavior.
7. Save the place when Studio-owned assets changed.
8. Review `git diff` and follow the release checklist.

Do not run `test.luau` as a routine sync command. It is a recursive place-to-source exporter and can rewrite the source tree. `decompose.luau`, `remodel.luau`, and `extract_reference_viewmodel.luau` are tooling or legacy migration utilities, not runtime code.

## Weapon viewmodel asset extraction

`src/ReplicatedStorage/WeaponViewmodelData.rbxm` is a serialized asset mounted by Rojo. When its Studio copy is intentionally edited, save the place first, then run:

```sh
lune run extract_weapon_viewmodel_data.luau
```

The extractor requires every weapon-data folder it encounters to contain `WeaponModel`, `Reload`, `Hold`, and `Joints`. Review the generated `.rbxm` diff and test every affected weapon.

## First playtest

Use Studio’s local server mode with two clients. Verify:

- both clients leave the menu and join a round;
- voting and team selection work;
- color phases hide and restore tiles;
- gun fire, reload, ADS, damage, and kill feed work;
- melee damage and swing presentation work;
- sprint, slide, double jump, wall run, wall climb, vault, and push work;
- elimination starts spectating and return-to-menu works;
- pressing `M` starts or cancels the five-second return-to-menu countdown;
- Studio output has no new errors or warnings.

See [Testing, Debugging, and Release](Testing-Debugging-and-Release) for the complete matrix.

## Debug switches

- `FXConfig.GunDebug` enables gun, melee, rig, and viewmodel logging. It is currently `true`.
- `RoundConfig.Push.Debug` enables push request and validation logging. It is currently `false`.

Disable verbose flags before a production release unless logs are intentionally needed.
