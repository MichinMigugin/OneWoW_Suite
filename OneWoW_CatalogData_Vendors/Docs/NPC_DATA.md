# Catalog NPCs — data rules

Runtime rules for `OneWoW_CatalogData_Vendors` and how static NpcDB shards are
built. Build-time source order lives in OneWoW_Workspace
[`Docs/WAREHOUSE_PLAN.md`](../../../Docs/WAREHOUSE_PLAN.md).

Load-unit wiring: [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Two boxes

1. **Tab = vendors.** Catalog's Vendors tab lists NPCs that sell. Flight
   masters, trainers, bankers, and innkeepers stay off the tab unless they
   also have a shop.
2. **Store = NPCs.** Rows are keyed by creature ID with `roles = { "vendor" }`
   so quest givers can share this table later. Do not dump `Creature.csv`.
   Journal rares stay Journal. Notes NPCs stay player-authored.

QuestDB still owns giver/turn-in pins. Dual-write and thinning come after
NpcDB covers those IDs. Disabling this pack must not blank quest pins.

## Two layers

1. **Static shards** — `Data/NpcDB/NpcDB_*.lua` merged into `ns.StaticVendors`.
   Warehouse shop groups, profession/item children, CollectableSourceVendorSparse,
   Creature identity (displayID / title → category, then specials / housing),
   and QuestDB pins on
   **vendor IDs only**. Other HandyNotes extract gap-fills missing pins and can
   add a shop row we do not already have. Wowhead `npcs/` is a last-fill shelf
   (not harvested yet).
2. **Live scan** — `VendorScanner` via `OneWoW.Merchant` gap-fills the vendor
   the player is standing at. It unions stock (never deletes static items a
   filtered window hid), writes the current map pin, and applies type rules:
   Uncategorized and General (including player-set) may take the merchant
   subtitle; Decor we set may only move to another special; other specials we
   set stay; non-specials we set may only upgrade to a special; player types
   other than General / Uncategorized never change.

`GetVendor` / `GetAllVendors` overlay static ⊕ live SavedVariables.

## What ships

Classic through Midnight (`NpcDB_classic.lua` … `NpcDB_midnight.lua`,
expansions **0–11**). Expansion IDs match Quests / `LE_EXPANSION_*`
(Classic = 0). Warehouse expansion ids / Journal `ZONE_SEED` are 1-based
(TWW = 11, Midnight = 12).

Home expansion follows the NPC's map, not item `awp`. A Dornogal vendor with
Midnight-added stock stays TWW. A Classic-zone NPC who gained TWW housing
items is not a Khaz Algar shop.

## Vendor type

Specials, ranked: Quartermaster, then Reputation, then PvP / Guild / Delve,
then Decor. A housing item (or a housing collectable source) stamps Decor
unless a higher special applies. Creature titles fill the rest (pet, repair,
and so on). Visit rules are under Live scan above.

## Schema

One keyed row per creature. Field order is `NPC_KEY_ORDER` in OneWoW_Workspace
`bin/lib/npc_lua.py`.

| Group | Keys | Source today |
| --- | --- | --- |
| Identity | `npcID`, `expansion`, `displayID`, `category`, `roles` | Warehouse Sources + Creature.csv. Specials (Quartermaster, Reputation, PvP, Guild, Delve) outrank housing/Decor, which outranks leftover titles. Names come from the tooltip queue at runtime (locale-safe). |
| Location | `locations[mapID] = { x, y, source }` (0–100) | Warehouse coords; QuestDB start/end pins if the ID is already a vendor; Other HandyNotes extract fills a missing map pin only. Zone names fill from `C_Map` at runtime. Other-filled pins omit `source`. |
| Stock | `items[itemID] = { cost, currencies, source }` | Warehouse children / linked item IDs; CollectableSourceVendorSparse. |

`NpcVendor` is not on Wago 12.1. Do not wait for it.

## Build (Workspace)

```bash
# from OneWoW_Workspace
python bin/catalog_data_status.py npcs
python bin/other_addon_ingest.py extract
python bin/npc_split.py emit
```
