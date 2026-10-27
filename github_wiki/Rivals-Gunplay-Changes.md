# Rivals-style gunplay: change report

**Written:** 2026-10-26 · **Game:** Color Clash (Roblox, placeId `137979441831476`)
**Audience:** AI models and engineers who need complete context on how Color Clash's shooting was brought closer to the feel of Roblox *Rivals*, and on the exact state it was left in.

> **Read this first: where the code lives**
> - Every change described here was made **directly in Roblox Studio** (place "Color Clash (placeId: 137979441831476)") using the Roblox Studio MCP tools.
> - The local git repo (`~/Desktop/color_clash`, synced by Rojo from `src/`) is **behind Studio** and does **not** contain these changes.
> - **Studio is the source of truth.** Read scripts with the Studio MCP (`script_read`, `script_grep`, `search_game_tree`), not from disk.
> - **Do not start `rojo serve` from the local repo** until it has been brought up to date from Studio. Rojo pushes the filesystem into Studio and would overwrite or delete everything below.
> - The place must be **saved/published from Studio** for these edits to persist.

> **Scope and IP:** only Rivals' *mechanics* were emulated (hit registration, spread, recoil, reload rules, swapping, feedback, a grenade). No Rivals models, animations, sounds or names were copied; those belong to Nosniy Games.

---

## 1. Summary

Shooting was reworked in two passes, and every new behavior sits behind a feature flag.

**Pass 1: hit registration and ammo** (`ClientHitReg`):
- The shooter's client decides what each pellet hit and shows the hit marker, damage number and blood instantly.
- The server **rewinds** targets up to ~0.2–0.6 s to verify the claim (lag compensation), checks line of sight, and only then applies damage.
- The server also owns every gun's magazine and reload timing.

**Pass 2: feel and features:**
- **`GunHandling`:**
  - Spread depends on movement, airborne, sliding and sustained-fire bloom.
  - The crosshair draws the real cone.
  - Recoil follows learnable per-gun patterns, and the aim recovers after a spray.
  - Damage falls off with range and uses per-gun headshot multipliers.
  - Tactical reloads are faster than empty ones, and the shotgun can fire mid-reload.
  - The sniper gets a scope overlay.
- **`QuickSwap`:** Q and the mouse wheel swap weapons, every gun has a draw time (enforced by the server too), and there is a procedural draw motion.
- **`CombatFeedback`:** wall impacts, a hit-direction indicator, a low-ammo tint, and hit-marker sounds that actually load.
- **`Utilities`:** an F-key frag grenade. It is server-simulated, deals splash damage with line of sight, and has charges that recharge.

**Flag defaults:** all flags are **off on live servers** and **on in Studio playtests** (see §3). With every flag off, the game behaves exactly as before; this was regression-tested in Studio.

---

## 2. Game context (what an agent needs to know)

### Engine and code layout (in Studio)

**Client bootstrap:** `StarterPlayer.StarterPlayerScripts.Client.Client`.
1. It requires every `ReplicatedStorage.Shared.Services.<X>Service.<X>Client` module and calls `.Init()`, then does the same for every `ReplicatedStorage.Shared.UIControllers.*` module.
2. It then runs a second pass calling `.Start()` on both.

**Server bootstrap:** `ServerScriptService.Server.Require.Require` does the same for `ServerScriptService.Server.Services.<X>Service.<X>Server`, calling `.Init()` then `.Start()`.

**Shared code:**
- **Classes:** `ReplicatedStorage.Shared.Classes`.
- **Modules:** `ReplicatedStorage.Shared.Modules.{Core,Utils,Gunsystem,Game}`.
- **Remotes:** `ReplicatedStorage.Shared.Remotes.*Remotes` modules. They create RemoteEvents on the server when first required.

**Guns are Roblox `Tool`s** whose names key into `ReplicatedStorage.Shared.Modules.Core.Items`. A gun is any Items entry with `MaxAmmo`; melee weapons have none.

**Core gun pipeline:**
- `GunClient` (Service) watches Tools and builds one controller per Tool:
  - Guns get `Classes.GunHandler`.
  - Melee gets `Classes.MeleeHandler`.
- `GunClient` binds LMB (fire), RMB (aim) and R (reload).
- The server side is `CombatService.CombatServer` → `Classes.WeaponServer`.

**First person:**
- `Classes.FirstPersonRig` owns the camera while `IsPlaying` is true.
- `Classes.Viewmodel` wraps `Modules.Gunsystem.ViewModelHandler`, the camera-space arms+gun model, with procedural motion in `Modules.Gunsystem.ViewmodelMotion`.

**Round state gates every shot on the server:**
- `player:GetAttribute("IsPlaying") == true`.
- `Workspace:GetAttribute("ArenaPhase") == "Shoot"`.

The round cycles through Voting, InGame (phases `Push` then `Shoot`) and PostRound. A solo player in FFA usually wins instantly and the round ends.

### Units and conventions used throughout
- **Spread** is in **milliradians** (Items `Spread`, `Handling.Spread.*`); `SPREAD_TO_RADIANS = 1/1000`.
- **Recoil pattern steps** are in **degrees**, written as `{ up, right }`.
- **`FirstPersonRig:ApplyAimKick(pitchDeg, yawDeg)`:** positive pitch looks up and positive yaw turns **right**. It permanently moves the aim.
- **`FirstPersonRig:applyRecoilImpulse(v)`** and **`CameraFX.Recoil(v)`** are visual springs that return to rest. In both, **positive Y turns left**.
- **Flags are checked at call sites** with `CombatConfig.IsEnabled("<Flag>")`. With a flag off, the original code path runs unchanged.
- **Instance-keyed tables must be plain (strong) tables cleaned up on `Destroying`.** Weak-keyed tables keyed by Instances silently lose entries in Roblox, because the Lua handle can be collected while the Instance still exists. That bug was hit and fixed in `AmmoServer`.

---

## 3. Feature flags: `ReplicatedStorage.Shared.Modules.Core.CombatConfig`

