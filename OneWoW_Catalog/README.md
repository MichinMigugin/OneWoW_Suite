# OneWoW - Catalog

**A complete reference database for World of Warcraft content. Look up instances, encounters, vendors, professions, and crafting recipes.**

---

## Features

### Journal Tab - Instances, Raids, Delves & World
Browse dungeons, raids, Delves, and World hubs from every expansion:
- **All Expansions Covered** - Classic through Midnight (Delves: The War Within and Midnight; World cards for Classic through Cataclysm, outdoor hubs after that; Zone and City cards)
- Loot matches the Adventure Guide; World cards list World Bosses and World Rares with their own loot and a rares count; extra drops with a known boss or rare sit on that encounter; the rest stay under General Loot; a drop from several rares is listed on each rare
- Source icons on encounters and loot: Adventure Guide or shipped OneWoW data. When AllTheThings is loaded, the filter bar shows ATT Detected and can add anything AllTheThings has live
- See all instances and encounters at a glance
- Pin on a card or the details toolbar opens the world map at that instance's entrance (gold pins are Wowhead locations until official doors ship). Right-click the pin to save a OneWay Pin in Notes
- Instance Type includes World, Zones, Cities, and Delves, with a Show Bountiful checkbox for this week's bountiful doors
- A pin on a World-hub rare, boss, or achievement opens that zone or city when we know the map. Cities and outdoor zones for every expansion ship with Journal
- Delve cards use official entrance background art. Zones, cities, and other cards without their own art use that expansion's Adventure Guide background
- Cards use a type-colored border for raid, dungeon, world, zone, city, Delve, and bountiful Delve
- Achievements sit above loot on the details side (collapsible, same header as Items). Cards show bosses, rares (World), items, and the achievement count. World cards include that expansion's exploration achievements. Status is a check / Warband mark / X
- Adventure Guide button on dungeon and raid details. Delves keep a disabled Difficulty dropdown so the map pin lines up
- Detailed encounter information (if data addon is installed)
- Look up loot tables and boss mechanics
- Search for specific raids, dungeons, or delves
- Perfect for planning raid nights or preparing for content

### Vendors Tab
Find vendors and what they sell:
- Browse all NPCs that sell items
- Search for specific vendors
- See what items each vendor has for sale
- Find vendors by location or item
- Check prices and currency requirements
- Filter by vendor type (general merchants, specialty vendors, etc.)

### Tradeskills Tab
Complete profession and recipe database:
- Browse recipes for all professions (Alchemy, Blacksmithing, Cooking, Enchanting, Engineering, Fishing, Herbalism, Housing Dyes, Inscription, Jewelcrafting, Leatherworking, Mining, Skinning, Tailoring)
- Search for specific recipes or crafts
- See what materials each recipe requires
- See skill ranks and where to learn a recipe when we know it, including the trainer or vendor name
- Find recipes that use specific materials
- Perfect for planning crafting projects

### Item Search Tab
Universal search across all item data:
- Search for any item in the game
- See where items come from (vendor, quest, drop, craft)
- Check which vendors sell specific items
- Find recipes that produce items
- Look up loot from dungeons and raids
- Quick reference for item sources

---

## Data Addons (Optional but Recommended)

The Catalog works with companion data addons to provide complete information:

### Data: Journal (OneWoW_CatalogData_Journal)
- Detailed instance and encounter information
- Dungeon and raid layouts
- Boss mechanics and loot tables
- Expansion history
- Complete expansion coverage (Classic through Midnight)

### Data: Tradeskills (OneWoW_CatalogData_Tradeskills)
- Complete recipe database for Classic through Midnight (patch 12.1)
- Material requirements
- Crafting costs and yields
- Profession progression guides
- All 14 professions covered

### Data: Vendors (OneWoW_CatalogData_Vendors)
- Vendor locations and NPCs
- Item prices and currencies accepted
- Vendor specialties
- Seasonal vendors

### Data: Quests (OneWoW_CatalogData_Quests)
- Static quest database with live scanner enrichment
- Per-character completion tracking
- This expansion and the previous one (The War Within and Midnight)
- Classic through Midnight (patch 12.1) lists have the pins and text we have

### Data: Quest Archive (OneWoW_CatalogData_Quests_Archive)
- Classic through Dragonflight
- Loads when you browse those expansions, search all quests, or look up quest rewards

Each data pack is optional. Disable any `OneWoW_CatalogData_*` addon you do not use to reduce memory and load time — `OneWoW_Catalog` itself keeps running.

---

## Disabling Data Modules

`OneWoW_Catalog` always loads when enabled. The **CatalogData** addons are separate load units; turn one off in the WoW addon list (or via suite feature controls) and only that pack's data disappears. Other Catalog tabs and unrelated suite addons keep working.

