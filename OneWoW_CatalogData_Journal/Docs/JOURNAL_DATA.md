# Catalog Journal — data rules

Runtime rules for `OneWoW_CatalogData_Journal` and how they relate to client DB2
extracts under OneWoW_Workspace `.wow_db2`.

## Two boxes

1. **Adventure Guide (Blizzard)** — cards, bosses, and loot from Generated DB2
   (`JournalTierMembership`, `JournalEncounters`, `JournalLoot`). This is the
   main table. Live EJ only refreshes links and names; it does not add items.
2. **Also from ATT** — trash, quest items, and outdoor rares the Guide never
   listed. Shown in a separate section (`encounterID = -4`). Never mixed into
   boss rows. Never unioned across expansions.

ATT on-disk extras (`OneWoWExtras_*`, plus legacy `OneWoWItems_*`) stay
expansion-scoped. A live overlay runs only if AllTheThings is already loaded
(never `LoadAddOn` / `EnsureLoaded` ATT).

## EJ-faithful listing

- Cards come from generated **`JournalTierMembership`** (`JournalTierXInstance`).
- Dual-list only where EJ dual-lists (Deadmines, SFK, Scholo, Scarlet Halls /
  Monastery). Onyxia is Wrath-only.
- ATT stubs that are not in membership for that expansion do **not** create cards.
- Optional overrides: [`Data/JournalListingOverrides.lua`](../Data/JournalListingOverrides.lua)
  (`forceHide` / `forceShow` keyed by `"expansionID:instanceID"`).

## Cache key

- Dungeon / raid / world hub: `expansionID .. ":" .. instanceID`
- Delves: `expansionID .. ":delve:" .. mapID`
- Synthetic Classic–Cata World cards: `expansionID .. ":world"` (instanceID 0)

Favorites and list selection use the same key.

## World

MoP–Midnight outdoor hubs in EJ are typed `world` (not raid). IDs live in
`JournalWorldHubs`. Classic–Cata have no hub; Journal synthesizes one World
card per expansion (`JournalSyntheticWorldExpansions`). Expansion-wide outdoor
extras (`world = true`) attach to `exp:world` and also to that expansion's hub
card when one exists.

## Delves

Delves are not Encounter Journal instances. Cards come from `DelveMembership`
(`MapDifficulty` 208, collapsed season-duplicate MapIDs) with
`instanceType = "delve"`. Pins use `DelveEntrances`. Achievements use
`DelveAchievements` (Stories/Discoveries + expansion Glory + matching lair solos).
There is no EJ loot table; the items section stays empty.

## Generated files

Produced by:

```bash
# from OneWoW_Workspace
python bin/journal_db2_tools.py generate
python bin/journal_db2_tools.py validate
python bin/journal_db2_tools.py report
```

| File | Contents |
| --- | --- |
| `Data/Generated/TierMembership.lua` | `ns.JournalTierMembership` |
| `Data/Generated/MapDifficulties.lua` | `ns.JournalMapDifficulties`, `ns.JournalDifficultyMeta` |
| `Data/Generated/InstanceFlags.lua` | `ns.JournalInstanceMeta` (flags, name, mapID, instanceType) |
| `Data/Generated/InstanceEntrances.lua` | `ns.JournalInstanceEntrances` (world-space door pins) |
| `Data/Generated/DelveMembership.lua` | `ns.DelveMembership` (primary delve MapIDs, not EJ) |
| `Data/Generated/DelveEntrances.lua` | `ns.DelveEntrances` (AreaPOI world doors) |
| `Data/Generated/Achievements.lua` | `ns.JournalAchievements`, `ns.DelveAchievements` |
| `Data/Generated/JournalEncounters.lua` | `ns.JournalEncounters` (boss rows per instanceID) |
| `Data/Generated/JournalLoot.lua` | `ns.JournalLoot` (Adventure Guide items per instanceID) |
| `Data/Generated/JournalWorldHubs.lua` | `ns.JournalWorldHubs`, `ns.JournalSyntheticWorldExpansions` |
| `Data/JournalInstanceEntranceFallbacks.lua` | `ns.JournalInstanceEntranceFallbacks` (UiMap `/way` pins; used only when DB2 has no row) |

`validate` fails if a fallback instanceID also has a `JournalInstanceEntrance` row: delete that handmade id so DB2 is the only source.

CSV schema / mermaid: OneWoW_Workspace `.wow_db2/docs/journal.md`.
Extract build pin: OneWoW_Workspace `.wow_db2/README.md`.
Agent skill: `onewow-db2` (when to use extracts vs FrameXML / ATT).

## Live EJ merge

`EJLiveLoot` selects the card’s EJ tier (`EJ_SelectTier`), then scans
difficulties from MapDifficulties / `EJ_IsValidInstanceDifficulty` (includes
legacy 10/25 and dungeon Timewalking). It updates names and item links only.
It does not invent encounters or add items. World hubs use `JournalWorldHubs`
for the difficulty scan. Cards with `instanceID == 0` are skipped.