| Flag | Live default | Studio default | What turning it on does |
|---|---|---|---|
| `ClientHitReg` | `false` | `true` | Client-detected hits checked by server lag compensation; server-owned ammo and reloads |
| `GunHandling` | `false` | `true` | Movement/air/slide/bloom spread with a real-cone crosshair; recoil patterns with aim recovery; damage falloff and per-gun headshots; tactical reloads; shotgun fire-interrupts reload; sniper scope |
| `QuickSwap` | `false` | `true` | Q/mouse-wheel swap; per-gun draw time (client and server); procedural draw motion |
| `CombatFeedback` | `false` | `true` | Bullet impacts on surfaces; hit-direction indicator; ammo counter tint; working hit-marker sounds |
| `Utilities` | `false` | `true` | F throws a frag grenade (2 charges, 12 s recharge each) |

**How the flags work:**
- `CombatConfig.Publish()` runs once from `CombatServer.Init`. For each flag with **no** Workspace attribute yet, it writes `Workspace:SetAttribute(flag, value)`.
  - The value is `STUDIO_DEFAULTS[flag]` when `RunService:IsStudio()`, otherwise the module's live value.
  - Attributes replicate, so clients agree with the server.
- `CombatConfig.IsEnabled(flag)` returns the Workspace attribute if set, else the module default.

**To compare old and new behavior in Studio:**
- Set a boolean attribute on `Workspace` (for example `GunHandling = false`) before pressing Play.
- Or flip it live on the **server** during a playtest.

**To ship a feature:** change its live value in `CombatConfig` to `true`.

---

## 4. Systems in detail

### 4.1 Hitscan base (pre-existing at the start of this work, then extended)

**Shared module:** `Modules.Utils.HitscanUtil`.

| Function | What it does |
|---|---|
| `EffectiveSpread(data, isAiming)` | Legacy spread: `Spread`, times `Aim.SpreadMultiplier` (default 0.5) when aiming |
| `ConeDirection(dir, spread)` | Uniform-disc jitter inside the cone |
| `WithinCone(aim, dir, spread)` | `atan2` angle test, tolerance `1e-5` rad |
| `ValidateDirections(dirs, aim, spread, pellets)` | Count must equal pellets; each entry finite, unit and inside the cone. Returns nil if invalid |
| `Cast(origin, dir, range, character)` | Raycast ignoring the character, `Workspace.WallDebrisFolder`, `Workspace.Base`, and parts named `Repair*` |
| `CastIgnoring(origin, dir, range, ignoreList)` | **New.** Same as `Cast`, with an arbitrary ignore list |
| `SpreadProfile(data)` | **New.** `Items.Handling.Spread` with defaults filled in, cached per weapon table |
| `SpreadBound(data)` | **New.** The widest cone the client can legitimately produce: `max(Hip, Aim) + Move + max(Air, Slide) + MaxBloom` |
| `HandlingDamage(data, distance, isHeadshot)` | **New.** `round(Damage × falloff × headshotMultiplier)` |

**Falloff formula:** `t = clamp((d − Start)/(End − Start), 0, 1)` and `multiplier = 1 + (Min − 1)·t`.

**Client shot flow** (`Classes.GunHandler:_fireOnce`):
1. Roll each pellet's direction locally.
2. Raycast each pellet locally.
3. Draw the tracer from the viewmodel muzzle immediately.
4. Fire `ToolConnections:FireServer(toolName, aimPoint, isAiming, eyeOrigin, directions, claims)`.

**Server validation:**
- The server casts from the client eye origin if it is within `MAX_EYE_OFFSET = 14` studs of the head.
- It validates the directions and rejects the whole shot if they are malformed.
- Shots from other players reach you as `ShowBulletTracer`. The shooter gets one only if the server rolled the spread itself.

**Server rate limit** (`CombatServer`): `nextAllowed[userId][tool]` with a token-style 0.05 s grace (`COOLDOWN_GRACE`).

### 4.2 `ClientHitReg`: client-claimed hits + lag compensation + server ammo

**Client side** (`GunHandler`):
- For each pellet whose local ray hit a damageable character, `_claimHit` appends `{ pelletIndex, part }` to `claims`.
- `damageableTarget(part)` decides what counts as damageable. It mirrors the server's checks:
  - Not your own character, and not under the camera (the viewmodel).
  - Has a living Humanoid.
  - A player target must be `IsPlaying` and not on your team (the `Team` attribute).
- If you are `IsPlaying` and the phase is `Shoot`, the hit is shown **immediately** through `CombatClient.ShowPredictedHit(position, damageText, part, normal)`. That draws the same marker, sound, number, blood and bullet hole as the server path.

**Server side** (`WeaponServer.FireHitscan`, with the flag on):
1. Directions are required (`if not directions then return`).
2. `readClaims(claims, pellets)` builds `pelletIndex → BasePart`, dropping anything malformed.
3. `resolveClaim(...)` runs per pellet:
   - `LagCompensation.ModelOf(part)` must be a living Humanoid model in Workspace that isn't the shooter. Stored assets, Tool descendants, and parts with both `CanCollide=false` and `CanQuery=false` are rejected. `ProcessDamage` independently refuses targets outside Workspace.
   - `LagCompensation.FindHit(shooter, part, origin, direction, range)` returns `(hitPosition, struckPart)` or nil.
   - `LagCompensation.IsClear(origin, hitPosition, targetModel)` must be true: no static geometry in between. All player characters and tracked models are ignored, because they are at present positions, not rewound ones.
   - Damage goes through `WeaponServer.ProcessDamage`. Only a **kill** is sent back, as `DamageVFX:FireClient(shooter, pos, dmg, part, nil, true, true)`. The 7th argument `predicted=true` tells the client to play just the kill flash, not a second marker or number.
4. Pellets with no claim are misses (favor-the-shooter in both directions). The tracer endpoint for other players comes from a server cast.