Per-pack READMEs have a short summary; this table is the canonical cross-module reference.

| Disabled module | In Catalog | Elsewhere in the suite |
| --- | --- | --- |
| **Journal** (`OneWoW_CatalogData_Journal`) | Journal tab empty; Item Search drop filter and drop details; collection status on journal loot; navigate-to-instance from toasts | QoL Item Tracker — no instance/encounter lines on item tooltips; QoL — no collection grid on instance-entry toasts or ESC instance panel |
| **Quests** (`OneWoW_CatalogData_Quests`) | Quests tab empty (including active-quest views); Item Search quest-reward filter and details; open-to-quest navigation | Notes — no associated-quest list on NPCs; Journal — no "View Quest" or quest completion on journal loot *(also needs Quests)*; AltTracker settings — quest completion not listed for character purge |
| **Quest Archive** (`OneWoW_CatalogData_Quests_Archive`) | Classic through Dragonflight missing from the Quests tab and from all-quest search | Reward lookups for those expansions stay empty until Archive is on |
| **Vendors** (`OneWoW_CatalogData_Vendors`) | Vendors tab empty; Item Search vendor filter and "sold by" details; open-to-vendor navigation | Core — no "Open Vendor Details" on NPC context menus; QoL Item Tracker — no vendor lines on item tooltips |
| **Tradeskills** (`OneWoW_CatalogData_Tradeskills`) | Tradeskills tab empty; Item Search crafted filter and recipe details (including known-by alts) | ShoppingList — no craft detection, craft orders, recipe picker, or crafting-quality inventory rollup; QoL Professions Panel — no supplemental alt recipe data from tradeskill scans |

**Still works with any subset:** Catalog shell, Settings, Item Search (owned items via AltTracker), and every Catalog tab whose data pack remains enabled. ShoppingList profession-window hooks that use Blizzard APIs directly are unaffected by disabling Tradeskills.

**Cross-dependencies:** Journal quest-loot links and completion badges need **both** Journal and Quests. ShoppingList recipe features need **Tradeskills** only (Catalog hub UI is not required for craft detection).

---

## Customization

### 14+ Theme Options
Choose from Forest Green, Ocean Blue, Royal Purple, Crimson Red, Sunset Orange, Deep Teal, Golden Amber, Rose Pink, Slate Gray, Earth Brown, Midnight Black, and more.

### Instant Theme Switching
No UI reload required for theme changes. Switch themes on the fly.

### Multi-Language Support
Supports all 11 suite locales via **OneWoW** — see [LOCALES.md](../OneWoW/Docs/LOCALES.md).

### Search & Filter
- Universal search across all data
- Filter by expansion
- Filter by type (dungeon, raid, quest, vendor, etc.)
- Alphabetical sorting

---

## Installation

1. Extract the `OneWoW_Catalog` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
2. Extract the `OneWoW` folder (required dependency) to the same directory
3. (Optional but recommended) Extract the `OneWoW_CatalogData_*` folders for complete data
4. Restart World of Warcraft or type `/reload` in-game
5. Type `/1wcat` to open the addon

## Requirements

- **OneWoW** - Core hub addon (required)
- **OneWoW_CatalogData_Journal** - Recommended for instance and encounter data (optional)
- **OneWoW_CatalogData_Tradeskills** - Recommended for recipe and profession data (optional)
- **OneWoW_CatalogData_Vendors** - Recommended for vendor and item data (optional)
- **OneWoW_CatalogData_Quests** - Recommended for quest database and completion data (optional)
- **OneWoW_CatalogData_Quests_Archive** - Classic through Dragonflight quests (optional)

## Slash Commands

- `/1wcat` - Open Catalog

## Localization

Supports all 11 suite locales — see [LOCALES.md](../OneWoW/Docs/LOCALES.md).

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md).

Browse-tab data rules (cheap list, Instant-only detail, chunked live-API filters):

- Journal: [JOURNAL_DATA.md](../OneWoW_CatalogData_Journal/Docs/JOURNAL_DATA.md) (Lazy hydrate)
- Quests: [QUEST_DATA.md](../OneWoW_CatalogData_Quests/Docs/QUEST_DATA.md) (Lazy hydrate)

## Support

**Website:** https://onewow.net/

**Report issues:** Through Discord community or our website

## OneWoW Suite

Part of the [OneWoW Suite](../README.md). See the suite README for the full addon catalog and install guide.

---

**Author:** OneWoW Development Team

**Website:** https://onewow.net/

**License:** See [LICENSE.md](../LICENSE.md). Copyright the OneWoW Development Team. All rights reserved.
