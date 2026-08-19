# Catalog Journal — data rules

Runtime rules for `OneWoW_CatalogData_Journal` and how they relate to client DB2
extracts under [`.wow_db2`](../../.wow_db2/README.md).

## EJ-faithful listing

- Cards come from generated **`JournalTierMembership`** (`JournalTierXInstance`),
  not from walking ATT `*-instances.lua` alone.
- Dual-list only where EJ dual-lists (Deadmines, SFK, Scholo, Scarlet Halls /
  Monastery). Onyxia is Wrath-only.
- ATT remains the loot / specials corpus: item locations for an `instanceID` are
  **unioned across all expansion tables** onto each EJ-facing card for that ID.
- ATT stubs that are not in membership for that expansion do **not** create cards
  (Classic Onyxia stub → no Classic card).
- Optional overrides: [`Data/JournalListingOverrides.lua`](../Data/JournalListingOverrides.lua)
  (`forceHide` / `forceShow` keyed by `"expansionID:instanceID"`).

## Cache key

Composite: `expansionID .. ":" .. instanceID`. Delves use
`expansionID .. ":delve:" .. mapID`. Favorites and list selection use the same key.

## Delves

Delves are not Encounter Journal instances. Cards come from `DelveMembership`
(`MapDifficulty` 208, collapsed season-duplicate MapIDs) with
`instanceType = "delve"`. Pins use `DelveEntrances`. Achievements use
`DelveAchievements` (Stories/Discoveries + expansion Glory + matching lair solos).
There is no EJ loot table; the items section stays empty.

## Generated files

Produced by:

```bash
python bin/journal_db2_tools.py generate
python bin/journal_db2_tools.py validate
python bin/journal_db2_tools.py report
```

| File | Contents |
| --- | --- |
| `Data/Generated/TierMembership.lua` | `ns.JournalTierMembership` |
| `Data/Generated/MapDifficulties.lua` | `ns.JournalMapDifficulties`, `ns.JournalDifficultyMeta` |
| `Data/Generated/InstanceFlags.lua` | `ns.JournalInstanceMeta` (flags, name, mapID) |
| `Data/Generated/InstanceEntrances.lua` | `ns.JournalInstanceEntrances` (world-space door pins) |
| `Data/Generated/DelveMembership.lua` | `ns.DelveMembership` (primary delve MapIDs, not EJ) |
| `Data/Generated/DelveEntrances.lua` | `ns.DelveEntrances` (AreaPOI world doors) |
| `Data/Generated/Achievements.lua` | `ns.JournalAchievements`, `ns.DelveAchievements` |
| `Data/JournalInstanceEntranceFallbacks.lua` | `ns.JournalInstanceEntranceFallbacks` (UiMap `/way` pins; used only when DB2 has no row) |

`validate` fails if a fallback instanceID also has a `JournalInstanceEntrance` row: delete that handmade id so DB2 is the only source.

CSV schema / mermaid: [`.wow_db2/docs/journal.md`](../../.wow_db2/docs/journal.md).
Extract build pin: [`.wow_db2/README.md`](../../.wow_db2/README.md).
Agent skill: `onewow-db2` (when to use extracts vs FrameXML / ATT).

## Live EJ merge

`EJLiveLoot` selects the card’s EJ tier (`EJ_SelectTier`), then scans
difficulties from MapDifficulties / `EJ_IsValidInstanceDifficulty` (includes
legacy 10/25 and dungeon Timewalking).
