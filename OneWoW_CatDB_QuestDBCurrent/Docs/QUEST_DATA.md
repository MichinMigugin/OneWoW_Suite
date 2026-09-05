# CatDB Quests (current) — data rules

Runtime rules for `OneWoW_CatDB_QuestDBCurrent` and how hot QuestDB shards
are built. Archive (Classic–Dragonflight) uses the **same schema**:
[`OneWoW_CatDB_QuestDBArchive/Docs/QUEST_DATA.md`](../../OneWoW_CatDB_QuestDBArchive/Docs/QUEST_DATA.md).

Build-time source order lives in OneWoW_Workspace
[`Docs/WAREHOUSE_PLAN.md`](../../../Docs/WAREHOUSE_PLAN.md).

Load-unit wiring: [`ARCHITECTURE.md`](ARCHITECTURE.md).

This is the Catalog Quests store (current expansions).

## One home

QuestDB owns **quest text, chains, and reward IDs**. Giver / turn-in pins
with an npcID live on NPCDB. Reward item identity lives on ItemDB.

| Fact | Home | On the quest row |
|------|------|------------------|
| NPC pin / look | NPCDB | `starts[]` / `ends[]` = `{ npcID }` |
| Object / area start | this pack | `startObjects` / `endObjects` / `coords` |
| Item identity | ItemDB | `rewardItems`, `rewardChoices`, `packageItems` |
| Place lore | ZoneDB | `mapID`, `zoneID` (IDs only) |

Kill `objectID` on `db2Objectives` is a creature or object ID — NPC rows
still live in NPCDB when the ID is a creature.

## What it owns

This expansion + previous (The War Within and Midnight). All current
Catalog quest fields stay, plus:

- Vignette tracking / reward quests (hidden rare-kill IDs)
- `QuestPackageItem` holes (`packageItems`)
- Quest sort / info names on the row (`db2QuestInfoID` / `db2QuestSortName`)
- Campaign lock text (`campaignLockText`, per-campaign `stallText`)
- World-task titles (`worldTaskTitle`)

UI can hide DNT / NYI. Remix-only stays out. Sparse named rows stay (same
rule as Catalog Quests).

Expansion IDs match `LE_EXPANSION_*` (Classic = 0, TWW = 10, Midnight = 11).

## IDs only

`starts` / `ends` with an npcID drop map xy — that pin is on NPCDB.
`rewardItems` / `rewardChoices` are itemIDs. `questLines` / `campaigns` /
`sourceQuests` / `nextQuests` are IDs (plus titles already on the row for
offline list paint).

## Schema

One keyed row per quest. Field order is `QUEST_KEY_ORDER` in
OneWoW_Workspace `bin/lib/wowhead/quest_lua.py`, then leftover keys
(`startObjects`, `db2Objectives`, `worldTaskTitle`, …).

| Group | Keys |
| --- | --- |
| Identity | `id`, `name`, `expansion`, `questType`, `categories`, `flags`, `level`, `requiredLevel`, `faction`, `sharable` |
| Lore / text | `description`, `objectivesText`, `objectives`, `objectiveDetails`, `worldTaskTitle` |
| Objectives (static) | `db2Objectives` (`text`, `type`, `objectID`, `amount`, `orderIndex`) |
| Giver / turn-in | `starts[]` / `ends[]` (`{ npcID }` only); `startObjects` / `endObjects` (`objectID`, `mapID`, `x`, `y`); `questGiverID` (no baked NPC names) |
| Location | `zoneID`, `mapID`, `coords`, `mapCandidates`, `db2PoiMapID`, `db2PoiUiMapID` |
| Chains | `storyline[]`, `series[]`, `questLines[]`, `campaigns[]`, `sourceQuests[]`, `nextQuests[]`, `campaignLockText` |
| Rewards | `rewardGold`, `rewardXP`, `rewardItems`, `rewardChoices`, `rewardCurrencies`, `packageItems` |
| Start item | `startItems` (itemIDs; identity in ItemDB) |

## Build (Workspace)

One command writes Current **and** Archive:

```bash
# from OneWoW_Workspace
python bin/catdb_quest_emit.py
python bin/catdb_status.py quest
python bin/catdb_contribute_merge.py --from EXPORT
```

Splits npc pins onto `{ npcID }`, keeps object/area starts as
`startObjects`.

Live dialog capture writes `global.learned` and sets `sync = true` when
the quest or its text / givers / rewards are new. CompSync Contribute
reads those rows only. See [CATDB_CONTRIBUTE](../../OneWoW/Docs/CATDB_CONTRIBUTE.md).
