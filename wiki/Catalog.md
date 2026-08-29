**OneWoW Catalog** is an in-game reference for instances, vendors, professions/recipes, quests, and item sources.

**Requires:** [OneWoW](Home) core. Enable **Catalog** under [Manage Features](Getting-Started). Companion `OneWoW_CatalogData_*` packs fill each tab.

**Open:** `/1wcat` (see [Slash commands](Slash-Commands))

---

## Tabs (overview)

* **Journal** — dungeons, raids, Delves, and World hubs across expansions; encounters, Adventure Guide loot, additional extras, and achievements when Journal data is installed. The pin next to the favorite star opens the map and marks the entrance. Right-click that pin to save a OneWay Pin in Notes.
* **Vendors** — who sells what, where, and for which currency. Classic through Midnight shops ship with the Vendors pack; housing, Quartermaster, PvP, Guild, and Delve shops get a type when we can tell. Shops you have not opened yet show Unseen on the details pane. Opening a merchant still updates portrait, live prices, and pins. **Pin** sets a live waypoint and opens that zone on the world map. **Save Pin** writes a OneWay Pin in Notes; it becomes **Open Pin** once that vendor location is saved. Filter by expansion, zone, currency, or type.
* **Tradeskills** — recipes for Classic through Midnight (patch 12.1), materials, skill ranks, and where to learn a recipe when we know it (trainer, vendor, drop, quest, or Specialization). Learned From uses the NPC name; vendor names open that shop in Vendors.
* **Item Search** — find an item and see vendors, crafts, drops, and other sources
* **Quests** — quest database and completion tracking (with Quests data)

Search and filters (expansion, type, and so on) work across the data you have loaded.

---

## Data packs

Each pack is optional. Disable packs you do not need to save memory; Catalog itself still opens.

| Pack | Fills |
|------|--------|
| **Journal** | Instances, encounters, Adventure Guide loot, additional extras, achievements, Delves, and World |
| **Vendors** | Classic through Midnight vendor NPCs and stock (live scan fills gaps) |
| **Tradeskills** | Recipes for Classic through Midnight (patch 12.1), materials, skill ranks, and where to learn a recipe (including Specialization) |
| **Quests** | This expansion and the previous one (The War Within and Midnight) |
| **Quest Archive** | Classic through Dragonflight; loads when you browse those expansions, search all quests, or look up quest rewards |

Turning a pack off empties its Catalog tab and removes related details elsewhere (for example vendor lines on tooltips, or Shopping List craft detection when Tradeskills is off). Other tabs keep working.

---

## Tips

* For crafting lists, keep **Tradeskills** installed even if you rarely open Catalog — [Shopping List](Shopping-List) uses it for the Craft button and recipe picker.
* On a recipe, Learned From shows the trainer or vendor name. Click a vendor name to open that shop in Vendors.
* On Journal cards, the pin beside the star opens the world map and drops a waypoint at the instance entrance. Right-click it to save a OneWay Pin in Notes. The same pin is on the details side, opposite Difficulty. Gold pins are Wowhead locations used until Blizzard publishes an official door. Hub cards still have no pin.
* Instance Type includes World (outdoor hubs, plus a World card for Classic through Cataclysm), Zones, Cities, and Delves (The War Within and Midnight). Loot matches the Adventure Guide. World cards split World Bosses and World Rares, each with their own loot, and show a rares count next to bosses. Extra drops include dungeon trash, outdoor rares, world drops, and holiday or world-event items that belong on a zone or World card. Extra drops with a known boss or rare sit on that encounter, including bosses or rares OneWoW did not already list. Unplaced extras stay under General Loot. A drop that comes from several rares is listed on each rare. Source icons on encounters and loot mark Adventure Guide or shipped OneWoW data. When AllTheThings is loaded, a shield sits on the lower right of the Journal filter bar; hover it. Journal can add anything AllTheThings has live. While Delves is selected, **Show Bountiful** sits next to Has uncollected and keeps only this week's bountiful doors. The checkbox clears when you close Catalog or press Clear.
* Zone and City cards are a second complete view of that place. The World hub stays the full rollup. A pin on a World-hub rare, boss, or achievement opens that zone or city when we know the map. Cities and outdoor zones for every expansion ship with Journal.
* Bountiful delve cards use the bountiful type icon, and a gold border when the filter is off. Delve cards show today's story on the type line. They use the official entrance background. Zones, cities, and other cards without their own art use that expansion's Adventure Guide background. Raid, dungeon, world, zone, city, and Delve cards each have their own border color.
* The Quests pack is Midnight and The War Within. Classic through Dragonflight load from Quest Archive when you browse those expansions, search all quests, or look up rewards. Classic through Midnight (patch 12.1) lists have the pins and text we have. Right-click a quest map ID to save a OneWay Pin in Notes.
* Quest list cards use that expansion's Adventure Guide background, with a border for Campaign, Story, Legendary, and other quest types.
* Cards show bosses, items, and achievements on one line. World cards also show a rares count. Zone and City cards show rares, items, and achievements (bosses only if that place has one). Delves show remaining Stories progress when that achievement is incomplete, plus the achievement count (no Adventure Guide loot table). World cards include that expansion's exploration achievements (Explore, Adventurer, Treasures).
* Details list achievements above items. Click the Achievement header (same plus/minus as Items) to collapse the table. Status uses a check (this character), a Warband mark, and an X (incomplete). The check is green when you earned it; the Warband icon uses its normal art when the Warband has it and a grey account mark when it does not; the X turns soft orange when it is still incomplete. Click a row to open it in the in-game Achievements window. On a Delve, Stories lists each variant under that achievement; today's is highlighted. Click still opens the achievement.
* Dungeons and raids have an Adventure Guide button on the details toolbar. Delves keep the Difficulty dropdown in place so the map pin lines up, but it stays disabled (Delves have no difficulty filter and no Adventure Guide page).
* Themes follow suite-wide OneWoW settings.

## Related

* [Shopping List](Shopping-List)
* [AltTracker](AltTracker)
* [Slash commands](Slash-Commands)

### Sources

* [OneWoW_Catalog/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Catalog/README.md)
* [OneWoW_CatalogData_Tradeskills/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_CatalogData_Tradeskills/README.md)
* [OneWoW_CatalogData_Vendors/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_CatalogData_Vendors/README.md)
* [OneWoW_CatalogData_Quests/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_CatalogData_Quests/README.md)
* [OneWoW_CatalogData_Quests_Archive/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_CatalogData_Quests_Archive/README.md)
* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md)
