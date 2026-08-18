# UI, Settings, and Audio

## UI architecture

UI controllers are automatically required by the client bootstrap. Most resolve required GUI descendants at module load time, before `Init()`. A missing or renamed required object can stall that controller on `WaitForChild`.

Keep UI hierarchy changes and controller changes in the same commit.

## Main screens and controllers

| Controller | Main Studio dependencies | Responsibility |
| --- | --- | --- |
| `MenuController` | `PlayerGui.Menu`, `Shop`, `Leaderboard`, `Settings`, `Rewards`, `Workspace.Cam` | Menu camera, Play, submenus, loading transition, menu spectate entry |
| `MainMenuController` | `MainHUD.MainMenuButton` | Five-second return-to-menu countdown; button or `M` toggles/cancels; blocks during round admission |
| `RoundUIController` | `MainHUD.Message`, `ButtonsHolder`, `Top` | voting, timers, color announcements, scoreboard |
| `TeamsController` | `PlayerGui.Teams.ButtonsHolder` | team picker and balance labels |
| `MainHudController` | `MainHUD.Weapons`, `HealthBar` | weapon slots, ammo/name, health, reset override, keys 1/2 |
| `CrosshairController` | `MainHUD.Crosshair` | crosshair visibility, bloom, hit and kill markers |
| `KillfeedController` | `MainHUD.DeathScreen` | kill-feed rows and elimination/win summary |
| `SpectateController` | `MainHUD.Spectate`, `SpectateButton` | target camera, previous/next/exit controls |
| `ShopController` | `PlayerGui.Shop.Frame` templates | category rendering, buy/equip, physical Shop/Skins zones |
| `RewardsController` | `PlayerGui.Rewards.Frame` templates | Daily Rewards claims/countdown and Quest progress/completion cards |
| `SettingsController` | `PlayerGui.Settings.Frame` templates | dynamic settings UI, persistence calls, local effects |
| `TeamVisualsController` | character models | team-colored Highlights |
| `PromptController` | ProximityPrompts | custom prompt UI |
| `MusicController` | `SoundService.Music` | Lobby/Calm/Action crossfades |

## Menu and round visibility

- Menu uses a Scriptable camera pinned to `Workspace.Cam` until Play.
- Play hides the menu, returns camera to `Custom`, and sends `PlayGameEvent` after a 0.6-second transition.
- Return-to-menu calls the server first, then restores the menu camera/UI.
- `MenuReturnLocked` blocks the return action only while the server is admitting and placing the player into a round. The button briefly reads `Round Starting` instead of beginning or completing the countdown.
- The in-round HUD is mostly controlled by `InMenu`, `IsPlaying`, and round update events.
- The top scoreboard refreshes once per second and displays up to eight active entries.

## Weapon HUD controls

- `1` or the Main slot toggles the ranged Tool.
- `2` or the Melee slot toggles the melee Tool.
- Roblox Backpack UI is disabled.
- The reset CoreGui callback is replaced with `ResetEvent`, allowing server-controlled round retirement.
- Weapon icons are rendered in ViewportFrames from `Shared.Assets.Weapons` templates.

## Settings persistence

`SettingsController` initializes defaults from `SettingsConfig`, invokes `GetSettings`, overlays saved values, and sends `UpdateSetting(name, value)` for changes. `SettingsServer` validates that a setting name exists in config before saving it.

The server currently validates names but not value type or range. New security-sensitive settings should validate both.

## Implemented setting effects

| Setting group | Runtime effect |
| --- | --- |
| Show FPS/Ping/Performance | Toggles existing stats GUIs outside menu/loading |
| Field of View | Base FOV target |
| Camera Shake | Gates `CameraFX` recoil/shake/fire blur |
| Dynamic FOV | Adds up to 15 FOV based on movement speed |
| Colorblind/High Contrast | Local ColorCorrection effects |
| Reduce Motion | Reduces UI animation behavior through `UIAnimations` |
| Master/Music Volume | Music volume scaling |
| Master/UI Volume | UI click/hover sound scaling |
| Hit Marker/Kill Sound | Combat feedback audio toggles |
| Look/Aim Sensitivity | Mouse-delta first-person sensitivity |
| Controller Vibration | Melee haptics |
| Crosshair settings | visibility, dynamic bloom, scale, outline |
| Lighting toggles | shadows, environment scales, ambient, bloom, DoF, sun rays |
| Particle Effects | Scales ParticleEmitter rates |
| Blood Effects | Gates blood particle/decal-style effects |
| Motion Blur | Camera-angle-based local BlurEffect |
| Aim Assist | Reduces `MouseDeltaSensitivity` while the cursor ray is over a Humanoid |

Configured but currently not consumed: SFX Volume, Ambient Volume, 3D Spatial Audio, Thumbstick Deadzone, Gamepad Look Sensitivity, and High Res Textures. Do not advertise these as functional until a runtime consumer is added.

## Audio contracts

`FXUtil` clones named sounds from `SoundService.GameSounds`. Referenced names include `DryFire`, `AimIn`, `Headshot`, `Land`, `KillStinger`, movement sounds from `FXConfig`, and round UI sounds such as `VoteOpen`, `RoundStart`, `ColorAlert`, `CountTick`, and `Vanish`.

Weapon Tools may contain sounds under their handle:

- `FireSFX` for server-visible weapon fire;
- `ReloadSFX` for reload;
- `MeleeSwingSound`, created by `MeleeHandler` if absent.

`SoundService.Music` should contain `Lobby`, `Calm`, and `Action`. Music selection is based on `InMenu` and `Workspace.ArenaPhase` and crossfades over 1.5 seconds.

## Adding a GUI feature

1. Decide whether the GUI is Studio-owned or fully Rojo-authored.
2. Use a stable, unique hierarchy; avoid generic duplicate names when a controller searches by name/position.
3. Add controller initialization through the existing auto-loader.
4. Connect visibility to lifecycle attributes, not only button state.
5. Route reusable motion and sounds through `UIAnimations`.
6. Test loading, menu, active, eliminated, spectating, respawn, and return-to-menu states.
