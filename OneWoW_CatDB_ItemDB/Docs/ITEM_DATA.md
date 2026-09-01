# CatDB Items — data rules

Runtime rules for `OneWoW_CatDB_ItemDB` and how item / currency shards are
built. Build-time source order lives in OneWoW_Workspace
[`Docs/WAREHOUSE_PLAN.md`](../../../Docs/WAREHOUSE_PLAN.md).

Load-unit wiring: [`ARCHITECTURE.md`](ARCHITECTURE.md).

This is the Catalog Items store. It is identity only. Client `ItemSparse`
has no drop table — do not invent "where" from the CSV.

## One home

ItemDB owns **what the item is**. Source joins stay on the other packs:

| Source | Pack | Field |
|--------|------|-------|
| Encounter drop | ZoneDB | `loot[].itemID` |
| Vendor stock / cost item | NPCDB | `items[itemID]`, `currencies[].itemID` |
| Quest reward / start | QuestDB | `rewardItems` / `rewardChoices` / `packageItems` / `startItems` |
| Craft output / reagent / scroll | TradeSkillDB | `item` / `items` / `rg[].itemID` / `taught` |
| Achievement reward or criterion | ItemDB | `ItemAchievements[itemID]` (from `Achievement.RewardItemID` + item criteria) |

An item ships only when another pack or an achievement CSV cites it.
Search does not list items Catalog has no source for.

## What it owns

Every cited live retail `ItemSparse` row. Skip DNT / NYI / UNUSED / `[PH]` /
TEST / removed. Skip retired IDs that are no longer in ItemSparse.

Also: cited `Currencies[currencyID] = { name, icon }` for vendor / quest costs.
`ItemAchievements[itemID] = { achievementID, ... }` is the item → achievement
join. ZoneDB `GetAchievementsForItem` reads it (plus any live loot overlay).

## IDs only

This pack does **not** store drop locations, vendor pins, quest text, or
recipes. Those are IDs pointing **here**.

Shipped item names are English from `ItemSparse` (offline search index).
Locale-safe display still goes through the live item cache when a row is
on screen.

## Schema

One keyed row per itemID. Buckets of 25_000 (`Items_000000.lua` …).

| Group | Keys |
| --- | --- |
| Identity | `itemID`, `name`, `quality`, `bindType` |
| Flags | `isTransmog`, `isToy` (omitted when false) |
| Collectable | `toyID`, `mountID`, `speciesID` (omitted when 0) |

`GetItem` fills `classID`, `subclassID`, `inventoryType`, and `icon` from
`C_Item.GetItemInfoInstant` / `GetItemInventoryTypeByID` on first read.
Those four are not shipped (the client already has them).

Currency row: `{ name, icon }` keyed by currencyID.

## Build (Workspace)

```bash
# from OneWoW_Workspace
python bin/catdb_item_emit.py
python bin/catdb_status.py item
```
