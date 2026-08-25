# Catalog Quests — data rules

Runtime rules for `OneWoW_CatalogData_Quests` and how static shards are built.
Build-time source order lives in OneWoW_Workspace
[`Docs/WAREHOUSE_PLAN.md`](../../../Docs/WAREHOUSE_PLAN.md).

Load-unit wiring: [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Layers

1. **Static shards** — Hot pack `Data/QuestDB/QuestDB_*.lua` (this expansion and
   the previous one) plus Quest Archive (`OneWoW_CatalogData_Quests_Archive`,
   Classic through Dragonflight). Both merge into `ns.ExternalQuestDB` via
   `RegisterQuestData` / `ImportQuestData`.
2. **Generated overlays** — `Data/Generated/*.lua` from Wago CSVs plus the
   warehouse clone. `Apply.lua` fills holes only (never replaces a pin that
   already has coordinates). Runs again after Archive import.
3. **Live scanner** — `QuestScanner` heals text, giver, and turn-in from the
   quest log / quest frame as the player plays. It does not invent quest IDs
   for the shipped DB, and it does not persist live objective progress
   (`finished` / `numFulfilled`). Overlay `C_QuestLog.GetQuestObjectives` only
   while the player is on the quest.

Completion is a separate SavedVariables track (`CompletionTracker`), optional
cross-alt via AltTracker.

## What ships

Every expansion ships a full `QuestDB_*.lua` shard (Classic through Midnight).
The War Within and Midnight load with the hot pack. Classic through Dragonflight
load from Quest Archive when you browse those expansions, search all quests, or
look up quest rewards. Shards load through `ns:RegisterQuestData`.

## Schema

One keyed row per quest. Field order is `QUEST_KEY_ORDER` in
OneWoW_Workspace `bin/lib/wowhead/quest_lua.py`.

| Group | Keys | Source today |
| --- | --- | --- |
| Identity | `id`, `name`, `expansion`, `questType`, `categories`, `flags` | Wowhead list + detail |
| Lore / text | `description`, `objectivesText`, `objectives`, `objectiveDetails` | Wowhead; scanner overlay (no live progress) |
| Objectives (static) | `db2Objectives` (`text`, `type`, `objectID`, `amount`, `orderIndex`) | Generated from `QuestObjective` |
| Giver / turn-in | `starts[]`, `ends[]` (`npcID`, `mapID`, `x`, `y`), `questGiverID/Name`, `questTurnInID/Name` | Wowhead + overlay pins + scanner. Overlay never overwrites an existing xy pin. |
| Location | `zoneID`, `mapID`, `coords`, `mapCandidates` | Wowhead / pins / `QuestPOIBlob` UiMap fallback |
| Chains | `storyline[]`, `series[]`, `questLines[]`, `campaigns[]`, `sourceQuests[]`, `nextQuests[]` | Wowhead storyline/series; Generated lines/campaigns; warehouse source/next |
| Rewards | `rewardGold`, `rewardXP`, `rewardItems`, `rewardChoices`, `rewardCurrencies` | Wowhead / scanner / warehouse `qis` fill |

Quest “tracks” in Catalog are pin + chain IDs. `GetQuestGuideChain` returns an
ordered ID list from the quest line, else storyline, else series, else
source/next. Nil when the chain has fewer than two quests. Map blobs
(`QuestPOIPoint`) are not dumped; only the quest-level `QuestPOIBlob` UiMapID
is stored as a fallback.

`GetQuest` returns static ⊕ runtime SV. Display hygiene drops DNT / NYI /
REMOVED rows.

## Lazy hydrate

The list and filter walk use static shard fields only: name, expansion, zone,
flags, categories, and reward **IDs**. They must not call `C_QuestLog` completion
APIs, `GetItemInfo`, tooltip hyperlinks, or `RequestLoadQuestByID`.

The left list then shows at most 25 rows with no filters, or 50 when a filter is
on. The status bar reports `showing / total (limit)` when more matches exist.

Picking an expansion with no other filters copies the cached sorted source for
that shard. It does not re-walk every quest applying include checks.

Completion and warband filters are the Quests equivalent of Journal "Has
uncollected": they need live client state, so they run as `OneWoW.ChunkedJob`
and publish matches as they arrive.

Detail open stays Instant-only for items (`GetItemInfoInstant` plus the Catalog
item cache). `LoadItemData` / `RequestLoadQuestByID` / NPC tooltip scans run
only for **visible** rows, with a fill token or render-version guard. Never
`GetItemInfo` or `GetTooltipItemName` on the click frame.

Journal's matching rules: [`JOURNAL_DATA.md`](../../OneWoW_CatalogData_Journal/Docs/JOURNAL_DATA.md)
§ Lazy hydrate. Visible-row fill: Catalog `ns.FillVisibleItem`.

## Build (Workspace)

```bash
# from OneWoW_Workspace
python bin/quest_db2_tools.py generate
python bin/catalog_data_status.py quests
python bin/wowhead/quest-refresh.py status --expansions all
```

`quest_db2_tools.py generate` writes `Data/Generated/` for every expansion in
one pass (lines, campaigns, objectives, pins), **tidies** shards (one quest ID
in one expansion file), and bakes overlays into those shards. Hole-fill only:
existing Wowhead pins and text stay. Runtime `Apply.lua` still fills leftover
holes after a Wowhead merge that has not been generated yet.

## Sparse rows (keep them)

A sparse row is a **real named quest** that is missing a giver/turn-in pin, or
missing lore text, or both. Wowhead list pages and client DB2 still gave an ID,
name, rewards, and often a quest line. They did not give the blurb or the NPC
dot. Catalog still uses that row for search, reward lookup, chains, and
completion. The live scanner fills pins and text when the player opens the
quest. Do **not** drop sparse named rows to save zip size; they are the index,
not wasted padding. Display hygiene already hides DNT / NYI / REMOVED /
tracking names. Unnamed QuestV2 IDs are not shipped.

## Wowhead leftover fill (backwards)

Pull **one expansion at a time**, newest unfinished first, down to Classic.
Do not start the next expansion until the current one has `merge` + `generate`.
**In progress: Battle for Azeroth** (first full leftover `run`). Then: Legion
→ Warlords of Draenor → Mists of Pandaria → Cataclysm → Wrath of the Lich King
→ Burning Crusade → Classic.

Done:

- Midnight leftover (`--only-new` / `--only-sparse`); leftover `need` is Wowhead-blank
- The War Within leftover; leftover `need` is Wowhead-blank
- Dragonflight first full `run` (discover + fetch + merge)
- Shadowlands first full `run`; leftover `need` is Wowhead-blank

From OneWoW_Workspace. Local `quest-refresh.py` only (Grok Bot: ask first).

```bash
# Remaining after Battle for Azeroth
python bin/wowhead/quest-refresh.py run --expansions legion
python bin/quest_db2_tools.py generate

python bin/wowhead/quest-refresh.py run --expansions wod
python bin/quest_db2_tools.py generate

python bin/wowhead/quest-refresh.py run --expansions mop
python bin/quest_db2_tools.py generate

python bin/wowhead/quest-refresh.py run --expansions cata
python bin/quest_db2_tools.py generate

python bin/wowhead/quest-refresh.py run --expansions wotlk
python bin/quest_db2_tools.py generate

python bin/wowhead/quest-refresh.py run --expansions bc
python bin/quest_db2_tools.py generate

python bin/wowhead/quest-refresh.py run --expansions classic
python bin/quest_db2_tools.py generate

python bin/catalog_data_status.py quests
python bin/wowhead/quest-refresh.py status --expansions all
```

`run` is discover + fetch + merge. Merge tidies shards so leaked IDs are not
left in two files. `generate` bakes client overlays and tidies again.

Scoreboard: `python bin/wowhead/quest-refresh.py status --expansions all`
(`new` / `need` columns). A leftover pass is done when `new` is 0 and `need`
stops falling (remaining `need` is Wowhead-blank, not unfetched).

**Grok Bot is optional — ask before using it.** Cache:
Workspace `.warehouse/Sources/WowHead/quests/README.md`.

Tidy without generate: `python bin/wowhead/quest-tidy.py`.

BtW campaign IDs: `bin/wowhead/btw-campaign-ids.py` writes
`bin/wowhead/data/btw-campaign-ids.json`. Pin fill:
`bin/wowhead/fill-btw-pins.py` (never overwrites an existing pin).

Wowhead cache is `.warehouse/Sources/WowHead/quests/` (gitignored). Merge **never drops**
existing giver/turn-in pins or text when Wowhead is blank.

Build order:

1. Generated overlays (Wago CSVs + warehouse clone)
2. Wowhead lore text and leftover pins (per expansion)
3. Live scanner heals while playing

BtWQuests is a temporary harvest, not an authority.

## Runtime capture

`QuestScanner` listens to quest-detail / progress / complete / accepted and
the quest log. Giver and turn-in use `UnitGUID`, not another addon. Bad
static NPC names are cleared (`questGiverCleared` / `questTurnInCleared`)
instead of kept stale.

## Related

- Warehouse scoreboard: `python bin/catalog_data_status.py all`
- Journal cards that link here: `JOURNAL_DATA.md` (quest-loot “View Quest”)
