# CatDB packs

Six `OneWoW_CatDB_*` load units are the Catalog databases: Zones, NPCs,
Items, Quests (Current / Archive), and Tradeskills.

Older `OneWoW_CatalogData_*` packs (Journal, Vendors, Quests, Archive,
Tradeskills) may still ship as leftover folders. `PackResolver` always
loads CatDB. Do not delete leftover folders until cutover (see
[CATDB_CUTOVER.md](CATDB_CUTOVER.md)).

**Rule:** one home per fact. Everyone else stores IDs.

| Pack | Catalog role | Leftover pack (until removed) | Docs |
|------|--------------|-------------------------------|------|
| `OneWoW_CatDB_ZoneDB` | `journal` / `zones` | `OneWoW_CatalogData_Journal` | [ARCHITECTURE](../../OneWoW_CatDB_ZoneDB/Docs/ARCHITECTURE.md) · [ZONE_DATA](../../OneWoW_CatDB_ZoneDB/Docs/ZONE_DATA.md) |
| `OneWoW_CatDB_NPCDB` | `vendors` / `npcs` | `OneWoW_CatalogData_Vendors` | [ARCHITECTURE](../../OneWoW_CatDB_NPCDB/Docs/ARCHITECTURE.md) · [NPC_DATA](../../OneWoW_CatDB_NPCDB/Docs/NPC_DATA.md) |
| `OneWoW_CatDB_ItemDB` | `items` | cited identity + `ItemAchievements` | [ARCHITECTURE](../../OneWoW_CatDB_ItemDB/Docs/ARCHITECTURE.md) · [ITEM_DATA](../../OneWoW_CatDB_ItemDB/Docs/ITEM_DATA.md) |
| `OneWoW_CatDB_QuestDBCurrent` | `quests` | `OneWoW_CatalogData_Quests` | [ARCHITECTURE](../../OneWoW_CatDB_QuestDBCurrent/Docs/ARCHITECTURE.md) · [QUEST_DATA](../../OneWoW_CatDB_QuestDBCurrent/Docs/QUEST_DATA.md) |
| `OneWoW_CatDB_QuestDBArchive` | `archive` | `OneWoW_CatalogData_Quests_Archive` | [ARCHITECTURE](../../OneWoW_CatDB_QuestDBArchive/Docs/ARCHITECTURE.md) · [QUEST_DATA](../../OneWoW_CatDB_QuestDBArchive/Docs/QUEST_DATA.md) |
| `OneWoW_CatDB_TradeSkillDB` | `tradeskills` | `OneWoW_CatalogData_Tradeskills` | [ARCHITECTURE](../../OneWoW_CatDB_TradeSkillDB/Docs/ARCHITECTURE.md) · [TRADESKILL_DATA](../../OneWoW_CatDB_TradeSkillDB/Docs/TRADESKILL_DATA.md) |

Public APIs are `OneWoW_CatDB_<Pack>_API` (`GetPlace`, `GetNPC`, `GetItem`,
`GetAchievementsForItem`, `GetQuest`, `GetRecipe`, …). `ns` stays private.

Emit and scoreboard live in OneWoW_Workspace (`bin/catdb_*_emit.py`,
`bin/catdb_status.py`). They write only `OneWoW_CatDB_*` Data files.

Entity counts, caller scan, and the 100% cutover plan (leftover packs
still on disk): [CATDB_CUTOVER.md](CATDB_CUTOVER.md).
