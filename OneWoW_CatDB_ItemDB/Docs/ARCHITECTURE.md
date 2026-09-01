# OneWoW_CatDB_ItemDB — Architecture

> **See also:** [Suite architecture](../../OneWoW/Docs/ARCHITECTURE.md) §6 (store access rules)
>
> Catalog pointer: [OneWoW_Catalog/Docs/CATDB.md](../../OneWoW_Catalog/Docs/CATDB.md).
> This is the Catalog Items store. Journal extras / `JournalItemNames` remain
> a leftover name source until cutover.

## Overview

Load-on-demand item **identity** store. Catalog's pack resolver loads it
for the `"items"` role.

Owns what an item **is** (name, quality, bind, collectable flags) for IDs
other packs or achievements cite. Class, subclass, inventory type, and icon
are filled by `GetItem` from the client Instant APIs. **Where** it drops,
sells, rewards, or crafts stays a join from ZoneDB / NPCDB / QuestDB /
TradeSkillDB. Achievement IDs for an item live here (`ItemAchievements`).

Also owns cited currency identity (`name`, `icon`) for vendor / quest costs.

**SavedVariable:** `OneWoW_CatDB_ItemDB_DB`

**RequiredDeps:** `OneWoW`. **LoadOnDemand:** yes (`## Group: OneWoW_Catalog`).
Catalog marks CatDB packs `lazyStores`.

**Public API:** `OneWoW_CatDB_ItemDB_API`

## Modules

| Module | Role |
|--------|------|
| `Core/DataLoader.lua` | `RegisterItemData` / `RegisterCurrencyData` / `RegisterItemAchievementData` → `ns.Items`, `ns.ItemNameIndex`, `ns.Currencies`, `ns.ItemAchievements` |
| `Core/Database.lua` | SavedVariables init (`ns.db`) |
| `Core/API.lua` | Public API (`GetItem`, `GetItemNameIndex`, `GetCurrency`, `GetAchievementsForItem`) |
| `Core/Core.lua` | `BootStore` lifecycle (`savedVar`) |
| `OneWoW_CatDB_ItemDB.lua` | Comment stub (no public globals) |

`ns` stays private. Cross-unit callers use the `_API` global only.

## BootStore

```lua
OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatDB_ItemDB_DB",
})
```

`InitializeDatabase` runs through BootStore. `GetSettings()` reads
`ns.db.global.settings`. No scan callbacks — this pack has no live overlay.

## Data Layout

ID-bucket shards under `Data/`:

- `Items_000000.lua` … (25k itemID buckets; only buckets that have cited rows)
- `Currencies.lua`
- `ItemAchievements.lua`

Each item shard calls `ns:RegisterItemData`. Currencies call
`ns:RegisterCurrencyData`.

## Tools (offline / Workspace)

Emit lives in OneWoW_Workspace (`bin/catdb_item_emit.py`,
`bin/catdb_status.py item`). Not loaded by the addon TOC.

Static schema: [ITEM_DATA.md](ITEM_DATA.md).
Workspace pipeline: `Docs/WAREHOUSE_PLAN.md`.
