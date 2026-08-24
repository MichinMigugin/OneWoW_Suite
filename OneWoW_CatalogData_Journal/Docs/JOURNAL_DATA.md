# Catalog Journal — data rules

Runtime rules for `OneWoW_CatalogData_Journal` and how they relate to client DB2
extracts under OneWoW_Workspace `.warehouse/Sources/Wago`.

## Two boxes

1. **Adventure Guide (Blizzard)** — cards, bosses, and loot from Generated DB2
   (`JournalTierMembership`, `JournalEncounters`, `JournalLoot`). This is the
   main table. Live EJ only refreshes links and names; it does not add items.
2. **Extras** — trash, quest items, and outdoor rares the
   Guide never listed. Matching `encounterID` joins (or creates) that boss
   row. World cards also split leftover `npcID` rows into per-rare loot under
   World Rares. Unplaced extras stay in General Loot (`encounterID = 0`).
   Never unioned across expansions.

Shipped extras (`OneWoWExtras_*`) stay expansion-scoped. A live overlay runs
only if AllTheThings is already loaded (never `LoadAddOn` / `EnsureLoaded` ATT).

`OneWoWExtras_*` is generated, not hand-written — see "Generated extras"
below. The old `OneWoWItems_*` / `OneWoWInstances_*` / `OneWoWEncounters_*`
tables **no longer ship**: 25.6 MB of Lua parsed at load, of which ~76% duplicated
Generated data and ~half the entries were duplicate `[itemID]` keys Lua discarded
anyway. Nothing may read those globals or add them back to the TOC.

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
- Zone / city: `expansionID .. ":zone:" .. uiMapID` (`instanceType = "zone"`, `isCity` for cities)
- Synthetic Classic–Cata World cards: `expansionID .. ":world"` (instanceID 0)

Favorites and list selection use the same key.

## Lazy hydrate

The in-memory card index is cheap: membership, delves, synthetic World, Generated
loot counts and boss counts. Encounter rows (`C_Item`, extras) load in
`EnsureEncounters` for **one card** when you open details, toast, or ESC
collection, or when Has uncollected filters the current list.

`GetInstanceByMapID` hydrates only the preferred card for that map. It must not
build loot for every dungeon and raid.

**Has uncollected** is the one filter that must hydrate many cards, so it runs as a
`OneWoW.ChunkedJob` and publishes matches as it finds them. Hydrating ~217 cards
synchronously froze the client — the same stall lazy hydrate exists to avoid, just
reached through a filter instead of through login. Any future filter that needs
collection state has to be chunked the same way.

List cards paint without hydrating. Taxonomy tags (`hasTMog`, and so on) fill in
after that card hydrates, but the **item count must not change on open**: a
skeleton card's `totalItems` is `CountGeneratedLoot` (unique `JournalLoot` itemIDs)
plus `CountExtrasLoot` (unique non-achievement `OneWoWExtras_*` itemIDs for that
card key), which is exactly what `ApplyTotals` recomputes after hydrate. Those two
sets never overlap because the extras files are pre-diffed against `JournalLoot`,
and achievement rows are excluded on both sides. Synthetic World cards hold extras
only, so their count comes from `CountExtrasLoot` alone — it is not `0`.
World cards also carry `rareCount` (unique extras `npcID`s with no boss
encounter) so the list line can show `4 Bosses | 13 Rares` before hydrate.

Hydrate itself is Instant-only: `C_Item.GetItemInfoInstant` plus
`GetItemNameByID` / `GetItemQualityByID`. It must not call `GetItemInfo` or
`RequestLoadItemDataByID` for every loot row (that was the hitch on a large
raid card). ToyBox / Mount / Pet journal probes run only for leftover
Miscellaneous or Consumable rows on that card, not for armor and weapons.

Those probes are deliberately **per card, not per visible row**: `ApplyTotals` turns
`item.special` into the card's `hasToys` / `hasMounts` / `hasPets` tags and feeds the
collectible filters, so deferring them to row paint would leave card tags and
filters wrong until the player scrolled every row.

Because hydrate is Instant-only, an uncached item resolves neither its name nor its
quality: the row gets the localized `JOURNAL_UNKNOWN_ITEM` placeholder and quality
`1`. Both are display fallbacks, and both are corrected the same way — the **store
item cache is the source of truth for "resolved"**. A visible detail row asks
`GetCachedItem(itemID)`; a hit settles name, icon and quality in one pass, a miss
goes through `LoadItemData` (this is the one place `RequestLoadItemDataByID` may
run, and only for rows actually on screen). Catalog UI does that through
`ns.FillVisibleItem` (fill token + `IsShown()`). Never gate that fill on the name alone:
name and quality are separate facts, and the live EJ merge fills names without
touching quality.

