# OneWoW_CatalogData_Quests — Architecture

> **See also:** [Suite architecture](../../OneWoW/Docs/ARCHITECTURE.md) §6 (store access rules)

## Overview

Load-on-demand data store registered with `OneWoW_Catalog` as the `"quests"` provider. Ships static `QuestDB_*` shards for this expansion and the previous one, and pulls Classic through Dragonflight from Quest Archive era packs on demand.

**SavedVariable:** `OneWoW_CatalogData_Quests_DB`

**RequiredDeps:** `OneWoW`. **LoadOnDemand:** yes (`## Group: OneWoW_Catalog`). Catalog marks these packs `lazyStores`: they parse when you open the Quests tab (or on a quest event / Item Search quest source), not at login.

## Modules

| Module | Role |
|--------|------|
| `Core/QuestDBLoader.lua` | Merges `Data/QuestDB/QuestDB_*.lua` into `ns.ExternalQuestDB` |
| `Data/Generated/*.lua` | Overlay tables from `bin/quest_db2_tools.py`; generate also bakes them into QuestDB shards; `Apply.lua` fills leftover holes (again after Archive import) |
| `Modules/QuestData.lua` | Static + runtime merged view for Catalog (lookup, expansion filter, `GetQuestGuideChain`) |
| `Modules/QuestScanner.lua` | Live capture from quest log / quest detail events |
| `Modules/CompletionTracker.lua` | Per-character completion; optional AltTracker cross-char |
| `Core/Database.lua` | SavedVariables init |
| `Core/API.lua` | Public API (`GetQuest`, `GetQuestCount`, `GetCompletedCharacters`, …) |
| `Core/Core.lua` | `BootStore` lifecycle; registers with `OneWoW_Catalog_API` |
| `OneWoW_CatalogData_Quests.lua` | Comment stub (no public globals) |

## Data Layout

Per-expansion Lua shards under `Data/QuestDB/`:

Each expansion is one full `QuestDB_*.lua` shard. The War Within and Midnight live in this addon. Classic through Dragonflight live in Quest Archive era packs (`OneWoW_CatalogData_Quests_Archive_*`) and import through `OneWoW_CatalogData_Quests_API.ImportQuestData`. Catalog loads one era when you pick that expansion (or every era across frames when you search all quests). `quest_db2_tools.py generate` tidies shards (one quest ID per expansion), then bakes overlays into them (hole-fill only). Runtime `Apply.lua` still fills leftover holes after a Wowhead merge that has not been generated yet, including after Archive import.

## Tools (offline / Workspace)

Wowhead refresh, shard emit, Generated overlays (`bin/quest_db2_tools.py`), and BtW campaign-ID harvest live in OneWoW_Workspace (`bin/wowhead/`, `bin/catalog_data_status.py`). They are not loaded by the addon TOC.

Static schema and build-time source order: [QUEST_DATA.md](QUEST_DATA.md).
Workspace pipeline: `Docs/WAREHOUSE_PLAN.md`.
