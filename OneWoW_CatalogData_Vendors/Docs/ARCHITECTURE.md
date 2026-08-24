# OneWoW_CatalogData_Vendors — Architecture

> **See also:** [Suite architecture](../../OneWoW/Docs/ARCHITECTURE.md) §6 (store access rules)

## Overview

Load-on-demand data store registered with `OneWoW_Catalog` as the `"vendors"`
provider. Ships static `NpcDB_*` shards and enriches them at runtime via the
merchant scanner.

The Catalog **tab** is vendors-only. The **store** is an NPC table (`roles`) so
Quests can share biography later without copying pins.

**SavedVariable:** `OneWoW_CatalogData_Vendors_DB`

**RequiredDeps:** `OneWoW`. **LoadOnDemand:** yes (`## Group: OneWoW_Catalog`).

## Modules

| Module | Role |
|--------|------|
| `Core/NpcDBLoader.lua` | Merges `Data/NpcDB/NpcDB_*.lua` into `ns.StaticVendors` / `ns.StaticVendorItems` |
| `Modules/VendorData.lua` | Static + live overlay for Catalog (lookup, expansion filter) |
| `Modules/VendorScanner.lua` | Live capture from `OneWoW.Merchant` |
| `Modules/VendorCategoryMap.lua` | Subtitle → category key |
| `Modules/DataLoader.lua` | Item cache + NPC name tooltip queue |
| `Core/Database.lua` | SavedVariables init |
| `Core/API.lua` | Public API (`GetVendor`, `GetAllVendors`, `GetVendorsByItem`, …) |
| `Core/Core.lua` | `BootStore` lifecycle |
| `OneWoW_CatalogData_Vendors.lua` | Comment stub (no public globals) |

## Data Layout

Per-expansion Lua shards under `Data/NpcDB/`. Each file calls
`ns:RegisterNpcData`. Classic through Midnight ship.

## Tools (offline / Workspace)

Emit and the warehouse scoreboard live in OneWoW_Workspace (`bin/npc_split.py`,
`bin/catalog_data_status.py`). They are not loaded by the addon TOC.

Static schema and build-time source order: [NPC_DATA.md](NPC_DATA.md).
Workspace pipeline: `Docs/WAREHOUSE_PLAN.md`.