**`ServerScriptService.Server.Classes.LagCompensation`:**
- **What it records:** every player character automatically, plus any Model with the CollectionService tag **`LagCompensated`** (for bots and test dummies). Recording runs only while `ClientHitReg` is on, and history clears when the flag turns off.
- **How it records:** every Heartbeat it stores `{ time = os.clock(), cframes = {[BasePart] = CFrame} }` for each tracked model, keeping `HISTORY_SECONDS = 1`. Tool parts are excluded because held tools are `CanQuery=false` and unhittable.
- **Rewind window:** `clamp(ping×2 + 0.15, 0.2, 0.6)` seconds, where `ping = player:GetNetworkPing()`.
- **`FindHit`:**
  - It first tests the part's current CFrame, then walks back through frames inside the window.
  - Each test is a ray vs oriented-box slab test against the part's box, padded by `BASE_TOLERANCE = 0.35` plus the part's movement to the next sample (capped at `MAX_MOTION_SLACK = 4`).
  - **Occlusion fix:** if another `CanQuery` part of the same character is entered more than `OCCLUSION_MARGIN = 0.5` studs earlier along the ray, the pellet counts on that nearer part. This stops "head claimed through the torso" cheats.
  - Untracked humanoids (shop NPC, authoring rigs) are only tested at their current position.

**`ServerScriptService.Server.Classes.AmmoServer`** (server magazines):
- **Storage:** `magazines[tool] = { ammo, reloadStartedAt, ammoAtReloadStart, reloadDuration }`. A plain table, entry removed on `tool.Destroying`.
- **`StartReload(tool, data)`:** called from the `Reload` remote. Ignored if a reload is already running or the magazine is full.
  - Duration is `TacticalReloadTime` under `GunHandling` when rounds remain and the gun is not per-shell; otherwise `ReloadTime`.
- **`settle`:** applies the reload with `RELOAD_GRACE = 0.2` s.
  - Per-shell guns gain `floor(elapsed/duration)` shells.
  - Magazine guns refill once `elapsed ≥ duration`.
- **`TryConsume(tool, data)`:**
  1. Settles first.
  2. **Any shot ends a running reload**, keeping what it loaded. The client only fires mid-reload after cancelling it: a shotgun interrupt, or swapping away and back.
  3. Returns `false, 0` when empty.
- **Rejected shots:** `CombatServer` answers an empty magazine with `AmmoSync:FireClient(player, tool, ammoLeft)`. The client sets `_ammo` from it unless it is mid-reload.
- **Swapping does not cancel a server reload.** This is intentional: the server can only end up more generous than the client, never stricter.

### 4.3 `GunHandling`: feel

**Data.** Each gun in `Items` gained a `Handling` table (typed as `HandlingConfig` in `ReplicatedStorage.Shared.Types`):

| Field | Meaning |
|---|---|
| `Spread.Hip` / `Spread.Aim` | Resting cone in mrad, hip-fire / aiming |
| `Spread.Move` | Added in full at sprint speed. Scales linearly from 8 studs/s (free) to `MovementConfig.Speeds.Sprint` (40) |
| `Spread.Air` | Added while airborne (`FloorMaterial == Air`; wall-running is **not** airborne) |
| `Spread.Slide` | Added while `MovementState == "Slide"` |
| `Spread.AimPenalty` | Scales the Move/Air/Slide penalties while aiming |
| `Spread.Bloom`, `MaxBloom`, `BloomRecovery` | Per-shot growth, cap, and decay per second |
| `Spread.BloomRecoveryDelay` | Seconds without firing before bloom starts recovering; defaults to 0.25 s |
| `Falloff = {Start, End, Min}` | Damage multiplier 1 at `Start` studs, `Min` at `End` and beyond |
| `Headshot` | Headshot multiplier (legacy was a flat 2×) |
| `Recoil = {Pattern, Wander, AimScale?, ResetTime?, RecoveryDelay, RecoveryRate}` | Aim kick per shot in degrees `{up, right}`. The last step repeats with ±`Wander` on the right axis. `AimScale` (default 0.7) applies while aiming. The pattern restarts after `ResetTime` (default 0.35 s) without firing. Aim recovers at `RecoveryRate` °/s once the trigger has rested `RecoveryDelay` s |
| `TacticalReloadTime` | Magazine reload time when rounds remain |
| `EquipTime` | Draw time, used by `QuickSwap` |
| `Scope` | Sniper scope overlay |

Values as shipped:

| Gun | Hip/Aim | Move/Air/Slide | AimPen | Bloom/Max/Rec | Falloff (Start→End, Min) | HS× | Recoil pattern (summary) | Recovery delay/rate | Tactical / full reload | Equip |
|---|---|---|---|---|---|---|---|---|---|---|
| Pistol | 3 / 0.5 | 6 / 18 / 6 | 0.5 | 5 / 20 / 60 | 60→160, 0.7 | 2.0 | `{1.4, 0.15}` repeat, wander 0.3 | 0.12 / 14 | 2.3 / 2.9 | 0.3 |
| Sniper | 45 / 0 | 20 / 50 / 25 | 0.2 | 0 / 0 / 60 | none | 2.0 | `{3.2, 0.3}`, wander 0.4 | 0.2 / 10 | 1.7 / 2.0 | 0.6 |
| AR | 8 / 3 | 6 / 22 / 8 | 0.5 | 1.5 / 14 / 40 | 90→220, 0.7 | 1.6 | 16 steps: up ~0.55–0.7°, drifting right then left; wander 0.25 | 0.12 / 14 | 1.25 / 1.5 | 0.45 |
| SMG | 12 / 6 | 3 / 12 / 4 | 0.5 | 1 / 12 / 50 | 40→120, 0.55 | 1.4 | 10 steps ~0.2–0.4° up, alternating sides; wander 0.3 | 0.1 / 12 | 1.0 / 1.2 | 0.35 |
| Scar | 6 / 2 | 7 / 24 / 10 | 0.5 | 2 / 16 / 35 | 100→260, 0.75 | 1.6 | 11 steps ~0.4–0.9° up, right then left; wander 0.3 | 0.14 / 16 | 1.35 / 1.6 | 0.5 |
| Shotgun | 30 / 20 | 4 / 6 / 0 | 1.0 | 0 / 0 / 60 | 15→60, 0.3 (per pellet) | 1.25 | `{2.6, 0.2}`, wander 0.4 | 0.15 / 12 | per-shell 0.8 | 0.5 |

