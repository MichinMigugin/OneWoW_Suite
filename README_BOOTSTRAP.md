# OneWoW Quest Catalog / Notes Bootstrap

This file summarizes the current OneWoW quest-catalog and notes integration work. It is meant as a bootstrap handoff for the GitHub fork, not as final user-facing documentation.

## Scope

The current work is concentrated in three addons:

- `OneWoW_Catalog`
- `OneWoW_CatalogData_Quests`
- `OneWoW_Notes`

The goal is to support a large searchable quest database, live in-game quest enrichment, and cross-navigation between Catalog quests and Notes entities such as NPCs and items.

## Major Systems Added Or Reworked

### Quest Data Layer

`OneWoW_CatalogData_Quests` now supports a merged quest-data model:

- Static Wowhead-scraped quest DBs are loaded as the broad source of truth.
- Runtime in-game captures are stored in SavedVariables.
- A generated runtime override file can merge live Blizzard data back over static data during development, but that generated override is not part of the shipped addon payload.
- Runtime data is field-merged instead of replacing whole quest records.
- Bad live captures can self-heal using explicit clear markers for quest giver and turn-in NPC data.

Primary files:

- `OneWoW_CatalogData_Quests/Modules/QuestData.lua`
- `OneWoW_CatalogData_Quests/Modules/QuestScanner.lua`

External development tooling:

- `Merge-SavedVariablesToQuestOverrides.ps1` currently lives outside the shipped addon payload and is expected to be replaced or invoked by AccountSync later.

### Live Quest Scrape / Self-Healing

The in-game quest scanner captures live Blizzard quest data when quests are accepted, scanned from the quest log, and turned in.

Captured/enriched fields include:

- Quest title, description, objectives, and objective details.
- Reward gold, XP, honor/artifact/title/spell/skill surfaces where Blizzard exposes them.
- Reward items, reward choices, reward currencies, currency names/icons, and required money.
- Quest-log special item data where available.
- Quest giver and turn-in NPC IDs/names where reliable.
- Start/end NPC map and coordinate data where available.
- Runtime classification flags such as bounty, task, story, scaling, auto-complete, disabled, on-map, local POI, and campaign ID.

Quest board and Adventure Guide behavior is guarded so selected NPCs are not incorrectly treated as the quest giver for board-sourced quests.
Reload/active quest-log scans refresh quest facts without re-adding deleted quest-giver NPC notes.

### External Merge Script

The PowerShell merge script is a development/review tool, not a file intended to ship inside the addon. It reads the latest `OneWoW_CatalogData_Quests.lua` SavedVariables file and emits generated addon data.

Development-only output:

- `OneWoW_CatalogData_Quests/Data/QuestDB/QuestDB_runtime_overrides.lua`

Supported script behavior includes:

- Optional JSON output.
- Optional backup suppression.
- Optional wait-for-WoW-exit flow.
- Filtering out low-value runtime captures.
- Stripping unsafe passive quest-log coordinates unless tied to a real start/end NPC.

### Catalog Quest UI

The Catalog quest tab has been overhauled around the large DB use case.

Major behavior:

- Quest list is virtualized for large expansion result sets.
- Top filters were simplified to Search, Expansion, Zone, Progress, and Advanced.
- Advanced drawer supports Group, Quest Type, Category, Flag, Profession, Class, Race, Faction, Story, and Runtime filters.
- Faction values normalize `none`, `both`, and `neutral` into a single `Both / Neutral` concept.
- Quest metadata now emphasizes useful player-facing fields: expansion, zone, progress, rewards, faction, category, flag, quest ID, and map ID.
- Quest chains render as clickable linked quest names.
- Map links open the map and set a pin/waypoint where coordinates are available.
- Reward items support Ctrl-click preview.
- Empty live-quest view keeps active quests first and appends saved quest favorites below a separator.

### Search Improvements

Quest search now includes:

- Quest name.
- Quest description.
- Quest objectives.
- Quest ID.
- Quest giver name.
- Quest turn-in NPC name.
- Reward item IDs.
- Cached reward item names from the shared Catalog item cache.

Reward item-name search uses client-cached/shared Catalog item data only. It does not bulk-request item names from Blizzard during the main search loop.

### Notes NPC Integration

