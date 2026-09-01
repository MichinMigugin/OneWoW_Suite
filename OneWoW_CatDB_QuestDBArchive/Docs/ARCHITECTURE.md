# OneWoW_CatDB_QuestDBArchive — Architecture

> **See also:** [Suite architecture](../../OneWoW/Docs/ARCHITECTURE.md) §6 (store access rules)
>
> Catalog pointer: [OneWoW_Catalog/Docs/CATDB.md](../../OneWoW_Catalog/Docs/CATDB.md).
> This is the Catalog Quest Archive store.

## Overview

Load-on-demand quest store for **Classic through Dragonflight**. The War
Within and Midnight live in `OneWoW_CatDB_QuestDBCurrent`. Catalog's pack
resolver loads this pack for the `"archive"` role.

Same row schema as Current. Current loads this pack on demand for
Classic–Dragonflight (or all-quest search), then imports these rows into
Current's `ns`. Guide chains read `QuestLineMembers` from Current
(`GetQuestLineMembers`); this pack does not ship Generated overlays.

**SavedVariable:** `OneWoW_CatDB_QuestDBArchive_DB`

**RequiredDeps:** `OneWoW`. **LoadOnDemand:** yes (`## Group: OneWoW_Catalog`).
Catalog marks CatDB packs `lazyStores`.

**Public API:** `OneWoW_CatDB_QuestDBArchive_API`

## Modules

| Module | Role |
|--------|------|
| `Core/DataLoader.lua` | `RegisterQuestData` → `ns.ExternalQuestDB`, `ExternalQuestDBByExpansion`, `QuestsByNPC`, `QuestsByRewardItem` |
| `Core/Database.lua` | SavedVariables init (`ns.db`) |
| `Core/API.lua` | Public API (`GetQuest`, `GetQuestsForNPC`, `GetQuestsRewardingItem`, …) |
| `Core/Core.lua` | `BootStore` lifecycle (`savedVar`) |
| `OneWoW_CatDB_QuestDBArchive.lua` | Comment stub (no public globals) |

`ns` stays private. Cross-unit callers use the `_API` global only.

## BootStore

```lua
OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatDB_QuestDBArchive_DB",
})
```

`InitializeDatabase` runs through BootStore. `GetSettings()` reads
`ns.db.global.settings`. No scan callbacks.

## Data Layout

Per-expansion shards under `Data/QuestDB/`:

`QuestDB_classic.lua` … `QuestDB_dragonflight.lua` (expansions **0–9**).

Each file calls `ns:RegisterQuestData`.

## Tools (offline / Workspace)

`python bin/catdb_quest_emit.py` writes this pack and Current in one pass.
Scoreboard: `python bin/catdb_status.py quest`.

Static schema: [QUEST_DATA.md](QUEST_DATA.md) (same as Current).
Current load unit: [`OneWoW_CatDB_QuestDBCurrent/Docs/ARCHITECTURE.md`](../../OneWoW_CatDB_QuestDBCurrent/Docs/ARCHITECTURE.md).
Workspace pipeline: `Docs/WAREHOUSE_PLAN.md`.
