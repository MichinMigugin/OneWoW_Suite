# OneWoW_CatDB_NPCDB — Architecture

> **See also:** [Suite architecture](../../OneWoW/Docs/ARCHITECTURE.md) §6 (store access rules)
>
> Catalog pointer: [OneWoW_Catalog/Docs/CATDB.md](../../OneWoW_Catalog/Docs/CATDB.md).
> This is the Catalog NPCs store (Vendors tab).

## Overview

Load-on-demand NPC store. Catalog's pack resolver loads it for the
`"vendors"` / `"npcs"` role.

The Catalog **tab** today is still named Vendors. The **store** is every
npcID that currently lives on vendors, quests, extras, bosses, vignettes,
recipes, or a Creature title that marks a service (`roles`). The list
shows vendor, trainer, service, and quest-giver rows. Stock identity is ItemDB. Quest
text is QuestDB. Place keys join ZoneDB.

**SavedVariable:** `OneWoW_CatDB_NPCDB_DB`

**RequiredDeps:** `OneWoW`. **LoadOnDemand:** yes (`## Group: OneWoW_Catalog`).
Catalog marks CatDB packs `lazyStores`.

**Public API:** `OneWoW_CatDB_NPCDB_API`

## Modules

| Module | Role |
|--------|------|
| `Core/DataLoader.lua` | `RegisterNpcData` → `ns.NPCs` / `ns.NPCsByItem` |
| `Core/Database.lua` | SavedVariables init (`ns.db`) |
| `Core/API.lua` | Public API (`GetNPC`, `GetVendor`, `GetAllVendors`, `GetAllNPCs`, `GetNPCsByRole`, …) |
| `Core/Core.lua` | `BootStore` lifecycle (`savedVar`, `withScanCallbacks`) |
| `OneWoW_CatDB_NPCDB.lua` | Comment stub (no public globals) |

`ns` stays private. Cross-unit callers use the `_API` global only.

## BootStore

```lua
OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatDB_NPCDB_DB",
    withScanCallbacks = true,
})
```

`InitializeDatabase` runs through BootStore. `GetSettings()` reads
`ns.db.global.settings`. At login the pack subscribes to `OneWoW.Merchant`
and overlays name, title category, and last visit onto the row view.

## Data Layout

Per-expansion Lua shards under `Data/NpcDB/`. Each file calls
`ns:RegisterNpcData`. Classic through Midnight (`NpcDB_classic.lua` …
`NpcDB_midnight.lua`). Expansion IDs match `LE_EXPANSION_*` (Classic = 0).

## Tools (offline / Workspace)

Emit lives in OneWoW_Workspace (`bin/catdb_npc_emit.py`,
`bin/catdb_status.py npc`). Seeds from current CatDB NPC shards plus
warehouse CSVs. Not loaded by the addon TOC.

Static schema: [NPC_DATA.md](NPC_DATA.md).
Workspace pipeline: `Docs/WAREHOUSE_PLAN.md`.