Quest giver and turn-in NPC links in the Catalog can add/open NPCs in `OneWoW_Notes`.

NPC integration includes:

- Quest givers are categorized as `Quest Givers`.
- Turn-in NPCs are shown separately where known.
- The Notes NPC tab lists associated quest IDs/names for an NPC.
- Associated quests link back to the Catalog quest details.
- NPC map locations can open the map and place a pin.
- NPC zone display prefers `C_Map.GetMapInfo(mapID).name` over stale stored zone text.

### Shared Item Cache

Quest reward item names are resolved through Catalog's shared `ItemDataLoader`, backed by:

```lua
OneWoW_Catalog_DB.global.itemCache
```

The static quest DBs keep reward items as numeric item IDs only. The shared Catalog item cache supplies localized names/details after the client has learned them, and quest search reads that cache for item-name matching.

The old generated Notes item-name DB path was retired so quest rewards do not ship or maintain a separate item-name database.

### Catalog Item Search / Notes Items Bridge

Catalog Item Search now cross-references known item sources from Catalog systems where available:

- Journal drops.
- Vendors.
- Tradeskills.
- Inventory/owned locations.
- Quest rewards from the quest DB and runtime overrides.

Item details link back to their source areas when possible. Favoriting an item in Catalog Item Search adds it to `OneWoW_Notes > Items`, opens that note, and keeps the item favorite state synchronized with Notes item favorites.

## Data Hygiene Filters

The quest data layer filters or cleans common scrape noise, including:

- DNT-marked quests.
- Nth/internal queue marker quests.
- `[PH]` placeholder quests.
- `[REMOVED]` quests.
- Wowhead chrome text such as `/run print(C_QuestLog.IsQuestFlaggedCompleted(...))`.
- Wowhead helper text such as `Accept this quest to record its description and rewards.`

These filters exist both for display safety and future scraper cleanup guidance.

## Current Development Workflow

1. Use the addon in-game.
2. Let WoW write SavedVariables by logging out or closing the client.
3. Run the external merge script from the development workspace:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "H:\OneWoW Ecosystem Addon Audit\your_working\OneWoW_CatalogData_Quests\Tools\Merge-SavedVariablesToQuestOverrides.ps1"
```

4. Generated quest overrides are updated.
5. Reload/restart WoW to load generated addon files.

For launch, the runtime override path should stay out of the shipped `.toc`; AccountSync can own that merge/self-heal workflow later.

## Future Plans

### AccountSync Integration

The merge script is currently manual. Later it should be called automatically by Ricky's external AccountSync app after WoW closes.

Desired behavior:

- Wait until WoW has fully exited.
- Run the merge script.
- Surface success/failure and counts.
- Eventually support multi-account and multi-locale handling cleanly.

### Notes Item Follow-Up

Current behavior:

- Catalog Item Search can favorite an item and add/open it in Notes Items.
- Notes Items can use Catalog's shared item cache as a fallback for known item names.

Possible follow-up behavior:

- Add name search to Notes Items using the shared Catalog item cache.
- Show matching item names and item IDs.
- Click a result to add it to the personalized Notes item list.

### Ricky's Item Scraper

If/when a Wowhead item scraper is added, it should complement the shared item-cache system:

- Scraper provides broad item coverage and stable numeric item IDs.
- In-game client/cache data provides localized names and live fallback data.
- Notes personal item data remains separate from generated item lookup data.

### Formal Generated Data Versioning

Generated DB files should eventually include schema/version markers so future migrations can be explicit.

### Scraper Follow-Up

The Wowhead quest scraper should eventually be updated to avoid emitting known noise at source:

- DNT.
- Nth/internal queue markers.
- `[PH]`.
- `[REMOVED]`.
- Wowhead helper/chrome text.

Runtime filters should remain as a defensive layer even after scraper cleanup.

## Notes For Contributors

- Lua target is Blizzard's retail WoW Lua environment, effectively Lua 5.1 with Blizzard API constraints.
- Avoid heavy work inside search/filter loops.
- Prefer cached/generated lookup tables over live API calls when searching large DBs.
- Keep static DBs numeric-first where possible for localization and size.
- Treat SavedVariables as a runtime learning layer, not the only source of truth.
- Generated files should be clearly marked and safe to overwrite.