**Client.** `ReplicatedStorage.Shared.Modules.Gunsystem.WeaponHandling` is a new module with one instance per GunHandler:
- **`:Spread(isAiming)`** returns `(isAiming ? Aim : Hip) + (Move·moving + (Air or Slide)) × (isAiming ? AimPenalty : 1) + bloom`.
- **`:Shot(isAiming)`** grows bloom and returns this shot's `(up, right)` kick from the pattern, accumulating `recoilPitch` and `recoilYaw`.
- **`:Update(dt, kick)`** decays bloom only after `Spread.BloomRecoveryDelay` (default 0.25 s) without a shot; it accounts for only the portion of a frame after the delay. Recoil separately uses `RecoveryDelay`, then calls `kick(-up, -right)` to walk the accumulated recoil back at `RecoveryRate` °/s along its own direction.
- **`:Reset()`** runs on unequip.

**How `GunHandler` uses it:**
- **`_fireOnce`:**
  - The shot's spread is read **before** the shot adds bloom.
  - The pattern kick goes through `rig:ApplyAimKick(up, right)` instead of the legacy random yaw.
  - The visual springs (`applyRecoilImpulse`, `CameraFX.Recoil`) lean the way the pattern pushes.
  - `CrosshairController.AddBloom` is skipped.
- **`_syncHandling`** runs on Equip and on live `GunHandling` attribute changes while equipped. It resets spray state, starts/stops the handling loop, and adds/removes the sniper scope if ADS is already held. Its attribute listener is disconnected on Destroy.
- **`_startHandling`** binds RenderStepped. Each frame it:
  1. Runs `handling:Update`.
  2. Converts the cone to screen pixels: `tan(spread/1000) / tan(FOV/2) × viewportHeight/2`.
  3. Calls `CrosshairController.SetSpreadGap(px)`. The controller divides by its UIScale and smooths it.
- **`_stopHandling`** (on Unequip) clears the gap. Passing nil restores the legacy per-shot bloom.

**Server.**
- `WeaponServer.FireHitscan` validates directions against `HitscanUtil.SpreadBound(data)`, because the server cannot see the client's exact movement state.
- Damage on both server paths (claims and legacy cast) uses `HitscanUtil.HandlingDamage` with the ray distance.

**Reloads:**
- **Tactical:** `GunHandler:_reloadDuration()` uses `TacticalReloadTime` when rounds remain (magazine guns only). `AmmoServer` applies the same rule from **its** ammo count.
- **Reload token:** `GunHandler:Reload()` now carries `_reloadToken`. A reload task stops touching gun state once the token changes.
- **Shotgun interrupt:** `gun:shoot()` calls `_interruptReload()` when the gun is reloading, `ReloadPerShell` is set, and `_ammo > 0`. That bumps the token, clears `isReloading`, stops the reload sound and animation, and fires immediately.

**Sniper scope** (`Handling.Scope = true`):
- `gun:ADS()` calls `_setScoped(true)`:
  - It shows a lazily built `PlayerGui.SniperScope` ScreenGui (DisplayOrder 6). The lens is a round Frame (UICorner 0.5) with a 2500-px black `UIStroke` that blacks out everything else, plus a thin reticle and a red center dot.
  - It hides the viewmodel with `Viewmodel:SetHidden(true)`, which saves and restores each part's `LocalTransparencyModifier`.
  - It hides only the four crosshair bars with `CrosshairController.SetSuppressed(true)`. The parent and `FeedbackLayer` remain visible so scoped hits and kills still show markers, and the mouse cursor stays hidden.
- `stopADS` reverses all of it. Reloading or unequipping goes through `stopADS`.

### 4.4 `QuickSwap`

**`UIControllers.MainHudController` (keys):**
- The game has two slots: **Main** (any gun) on key 1 and **Melee** on key 2.
- With the flag on:
  - Pressing the held slot's key puts the weapon away, with or without the flag (2026-10-28). It also records that slot as `lastSlot`, so Q brings the same weapon back out.
  - **Q** switches to the other slot, or to the last-used slot when empty-handed.
  - The **mouse wheel** does the same, with a 0.15 s debounce, only while `IsPlaying`.

**Draw time, client:** `GunHandler:Equip()` sets `nextShotAt = max(nextShotAt, now + Handling.EquipTime)`.
- A semi-auto click during the draw is ignored.
- A held automatic trigger fires as soon as the draw ends, because the auto loop waits on `nextShotAt`.

**Draw time, server:** `CombatServer` records `drawnAt[tool] = os.clock()` whenever a Tool enters a character (via `character.ChildAdded`, plain table cleared on `Destroying`). A gun shot is dropped if `now < drawnAt + EquipTime − DRAW_GRACE(0.12)`.

**Draw motion:**
- **Call chain:** `Viewmodel:Draw(duration)` → `ViewModelHandler viewmodel:Draw` → `ViewmodelMotion Motion:Draw`.
- **Effect:** the gun starts lowered and tilted and eases into place with an ease-out cubic.
- **Tuning:** `ViewmodelSettings.Motion.DrawDrop/DrawPullBack/DrawTilt/DrawRoll`.

### 4.5 `CombatFeedback`

- **Wall impacts:** `FXUtil.BulletImpact(position, normal, surface)` draws:
  - A dark disc oriented to the surface, fading out after about 3.5 s.
  - Dust in the surface's color, plus 4 sparks.
  - The shooter draws impacts from its own pellet casts.
  - Observers get them in `CombatClient`'s `ShowBulletTracer` handler, which raycasts from the third-person muzzle to the tracer endpoint to find the surface. Impacts are skipped on characters.
- **Hit-direction indicator:**
  - **Server:** `WeaponServer.ProcessDamage(..., sourcePosition?)` gained a 7th optional argument. Before applying damage to an `IsPlaying` player, `notifyHit` fires `DamageIndicator:FireClient(victim, sourcePosition or attackerRoot.Position)`. Self-damage is excluded.
  - **Client:** `CombatClient` draws a red, end-faded 140×13 bar on a 120-px ring around the crosshair. Each frame it re-aims at the source (`atan2(relative.X, −relative.Z)`) and fades over 1.5 s.
