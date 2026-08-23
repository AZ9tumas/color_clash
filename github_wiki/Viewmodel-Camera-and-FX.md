# Viewmodel, Camera, and FX

## Implemented pattern

Color Clash uses a character-derived R6 camera viewmodel. This follows the structural pattern from the reference `gunsystem.rbxl`: a dedicated model lives under `Workspace.CurrentCamera`, its root follows `Camera.CFrame`, and cloned weapon geometry is attached from the viewmodel’s right arm.

- `Viewmodel` clones the current character’s `HumanoidRootPart`, `Right Arm`, `Left Arm`, `Humanoid`, Animator, and arm appearance data. It does not clone a torso.
- `BodyColors`, `Shirt`, `ShirtGraphic`, and every `CharacterMesh` are copied so package arms and character-mesh arm replacements render like the player.
- `GunHandler` loads `ReplicatedStorage.Shared.Assets.Animations.Shooting` and the item animation set once on the real Animator. The camera arms mirror the resulting real-root-relative arm frames every render step, preserving first-person and replicated third-person presentation without a cloned torso.
- The real body and real gun Tool are hidden locally while a gun is equipped. Melee continues using the real-arm path.
- `Viewmodel` clones weapon geometry from `ReplicatedStorage.WeaponViewmodelData`, aligns the authored model pivot to a generated hand mount, and creates a simple `WeldConstraint` from that mount to the weapon handle.
- If a weapon has no authored `WeaponModel`, the equipped Tool remains the visual source and muzzle lookup falls back to that Tool.

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

The current shared `Shooting` asset is a looping R6 animation with asset ID `rbxassetid://97125390149216`. Roblox R6 animation poses place arm poses beneath a `Torso` pose, so playing that asset directly on the torso-free camera model does not move its arm motors. The tracks therefore play once on the real R6 Animator. Each viewmodel render update reads each real arm relative to the real root and writes the equivalent transform into the corresponding direct root-to-arm Motor6D. Reload sequences additionally play on the cloned Animator so authored root-level weapon motors continue resolving.

`MovementClient` also writes root-joint tilt, and movement states can own root rotation. If adding an animation or movement mechanic, use the existing `MovementState` coordination instead of fighting the camera every frame.

`AimPoseController` currently smooths remote players’ replicated pitch onto an R6-style neck lookup. R15 remote full-arm pose parity is not implemented; see [Known Limitations](Known-Limitations).

## WeaponViewmodelData schema

Each authored weapon folder may contain:

| Child | Purpose |
| --- | --- |
| `WeaponModel` | Cloned inert first-person weapon geometry |
| `Joints` | Child configs whose attributes define `Part0`, `Part1`, `C0`, and `C1` |
| `Hold` | Legacy authored sequence retained in content but no longer used for gun-arm placement |
| `Reload` | KeyframeSequence registered and played as Action4 |
| `ReloadLength` attribute | Fallback duration when the loaded track has no length yet |

The authored handle-to-root joint and `HAND_WELD_OFFSETS` are no longer used for placement. `Viewmodel` calls `WeaponModel:PivotTo(RightHandGunMount.CFrame)`. It then creates `GunPivotWeld`, a `WeldConstraint` from the mount to `Handle`, without applying another positional or rotational offset.

Changing `WeaponModel`’s pivot therefore changes runtime placement directly. The pivot becomes coincident with the mount; every weapon part keeps its authored transform relative to that pivot. Keep each pivot near its model bounds unless a deliberate large displacement is wanted.

Authored root-level magazine and shell motors attach to the cloned camera-viewmodel root so existing reload pose names continue resolving. Their base `C0` follows the hand-mounted handle each render step. Handle-child motors and unjointed welded parts continue to follow the handle normally.

The runtime creates `FirstPersonViewmodel` under `CurrentCamera` and `ViewmodelWeapon` beneath that rig. `ClearWeapon()` destroys weapon tracks, motors, welds, and cloned geometry before the next weapon is installed, while the character-derived arm rig remains allocated for fast swaps.

## Hand mount calculation

`RightHandGunMount` is generated once when the R6 camera rig is built.

1. The real root position is converted into right-arm local coordinates with `RightArm.CFrame:PointToObjectSpace(HumanoidRootPart.Position)`.
2. The arm’s eight local box corners are generated from all sign combinations of `RightArm.Size * 0.5`.
3. For each corner, squared local distance to the localized root point is computed as `delta:Dot(delta)`.
4. The corner with the largest squared distance is selected. Because both points are in right-arm local space, arm world position and orientation no longer complicate the comparison.
5. The mount’s world frame is `RightArm.CFrame * CFrame.new(selectedCorner)`, giving the part the hand’s orientation and placing its center exactly on the selected edge corner.
6. `HandMountWeld` freezes that relationship. Animation moves the arm, and the mount follows without recomputing placement.

For classic R6 parts and MeshParts, `BasePart.Size` is the physical hand/arm bound used by Roblox joints. Character-mesh objects are copied into the viewmodel so their visual package geometry follows the same R6 body-part bound.

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
| `Viewmodel` | Camera + 3 |
| `CameraFX.Shake` | Camera + 5 |
| `CameraFX.Recoil` | Camera + 10 |

Preserve this ordering when adding camera work. Effects assume the base rig has written the camera first.
