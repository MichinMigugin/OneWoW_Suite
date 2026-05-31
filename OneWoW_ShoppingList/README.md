# OneWoW - Shopping List

**A shopping and crafting list manager. Build lists to track what you need to buy, craft, or farm — and see what you already have, on this character or across your account.**

---

## Features

### Shopping List Management

- Create multiple shopping lists (Main List plus your own).
- Add items by ID, by drag-and-drop from your bags, or by importing a pasted list (name-based imports become "unresolved" entries that can be resolved later by the **Scan All** button).
- Set per-item quantities. Each list also has a multiplier — bumping the list quantity scales every item's required count.
- Status colors at a glance show what you have vs. need:
  - **Green** — owned on this character covers the need.
  - **Blue** — covered when you include the warband bank (or alts, if enabled).
  - **Yellow** — partial coverage.
  - **Red** — none owned.
- Hover an item's status to see exact locations (which character, bank tab, guild bank, etc.).
- Per-item right-click menu: move to another list, create a craft order from the item.

### Multiple Lists

- A pinned **Main List** that cannot be deleted.
- Set any list as the default (loaded on open).
- Favorite lists float to the top of the sidebar.
- Rename, delete, export, and import lists from the right-click menu.
- Auto-generated **Craft Order** sub-lists nest under their parent in the sidebar (see Crafting Integration).

### Crafting Integration

In the in-game Profession crafting page, three buttons appear under the schematic:

- **Make List** — create a new list named after the recipe and populate it with the recipe's reagents.
- **Add to Active** — add the recipe's reagents to the current default/active list.
- **Add to List** — pick any existing list to add the reagents to.
- **Shift-click** any of the three buttons to enter how many crafts to add (materials scale accordingly).

When you click the green **Craft** button on an item row, the addon:

- Creates a `Craft: <item>` sub-list under the current list.
- Pre-fills it with the recipe's reagents.
- Auto-merges quantities if the same item is craft-ordered again under the same parent list.

With **OneWoW_Catalog** also installed, the **Craft** button knows which recipes produce a given item and shows a recipe picker that lists which characters know each recipe. Quality-variant reagents (rank 1/2/3 versions) are recognized as interchangeable when scanning bags.

### Crafting Orders Integration

When the Profession Orders page is open, dedicated buttons let you push the order's reagents into a list, mirroring the crafting page workflow.

### Bag Integration

- A small cart icon appears on bag slots holding items that are on any list.
- Toggleable Auction House quick-search button anchored to the bag UI.
- Toggleable in-bag "open Shopping List" button.
- All overlays / extra buttons can be turned off individually in settings.

### Tooltip Integration

Item tooltips show the needed/owned counts whenever the item is on a list.

### Cross-Character Support (with OneWoW_AltTracker)

- Per-list **Search Alts** toggle in the header. When enabled, the addon counts the item across all your alts' bags and personal banks, plus all known guild banks.
- The warband bank is always counted regardless of the toggle, since it's account-wide.
- Without OneWoW_AltTracker, only the current character's bags + warband bank are scanned.

### Loot Alerts

A chat alert prints when an item from any of your lists drops into your bags, with a 60-second per-item cooldown to avoid spam.

### Customization

- Suite-wide color themes (managed in **OneWoW_GUI** settings — affects all OneWoW addons together).
- Six languages: English, Spanish, French, German, Korean, Russian.
- Quick-access minimap button (registered through the **OneWoW** hub).
- Optional confirmation dialogs for deletes (item delete, list delete) — both can be silenced via "Don't ask again".
- Optional name wrapping for long item names.

---

## Installation

1. Extract the `OneWoW_ShoppingList` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory.
2. Extract the `OneWoW` and `OneWoW_GUI` folders (required dependencies) to the same directory.
3. Restart World of Warcraft or type `/reload` in-game.
4. Type `/owsl` in-game to open the addon.

## Requirements

- **OneWoW** — Core hub addon (required).
- **OneWoW_GUI** — Shared UI library (required).
- **OneWoW_AltTracker** — Optional. Enables alt / personal-bank / guild-bank scanning.
- **OneWoW_Catalog** — Optional. Enables the **Craft** button on item rows, alt-recipe-knowledge lookup, and quality-variant reagent matching.

## Slash Commands

- `/owsl` — toggle the main window.
- `/owsl show` — show the main window.
- `/owsl hide` — hide the main window.
- `/owsl add <itemID>` — add an item to the active list.
- `/owsl help` — print the command list.
- `/shoppinglist` — alias for `/owsl`.
- `/1wsl` — alias for `/owsl`.

## Keybindings

Configurable under WoW's **Key Bindings** menu under the **OneWoW** category:

- **Toggle Shopping List Window**
- **Show Shopping List Window**

## Localization

- English (enUS)
- Spanish (esES)
- Korean (koKR)
- Russian (ruRU)
- French (frFR)
- German (deDE)

## Support

**Website:** https://wow2.xyz/

**Report issues:** Through the Discord community or the website above.

## Part of the OneWoW Suite

OneWoW_ShoppingList works with these addons:

- **OneWoW** — Core hub (required)
- **OneWoW_GUI** — Shared UI library (required)
- **OneWoW_QoL** — Quality of life features
- **OneWoW_AltTracker** — Cross-character data
- **OneWoW_Notes** — Note-taking system
- **OneWoW_Bags** — Inventory management
- **OneWoW_DirectDeposit** — Automatic gold management
- **OneWoW_Catalog** — Game data reference (recommended for crafting features)

See [TODO.md](TODO.md) for features that are planned or partially scaffolded but not yet exposed in the UI.

---

**Author:** MichinMuggin / Ricky

**Website:** https://wow2.xyz/

**All rights reserved. Part of the OneWoW Suite.**