- **Ammo tint:** `MainHudController.SetAmmoWarning(fraction)` colors the counter:
  - At or below 30%: orange (255,170,40).
  - At 0: red (255,60,60).
  - `nil` restores the original color.
  - `GunHandler:updateUI` calls it under the flag; Unequip resets it.
- **Moving tracers (2026-10-28):** `FXUtil.BulletTracer` used to draw one 0.1-stud neon bar from the muzzle to the hit point and shrink it to nothing over 0.15 s. Past about 25 studs that bar is under 2 pixels thick and gone within a few frames, so shots looked as if they stopped short and turned into a bullet hole. The rays always reached the hit point. Under the flag, `movingTracer` instead flies a streak from the muzzle to the hit point:
  - Up to `FXConfig.Tracer.Length` (14) studs long, at `Speed` (700 studs/s), or faster so no streak is in the air longer than `MaxTime` (0.3 s).
  - Its thickness is recomputed every frame from its distance to the camera, so it holds about `Pixels` (2.5) pixels at any range.
  - One `RenderStepped` connection moves all live streaks and disconnects when none are left.
  - With the flag off, the old bar is unchanged.
- **Hit-marker sounds:** `CrosshairController.ShowHitMarker` used `rbxassetid://4606132034` and `8617756184`. Neither is an audio asset, so both always failed with "Asset type does not match requested type". Under the flag, `hitSound()` swaps in `rbxassetid://7242037470`, the guns' own `Handle.HitMarker` sound (verified to load, 0.39 s).

### 4.6 `Utilities`: frag grenade

- **Config:** `Modules.Core.UtilityConfig.Grenade`:

  | Field | Value |
  |---|---|
  | `Charges` | 2 |
  | `Recharge` | 12 s per charge |
  | `ThrowCooldown` | 0.6 s |
  | `ThrowSpeed` / `ThrowLift` | 75 / 18 studs/s |
  | `Fuse` | 1.8 s |
  | `Radius` | 16 studs |
  | `MaxDamage` → `MinDamage` | 95 → 15, linear by distance |
  | `DisplayName` | "Frag Grenade" (shown in the kill feed) |

- **Client:** `Services.UtilityService.UtilityClient`.
  - **F** fires `ThrowUtility("Grenade", cameraPos, cameraLook)` when `IsPlaying` and there are charges left. It also flicks the viewmodel.
  - A small `PlayerGui.UtilityHUD.Grenades` label reads "[F] GRENADE xN" beside the weapon slots.
- **Server:** `Services.UtilityService.UtilityServer`.
  - **Validation:** flag on, `IsPlaying`, phase Shoot, eye within 14 studs of the head, charges available, cooldown elapsed.
  - **Charges:** published as the player attribute `GrenadeCharges`, refilled whenever `IsPlaying` turns true, and recharged one at a time.
  - **Grenade part:** a collidable 0.9-stud ball with `CanQuery=false`, a red PointLight and server network ownership. It lives in `Workspace.GrenadeProjectiles`, which `HitscanUtil.CastIgnoring` explicitly excludes: Roblox still raycasts collidable parts despite `CanQuery=false`. Aim rays, bullet casts, observer impact casts, and lag-compensation line-of-sight checks use that shared filter. It spawns 2.5 studs ahead of the eye (or in front of a wall the player is hugging) and inherits half the thrower's velocity.
  - **On the fuse:**
    1. It spawns a visual `Explosion` with no pressure and no joint breaking.
    2. It damages every Humanoid model in `Radius` except the thrower, if `LagCompensation.IsClear` reaches the root or the head.
    3. Damage goes through `ProcessDamage`, so team rules, kills and rewards apply. The kill feed shows "FRAG GRENADE".
    4. The thrower gets `DamageVFX` hit markers, and victims get the hit-direction indicator pointing at the blast.
  - There is no self-damage and no knockback.

---

## 5. Remotes (`ReplicatedStorage.Shared.Remotes.CombatRemotes`)

| Remote | Direction | Arguments | Notes |
|---|---|---|---|
| `ToolConnections` | C→S | `toolName, aimPoint, isAiming, eyeOrigin, directions{Vector3}, claims{ {pelletIndex, BasePart} }?` | `claims` is sent only under `ClientHitReg` |
| `ShowBulletTracer` | S→C | `origin, targetPos, isLocalShot` | Not sent to the shooter when it drew its own tracers |
| `DamageVFX` | S→C | `position, damageText, hitPart, normal?, killed, predicted?` | `predicted=true`: the client already showed it, so only `killed` matters |
| `Reload` | C→S | `toolName` | **New.** Starts the server reload timer (`ClientHitReg`) |
| `AmmoSync` | S→C | `tool, ammo` | **New.** Server correction after it refuses an empty-magazine shot |
| `DamageIndicator` | S→C | `sourcePosition` | **New.** `CombatFeedback` |
| `ThrowUtility` | C→S | `"Grenade", origin, direction` | **New.** `Utilities` |
| `PushRequest`, `AimPitch` | – | – | Unchanged |

---

## 6. Every instance created or changed (Studio paths)

**New:**
- `ReplicatedStorage.Shared.Modules.Core.CombatConfig`: the flags.
- `ReplicatedStorage.Shared.Modules.Core.UtilityConfig`: grenade tuning.
- `ReplicatedStorage.Shared.Modules.Gunsystem.WeaponHandling`: client spread and recoil state.
- `ReplicatedStorage.Shared.Services.UtilityService` (Folder) `.UtilityClient`.
- `ServerScriptService.Server.Classes.LagCompensation`.
- `ServerScriptService.Server.Classes.AmmoServer`.
- `ServerScriptService.Server.Services.UtilityService` (Folder) `.UtilityServer`.

**Modified:**

