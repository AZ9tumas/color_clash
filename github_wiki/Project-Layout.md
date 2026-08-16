# Project Layout

## Repository root

| Path | Purpose |
| --- | --- |
| `color_clash.rbxl` | Studio place containing world, UI, sound, tool, and other Studio-authored instances |
| `default.project.json` | Rojo mapping; preserves unknown Studio instances |
| `src/` | Rojo-managed scripts, metadata, packages, and serialized assets |
| `src/ReplicatedStorage/WeaponViewmodelData.rbxm` | Authored weapon model, joint, hold, and reload data |
| `aftman.toml` | Pinned Rojo toolchain |
| `rokit.toml` | Pinned Lune toolchain |
| `extract_weapon_viewmodel_data.luau` | Exports viewmodel data from the saved place into the Rojo model |
| `test.luau` | Place-to-source exporter; not a test suite |
| `remodel.luau`, `decompose.luau` | Place/model processing utilities |
| `extract_reference_viewmodel.luau`, `fsafs.rbxm` | Legacy/reference viewmodel migration artifacts |
| `beretta_silencer.rbxm` | Standalone model asset |

## Source tree

```text
src/
├── ReplicatedStorage/
│   ├── Shared/
│   │   ├── Classes/
│   │   ├── Modules/
│   │   │   ├── Core/
│   │   │   ├── Game/
│   │   │   └── Utils/
│   │   ├── Packages/
│   │   ├── Remotes/
│   │   ├── Services/
│   │   └── UIControllers/
│   └── WeaponViewmodelData.rbxm
├── ServerScriptService/Server/
│   ├── Classes/
│   ├── Require/
│   ├── ServerPackages/
│   └── Services/
├── ServerStorage/
├── StarterGui/
└── StarterPlayer/StarterPlayerScripts/Client/
```

## Studio-owned instance contracts

These instances are referenced by runtime code but may not appear as source files because Rojo preserves unknown instances.

### Workspace

| Instance | Required by | Contract |
| --- | --- | --- |
| `Cam` | `MenuController` | Menu camera CFrame; required and waited for indefinitely |
| `Map` | map and round mechanics | Contains color template folders before initialization and generated cells during play |
| `Game` | `RoundServer` | Preferred map-entry spawn/marker |
| `Spawnlocation` | round, damage, and fall logic | Lobby return location |
| `Base` | combat/settings raycasts | Optional world geometry excluded from target raycasts |
| `Shop` | `ShopController` | Optional physical zone for opening the Weapons tab |
| `Skins` | `ShopController` | Optional physical zone for opening the Skins tab |
| `Chests` | `ChestServer` | Optional folder of chest Models with `PrimaryPart` |
| `WallDebrisFolder` | FX and raycasts | Runtime effects folder; created lazily if absent |

### ReplicatedStorage

| Instance | Contract |
| --- | --- |
| `Shared.Assets.Weapons` | Tool templates named exactly like `Items` entries |
| `WeaponViewmodelData` | Per-weapon folders with optional authored first-person weapon data |

### ServerStorage

`MapMechanic.Init()` moves map cell templates out of `Workspace.Map` into `ServerStorage.MapTemplates`. Do not build another system that assumes those original template models remain in Workspace after server initialization.

### SoundService

- `GameSounds` contains named templates used by `FXUtil`.
- `Music` should contain `Lobby`, `Calm`, and `Action` Sound instances.

### StarterGui

Runtime controllers expect the GUI names and descendants listed in [UI, Settings, and Audio](UI-Settings-and-Audio). Renaming a Studio GUI without updating its controller commonly causes an infinite `WaitForChild` yield during client startup.

## Metadata files

`init.meta.json` preserves the intended Roblox class and unknown child behavior for a Rojo directory. Keep metadata when moving directories, especially beneath GUI and service containers.

## Source-of-truth decisions

- Edit `.luau` in the filesystem while Rojo is connected.
- Edit GUI layout, tools, sounds, map parts, and other preserved instances in Studio unless they have an explicit serialized source file.
- Save `color_clash.rbxl` after Studio-owned changes.
- Re-extract `WeaponViewmodelData.rbxm` after editing its Studio copy.
- Never assume saving the place alone updates mapped filesystem scripts.
