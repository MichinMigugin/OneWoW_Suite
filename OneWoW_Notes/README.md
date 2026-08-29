# OneWoW - Notes

**A comprehensive note-taking system for World of Warcraft. Record information about players, NPCs, zones, items, collectibles, and quests. Everything stays organized and searchable.**

---

## Features

### Notes Tab
Your personal note journal:
- Create unlimited notes for any purpose
- Organize notes into custom categories (e.g., "Quest Tips," "Farming Guides," "Guildmate Info")
- Add tags for easy filtering
- Add to-do lists within notes (great for tracking goals or tasks)
- Mark notes as favorites for quick access
- Choose which notes display on login
- Customize note appearance (font size, color, opacity)
- Pin notes to your screen while playing
- Rich text formatting (bold, colors, custom styling)
- Search notes by title or content

### Players Tab
Notes about other players:
- Record notes about guildmates and friends
- Track player information (realm, guild, class, level)
- Add personal notes (strengths, weaknesses, preferences)
- Rate or comment on player interactions
- Search for player notes quickly
- Organize by guild or realm

### NPCs Tab
Keep information about NPCs and vendors:
- Track NPC locations and purposes
- Record what vendors sell
- Note NPC reward quests
- Remember important NPCs for farming or crafting
- Link to items those NPCs trade

### Zones Tab
Annotate your zones and locations:
- Create a zone note for the area you are in
- Add zone-specific notes (farming spots, quest chains)
- Pin a zone note to the screen as a floating window
- Minimize the pinned window to the title bar; that setting is remembered when you return to the zone
- Optional Show Pins list of OneWay Pins for that map, docked beside the window
- Uncheck Show Zone Notes to keep only that pin list (no blank notes pane). Hover bar sits under both boxes
- Hide Scrollbar on the hover bar hides the pin list bar; the list still scrolls with the mouse wheel
- Add Here / Find Location from the pin list (Add button or right-click empty space)
- Opacity slider matches the note, hover bar, and pin list (solid at 100%)

### OneWay Pins Tab
Persistent map landmarks (bank, craft tables, vendors, and anything you mark):
- Stay on the world map and minimap until you delete them
- The tab defaults to This Map. The count under the list is Showing X of Y pins, so an empty list does not look like you have no pins. Switch Zone to All to see every pin.
- Minimap pins stay on the landmark as you walk; pins outside the current zoom sit on the rim
- Click a pin for a live waypoint that clears when you arrive; the icon stays
- Add from this tab (Add Here or Find Location), Ctrl-Right on the world map by default (turn Map Click Menu off, or pick Ctrl-Right / Right, in OneWay Pins settings), your own unit frame, any NPC's target frame, Catalog, or an NPC note
- **Manage Features** under Notes turns OneWay Pins off (tab, maps, click, lists, add menus). Saved pins stay
- Open **OneWay Pins settings** from Notes settings, this tab, or the world-map pin button for map, click, size, and animation options
- Find Location searches as you type by NPC name, ID, type, notes, tooltips, vendor items, or a custom category. Zone accepts a name or map ID (Current Zone / Verify Zone)
- Each list row has Go and Show Map (opens that pin's zone and sets a live waypoint). The world map button uses the OneWoW icon. Add Pin, then click the map (ghost pin and live coordinates). Add Here saves at your feet. Find Location is on that button too. Map Click Menu defaults to on with Ctrl-Right so a plain right-click stays with other addons
- The world map Map Legend can list pins for the map you are viewing (OneWay Pins settings or the map button). Hover a name to highlight that pin. Pinned zone notes hide until you close the map
- Edit title, optional description, icon (including Blizzard minimap tracking icons such as banker, mailbox, flight master, trainers, food, and reagents), world-map and minimap size, optional background, Effect (None / Zooming / Spinning / Both), and Background Scale (relative to the icon so map, minimap, and list match). Extra layers use more memory. Hover a pin in the zone list or map legend for title, description, and coordinates. Pins saved from Catalog Journal, Vendors, or Quests mention Catalog on the tooltip.
- Add to Zone Notes to show the list beside a pinned zone window when you enter that zone. Uncheck Show Zone Notes to leave only the pin list. Hide Scrollbar hides the pin list bar; wheel scroll still works. Add / right-click empty space for Add Here and Find Location. Left-click to go, Ctrl-click to open the tab, right-click for more
- Disable minimap animations in OneWay Pins settings is on by default (the minimap does not play pin animations well)

### Items Tab
Notes about items and rewards:
- Track where to get specific items
- Note farming routes for materials
- Record quest rewards
- Track item sources (vendors, dungeons, crafting)
- Mark items you need to find or obtain
- Link items directly in notes
- Search for items to see notes about them

### Collectibles Tab
Track mounts, pets, toys, transmog, and other collectibles you care about:
- Build a personal list with intents: **Want**, **Spotted**, **Farming**, or move entries to a **Delete List**
- Filter by category, type, storage scope, and collected / uncollected status
- See live collection state from OneWoW’s collectibles service
- Capture vendor offers for uncollected collectibles (**Off** / **Prompt** / **Automatic** in Notes settings)
- View “Sold by” vendor info (richer with Catalog Vendors data) and set / ensemble progress where available
- Optional auto-cleanup: when enabled, collected Want/Spotted/Farming entries move to the Delete List and purge after a delay you choose
- Custom categories and account- or character-scoped storage, like other Notes tabs
- Link collectibles into notes and associate sightings on player notes

---

## Advanced Features

### Hyperlinks
- Insert direct links to items, spells, NPCs, quests, and achievements
- Create references between notes
- Copy item links from chat to notes automatically

### Waypoints & Map Coordinates
- OneWay Pins are saved landmarks on the world map and minimap
- Click a OneWay Pin to set a live waypoint; it clears when you arrive
- Per-pin world map and minimap size; OneWay Pins settings can turn off minimap animation. Manage Features under Notes turns the feature off
- Insert exact map coordinates in notes
- Navigate to NPC and zone coordinates with one click

### Organization
- Create your own custom categories
- Tag notes for filtering
- Search across all notes
- Organize by character or account
- Mark important notes as favorites

### Customization
- 14+ color themes to match your UI
- Adjustable note appearance
- Pin colors to color-code information
- Font size options for accessibility
- Suite-wide themes and all 11 client locales via **OneWoW**

### Storage Options
- Save notes to your account (shared across all characters)
- Save notes per character (private to that character)
- Switch between account and character storage
- Backup your notes

### Smart Features
- Right-click context menu for quick actions
- Insert target information into notes
- Add current date/time stamps
- Insert your character name
- Auto-save as you type

---

## Installation

1. Extract the `OneWoW_Notes` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
2. Extract the `OneWoW` folder (required dependency) to the same directory
3. Restart World of Warcraft or type `/reload` in-game
4. Type `/1wn` to open the addon

## Requirements

- **OneWoW** - Core hub addon (required)

## Slash Commands

- `/1wn` - Open Notes

## Localization

Supports all 11 suite locales — see [LOCALES.md](../OneWoW/Docs/LOCALES.md).

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md).

## Support

**Website:** https://onewow.net/

**Report issues:** Through Discord community or our website

## OneWoW Suite

Part of the [OneWoW Suite](../README.md). See the suite README for the full addon catalog and install guide.

---

**Author:** OneWoW Development Team

**Website:** https://onewow.net/

**License:** See [LICENSE.md](../LICENSE.md). Copyright the OneWoW Development Team. All rights reserved.
