# OneWoW - Bags

**A complete bag organization and inventory management system. Replace or enhance the default bag interface with powerful organization tools.**

---

## Features

### Unified Bag Interface
- Single window shows all your bags at once
- See your backpack, individual bags, and reagent bag together
- Color-coded by item rarity (common, uncommon, rare, epic, legendary)
- Resize and customize the layout to fit your screen

### Multiple View Modes
- **List View** - Simple list format, easy to scan
- **Category View** - Items grouped by type (consumables, gear, crafting materials, etc.)
- **Bag View** - See items organized by which bag they're in

### Smart Categorization
- Items automatically sorted by type (equipment, consumables, reagents, trade goods, tradeskill items, recipes, gems, quest items, cosmetics, toys, pets/mounts, keys, junk, other)
- Custom categories - create your own groups for special items
- Drag-and-drop items into custom categories
- Add items by ID to your custom categories

### Search & Filter
- Search items by name
- Filter by which bag you're looking in
- Quick access to specific item types
- Shows free slot count

### Tracking & Monitoring
- Track specific currencies or items
- See how much you have at a glance
- Rarity color indicators on items
- Highlight new items that came into your bags

### Customization Options
- Adjust icon size (small, medium, large, extra large)
- Adjust number of columns
- Change window scale
- 14+ color themes for the UI (suite-wide via **OneWoW** settings)

### Convenience Features
- Auto-open when you visit vendors
- Auto-close when you leave a vendor
- Lock window position to prevent accidental movement
- Show bags bar for quick switching
- Integrate with Shopping List to track what you need

### Settings & Organization
- Sort by priority or alphabetically
- Rarity color intensity adjustment
- Recent items tracking (highlights items picked up recently)
- Customizable highlight duration

---

## Installation

1. Extract the `OneWoW_Bags` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
2. Extract the `OneWoW` folder (required dependency) to the same directory
3. Restart World of Warcraft or type `/reload` in-game
4. Type `/bags` or `/1wb` to open the addon

## Requirements

- **OneWoW** — Core hub addon (required; includes the shared UI toolkit)

## Documentation

Contributor and integrator docs live in [`Docs/`](Docs/README.md):

- [Architecture](Docs/ARCHITECTURE.md) — load order, data flow, DB schema
- [Categorization](Docs/CATEGORIZATION.md) — category assignment and layout
- [Search syntax](Docs/SEARCH_SYNTAX.md) — predicate expression reference
- [Import/export](Docs/IMPORT_EXPORT.md) — sharing category profiles
- [Item-button API](Docs/ITEM_BUTTON.md) — overlay callbacks for third-party addons

Addon authors: start with [`API/INTEGRATION_GUIDE.md`](API/INTEGRATION_GUIDE.md).

## Slash Commands

- `/bags` - Open Bags
- `/1wb` - Open Bags
- `/owbags` - Open Bags

## Localization

Supports all 11 suite locales — see [LOCALES.md](../OneWoW/Docs/LOCALES.md).

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md).

## Support

**Website:** https://wow2.xyz/

**Report issues:** Through Discord community or our website

## Part of the OneWoW Suite

OneWoW_Bags works with these addons:
- [OneWoW](../OneWoW/README.md) - Core hub (required)
- [OneWoW_QoL](../OneWoW_QoL/README.md) - Quality of life features
- [OneWoW_AltTracker](../OneWoW_AltTracker/README.md) - Track all your characters
- [OneWoW_Notes](../OneWoW_Notes/README.md) - Note-taking system
- [OneWoW_ShoppingList](../OneWoW_ShoppingList/README.md) - Shopping and crafting lists
- [OneWoW_DirectDeposit](../OneWoW_DirectDeposit/README.md) - Automatic gold management
- [OneWoW_Catalog](../OneWoW_Catalog/README.md) - Game data reference

---

**Author:** MichinMuggin / Ricky

**Website:** https://wow2.xyz/

**All rights reserved. Part of the OneWoW Suite.**