| Script | Changes |
|---|---|
| `Shared.Classes.GunHandler` | `damageableTarget`, `isCharacterPart`, `scopeOverlay`, `controllersByTool` + `AmmoSync` handler, `_claimHit`, `_fireOnce` (claims, handling spread/recoil, impacts), `shoot` (shotgun interrupt), `_setScoped`, `_reloadDuration`, `_interruptReload`, `Reload` (token), `Equip` (draw time, handling loop), `_startHandling`/`_stopHandling`, `Unequip`, `Destroy` |
| `Shared.Services.CombatService.CombatClient` | `DamageVFX` handler split into `showHitFeedback`, plus `CombatClient.ShowPredictedHit`; `predicted` argument; hit-direction indicator; observer impacts |
| `Shared.UIControllers.CrosshairController` | `SetSpreadGap`, `SetSuppressed`, spread-gap drawing, `hitSound()` fix |
| `Shared.UIControllers.MainHudController` | `SetAmmoWarning`, `heldSlot`, `swapWeapon`, Q/wheel input, no holster under `QuickSwap` |
| `Shared.Modules.Utils.HitscanUtil` | `CastIgnoring`, `SpreadProfile`, `SpreadBound`, `HandlingDamage` |
| `Shared.Modules.Utils.FXUtil` | `BulletImpact` |
| `Shared.Modules.Core.Items` | `Handling` table on all six guns, plus a doc comment |
| `Shared.Types` | `SpreadHandling`, `FalloffConfig`, `RecoilPattern`, `HandlingConfig`, and `WeaponDefinition.Handling` |
| `Shared.Remotes.CombatRemotes` | `Reload`, `AmmoSync`, `DamageIndicator`, `ThrowUtility` |
| `Shared.Classes.Viewmodel` | `Draw`, `SetHidden` |
| `Shared.Modules.Gunsystem.ViewModelHandler` | `viewmodel:Draw` |
| `Shared.Modules.Gunsystem.ViewmodelMotion` | `Motion:Draw` and draw offsets in `Update` |
| `Shared.Modules.Gunsystem.ViewmodelSettings` | `Motion.Draw*` tuning |
| `ServerScriptService.Server.Classes.WeaponServer` | `notifyHit`, `ProcessDamage(..., sourcePosition)`, `readClaims`, `resolveClaim`, `FireHitscan(..., claims)` with the claims path, `SpreadBound` and `HandlingDamage` |
| `ServerScriptService.Server.Services.CombatService.CombatServer` | `Publish` + `LagCompensation.Start`, the `drawnAt` draw-time check, the ammo check + `AmmoSync`, the `Reload` handler |

Untouched: `MeleeHandler`, `FirstPersonRig`, `ThirdPersonRig`, `MovementClient`, `RoundServer`, all Tool assets (no welds or parts were changed).

---

## 7. Verification done in Studio playtests (2026-10-25/26)

Shots were produced with real mouse input and with crafted `ToolConnections` calls. Dummies were player-character clones tagged `LagCompensated`.

| Check | Result |
|---|---|
| All flags off: legacy shot | 35 body / 70 head (flat 2×), crosshair at legacy bloom, no grenade HUD. Identical to before |
| Instant hit feedback | Exactly one damage number per hit (from the prediction); the server added no duplicate; the kill flash came from the server |
| Rewind: target position 0.08 s old (2.5 studs away now) | Accepted |
| Target position 0.5 s old (13–15 studs away) | Rejected |
| Claimed hit behind floor geometry | Rejected (line of sight) |
| Head claimed through the torso | Counted as a body hit (was −70 before the occlusion fix) |
| 17 shots from a 15-round magazine | 15 accepted, 2 rejected, client corrected to 0/15 |
| Shot fired mid-reload (magazine gun) | Rejected |
| Real empty click → auto reload → 3 shots | Reload went through the server; all 3 landed |
| AR spread | Hip 8, aim 3, airborne 30, server bound 50; crosshair gap 4 px → 16 px airborne → 4 px landed |
| AR spray (~10 rounds) | Aim climbed ~7.7° following the pattern (right, then left) and recovered to exactly 0° about 0.6 s after release |
| `HandlingDamage` | AR 35@50, 25@220, 56 head; SMG 11@120, 28 head; Shotgun pellet 35@10, 11@60; Sniper 250 / 500 head |
| Server tactical vs empty reload (AR) | Tactical shot at 1.1 s accepted; empty shot at 1.1 s rejected, accepted at 1.4 s |
| Draw time (Sniper 0.6 s) | Shot 0.16 s after equip rejected; at 0.77 s accepted (−250) |
| Q / key 2 while holding melee | Q: Knife → Shotgun → back; key 2 kept the Knife |
| Shotgun interrupt | 8→7→6, R loads 1 shell (7), firing mid-reload went straight to 6 and stopped the reload |
| Sniper scope | Lens overlay, reticle, viewmodel and crosshair hidden; all restored after release |
| Impacts / ammo tint / hit-direction indicator | Visible; counter red at 0/30; indicator on the correct side |
| Hit sound `7242037470` | Loads (Success, 0.39 s); old IDs fail as expected |
| Grenade | Thrown, exploded on the fuse, dummy −62, charges 2→1→2 after 12 s |
| Console | No script errors from any of this code |

**Not yet verified:**
- Real network latency with two or more players. Solo Studio has about 0 ping; rewind was tested with deliberately delayed claims instead.
- Behavior on a live server.

---

## 8. Known issues and limitations

**Fixed on 2026-10-27, existing before this work:**
- **Shotgun viewmodel:** the gun sat below the camera, out of view, with neither hand on it. This was the same with every flag off. It was fixed in the rig data, not the Tool:
  - **Fighting joints:** in `ReplicatedStorage.WeaponViewmodelData.Shotgun.Joints`, the `trigger`, `Bullet` and `Reolader ` joints were enabled motors fighting the Tool's own welds and pulling the gun body off its handle. They now have `UseToolWeld = true`, the same way the Sniper's joints are set up, so the Tool's welds hold those parts.
  - **Borrowed animations:** the Shotgun's own published Hold and Reload frame the gun out of view and can't be republished from here. The data folder now has `AnimationsFrom = "AR"`, so it uses the AR's published two-handed hold and reload. This needed a small hook, `gun:_animationFolder()`, in `ReplicatedStorage.Shared.Modules.Gunsystem.GunHandler`.
  - **Fit:** `Joints.Handle` has a `ToolC1` fitted to the AR hold. It puts the pump center (the `Reolader ` part) in the left hand, with the barrel along the AR's barrel direction.
  - **Verified in a playtest:** the gun is visible and points forward, and the left hand sits on the pump. Over a full reload, the barrel stayed on screen in every frame. Other guns are unchanged.
  - **Undo:** clear `AnimationsFrom`, `ToolC1`, and the three `UseToolWeld` attributes.

