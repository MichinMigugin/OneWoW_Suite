## Current

- **Status**: Draft

### Home
- Updated Home links.
- Hub search results and the minimap menu no longer error when they close after the mouse leaves.
- Character profiles no longer error when saving or restoring macros.

### Manage Features
- DevTools starts off on a new install. Enable it in Manage Features; no reload needed.

---

### QoL
#### Icon Browser
- Icon pickers for macros, bank tabs, guild bank tabs, equipment sets, and transmog outfits now have search and category filters.
- Icon pickers no longer error on login when Icon Browser is enabled.

#### Portals
- ESC Portals keeps the Season 1 flyout and adds a Season 2 row. Each can be shown or hidden from Portals settings. Midnight Season 2 dungeon teleports are included, and the Midnight expansion flyout lists the new dungeons.
- Dungeons & Raids on the Portals tab now includes Midnight.
- ESC Midnight column shows its icon, Season 2 appears when its toggle is on, and ESC portal icons fill their slots.
- Portals tab details open with every section expanded.
- Portals Settings has an ESC icon size slider. The ESC strip also has a slider under the Settings icon so you can resize icons while the menu is open. Portal icons line up with the top of the game menu.
- ESC Dungeons, Raids, and previous-season flyouts can list portals you have not learned yet, dimmed. A Portals setting shows or hides those unknown portals. The current season always lists every portal.

#### Fixes
- Auto Mount pauses polling in combat and other aura-restricted situations (12.1), detects stealth without scanning secret buffs, and no longer errors when aura data is restricted. Play Mounts tooltips use the same guard.
- Cursor Enhancer class-color labels display correctly in Russian, Korean, Chinese, and accented European text.
- World map coordinates no longer error while the map is open.

---

### Catalog
#### Journal
- Midnight Journal now includes encounters and loot for The Tidebound Grotto, The Venomous Abyss, and Altar of Fangs.

---

### Bags
#### Settings
- Bags settings → General has three replacement toggles: Bags, Bank (personal and warband together), and Guild Bank.

#### Filters
- Expansion filter can include more than one expansion at once. The menu is taller so two more expansions stay visible.

#### Search
- `#disenchantable` (`#de`) now finds items that can be disenchanted.
- `#midnights1` and `#midnights2` find Midnight Season 1 and Season 2 items. `#currentseason` still means whatever season is live now.

---

### AltTracker
#### Progress
- Progress tracks Midnight Season 2: Venomous Abyss and Tidebound Grotto, the new Mythic+ dungeon pool, Mistcrests, and Nymrissa Wavecaller.

#### Commands
- `/1wat status` opens a dialog of the current season, raids, Mythic+ dungeons, world bosses, weeklies, and currencies Progress is tracking.

#### Fixes
- Saving an action bar set no longer errors.

---

### Trackers
- The bundled Midnight weekly tracker now follows Season 2 Mistcrests.
- Currency, item, level, item-level, reputation, and renown steps show the real target (for example 659/1000) and complete against that target, not 1.
- Holiday and event-gated steps stay visible until the in-game calendar has loaded, instead of hiding when the calendar is still empty.
- Tracker filters sit above the list, with Clear next to search. New, Import, and Restore Examples sit above the details. The first list opens automatically. The extra Preset button is gone; New still offers the same templates.
- Hide Done hides finished lists. Each open list has Hide completed on the detail title (the same setting as the pinned window), and it hides finished steps and empty sections.

---

### Mail
#### Shipments
- Disenchantables now matches items that can be disenchanted.

#### Fixes
- Mail tabs and translated labels show the right language again instead of garbled characters (including Russian, Korean, Chinese, and accented European text).
- The Mail window follows the suite font when you change it. No reload needed.

---

### Shopping List
#### Fixes
- Shopping-list buttons on professions, craft orders, and Catalog follow the suite language and font when you change them. No reload needed.
- The shopping list window no longer errors when you open it or move the mouse over a list.

---

### DevTool
#### Errors
- DEVMODE shows a floating error list when there are Lua errors, including leftover ones. Left-click a row for details; right-click opens the Errors tab. New rows can flash (on by default). Clear errors to hide it. `/1wdt devmode` toggles it.

---

*No user-facing changes this release for Notes.*

---

- **Last Updated**: Aug 17, 2026

## R6.2608.1105

Released Aug 11, 2026. Home attention filtering, suite On/Off settings chrome, Portals and Catalog Tradeskills/Quests polish, plus Mail shipment and AH receipt fixes.

[Read full release notes](Release-Notes-R6.2608.1105)

## R6.2608.0406

Released Aug 4, 2026. Home hub cards and What’s New, slash cleanup path, Mail AH invoice breakdown, Catalog Journal/Vendors work, AltTracker auctions, and Notes list polish.

[Read full release notes](Release-Notes-R6.2608.0406)

## Related

* [Home](Home)
* [Slash commands](Slash-Commands)
* [Getting started](Getting-Started)

### Sources

* [CHANGELOG.md](https://github.com/kellewic/OneWoW_Suite/blob/main/CHANGELOG.md)
* In-game: Home → What’s New (highlights only)
