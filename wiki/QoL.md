**OneWoW QoL** is a set of **toggleable** quality-of-life modules — automation, UI helpers, social, and economy. Enable only what you want; each module turns on or off independently.

**Requires:** [OneWoW](Home) core. Enable **QoL** under [Manage Features](Getting-Started).

**Open:** `/1wqol` (see [Slash commands](Slash-Commands))

---

## How to use it

1. Open QoL from the hub or a slash command.
2. Browse modules by category and turn on the ones you need.
3. Configure options on each module’s panel.
4. Themes and locales follow suite-wide OneWoW settings.

Module shortcuts (when QoL is loaded):

* `/1wbb` — toggle **Bag Bar**
* `/1wcopytext` / `/1wct` — **Copy Text** (only while that module is enabled)

## Tooltips

QoL has a **Tooltips** tab (not a module toggle). **Collections** puts Collected or Not Collected on the item type line. Optionally turn on Show status for non-collectable items to also show gold Not Collectable on items that are not a collectible. **Item Tracker** adds two blocks on item tooltips: **Where it is** (bags, bank, alts, and so on) and **Where to get it** (quest, vendor, instance, profession). Those source lines appear only when that Catalog pack is already loaded this session. Hovering an item does not load packs. Turn individual lines on or off under QoL → Tooltips → Item Tracker.

---

## Module categories (overview)

### Automation

Hands-off helpers: **Auto Repair**, **Fast Loot**, **Auto Mount**, **Auto Open** (containers; skips bank/mail/vendor and locked items; blacklist sortable by name or item ID), **Fast Forward** (skip cinematics; hold a modifier to watch), **Quest Tools** (accept/turn-in/gossip; Shift to skip), **Untrack Completed Achievements**, **Screenshot On Achievement**.

### Interface

UI and map tools: **AFK Panel**, **Auto Delete**, **ESC Menu Panel** (zone notes and OneWay Pins for this map), **Bag Bar** (items matched by [search expressions](Bags-Search-Syntax); manual and blacklist lists sortable by name or item ID), **Quest Item Bar**, **Professions Panel**, **Crafting Orders** (on by default; Craftable now / Missing mats / Recipe Unlearned; Compact View on by default to match Blizzard's original row height; default columns You Provide, Cart, Profit / Loss, Time, and Craft; Features sliders set the width of each shown column, and columns shrink to fit beside the order name; Hide list scrollbar keeps mouse-wheel scrolling; hover Gold or Profit / Loss on a row for the full breakdown; Time Left is abbreviated; Cart hides when every row is already craftable; Craftable now rows can Start, apply Concentration when the order requires it, craft, and complete from the list, or cancel with X; the started order stays at the top until you finish it; starts off if No Mats No Make or PatronOffers is enabled, and you can still turn One UI on; WoW UI switch and a gear to Features on the order tabs), **Character Info Sheet**, **Coords Display**, **Cursor Enhancer**, **Frame Mover**, combat-error spam filter, **Icon Browser** (searchable icon picker for macros, bank tabs, and transmog outfits), **Inspect Gear**, **LFG Lockouts**, minimap/world map tools, **Minimap Button Collector**, **Player Mounts**, **Prey Hunt Bar**, and more.

### Social

**Auto-Accept** party invites (trusted sources), ready checks, resurrections (out of combat), and summons; **Auto-Decline Duels**.

### Economy

**Auction House — Current Expansion** filter on open; **Vendor Panel** for junk filters and quick sell.

### Utility

**Copy Text** — copy tooltip or UI text under the cursor.

Built-in with QoL (not separate toggles): toast-style alerts and the Portals hub / ESC strip. Mages get separate Teleport and Portal flyouts on ESC; show or hide each set in Portals settings.

There are **36** external modules. The full labeled catalog lives in the repo ([MODULES.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_QoL/MODULES.md)).

---

## Tips

* Start with a few modules (Repair, Fast Loot, Quest Tools) before enabling everything.
* Open **Details** on a module to see who wrote it.
* Bag Bar and similar tools use the same expression language as Bags — see [Search syntax](Bags-Search-Syntax).
* Hold **Shift** on quest/gossip dialogs when Quest Tools is on and you want to handle the dialog yourself.

## Related

* [Slash commands](Slash-Commands)
* [Catalog](Catalog)
* [Bags search syntax](Bags-Search-Syntax)
* [Getting started](Getting-Started)

### Sources

* [OneWoW_QoL/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_QoL/README.md)
* [OneWoW_QoL/MODULES.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_QoL/MODULES.md)
* [MODULE_CREDITS.md](https://github.com/kellewic/OneWoW_Suite/blob/main/MODULE_CREDITS.md)
* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md)
