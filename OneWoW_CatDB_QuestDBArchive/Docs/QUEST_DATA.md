# CatDB Quests (archive) — data rules

Runtime rules for `OneWoW_CatDB_QuestDBArchive`. **Same schema** as
Current — do not fork the row shape.

Full field list, IDs-only rules, and emit command:
[`OneWoW_CatDB_QuestDBCurrent/Docs/QUEST_DATA.md`](../../OneWoW_CatDB_QuestDBCurrent/Docs/QUEST_DATA.md).

Load-unit wiring: [`ARCHITECTURE.md`](ARCHITECTURE.md).

This is the Catalog Quest Archive store.

## What it owns

Classic through Dragonflight (`QuestDB_classic.lua` …
`QuestDB_dragonflight.lua`, expansions **0–9**, `LE_EXPANSION_*`).

Current (TWW + Midnight) is a different TOC so old expansions stay
unparsed until Catalog asks for them.

## IDs only

Same as Current: npc pins live on NPCDB; reward identity lives on ItemDB;
object / area starts keep coords on the quest.

## Build (Workspace)

```bash
# from OneWoW_Workspace — writes Current and Archive
python bin/catdb_quest_emit.py
python bin/catdb_status.py quest
python bin/catdb_contribute_merge.py --from EXPORT
```
