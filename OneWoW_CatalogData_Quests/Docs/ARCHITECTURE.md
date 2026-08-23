# OneWoW_CatalogData_Quests — Architecture

> **See also:** [Suite architecture](../../OneWoW/Docs/ARCHITECTURE.md) §6 (store access rules)

## Overview

Load-on-demand data store registered with `OneWoW_Catalog` as the `"quests"` provider. Ships static `QuestDB_*` shards and enriches them at runtime via the quest scanner.

**SavedVariable:** `OneWoW_CatalogData_Quests_DB`

**RequiredDeps:** `OneWoW`. **LoadOnDemand:** yes (`## Group: OneWoW_Catalog`).

## Modules

| Module | Role |
|--------|------|
| `Core/QuestDBLoader.lua` | Merges `Data/QuestDB/QuestDB_*.lua` into `ns.ExternalQuestDB` |
| `Modules/QuestData.lua` | Static + runtime merged view for Catalog (lookup, expansion filter) |
| `Modules/QuestScanner.lua` | Live capture from quest log / quest detail events |
| `Modules/CompletionTracker.lua` | Per-character completion; optional AltTracker cross-char |
| `Core/Database.lua` | SavedVariables init |
| `Core/API.lua` | Public API (`GetQuest`, `GetQuestCount`, `GetCompletedCharacters`, …) |
| `Core/Core.lua` | `BootStore` lifecycle; registers with `OneWoW_Catalog_API` |
| `OneWoW_CatalogData_Quests.lua` | Comment stub (no public globals) |

## Data Layout

Per-expansion Lua shards under `Data/QuestDB/`:

Each expansion is one full `QuestDB_*.lua` shard. Shards load through `ns:RegisterQuestData`.

## Tools (offline / Workspace)

Wowhead refresh, shard emit, and BtW campaign-ID harvest live in OneWoW_Workspace (`bin/wowhead/`, `bin/catalog_data_status.py`). They are not loaded by the addon TOC.

Static schema and build-time source order: [QUEST_DATA.md](QUEST_DATA.md).
Workspace pipeline: `Docs/WAREHOUSE_PLAN.md`.
