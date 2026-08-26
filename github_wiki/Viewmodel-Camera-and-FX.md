# Viewmodel, Camera, and FX

## Implemented pattern

Color Clash uses a character-derived R6 camera viewmodel. This follows the structural pattern from the reference `gunsystem.rbxl`: a dedicated model lives under `Workspace.CurrentCamera`, its root follows `Camera.CFrame` through one global framing offset, and cloned weapon geometry is attached from the viewmodel’s right arm.

- `Viewmodel` clones the current character’s `HumanoidRootPart`, `Right Arm`, `Left Arm`, `Humanoid`, Animator, and arm appearance data. It does not clone a torso.
- `BodyColors`, `Shirt`, `ShirtGraphic`, and every `CharacterMesh` are copied so package arms and character-mesh arm replacements render like the player.
- `GunHandler` loads `ReplicatedStorage.Shared.Assets.Animations.Shooting` and the item animation set once on the real Animator. The camera arm motors copy the real shoulder C0 delta and Animator Transform during `PreSimulation`, preserving first-person and replicated third-person presentation without a cloned torso.
- The real body and real gun Tool are hidden locally while a gun is equipped. Melee continues using the real-arm path.
- `Viewmodel` strips a visual clone from the equipped Tool, supplements reload-only parts from `ReplicatedStorage.WeaponViewmodelData`, and connects its `Handle` with an explicit `RightGrip` Motor6D.
- `Items[weapon].Grip` is the version-controlled standard Roblox Tool grip. The server and client apply it to the gameplay Tool, and the camera grip copies the engine-created real `RightGrip` frames.

The viewmodel is rebuilt from the current character after each respawn and remains a per-client singleton across weapon swaps during that life.

## First-person camera

`FirstPersonController` owns the round-lifetime enable/disable decision. `FirstPersonRig` is a singleton returned by `FirstPersonRig.GetShared()`.

When active, the rig:

- sets `CameraType` to `Scriptable`;
- locks the mouse to center;
- consumes `GetMouseDelta()` directly;
- clamps pitch to ±75 degrees;
- positions the camera at the real root plus an R6/R15 eye height;
- rotates the real root toward flat camera look unless movement owns rotation;
- leaves local gun rendering to the camera viewmodel while retaining real-character neck and melee pose control;
- sends aim pitch at most every 0.1 seconds and only after a change of at least 2 degrees.

When the player leaves play, ragdolls, dies, or loses required character parts, the camera returns to Roblox’s `Custom` behavior and body/joint visibility is restored.

## R6 pose ownership

The camera viewmodel is intentionally R6-only because Color Clash runs R6 and the shared `Shooting` asset targets the R6 hierarchy. The cloned arms connect directly to the cloned `HumanoidRootPart` with shoulder Motor6Ds. No torso part exists in the camera model.

The current shared `Shooting` asset is a looping R6 animation with asset ID `rbxassetid://97125390149216`. Roblox R6 animation poses place arm poses beneath a `Torso` pose, so playing that asset directly on the torso-free camera model does not move its arm motors. The tracks therefore play once on the real R6 Animator. The viewmodel copies each real shoulder’s C0 delta and Animator Transform into its direct root-to-arm Motor6D during `PreSimulation`, allowing the active `RightGrip` and the weapon assembly to settle before rendering. Reload sequences additionally play on the cloned Animator so authored root-level weapon motors continue resolving.

`MovementClient` also writes root-joint tilt, and movement states can own root rotation. If adding an animation or movement mechanic, use the existing `MovementState` coordination instead of fighting the camera every frame.

`AimPoseController` currently smooths remote players’ replicated pitch onto an R6-style neck lookup. R15 remote full-arm pose parity is not implemented; see [Known Limitations](Known-Limitations).

## WeaponViewmodelData schema

Each authored weapon folder may contain:

| Child | Purpose |
| --- | --- |
| `WeaponModel` | Source for reload-only parts absent from the Tool visual |
| `Joints` | Child configs whose attributes define `Part0`, `Part1`, `C0`, and `C1` |
| `Hold` | Legacy authored sequence retained in content but no longer used for gun-arm placement |
| `Reload` | KeyframeSequence registered and played as Action4 |
| `ReloadLength` attribute | Fallback duration when the loaded track has no length yet |

The actual equipped Tool is the first-person geometry source. Runtime cloning removes scripts, joints, constraints, and WeldConstraints, makes every part inert, and moves the remaining visual children into `ViewmodelWeapon`. Clearing the old WeldConstraints is required before rebuilding reload joints; retaining both creates a rigid cycle that causes Roblox to deactivate `RightGrip`. If a `Joints` target is absent from the Tool, the matching part is copied from `WeaponModel` at its authored handle-relative transform. This currently preserves `SMG.Mag` and `Shotgun.Bullet1`/`Bullet2`.

The camera grip is a Motor6D named `RightGrip` with the cloned R6 `Right Arm` as `Part0` and the visual `Handle` as `Part1`. When Roblox’s real equipped `RightGrip` is available, its exact `C0` and `C1` are copied. The fallback uses the standard R6 hand basis for `C0` and `Tool.Grip` for `C1`. Model pivots and viewmodel-only weapon offsets do not affect placement.

Authored root-level magazine and shell motors attach to the cloned camera-viewmodel root so existing reload pose names continue resolving. Their base `C0` follows the hand-mounted handle each render step. Handle-child motors and unjointed welded parts continue to follow the handle normally.

The runtime creates `FirstPersonViewmodel` under `CurrentCamera` and `ViewmodelWeapon` beneath that rig. `ClearWeapon()` destroys weapon tracks, motors, welds, and cloned geometry before the next weapon is installed, while the character-derived arm rig remains allocated for fast swaps.

## Tool Grip authoring

Every `Items` weapon entry has a `Grip` CFrame seeded from the current Studio Tool. `PlayerUtil.GiveWeapons()` applies it before the server parents a Tool to the Backpack, and `GunClient` reapplies it before controller setup. This keeps real third-person and cloned first-person placement on one standard value.

1. Equip or preview the real Tool with an R6 rig in a Tool Grip Editor.
2. Move and rotate the grip until the handle sits correctly in the shooting animation pose.
3. Copy the resulting CFrame into that weapon’s `Items.Grip` field.
4. Re-enter play so server-issued Tools receive the new grip.
5. Verify both real third-person and camera-viewmodel placement.

Do not add a separate camera-only offset. If first- and third-person placement differ with the same grip, inspect the real and camera `RightGrip.C0/C1`, Handle identity, and arm pose mirroring.

`CAMERA_ROOT_OFFSET` near the top of `Viewmodel.luau` controls the framing of the complete arms-and-weapon assembly. It is not a weapon grip and should only be changed to move the entire first-person presentation. `Items.Grip` controls a weapon relative to the right hand. Keep those two tuning responsibilities separate.

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
3. `Viewmodel.applyRecoilImpulse()` adds a recovering 300/30 rotation to the complete camera viewmodel at its camera-root pivot.
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
| `Viewmodel` arm-pose copy | PreSimulation |
| `Viewmodel` | Camera + 3 |
| `CameraFX.Shake` | Camera + 5 |
| `CameraFX.Recoil` | Camera + 10 |

Preserve this ordering when adding camera work. Effects assume the base rig has written the camera first.
