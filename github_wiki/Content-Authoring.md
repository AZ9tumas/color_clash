# Content Authoring

## Add a ranged weapon

A ranged weapon is identified by the presence of `MaxAmmo` in `Items`.

1. Choose a stable exact name.
2. Add a complete entry to `Items` with damage, cooldown, range, ammo, reload, spread, recoil, aim, and animation fields.
3. Use full `rbxassetid://...` strings for every animation ID.
4. Add a matching `Tool` under `ReplicatedStorage.Shared.Assets.Weapons`.
5. Ensure the Tool has `Handle` or another discoverable BasePart.
6. Add `FireSFX` and `ReloadSFX` beneath the handle when applicable.
7. Add a `MuzzlePoint`/`Muzzle` Attachment or a BasePart whose name contains `muzzle`.
8. Add the same exact name to `ShopConfig.Categories.Weapons` with `Subcategory = "Ranged"` if purchasable.
9. Add optional authored `WeaponViewmodelData/<name>` content.
10. Save the place and re-extract `WeaponViewmodelData.rbxm` if that data changed.
11. Test fire, dry fire, reload, ADS, automatic/semi cadence, muzzle FX, tracer origin, headshots, elimination, weapon swap, R6, and R15.

Example shape:

```lua
["Example Rifle"] = {
    Damage = 30,
    Cooldown = 0.1,
    Range = 600,
    MaxAmmo = 30,
    ReloadTime = 1.6,
    Spread = 7,
    AutoFire = true,
    Shake = { Intensity = 0.8, Decay = 12 },
    Recoil = { Pitch = 2.8, Yaw = 0.9 },
    Aim = { FOV = 55, SpreadMultiplier = 0.45 },
    Viewmodel = { Offset = Vector3.zero },
    Animations = {
        Shoot = "rbxassetid://00000000000000",
        Reload = "rbxassetid://00000000000000",
        Idle = "rbxassetid://00000000000000",
        Walk = "rbxassetid://00000000000000",
        Sprint = "rbxassetid://00000000000000",
    },
}
```

## Add a melee weapon

1. Add an `Items` entry without `MaxAmmo`.
2. Include damage, cooldown, shake, and `Animations.Swing.R6/R15` plus idle/walk/sprint.
3. Add a matching Tool to `Shared.Assets.Weapons`.
4. Add it to `ShopConfig` with `Subcategory = "Melee"` if purchasable.
5. Decide its sound family. Names containing `Axe` or `Bat` use those families; all others use default unless code is extended.
6. Test server radius hit registration from the handle, cooldown, animation, sound, hit feedback, team filtering, R6, and R15.

## Author weapon viewmodel data

Create or edit `ReplicatedStorage.WeaponViewmodelData/<WeaponName>` in Studio with:

- `WeaponModel` containing a resolvable `Handle`;
- `Joints` configs with `Part0`, `Part1`, `C0`, and `C1` attributes;
- `Hold` KeyframeSequence;
- `Reload` KeyframeSequence;
- optional `ReloadLength` numeric attribute.

Names are normalized for trailing spaces and case during model-part lookup, but folder names still need to match the item name. Prefer exact names to avoid ambiguity.

When complete:

```sh
lune run extract_weapon_viewmodel_data.luau
```

The extractor serializes the complete folder into `src/ReplicatedStorage/WeaponViewmodelData.rbxm`.

## Add a map cell variant

1. Open `Workspace.Map` before the server initializes.
2. Place the Model under one of the configured color folders.
3. Set a stable Model pivot suitable for grid placement.
4. Keep gameplay surfaces as BaseParts; generation recolors all BaseParts.
5. Verify the model fits the configured X/Z pitch and does not overlap neighbors.
6. Start a fresh server and confirm `MapMechanic.Init()` harvests it into `ServerStorage.MapTemplates`.
7. Generate multiple rounds to catch variant-specific collisions and spawn failures.

## Add a map color

Add it to `MapConfig`, create its Workspace template folder, and update `RoundUIController`’s text-color mapping. Test color balancing and every hide/restore cycle.

## Add a shop item

For weapons, content must already exist in `Items` and `Shared.Assets.Weapons`. Add its exact name, price, description, and subcategory to `ShopConfig`. Verify fresh ownership state, insufficient funds, purchase, equip, persistence, and HUD icon rendering.

Skins and Effects need server equip semantics and runtime consumers before content in those categories becomes functional.

## Add a daily reward

Edit `DailyRewardConfig.Rewards`. Supported keys are `Name`, `Cash`, and `Weapon`. Weapon names must match a real inventory weapon. The backend uses array order as the day sequence.

## Add a quest

Add a stable ID and definition in `QuestConfig`; connect its stat increment at an authoritative server event. See [Quests and Daily Rewards](Quests-and-Daily-Rewards).

## Add a sound

Shared named effects belong in `SoundService.GameSounds`. Music tracks belong in `SoundService.Music`. Tool-specific fire/reload sounds belong beneath the Tool handle. Update `FXConfig` or the caller with the exact template name, then verify missing-sound behavior remains nonfatal.

## Add a setting

1. Add a definition to `SettingsConfig` with name, type, default, description, and slider range when relevant.
2. Implement the runtime consumer through `SettingsController.GetValue`.
3. Apply it after saved settings load and whenever the user changes it.
4. Add server-side type/range validation if the value has gameplay or resource-cost impact.
5. Add it to the implemented-settings table in [UI, Settings, and Audio](UI-Settings-and-Audio).
