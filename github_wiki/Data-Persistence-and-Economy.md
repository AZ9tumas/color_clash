# Data, Persistence, and Economy

## Profile storage

`DataServer` uses ProfileStore with store name `PlayerData_v2` and `DataTemplate` as the default schema. Profile keys are `Player_<UserId>`.

On load, the server:

1. starts a session with cancellation if the player leaves;
2. associates the UserId with the profile;
3. stores the active profile by Player instance;
4. fires `DataServer.ProfileLoaded(player, profile)`;
5. ends the session on player removal or server shutdown.

If loading fails, or an active session ends unexpectedly, the player is kicked to avoid unsafely continuing without authoritative data.

## Data schema

```lua
{
    Cash = 0,
    Wins = 0,
    Kills = 0,
    Inventory = {
        Weapons = {
            Pistol = true,
            ["Wooden Knife"] = true,
        },
        Skins = {},
        Effects = {},
    },
    Equipped = {
        Main = "Pistol",
        Melee = "Wooden Knife",
    },
    Settings = {},
    Quests = {
        Stats = {},
        Completed = {},
    },
    DailyRewards = {
        LastClaimedDay = 0,
        Streak = 0,
        TotalClaimed = 0,
    },
}
```

## Safe profile access

| API | Use |
| --- | --- |
| `DataServer.GetProfile(player)` | Immediate access when the caller already knows the profile is loaded |
| `DataServer.WaitForProfile(player)` | Remote handlers or player initialization that may race profile loading |
| `DataServer.GetData(player)` | Read the loaded profile data table or nil |
| `DataServer.ProfileLoaded` | Initialize dependent server systems without relying on service order |

Never yield forever on a Player that has left. `WaitForProfile` stops when the Player is no longer parented to `Players`.

## Schema changes and migration

ProfileStore receives `DataTemplate`, but existing code also defensively initializes nested tables in Shop, Quest, Daily Reward, and Settings services. When adding a field:

1. add a backwards-compatible default to `DataTemplate`;
2. initialize/repair the field at the server boundary that consumes it;
3. accept old profiles where the field is absent or malformed;
4. never rename or delete a production field without an explicit migration;
5. test with both a fresh profile and a profile shaped like the previous schema.

Do not store Instances, CFrames, EnumItems, or functions directly in profile data. Use primitive/table representations.

## Currency and stats

`CurrencyServer` is the single mutation API for:

- cash;
- wins;
- lifetime kills.

It mirrors persisted values into:

- `player.leaderstats.Cash`;
- `player.leaderstats.Wins`;
- `player.HiddenStats.TotalKills`.

Use `AddCash`, `RemoveCash`, `AddWins`, and `AddKills` instead of editing profile data directly so runtime values stay synchronized.

## Inventory and equipment

Inventory ownership is stored as Boolean lookup tables. Equipment uses two weapon slots:

- `Equipped.Main` for a ranged weapon;
- `Equipped.Melee` for a melee weapon.

`ShopServer` repairs missing inventory/equipment structures, always grants Pistol and Wooden Knife ownership, and migrates an invalid legacy Knife melee selection back to Wooden Knife.

`PlayerUtil.GiveWeapons()` reads the equipped names and clones matching Tool templates from `ReplicatedStorage.Shared.Assets.Weapons`. If a name does not match a Tool template exactly, the player silently receives no Tool for that slot.

## Shop transaction flow

`ShopController` retrieves inventory using `GetInventory`, renders `ShopConfig`, and invokes server functions for buy/equip.

The server validates:

- category exists in `ShopConfig`;
- item exists in that category;
- item is not already owned;
- the player has enough cash;
- equip ownership is present;
- melee/ranged slot is derived from the configured subcategory.

Skins and Effects have empty configurations and no equip implementation. Weapon purchases are the only complete current category.

## Rewards

`RewardConfig` defines placement and per-kill cash. `RewardManager` awards:

- kill cash immediately and records it in `RoundCash`;
- placement cash on elimination;
- first-place cash and a win on victory;
- quest updates for elimination, second place, and wins.

The death-screen total combines placement reward and already-awarded round kill cash for display. `RewardManager` adds only the placement component at death because kill cash was paid as kills occurred.

## Studio testing caution

Profile behavior depends on Studio API access and ProfileStore’s environment. Use dedicated test accounts/data policies. Never test destructive migrations against production profiles without a rollback/export plan.
