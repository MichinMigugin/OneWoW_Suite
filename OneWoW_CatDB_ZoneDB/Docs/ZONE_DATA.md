# CatDB Zones — data rules

Runtime rules for `OneWoW_CatDB_ZoneDB` and how place / encounter shards are
built. Build-time source order lives in OneWoW_Workspace
[`Docs/WAREHOUSE_PLAN.md`](../../../Docs/WAREHOUSE_PLAN.md).

Load-unit wiring: [`ARCHITECTURE.md`](ARCHITECTURE.md).

This is the Catalog Zones store.

## One home

ZoneDB owns the **place** and the **encounter**: lore, art file IDs, world
and in-instance pins, valid difficulties, lock text, encounter mechanics,
and loot **links** (itemIDs only).

Everyone else stores IDs:

| Fact | Home | On the ZoneDB row |
|------|------|-------------------|
| Item name / icon / quality | ItemDB | `loot[].itemID` |
| NPC pin / display / roles | NPCDB | `npcIDs` |
| Quest text / rewards | QuestDB | `questIDs` |
| Recipe / craft | TradeSkillDB | (not stored here) |

Do not dump `Creature.csv` or full ItemSparse into this addon.

## What it owns

- Instance lore and encounter lore
- Button / background / lore art file IDs
- World entrance pin and queue / meeting-stone pin
- In-instance boss pin + UiMap
- Encounter difficulties and `DungeonEncounter` kill-credit → npcID
- Encounter creature display IDs
- Valid difficulties, difficulty names, lock text
- AreaTable + UiMap parent / continent
- Covenant lock
- Delve vs bountiful door pins (`areaPoiID` / `bountifulPoiID` on entrance)
- Encounter mechanic writeups (`sections`)
- Object IDs in the place (treasures; client has no object loot table)
- Vignette IDs on the place (the person is still NPCDB)
- Journal membership, flags, listing overrides, achievements as IDs

Place kinds: `zone` | `instance` | `delve` | `hub` | `world`.

## IDs only

`npcIDs`, `objectIDs`, `vignetteIDs`, `achievementIDs`, `questIDs`, and
`loot[].itemID` are joins. Identity for those rows lives in the other CatDB
packs (or Blizzard APIs for achievements).

## Expansion IDs

Place `expansion` is **1-based** warehouse / Journal `ZONE_SEED` (Classic = 1,
TWW = 11, Midnight = 12). Dual-list places may set `expansions = { 1, 3 }`
and still have one home shard. NPCDB and QuestDB use `LE_EXPANSION_*`
(Classic = 0). Do not mix the two without converting.

## Schema

### Place row

Keyed by place key (`"instance:63"`, `"zone:84"`, `"delve:<mapID>"`,
`"hub:<instanceID>"`, `"world:<expansion>"`).

| Group | Keys |
| --- | --- |
| Identity | `kind`, `name`, `expansion`, `expansions`, `instanceID`, `mapID`, `uiMapID`, `areaID`, `parentUiMapID`, `instanceType`, `isCity`, `flags`, `covenantID`, `order` |
| Lore / art | `lore`, `art = { button, background, lore }` (file IDs) |
| Joins | `difficultyIDs`, `encounterIDs`, `npcIDs`, `objectIDs`, `vignetteIDs`, `achievementIDs`, `questIDs` |
| Pins | `entrance[]`, `queue[]` — `{ mapID, x, y, faction, uiMapID?, areaPoiID?, bountifulPoiID? }` |

### Encounter row

Keyed by `encounterID`. World rares use the same shape (`npcIDs` + `loot`).

| Group | Keys |
| --- | --- |
| Identity | `encounterID`, `instanceID`, `order`, `name`, `dungeonEncounterID` |
| Lore / pin | `lore`, `uiMapID`, `pin = { x, y }` (0–1), `difficultyIDs`, `displayIDs` |
| Joins | `npcIDs`, `loot[] = { itemID, diffs, faction, season?, achievementID? }` |

`loot.achievementID` is optional (live overlay). The shipped item →
achievement join is ItemDB `ItemAchievements`.
| Mechanics | `sections[] = { id, title, body?, difficultyIDs? }` |

Synthetic IDs (emit, `bin/lib/catdb_zone.py`) are not Journal encounter IDs:

| Range | Meaning | Hydrate |
| --- | --- | --- |
| `1 .. 9999999` | Adventure Guide / world boss | Named encounter |
| `10000000 + npcID` | Outdoor rare | `worldRare`, NPC name |
| `>= 20000000` | Unplaced leftover bucket | **General Loot** only |

`EnsureEncounters` matches old Journal grouping: World Bosses, World Rares by
NPC name, General Loot for leftovers. Rows with no loot are omitted. Rare
and leftover rows ship with an empty `name`; the API fills it at hydrate.

Also in this addon: `Difficulties` (`name`, `maxPlayers`, `instanceType`),
`MapDifficulties` (per mapID: `id`, `message` / `lock`), `TierMembership`
(`[expansionID][instanceID] = order`), `ListingOverrides` (`forceHide` /
`forceShow` keyed by `"expansionID:instanceID"`).

## Build (Workspace)

```bash
# from OneWoW_Workspace
python bin/catdb_zone_emit.py
python bin/catdb_status.py zone
```