**Found during this work, existing before it, not fixed:**
1. **Shoot animation:** the viewmodel shoot animation `rbxassetid://83100159695747` fails with "User is not authorized to access Asset"; the experience needs access to that asset.
2. **Asset warning:** `rbxassetid://203785492` logs "Asset type does not match requested type" at startup.
3. **Invisible part above the head:** `Workspace.Game` is a 0.5-stud invisible part with `CanQuery=true` about 6 studs above the player's head. It stops shots fired straight up.
4. **Duplicate modules:** `ReplicatedStorage.Shared.Classes` contains two identical `ThirdPersonRig` modules, and nothing references either.
5. **Dead module:** nothing requires `ReplicatedStorage.Shared.Modules.Gunsystem.GunAudio`; `GunHandler` has its own local gunshot audio.
6. **Log spam:** `ViewmodelSettings.Verbose = true` and `LogAnimations = true` flood the console with joint dumps.
7. **Slot icons:** the Main and Melee HUD slot icons can both show a pistol (icon rendering in `MainHudController.refreshWeaponIcons`).

**Limitations of the new systems:**
- **Melee** is still checked on the server with no lag compensation (`WeaponServer.FireMelee`).
- **Predicted feedback is not rolled back:** if the server rejects a claim, which should only happen with cheats or desync, the client already showed the hit marker.
- **Fire modes:** burst, charge and spin-up are not implemented. Every gun is semi or auto.
- **Grenade:** no knockback, no self-damage, no cook/hold, and no throw animation.
- **Loadout:** still two Tool slots (Main/Melee), with no secondary or utility slot in the shop or loadout data.
- **No authored draw, inspect or tactical-vs-empty animations:** the draw is procedural.
- **Server spread check:** under `GunHandling` it accepts any direction inside the gun's widest possible cone, so a no-spread cheat is not detected. Aim itself is client-authoritative by design.

---

## 9. How to test manually (Studio)

1. Press Play. All five flags are on automatically in Studio.
2. Click **Play** in the menu, join a round, and get a gun. The Studio-only **G** gun picker or the `StudioGiveGun` RemoteFunction gives any gun.
3. Things to try:
   - Move, jump and slide and watch the crosshair widen.
   - Spray the AR and let the aim recover.
   - Scope the Sniper.
   - Interrupt the Shotgun reload by firing.
   - Swap with Q or the wheel and notice the draw delay.
   - Throw a grenade with F.
   - Shoot walls.
4. To compare with the old behavior, add the Workspace attribute `<Flag> = false` before pressing Play.

**Tips for agents driving Studio through MCP:**
- Click the menu's Play button with `user_mouse_input` and `instance_path: "LocalPlayer.PlayerGui.Menu.Holder.Play.btn"`; raw coordinates did not register reliably.
- Pause the round with `ReplicatedStorage.Shared.Remotes.TogglePause:FireServer(true)` from the client.
- **A solo player wins FFA immediately.** For combat tests, set `player:SetAttribute("IsPlaying", true)` and `Workspace:SetAttribute("ArenaPhase", "Shoot")` on the server in the throwaway playtest.
- **Test dummy:** clone the player's character (`Archivable = true`), strip scripts and tools, anchor the HumanoidRootPart, and tag it `LagCompensated` so it gets a position history.
- **`execute_luau` gets its own module instances:** `require` there returns a separate copy from the game's scripts. Test live state through Instances, attributes and remotes, not through module-local tables.
- **Scripts can only be edited in Edit mode.** `multi_edit` refuses during Play.

---

## 10. Shipping and rollback

- **Ship a feature:** set its live value to `true` in `CombatConfig` and publish. Suggested order: `ClientHitReg` and `CombatFeedback` first, then `GunHandling`, then `QuickSwap`, then `Utilities`. Test `ClientHitReg` with real latency first.
- **Roll back instantly:** set the flag to `false`. The code paths are independent, and every legacy path is intact.
- **Tune:** spread, recoil, falloff, headshots, reload and draw times are all data in `Items[gun].Handling`. Grenade numbers are in `UtilityConfig`; draw motion is in `ViewmodelSettings.Motion`.

---

## 11. What is still missing to feel like Rivals

1. **Authored viewmodel animations** per gun (viewmodel rebuild stage 3): draw, inspect, sprint pose, tactical and empty reloads. Fix the inaccessible shoot animation first. The Shotgun currently borrows the AR's hold and reload (see §8), so it would benefit most from its own animations.
2. **A real loadout:** primary, secondary, melee and utility slots owned by the server, ideally replacing Roblox Tools for first person.
3. **More weapon types:** burst/charge/spin-up fire modes (the server rate limit needs a burst-aware token bucket), projectile weapons (rocket launcher, bow), and more utilities (flashbang, smoke, molotov). The grenade code in `UtilityServer` is the template.
4. **Melee** lag compensation through `LagCompensation`.
5. **A multi-client latency test.** Tune `INTERPOLATION_ALLOWANCE`, `MIN_REWIND`/`MAX_REWIND` and `BASE_TOLERANCE` from the results.
6. **Polish:** kill cam / death recap, inspect key, crosshair customization presets, and per-gun hit/kill sound sets.


---

## 12. Review fixes (2026-10-26)

A local place snapshot containing these fixes is saved as [`color_clash-gunplay-fixes.rbxl`](../color_clash-gunplay-fixes.rbxl). This was downloaded from the current Edit session after verification; the existing `color_clash.rbxl` and local `src/` were not overwritten.

All five issues from the follow-up review were fixed directly in Studio through MCP. Live flag defaults remain off. The local `src/` tree is still behind Studio; do not start Rojo from it.

