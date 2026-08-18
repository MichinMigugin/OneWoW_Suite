# DB2 data you can pull (Catalog lookup)

Browse this when you want a Catalog detail later. Each line is **what the player
would see**, then the **Wago table**, then whether that CSV is already in
[`.wow_db2/`](../).

**Have** = file is in the repo now (build pin in [`README.md`](../README.md)).
**No** = not extracted yet. Fetch from
`https://wago.tools/db2/<TableName>/csv?build=<pin>` only when a generator
needs it.

Wago has 1,000+ tables. This list is the Catalog-useful set, not every table.

---

## Instances (Adventure Guide cards)

- **Name / map / flags** — `JournalInstance` — Have
- **Lore blurb** — `JournalInstance.Description_lang` — Have (same table; not shown in Catalog yet)
- **Button / background / lore art** — `JournalInstance` file-data IDs — Have
- **Which cards exist per expansion** — `JournalTier` + `JournalTierXInstance` — Have
- **World entrance pin** — `JournalInstanceEntrance` — Have
- **Queue / meeting-stone pin** — `JournalInstanceQueueLoc` — Have
- **Area the instance sits in** — `JournalInstance.AreaID` → `AreaTable` — Instance side Have; `AreaTable` No
- **Covenant / special lock** — `JournalInstance.CovenantID` — Have (column only)

## Encounters (bosses)

- **Boss name / order / instance** — `JournalEncounter` — Have
- **Boss lore blurb** — `JournalEncounter.Description_lang` — Have (not shown in Catalog yet)
- **In-instance map pin** — `JournalEncounter` Map_0/Map_1 + `JournalEncounterXMapLoc` — Have
- **UiMap for the pin** — `JournalEncounter.UiMapID` / `JournalEncounterXMapLoc.UiMapID` — Have
- **Which difficulties the boss is on** — `JournalEncounterXDifficulty` — Have
- **Creature model / portrait** — `JournalEncounterCreature` — Have
- **Combat kill-credit ID** — `JournalEncounter.DungeonEncounterID` → `DungeonEncounter` — Have
- **Mechanic writeups** (abilities, phases) — `JournalEncounterSection` — Have
- **Which difficulties a mechanic shows on** — `JournalSectionXDifficulty` — Have

## Loot (Encounter Journal only)

- **Curated boss loot list** — `JournalEncounterItem` — Have
- **Loot per difficulty** — `JournalItemXDifficulty` — Have
- **Season stamp on a journal item** — `JournalEncounterItem.DisplaySeasonID` → `DisplaySeason` — Have
- **Faction-only journal loot** — `JournalEncounterItem.FactionMask` — Have
- **Live current-character loot** — not a CSV; in-game `C_EncounterJournal` (`EJLiveLoot`) — n/a
- **World / zone / rare / trash drop tables** — **not in client DB2** (server-side). Stay on ATT / Wowhead / play.

## Difficulties and maps

- **Valid difficulties for a map** — `MapDifficulty` — Have
- **Difficulty names / max players** — `Difficulty` — Have
- **“Why this difficulty is locked” text** — `MapDifficultyXCondition` — Have
- **UiMap names / hierarchy** — `UiMap` — No
- **Continent / zone map** — `Map` — No
- **Area names** — `AreaTable` — No

## Seasons and upgrade tracks

- **Season dictionary** (M+ season number, expansion ordinal) — `DisplaySeason` — Have
- **Upgrade-track bonus-list groups** (`#midnights1`, …) — `ItemBonusListGroup` + `ItemBonusListGroupEntry` — Have
- **Bonus-list contents** — `ItemBonusList` / `ItemBonus` — No
- **Holidays / calendar events** — `Holidays` + `HolidayNames` — No

## Quests

- **Quest id / flags / type** — `QuestV2` — No
- **Quest title / log text** — `QuestV2` lang fields (often thin; live scanner still wins) — No
- **Objectives** — `QuestObjective` — No
- **World-quest / task wrapper** — `QuestV2CliTask` — No
- **Reward package items** — `QuestPackageItem` — No
- **Quest line (chapter list)** — `QuestLine` + `QuestLineXQuest` — No
- **Campaign title / order** — `Campaign` + `CampaignXQuest` — No
- **Campaign lock text** — `CampaignXCondition` — Have
- **Map POI / blob / points** — `QuestPOI` + `QuestPOIBlob` + `QuestPOIPoint` — No
- **Quest giver / turn-in NPC + x,y** — not a complete client table. Wowhead + live scanner.
- **Quest sort / category label** — `QuestSort` + `QuestInfo` — No

## Conditions (is this visible / available)

- **Player-condition rules** — `PlayerCondition` — Have
- **Global condition sets** — `GlobalPlayerCondition` + `GlobalPlayerConditionSet` — Have
- **Area gated by a condition** — `AreaConditionalData` — Have
- **Evaluating those rules in-addon** — not built yet (shared-contract work)

## Items, vendors, professions (Catalog tabs, later)

- **Item name / quality / class** — `ItemSparse` + `Item` — No (large)
- **Vendor inventory** — `NpcVendor` / related — No (incomplete vs live merchant scan)
- **Recipes / reagents** — `SkillLineAbility` + `SpellReagents` + `CraftingData*` — No
- **Currency names** — `CurrencyTypes` — No

## Achievements (future group)

- **Achievement name / description** — `Achievement` — No
- **Criteria** — `Criteria` + `CriteriaTree` — No
- **Dungeon / raid criteria link** — often via MapID / encounter IDs you already have

## NPCs and world content (limited)

- **Creature name / type** — `Creature` + `CreatureDisplayInfo` — No
- **Spawn positions** — incomplete in client; not a drop-in “where is this rare”
- **Vignettes / rare portraits** — `Vignette` — No
- **Treasures / objects** — `GameObjects` — No (still no loot table)

---

## How to use this later

1. Pick the **bullet** (e.g. Instances → Lore).
2. If it says **Have**, the CSV is already here. Add a generator that emits compact Lua. Do not ship the CSV in the addon.
3. If it says **No**, download that one table from Wago, drop it in `.wow_db2/`, add `docs/<group>.md`, then generate.
4. Do not bulk-download the rest of Wago into git.