Rows also carry `nameResolved` (boolean), which answers exactly one question: does
this row still need a name from live EJ? `mergeEJRowsIntoEncounter` reads it before
overwriting, and `HasUnresolvedBossNames` uses it to decide whether the
`EJ_LOOT_DATA_RECIEVED` retry is still worth running. Consumers must never compare
against the placeholder string instead — that key lives in this store's locale
scope, so another addon re-localizing it gets the key name back, not the
translation.

## World

MoP–Midnight outdoor hubs in EJ are typed `world` (not raid). IDs live in
`JournalWorldHubs`. Classic–Cata have no hub; Journal synthesizes one World
card per expansion (`JournalSyntheticWorldExpansions`). Expansion-wide outdoor
extras (`world = true`) attach to `exp:world` and also to that expansion's hub
card when one exists.

World card encounters are:

- **World Bosses** — Adventure Guide bosses on the hub, plus extras whose
  `encounterID` matches (or a new boss row when an extra has an encounter ID the
  Guide does not list).
- **World Rares** — extras with an `npcID` and no matching boss encounter,
  one section per creature. Names resolve from `npcID` at runtime.
- **General Loot** — leftover extras with neither a boss encounter nor an
  NPC (`encounterID = 0`).
- The same item may appear on more than one rare when it drops in several
  places. Card item counts stay unique itemIDs.
- World cards attach exploration-category achievements for that expansion
  (`JournalWorldAchievements`) plus any map-keyed Journal achievements.
  World-hub achievement rows carry `zoneMapID` when
  `JournalAchievementZones` knows the place, so Catalog can jump to that
  Zone / City card.

## Zones and cities

