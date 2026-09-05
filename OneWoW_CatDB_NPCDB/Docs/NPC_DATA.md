# CatDB NPCs — data rules

Runtime rules for `OneWoW_CatDB_NPCDB` and how static NpcDB shards are
built. Build-time source order lives in OneWoW_Workspace
[`Docs/WAREHOUSE_PLAN.md`](../../../Docs/WAREHOUSE_PLAN.md).

Load-unit wiring: [`ARCHITECTURE.md`](ARCHITECTURE.md).

This is the Catalog NPCs store.

## One home

NPCDB owns the **creature**: display, title, type, roles, map pins, and
vendor stock as itemIDs + price. Name resolves at runtime (tooltip queue),
locale-safe — do not bake names into shards. Opening a Catalog NPC card or
a quest giver / turn-in requests that tooltip and writes `nameCache`.

Everyone else stores IDs:

| Fact | Home | On the NPCDB row |
|------|------|------------------|
| Item identity | ItemDB | `items[itemID]` (cost / currencies only) |
| Quest text | QuestDB | `questIDs`, `trackingQuestIDs`, `rewardQuestIDs` |
| Place / encounter lore | ZoneDB | `placeKeys`, `encounterIDs` |

Quest `starts` / `ends` with an npcID are `{ npcID }` only. The xy lives
here. Object / area starts stay on the quest.

## What it owns

Today's vendor row, plus a row for every npcID that currently only lives
on quests, extras, bosses, vignettes, recipes, or a Creature title that
marks a service (inn, repair, stable, flight master, banker, trainer).

Roles (ordered): `vendor`, `quest_giver`, `rare`, `boss`, `trainer`,
`service`, `vignette`. A creature may have more than one. Trainers use
`trainer`; inns, repair, stables, flight masters, bankers, and the rest
of those titled services use `service`.

Home expansion follows the NPC's map (majority of pins), then quest
homes, then Classic. A Dornogal vendor with Midnight-added stock stays
TWW.

## IDs only

`items`, `questIDs`, `trackingQuestIDs`, `rewardQuestIDs`, `encounterIDs`,
`achievementIDs`, and `placeKeys` are joins. What the item is, what the
quest says, and place lore live elsewhere.

## Schema

One keyed row per creature. Field order is `NPC_KEY_ORDER` in
OneWoW_Workspace `bin/lib/npc_lua.py`.

| Group | Keys |
| --- | --- |
| Identity | `npcID`, `expansion`, `displayID`, `title`, `creatureType`, `creatureFamily`, `classification`, `category`, `roles` |
| Location | `locations[mapID] = { x, y }` (0–100), `placeKeys` (`"zone:84"`, `"instance:63"`) |
| Stock | `items[itemID] = { cost, currencies }` |
| Joins | `questIDs`, `trackingQuestIDs`, `rewardQuestIDs`, `encounterIDs`, `achievementIDs` |

`NpcVendor` is not on Wago 12.1. Do not wait for it.

Runtime overlay (Catalog NPCs tab) fills a missing `category` from, in
order: player `vendorCategories` SV, shipped `category`, Creature
`title` / live subtitle via `VendorCategoryMap`, then `trainer` or
`quest_giver` roles. An unstamped quest giver is stamped `quest_giver`.
Barber / Trainer / Innkeeper / Quest Giver filters use that key. Rare
and boss stay roles only — no extra shop-category rows.

When a creature row has no `locations` pin, the overlay joins ZoneDB
encounter `uiMapID` / `pin` and `placeKeys` `zone:<mapID>` so Catalog
can show the instance or zone and Current Zone Only can match this map.
Shipped shards stay unchanged.

The Catalog NPCs list is `vendor`, `trainer`, `service`, `quest_giver`,
`rare`, `boss`, or `vignette`, plus anyone the player talked to (learned
overlay). Learned rows and new facts set `sync = true` for CompSync
Contribute. Do not mutate shipped shards. `GetVendorsByItem` /
`ItemIsSold` still require stock.
See [CATDB_CONTRIBUTE](../../OneWoW/Docs/CATDB_CONTRIBUTE.md).

## Build (Workspace)

```bash
# from OneWoW_Workspace
python bin/catdb_npc_emit.py
python bin/catdb_status.py npc
python bin/catdb_contribute_merge.py --from EXPORT
```

Seeds from current CatDB NPC shards plus Creature titles and related CSVs.
