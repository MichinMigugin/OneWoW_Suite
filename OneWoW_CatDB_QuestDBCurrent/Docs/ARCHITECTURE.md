# OneWoW_CatDB_QuestDBCurrent — Architecture

> **See also:** [Suite architecture](../../OneWoW/Docs/ARCHITECTURE.md) §6 (store access rules)
>
> Catalog pointer: [OneWoW_Catalog/Docs/CATDB.md](../../OneWoW_Catalog/Docs/CATDB.md).
> This is the Catalog Quests store (current expansions).

## Overview

Load-on-demand quest store for **this expansion and the previous one**
(The War Within and Midnight). Classic through Dragonflight live in
`OneWoW_CatDB_QuestDBArchive`. Catalog's pack resolver loads this pack
for the `"quests"` role.

Same row schema as Archive. Pins with an npcID live on NPCDB
(`starts` / `ends` are `{ npcID }` only). Reward identity is ItemDB.

**SavedVariable:** `OneWoW_CatDB_QuestDBCurrent_DB`

**RequiredDeps:** `OneWoW`. **LoadOnDemand:** yes (`## Group: OneWoW_Catalog`).
Catalog marks CatDB packs `lazyStores`.

**Public API:** `OneWoW_CatDB_QuestDBCurrent_API`

Archive load: `EnsureArchiveThen(callback)` →
`OneWoW:EnsureLoaded("OneWoW_CatDB_QuestDBArchive")` when the expansion is
Classic–Dragonflight (or all-quest search). After load, Current imports
Archive rows into this pack's `ns` so Catalog keeps using the Current API.

## Modules

| Module | Role |
|--------|------|
| `Core/DataLoader.lua` | `RegisterQuestData` → `ns.ExternalQuestDB`, `ExternalQuestDBByExpansion`, `QuestsByNPC`, `QuestsByRewardItem` (items, choices, package) |
| `Modules/CompletionTracker.lua` | Per-character completion (`GetCompletedCharacters` `{ key, name }` rows, AltTracker supplement, `QUEST_TURNED_IN`) |
| `Data/Generated/QuestLineMembers.lua` | QuestLine id → ordered quest IDs (all expansions; used by `GetQuestGuideChain`) |
| `Core/Database.lua` | SavedVariables init (`ns.db`, including `completion`) |
| `Core/API.lua` | Public API (`GetQuest`, `GetQuestLineMembers`, `GetQuestsForNPC`, `GetQuestsRewardingItem`, `GetCompletedCharacters`, `EnsureArchiveThen`, …) |
| `Core/Core.lua` | `BootStore` lifecycle (`savedVar`, `onLogin` initializes CompletionTracker) |
| `OneWoW_CatDB_QuestDBCurrent.lua` | Comment stub (no public globals) |

`ns` stays private. Cross-unit callers use the `_API` global only.

## BootStore

```lua
OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
    savedVar = "OneWoW_CatDB_QuestDBCurrent_DB",
    onLogin = function()
        ns.CompletionTracker:Initialize()
    end,
})
```

`InitializeDatabase` runs through BootStore. `GetSettings()` reads
`ns.db.global.settings`.

## Data Layout

Hot shards under `Data/QuestDB/`:

- `QuestDB_warwithin.lua`
- `QuestDB_midnight.lua`

Each file calls `ns:RegisterQuestData`. `QuestLineMembers` loads first.
Emit bakes other overlays (lines, campaigns, objectives, pins) into the
quest rows. Archive does not ship a second copy of Generated.

## Tools (offline / Workspace)

Emit lives in OneWoW_Workspace (`bin/catdb_quest_emit.py` writes **both**
Current and Archive, `bin/catdb_status.py quest`). Not loaded by the addon TOC.

Static schema: [QUEST_DATA.md](QUEST_DATA.md).
Archive load unit: [`OneWoW_CatDB_QuestDBArchive/Docs/ARCHITECTURE.md`](../../OneWoW_CatDB_QuestDBArchive/Docs/ARCHITECTURE.md).
Workspace pipeline: `Docs/WAREHOUSE_PLAN.md`.
