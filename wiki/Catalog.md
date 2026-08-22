**OneWoW Catalog** is an in-game reference for instances, vendors, professions/recipes, quests, and item sources.

**Requires:** [OneWoW](Home) core. Enable **Catalog** under [Manage Features](Getting-Started). Companion `OneWoW_CatalogData_*` packs fill each tab.

**Open:** `/1wcat` (see [Slash commands](Slash-Commands))

---

## Tabs (overview)

* **Journal** — dungeons, raids, Delves, and World hubs across expansions; encounters, Adventure Guide loot, additional extras, and achievements when Journal data is installed. The pin next to the favorite star opens the map and marks the entrance.
* **Vendors** — who sells what, where, and for which currency
* **Tradeskills** — recipes, materials, and profession requirements
* **Item Search** — find an item and see vendors, crafts, drops, and other sources
* **Quests** — quest database and completion tracking (with Quests data)

Search and filters (expansion, type, and so on) work across the data you have loaded.

---

## Data packs

Each pack is optional. Disable packs you do not need to save memory; Catalog itself still opens.

| Pack | Fills |
|------|--------|
| **Journal** | Instances, encounters, Adventure Guide loot, additional extras, achievements, Delves, and World |
| **Vendors** | Vendor NPCs and stock |
| **Tradeskills** | Recipes and materials |
| **Quests** | Quest DB and completion (Midnight and The War Within in full, plus older story/campaign) |
| **Extended Data** | Optional leftover older quests. Not in the main Suite zip. Catalog works without it. |

Turning a pack off empties its Catalog tab and removes related details elsewhere (for example vendor lines on tooltips, or Shopping List craft detection when Tradeskills is off). Other tabs keep working.

---

## Tips

* For crafting lists, keep **Tradeskills** installed even if you rarely open Catalog — [Shopping List](Shopping-List) uses it for the Craft button and recipe picker.
* On Journal cards, the pin beside the star opens the world map and drops a waypoint at the instance entrance. The same pin is on the details side, opposite Difficulty. Gold pins are Wowhead locations used until Blizzard publishes an official door. Hub cards still have no pin.
* Instance Type includes World (outdoor hubs, plus a World card for Classic through Cataclysm), Zones, Cities, and Delves (The War Within and Midnight). Loot matches the Adventure Guide. World cards split World Bosses and World Rares, each with their own loot, and show a rares count next to bosses. Extra drops with a known boss or rare sit on that encounter, including bosses or rares OneWoW did not already list. Unplaced extras stay under General Loot. A drop that comes from several rares is listed on each rare. Source icons on encounters and loot mark Adventure Guide, shipped OneWoW data, Extended Data, or live AllTheThings. When AllTheThings is loaded, the Journal filter bar shows ATT Detected. While Delves is selected, **Show Bountiful** sits next to Has uncollected and keeps only this week's bountiful doors. The checkbox clears when you close Catalog or press Clear.
* Zone and City cards are a second complete view of that place. The World hub stays the full rollup. A pin on a World-hub rare, boss, or achievement opens that zone or city when we know the map. Cities and The War Within / Midnight zones ship with Journal. Older outdoor zones need optional Extended Data.
* Bountiful delve cards use the bountiful type icon, and a gold border when the filter is off. Delve cards use the official entrance background.
* Cards show bosses, items, and achievements on one line. World cards also show a rares count. Zone and City cards show rares, items, and achievements (bosses only if that place has one). Delves show the achievement count only (no Adventure Guide loot table). World cards include that expansion's exploration achievements (Explore, Adventurer, Treasures).
* Details list achievements above items. Click the Achievement header (same plus/minus as Items) to collapse the table. Status uses a check (this character), a Warband mark, and an X (incomplete). The check is green when you earned it; the Warband icon uses its normal art when the Warband has it and a grey account mark when it does not; the X turns soft orange when it is still incomplete. Click a row to open it in the in-game Achievements window.
* Dungeons and raids have an Adventure Guide button on the details toolbar. Delves keep the Difficulty dropdown in place so the map pin lines up, but it stays disabled (Delves have no difficulty filter and no Adventure Guide page).
* Themes follow suite-wide OneWoW settings.

## Related

* [Shopping List](Shopping-List)
* [AltTracker](AltTracker)
* [Slash commands](Slash-Commands)

### Sources

* [OneWoW_Catalog/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Catalog/README.md)
* [OneWoW_ExtendedData/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_ExtendedData/README.md)
* [README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/README.md) — Catalog data-store catalog
* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md)
