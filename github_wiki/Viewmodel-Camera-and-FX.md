# Viewmodel, Camera, and FX

## Implemented pattern

Color Clash uses direct real-joint driving for arms, combined with a separately authored weapon model attached to the player’s real `HumanoidRootPart`.

- `FirstPersonRig` drives real R6 or R15 shoulder/arm/neck Motor6D `C0` values.
- The local body is hidden except for real arm geometry and eligible melee Tool geometry.
- `Viewmodel` does not clone a foreign full-body rig. It clones only optional weapon geometry from `ReplicatedStorage.WeaponViewmodelData` and attaches it to the real root.
- If a weapon has no authored `WeaponModel`, the equipped Tool remains the visual source and muzzle lookup falls back to that Tool.

This design lets real Humanoid animation tracks and aim pose share the character while avoiding a separate stock-arm fallback.

## First-person camera

`FirstPersonController` owns the round-lifetime enable/disable decision. `FirstPersonRig` is a singleton returned by `FirstPersonRig.GetShared()`.

When active, the rig:

- sets `CameraType` to `Scriptable`;
- locks the mouse to center;
- consumes `GetMouseDelta()` directly;
- clamps pitch to ±75 degrees;
- positions the camera at the real root plus an R6/R15 eye height;
- rotates the real root toward flat camera look unless movement owns rotation;
- poses real joints for aim pitch and weapon hold;
- sends aim pitch at most every 0.1 seconds and only after a change of at least 2 degrees.

When the player leaves play, ragdolls, dies, or loses required character parts, the camera returns to Roblox’s `Custom` behavior and body/joint visibility is restored.

## R6 and R15 pose ownership

R6 poses `Right Shoulder`, `Left Shoulder`, and `Neck`. R15 poses `RightShoulder`, `LeftShoulder`, both elbows, and `Neck`. Original `C0` values are stored before modification and restored on disable.

`MovementClient` also writes root-joint tilt, and movement states can own root rotation. If adding an animation or movement mechanic, use the existing `MovementState` coordination instead of fighting the camera every frame.

`AimPoseController` currently smooths remote players’ replicated pitch onto an R6-style neck lookup. R15 remote full-arm pose parity is not implemented; see [Known Limitations](Known-Limitations).

## WeaponViewmodelData schema

Each authored weapon folder may contain:

| Child | Purpose |
| --- | --- |
| `WeaponModel` | Cloned inert first-person weapon geometry |
| `Joints` | Child configs whose attributes define `Part0`, `Part1`, `C0`, and `C1` |
| `Hold` | KeyframeSequence registered and played as a looping Action3 track |
| `Reload` | KeyframeSequence registered and played as Action4 |
| `ReloadLength` attribute | Fallback duration when the loaded track has no length yet |

A joint with `Part0 == "HumanoidRootPart"` attaches its target part to the real root. Other authored joints use the weapon handle as `Part0`. Unjointed weapon parts are welded to the handle.

The runtime creates `ViewmodelWeapon` under the character and keeps one shared `Viewmodel` controller across weapon swaps. `ClearWeapon()` destroys tracks, motors, welds, and cloned geometry before the next weapon is installed.

## Muzzle contract

Muzzle discovery intentionally supports existing content:

1. a BasePart whose lowercase name contains `muzzle` in the viewmodel weapon;
2. a Tool Attachment named `MuzzlePoint` or `Muzzle`;
3. a Tool BasePart whose lowercase name contains `muzzle`;
4. fallback to the handle’s forward edge.

Tool muzzle positions more than 15 studs from the handle are ignored. Do not rename muzzle parts casually or move an attachment outside this guard.

## Recoil layers

Gun recoil is intentionally split:

1. `FirstPersonRig.ApplyAimKick()` changes pitch/yaw permanently until the player compensates.
2. `FirstPersonRig.applyRecoilImpulse()` adds a recovering 300/30 spring to camera aim.
3. `Viewmodel.applyRecoilImpulse()` adds a recovering 300/30 spring to the root-attached weapon.
4. `CameraFX.Recoil()` adds a sharper recovering 300/15 camera spring plus a small FOV kick.
5. `CameraFX.Shake()` stacks short decaying camera impulses.

Do not collapse these into one spring. Each layer communicates a different kind of weapon weight.

## ADS

`GunHandler.ADS()` calls:

- `FirstPersonRig.StartADS()`;
- `Viewmodel.StartADS()`;
- `CameraFX.SetAim(item.Aim.FOV)`;
- an aim-in sound;
- `AimSlowMultiplier = 0.55`.

The current rig offsets are zero, so ADS is primarily FOV-based. `SettingsController` interpolates the camera toward `AimFOV` at `dt * 10`.

`CameraFX.SetAim()` also fades in a light black vignette built from four gradient frames. Current tuning is black, `0.45` edge transparency, 0.12-second fade-in, and 0.10-second fade-out. The generated `AimVignette` ScreenGui uses display order 4 and persists across respawns.

## Camera effects and feedback

`CameraFX` exposes `Recoil`, `Shake`, `SetAim`, `ClearAim`, `IsAiming`, and `FirePulse`. Every recoil, shake, and blur call respects the `Camera Shake` setting. ADS FOV/vignette is independent of that toggle.

`CombatClient` adds hit markers, floating damage numbers, blood/hole effects, a red kill vignette, kill color correction, and remote tracers. `FXUtil` provides shared sound cloning, muzzle flash, shell ejection, landing dust, speed trails, slide sound, body-hit particles, and double-jump rings.

## Render ordering

| Writer | Render priority |
| --- | ---: |
| `FirstPersonRig` | Camera + 2 |
| `Viewmodel` | Camera + 3 |
| `CameraFX.Shake` | Camera + 5 |
| `CameraFX.Recoil` | Camera + 10 |

Preserve this ordering when adding camera work. Effects assume the base rig has written the camera first.
