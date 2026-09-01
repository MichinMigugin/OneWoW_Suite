# CatDB packs

Six `OneWoW_CatDB_*` load units are the Catalog databases: Zones, NPCs,
Items, Quests (Current / Archive), and Tradeskills.

`PackResolver` always loads these packs.

**Rule:** one home per fact. Everyone else stores IDs.

| Pack | Catalog role | Docs |
|------|--------------|------|
| `OneWoW_CatDB_ZoneDB` | `journal` / `zones` | [ARCHITECTURE](../../OneWoW_CatDB_ZoneDB/Docs/ARCHITECTURE.md) · [ZONE_DATA](../../OneWoW_CatDB_ZoneDB/Docs/ZONE_DATA.md) |
| `OneWoW_CatDB_NPCDB` | `vendors` / `npcs` | [ARCHITECTURE](../../OneWoW_CatDB_NPCDB/Docs/ARCHITECTURE.md) · [NPC_DATA](../../OneWoW_CatDB_NPCDB/Docs/NPC_DATA.md) |
| `OneWoW_CatDB_ItemDB` | `items` | [ARCHITECTURE](../../OneWoW_CatDB_ItemDB/Docs/ARCHITECTURE.md) · [ITEM_DATA](../../OneWoW_CatDB_ItemDB/Docs/ITEM_DATA.md) |
| `OneWoW_CatDB_QuestDBCurrent` | `quests` | [ARCHITECTURE](../../OneWoW_CatDB_QuestDBCurrent/Docs/ARCHITECTURE.md) · [QUEST_DATA](../../OneWoW_CatDB_QuestDBCurrent/Docs/QUEST_DATA.md) |
| `OneWoW_CatDB_QuestDBArchive` | `archive` | [ARCHITECTURE](../../OneWoW_CatDB_QuestDBArchive/Docs/ARCHITECTURE.md) · [QUEST_DATA](../../OneWoW_CatDB_QuestDBArchive/Docs/QUEST_DATA.md) |
| `OneWoW_CatDB_TradeSkillDB` | `tradeskills` | [ARCHITECTURE](../../OneWoW_CatDB_TradeSkillDB/Docs/ARCHITECTURE.md) · [TRADESKILL_DATA](../../OneWoW_CatDB_TradeSkillDB/Docs/TRADESKILL_DATA.md) |

Public APIs are `OneWoW_CatDB_<Pack>_API` (`GetPlace`, `GetNPC`, `GetItem`,
`GetAchievementsForItem`, `GetQuest`, `GetRecipe`, …). `ns` stays private.

Emit and scoreboard live in OneWoW_Workspace (`bin/catdb_*_emit.py`,
`bin/catdb_status.py`). They write only `OneWoW_CatDB_*` Data files.
