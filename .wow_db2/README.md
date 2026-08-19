# `.wow_db2` — client DB2 extracts

Hand-extracted **World of Warcraft Retail** DB2 tables (CSV), used by offline
tools such as [`bin/journal_db2_tools.py`](../bin/journal_db2_tools.py) and
[`bin/season_bonus_list_ids.py`](../bin/season_bonus_list_ids.py). This is
**not** FrameXML and is **not** synced by `refresh_wow_docs.py`.

## Build

**`12.1.0.69382`**

Bump this string whenever you replace CSVs with a newer client extract.

## Layout

CSVs live **flat** in this folder (easy drop-in from an extractor). Model-group
docs live under [`docs/`](docs/):

| Group | Doc | Tables (examples) |
| --- | --- | --- |
| Catalog lookup (have / not have) | [`docs/available-data.md`](docs/available-data.md) | What each feature uses, and whether the CSV is already here |
| Journal (EJ) | [`docs/journal.md`](docs/journal.md) | `Journal*`, `MapDifficulty*`, `Difficulty`, `DungeonEncounter` |
| Achievements + delves | [`docs/achievements.md`](docs/achievements.md) | `Achievement`, `Achievement_Category`, `Map`, `AreaPOI` |
| Item bonus seasons | [`docs/item-bonus-seasons.md`](docs/item-bonus-seasons.md) | `ItemBonusListGroup`, `ItemBonusListGroupEntry`, `DisplaySeason` |
| Conditions (shared) | *(cross-links only for now)* | `PlayerCondition`, `*XCondition`, `GlobalPlayerCondition*` |

`Map` / `AreaPOI` / `Achievement*` in this drop are Wago **`12.1.0.69273`**
(same 12.1.0 patch; Wago `69382` CSV returned 500). Re-pull those four when a
matching pin build is available.

## Cross-model notes

- **Journal → Conditions:** `JournalTier.PlayerConditionID`,
  `JournalTierXInstance.AvailabilityCondition`, and
  `MapDifficultyXCondition` reference player-condition tables. Catalog Journal
  does **not** evaluate these in-addon yet.
- **Journal ↔ Map:** `JournalInstance.MapID` aligns with `MapDifficulty.MapID`.
- **Achievements ↔ Map:** dungeon/raid `Achievement.Instance_ID` is `Map.ID`.
  Delve achievements are `Instance_ID = -1`; join by `{MapName} Stories` /
  `Discoveries`. Delve doors are `AreaPOI` rows on the continent `Map`.
- **Journal ↔ Combat:** `JournalEncounter.DungeonEncounterID` → `DungeonEncounter`.
- **Item bonus seasons:** `DisplaySeason` is a season dictionary only — it does
  **not** join to `ItemBonusListGroup`. PvE track list IDs are generated from a
  curated group map; see [`docs/item-bonus-seasons.md`](docs/item-bonus-seasons.md).

## Refreshing extracts

1. Export the needed `.db2` tables from the client for the build you care about.
2. Drop/replace the CSVs here (semicolon-delimited headers matching current
   files).
3. Update the **Build** line above.
4. Re-run generators for the groups you changed:
   - Journal: `python bin/journal_db2_tools.py generate` (and `validate` as needed)
   - Named-season bonus lists: `python bin/season_bonus_list_ids.py generate`

## Related

- Runtime Journal rules: [`OneWoW_CatalogData_Journal/Docs/JOURNAL_DATA.md`](../OneWoW_CatalogData_Journal/Docs/JOURNAL_DATA.md)
- FrameXML / API mirrors: [`.wow_docs/README.md`](../.wow_docs/README.md)
