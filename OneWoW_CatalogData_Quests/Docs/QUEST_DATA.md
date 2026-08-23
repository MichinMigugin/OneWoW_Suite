# Catalog Quests — data rules

Runtime rules for `OneWoW_CatalogData_Quests` and how static shards are built.
Build-time source order lives in OneWoW_Workspace
[`Docs/WAREHOUSE_PLAN.md`](../../../Docs/WAREHOUSE_PLAN.md).

Load-unit wiring: [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Two layers

1. **Static shards** — `Data/QuestDB/QuestDB_*.lua` merged into
   `ns.ExternalQuestDB`. Wowhead-derived today. DB2 `QuestV2` / `QuestPOIBlob`
   are now in `.warehouse/Sources/Wago/`; generators that emit from them are not written yet.
   ATT quest rows would come from `.warehouse/Sources/ATT` (not dumped as a second file).
2. **Live scanner** — `QuestScanner` heals text, giver, and turn-in from the
   quest log / quest frame as the player plays. It does not invent quest IDs
   for the shipped DB.

Completion is a separate SavedVariables track (`CompletionTracker`), optional
cross-alt via AltTracker.

## What ships

Every expansion ships a full `QuestDB_*.lua` shard (Classic through Midnight).
Late registers still go through
`OneWoW_CatalogData_Quests_API.RegisterQuestData`.

## Schema

One keyed row per quest. Field order is `QUEST_KEY_ORDER` in
OneWoW_Workspace `bin/lib/wowhead/quest_lua.py`.

| Group | Keys | Source today |
| --- | --- | --- |
| Identity | `id`, `name`, `expansion`, `questType`, `categories`, `flags` | Wowhead list + detail |
| Lore / text | `description`, `objectivesText`, `objectives`, `objectiveDetails` | Wowhead; scanner overlay |
| Giver / turn-in | `starts[]`, `ends[]` (`npcID`, `mapID`, `x`, `y`), `questGiverID/Name`, `questTurnInID/Name` | Wowhead + BtW pins + scanner. Not a complete client table. |
| Location | `zoneID`, `mapID`, `coords`, `mapCandidates` | Wowhead / pins |
| Chains | `storyline[]`, `series[]` | Wowhead. Not a route polyline. |
| Rewards | `rewardGold`, `rewardXP`, `rewardItems`, `rewardChoices`, `rewardCurrencies` | Wowhead / scanner |

Quest “tracks” in Catalog are pin + chain IDs. Map blobs (`QuestPOI`,
`QuestPOIBlob`, `QuestPOIPoint`) are listed as No in
`.warehouse/Sources/Wago/docs/available-data.md` and are not generated yet.

`GetQuest` returns static ⊕ runtime SV. Display hygiene drops DNT / NYI /
REMOVED rows.

## Build (Workspace)

```bash
# from OneWoW_Workspace
python bin/catalog_data_status.py quests
python bin/wowhead/quest-refresh.py status --expansions all
python bin/wowhead/quest-refresh.py run --expansions midnight --only-new
python bin/wowhead/quest-split.py emit --expansions all
```

BtW campaign IDs: `bin/wowhead/btw-campaign-ids.py` writes
`bin/wowhead/data/btw-campaign-ids.json`. Pin fill:
`bin/wowhead/fill-btw-pins.py` (never overwrites an existing pin).

Wowhead cache is `.warehouse/Sources/WowHead/quests/` (gitignored). Merge **never drops**
existing giver/turn-in pins or text when Wowhead is blank.

Intended build order once DB2 quest tables are pulled:

1. DB2 IDs / flags / lines / POI
2. ATT providers / coords (`.warehouse/Sources/ATT`, not generated yet)
3. Wowhead lore text and leftover pins
4. Live scanner heals while playing

BtWQuests is a temporary harvest, not an authority.

## Runtime capture

`QuestScanner` listens to quest-detail / progress / complete / accepted and
the quest log. Giver and turn-in use `UnitGUID`, not another addon. Bad
static NPC names are cleared (`questGiverCleared` / `questTurnInCleared`)
instead of kept stale.

## Related

- Warehouse scoreboard: `python bin/catalog_data_status.py all`
- Journal cards that link here: `JOURNAL_DATA.md` (quest-loot “View Quest”)