| Issue | Fix | Verification |
|---|---|---|
| Client claims accepted stored asset humanoids | `LagCompensation.ModelOf` requires a living, queryable world target, excludes Tool descendants; `WeaponServer.ProcessDamage` independently rejects non-Workspace targets | The actual ReplicatedStorage viewmodel template was rejected and its health stayed unchanged. A world dummy still took 35 damage; walls still blocked claims; Tool and non-queryable parts were rejected |
| Bloom decayed completely between shots | Added `Spread.BloomRecoveryDelay` (default 0.25 s) before recovery, including partial-frame accounting; Reset clears the shot timestamp | 24-shot timing simulations built Pistol/AR/SMG/Scar bloom to 20/14/12/16 respectively, then recovered to zero after resting |
| Live `GunHandling` toggles did not manage the frame loop | Equipped controllers listen for flag changes, reset state, start/stop the loop and update scopes; Destroy disconnects both listeners | Enable restored bloom/recoil recovery; disable disconnected the loop and stopped recovery; re-enable created a new loop; destruction disconnected both connections. Server flag changes also correctly toggled the scope on a real equipped Sniper while ADS stayed held |
| Sniper suppression hid hit/kill feedback | Only Top/Bottom/Left/Right bars are hidden; the Crosshair parent and FeedbackLayer remain visible | Real equipped Sniper in ADS displayed both hit and kill markers from server feedback events; scope disable restored all four bars |
| Collidable grenades intercepted bullets | Grenades spawn under `Workspace.GrenadeProjectiles`; shared hitscan filtering excludes that folder, including aim and observer-impact rays | A raw ray hit a collidable test grenade; both shared casts skipped it and hit the wall behind it. A real throw used the folder, retained collisions, consumed one charge, and was skipped by hitscan |

Changed scripts: `LagCompensation`, `WeaponServer`, `HitscanUtil`, `WeaponHandling`, `Types`, `Classes.GunHandler`, `CrosshairController`, `UtilityServer`, and `CombatClient`.

Tests used temporary Studio play sessions and did not apply gameplay rewards. Studio was returned to Edit mode. No new script errors appeared in the final integration session; the pre-existing `203785492` asset-type warning remains. Multi-client latency and live-server behavior still require separate verification. These fixes were not published to Roblox.


---

## 13. Full avatar body and R15 compatibility (2026-10-26)

The experience was configured as **R6 Only**. The affected player's body bundle uses R15 meshes: Roblox retained the custom head but fell back to the blocky R6 body. A temporary R15 StarterCharacter built from the player's current HumanoidDescription displayed the full bunny body correctly. The temporary character was removed after testing, so players are not forced to share that avatar.

The required experience setting is **R15 & R6**, preserving each player's chosen body, scale, and build. **This setting is still pending approval:** Studio says saving affects every place in the experience and restarts all running places. The script fixes alone do not remove the R6-only restriction.

Changed scripts:
- Added `Shared.Modules.Utils.JointUtil`: writes Motor6D.C0 or AnimationConstraint.Attachment0.CFrame as appropriate. Modern R15 AnimationConstraint.C0 is read-only; direct writes previously caused repeated MovementClient errors.
- `AimPoseController`: finds the R15 neck under Head, applies the correct pitch sign, and uses the compatible joint writer.
- `FirstPersonRig`: applies and restores procedural poses on both joint types. The authored first-person weapon rig remains separate from the world avatar.
- `MovementClient`: supports both joint types, disposes old character tracks on respawn, and avoids playing R6-only parkour clips on R15.
- `MeleeHandler`: R15 retains its avatar locomotion and uses the configured R15 swing; R6 retains the existing animation set.

Verification:
- Full custom R15 head, torso, arms, hands, legs and feet rendered in a real local play session; [screenshot](../avatar-r15-playtest.png).
- Keyboard walking/jumping moved the character 14.6 studs in the sampled test. First-person and M-toggle third-person modes restored body visibility and original neck pose.
- Sniper equip, ADS (FOV approximately 30), firing (HUD 4/5), and Knife's R15 MeleeSwing (animation 522635514, 0.5 s) worked.
- Both Motor6D and AnimationConstraint passed pose/restore checks. A normal R6 spawn passed first-person visibility and pose restoration with no script errors.
- Existing asset problems remain: 203785492 has an asset-type mismatch, and animation 83100159695747 is inaccessible to this experience. R15-specific parkour animation clips are not authored; movement mechanics remain available with avatar locomotion.

Saved a complete local snapshot, including the earlier gunplay fixes: [color_clash-avatar-fixes.rbxl](../color_clash-avatar-fixes.rbxl), 1,012,238 bytes. Studio initially hung during Download a Copy, then reconnected with all five avatar scripts intact; their sources were verified before the successful retry. Exact source copies are in [studio-recovery/avatar-fixes](../studio-recovery/avatar-fixes). Local `src/` remains stale and was not overwritten or synced with Rojo.

Studio's Output reported **version 657 published** after the snapshot was saved. The avatar-mode setting still needs its separate save/restart step.

## 14. Hidden color blocks stopped bullets (2026-10-28)

**Symptom:** during the Shoot phase, shots ended in mid-air and left a bullet hole there.

**Cause:** each cycle `RoundMechanic` hides every color folder except the chosen one by setting `Transparency = 1` and `CanCollide = false`. `CanQuery` stayed `true`, so every raycast still hit the invisible blocks. That covered the shooter's client cast, the server's cast, and other gameplay raycasts. The same was true of `HitPartMechanic`'s invisible kill floor ("hit part", 50 studs under the map). It must collide, so `CanQuery = false` has no effect on it.

**Fix (not behind a flag; it applies on live servers too):**
- `RoundMechanic` records each hidden part's `CanQuery`, sets it to `false` while hidden, and restores it at the next Push phase. `RoundMechanic:Stop()` also resets `CanQuery = true` when it resets the map.
- `HitscanUtil.IGNORE_NAMES` includes `"hit part"`, so bullets pass the kill floor.
- `LagCompensation`'s line-of-sight check already treats non-colliding, non-queryable parts as clear, so server validation agrees with the client.

**Verified in a live solo round:**
- During Shoot, the client saw 446 hidden blocks, none queryable.
- Forty `HitscanUtil.Cast` rays fired down through hidden blocks: none stopped on a hidden block or on the kill floor.
- After the round returned to Push, all map parts were visible, collidable and queryable again.