Cards come from generated `JournalZoneMembership` (cities and outdoor zones
for every expansion). Classification uses `UiMap`
Type 3 / System 0: continent children plus the city / special-zone seed
(Undermine, Vashj'ir trio, Nazjatar, Korthia). Wowhead zone lists are
AreaTable ids, joined through `UiMapAssignment`. Floor UiMaps fold through
`JournalZoneCollapse` (Wrath Dalaran 125 stays separate from Legion Dalaran 627).

Zone cards use the World encounter layout (rares, bosses when present,
General Loot). Extras with a membership `mapID` attach to that zone key
**and** stay on the World hub. Unknown mapIDs (for example ATT Midnight
`2600`) stay World-only. Zone achievements come from
`JournalZoneAchievements` (ExploreArea overlays via WorldMapOverlay /
AreaTable, plus English title fallback for Adventurer / Treasures / glyphs
at generate time). Runtime only calls `GetAchievementInfo`.

Dungeon and raid extras with an `encounterID` merge onto that boss the same
way. Live EJ creates a missing boss row when the Adventure Guide lists one
OneWoW did not ship. Live overlay is a fallback only: if AllTheThings is already loaded it places
extras we have not shipped yet. Encounter rows carry `source`
(`ej` / `att-live` / omitted for shipped OneWoW extras) for the Journal Source icon.

## Delves

Delves are not Encounter Journal instances. Cards come from `DelveMembership`
(`MapDifficulty` 208, collapsed season-duplicate MapIDs) with
`instanceType = "delve"`. Pins use `DelveEntrances`. Achievements use
`DelveAchievements` (Stories/Discoveries + expansion Glory + matching lair solos).
There is no EJ loot table; the items section stays empty.
Weekly bountiful doors (`RefreshBountiful`) read `DelveMembership` names and
`DelveEntrances` pins/POIs only — never the journal loot cache.

## Generated files

Produced by:

```bash
# from OneWoW_Workspace
python bin/catalog_data_status.py journal
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
| `Data/Generated/ZoneMembership.lua` | `ns.JournalZoneMembership`, `ns.JournalZoneCollapse` |
| `Data/Generated/ZoneAchievements.lua` | `ns.JournalZoneAchievements`, `ns.JournalAchievementZones` |
| `Data/Generated/JournalEncounters.lua` | `ns.JournalEncounters` (boss rows per instanceID) |
| `Data/Generated/JournalLoot.lua` | `ns.JournalLoot` (Adventure Guide items per instanceID) |
| `Data/Generated/JournalWorldHubs.lua` | `ns.JournalWorldHubs`, `ns.JournalSyntheticWorldExpansions` |
| `Data/JournalInstanceEntranceFallbacks.lua` | `ns.JournalInstanceEntranceFallbacks` (UiMap `/way` pins; used only when DB2 has no row) |

`validate` fails if a fallback instanceID also has a `JournalInstanceEntrance` row: delete that handmade id so DB2 is the only source.

CSV schema / mermaid: OneWoW_Workspace `.warehouse/Sources/Wago/docs/journal.md`.
Extract build pin: OneWoW_Workspace `.warehouse/Sources/Wago/README.md`.
Warehouse / source order: OneWoW_Workspace `Docs/WAREHOUSE_PLAN.md`.
Agent skill: `onewow-db2` (when to use extracts vs FrameXML / ATT).

## Generated extras

Raw shelves are the Workspace clone (`.warehouse/Sources/ATT`), CSVs
(`.warehouse/Sources/Wago`), and the rest of Sources. Generators read every
shelf under `.warehouse/Sources/`. Today's shipped extras and Generated files
stay as they are until a feature generator is run on purpose.

`bin/att_dump.py journal` walks compiled ATT `Instances`, `Zones`, `Delves`,
`WorldDrops`, `ExpansionFeatures`, `WorldEvents`, and `Holidays` into staging.
`bin/wowhead/journal-drops.py fetch` pulls dungeon and outdoor NPC drops from
Wowhead as last-fill (never invents an instance or item ID).
`bin/journal_extras.py emit` (from Sources) writes:

| Output | Global | Contents |
| --- | --- | --- |
| `Data/<Expansion>-extras.lua` | `OneWoWExtras_<Expansion>` | loot the Adventure Guide does not list |
| `Data/JournalItemNames.lua` | `ns.JournalItemNames` | offline names for Adventure Guide loot |

Shipped extras stay as they are until a feature generator is run on purpose.

### Extras rows

One flat row per (item, location); the row **is** the `itemData`, so it carries the
display and classification fields `BuildExtrasEncounter` / `DetermineItemSpecial`
read (`name`, `icon`, `quality`, `classID`, `subclassID`, `itemType`, `itemSubType`,
`isTransmog`, `isToy`, `toyID`, `mountID`, `speciesID`, `achievementID`,
`questSources`) plus its location (`instanceID` or `world`, `encounterID`,
`difficulties`, `npcID`, `mapID`, and `source` only for Adventure Guide
(`ej`) or runtime live-added rows). Shipped extras omit `source`. The row
deliberately omits `link`: the visible-row fill resolves a live link through
the store item loader, and `link` was the single heaviest field in the
legacy tables.

Duplicate `[itemID]` keys are **merged**, not last-wins. The extractor now emits one
key per item, but older extracts repeat the same item many times (57,790 entries for
29,174 unique items) because ATT stores an item per bucket; Lua kept only the last
and silently dropped the earlier `locations`. Merging on read recovers 230 extras
rows the client never saw, and keeps old extracts usable.

Current output: 36,085 rows / 6.75 MB (diffed against `JournalLoot`; world-drop
and outdoor rows sit on World / zone cards, instance rows on dungeon and raid
cards). Wowhead NPC drops last-fill holes the Guide and clone extras omit.

### Item names and drop locations (cross-addon)

`ns.JournalItemNames` covers Adventure Guide itemIDs only (19,068 of 19,068 from
ItemSparse). Extras rows
carry their own `name`, so `GetItemNameIndex` folds them in on first use and
returns one map.

Two API surfaces exist so no other addon reads Journal data tables directly:

- `GetItemNameIndex()` — flat `itemID -> name`. Catalog Item Search text-matches
  against this. It must stay **offline**: `C_Item.GetItemNameByID` returns nil for
  any uncached item, so resolving names live would silently drop most loot from a
  name search (and that call was itself a measured stall).
- `GetItemDropLocations(itemID)` — `{ instanceID, instanceName, encounterName,
  difficulties }` per place an item drops, deduped by instance+encounter. Backs
  both Item Search's drop list and the QoL item-tracker tooltip. Instance names
  come from Generated `JournalInstanceMeta`, encounter names from Generated
  `JournalEncounters` — which is why the legacy instance/encounter files are gone.

The reverse index behind `GetItemDropLocations` builds on first query only, so a
player who never opens Item Search and never hovers an item with the tracker
tooltip enabled never pays for it.

## Live EJ merge

Live merge is **per card** (`MergeInstance`), never a login walk of every
instance. `EJLiveLoot` selects the card’s EJ tier (`EJ_SelectTier`), then scans
difficulties from MapDifficulties / `EJ_IsValidInstanceDifficulty` (includes
legacy 10/25 and dungeon Timewalking). It updates names and item links only.
It does not invent encounters or add items. World hubs use `JournalWorldHubs`
for the difficulty scan. Cards with `instanceID == 0` and delves are skipped.
`EJ_LOOT_DATA_RECIEVED` (Blizzard’s spelling) refreshes the open card only when
`SetLiveMergeTarget` is set; it does not rebuild the world cache.
Hover tooltips still resolve a scaled link via `GetScaledLootLink`.

On a cold session the first merge can beat the server's loot data, so the event
retries — but only while `HasUnresolvedBossNames` is true and at most
`MAX_MERGE_RETRIES` (3) times. Both bounds matter: the check is scoped to rows
inside real encounters (`encounterID > 0`) because those are the only names EJ can
supply, and without the counter, extras and General / Achievement / Quest rows —
which EJ will never name — kept the retry permanently armed and re-merged the card
every 0.25s for the rest of the session.
