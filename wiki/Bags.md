**OneWoW Bags** replaces (or sits alongside) the default bag UI with one window for backpack, bags, and reagent bag — categories, search, and suite themes.

**Requires:** [OneWoW](Home) core. Enable **Bags** under [Manage Features](Getting-Started).

**Open:** `/1wbags` (see [Slash commands](Slash-Commands))

---

## What you can do

### One window

* Backpack, character bags, and reagent bag in a single layout
* Rarity coloring, free-slot count, resize and scale to fit your screen
* Suite themes from OneWoW settings

### View modes

* **List** — flat scan
* **Category** — grouped by type (and your custom categories)
* **Bag** — grouped by which bag the item is in

### Categories

* Built-in groups (equipment, consumables, reagents, recipes, junk, and more)
* **Custom categories** — your own rules, including search expressions
* Pin specific items into a category; drag-and-drop where the UI allows. Sort those pinned items by name or item ID.
* Optional special rows such as **Recent Items** and junk handling

Category **search rules** use the same language as the search bar — see [Search syntax](Bags-Search-Syntax).

### Search and filters

* Type in the search bar to filter what you see
* Plain text matches names; `#keywords`, operators, and properties unlock advanced filters
* Optional **Expansion** dropdown on the header bar (enable in Bags settings) — pick one or more expansions; the filter clears when you close the window
* Save frequent expressions as **Search Shortcuts** (hub: **OneWoW Settings → Search Shortcuts**; Bags also has a Save control on the search bar)

Full reference: [Search syntax](Bags-Search-Syntax).

### Convenience

* Auto-open / auto-close at vendors (when enabled)
* Lock window position
* Highlight recently acquired items
* Optional Shopping List integration for what you still need
* **Replacement Windows** on Bags settings → General: Bags, Bank (personal and warband together), and Guild Bank. `/1wbags` still opens OneWoW Bags so you can turn a replacement back on.

### Layout tweaks

* Icon size, columns, window scale
* Sort and grouping options (global and per-category where available)
* Rarity color intensity and recent-item highlight duration

---

## Setup checklist

1. Install `OneWoW` and `OneWoW_Bags` ([Install](Install)).
2. Enable **Bags** in Manage Features.
3. Open Bags with `/1wbags` and pick a view mode you like.
4. Skim [Search syntax](Bags-Search-Syntax) — start with the quick-start table.
5. Create a custom category or saved search when you outgrow typing the same filter every time.

---

## Related

* [Search syntax](Bags-Search-Syntax)
* [Slash commands](Slash-Commands)
* [Shopping List](Shopping-List)
* [QoL](QoL) — overlays and other UI helpers that can use the same search language

### Sources

* [OneWoW_Bags/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_Bags/README.md) — player feature overview
* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md) — Bags slash commands
