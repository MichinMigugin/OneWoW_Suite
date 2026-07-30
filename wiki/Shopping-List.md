**OneWoW Shopping List** tracks what you need to buy, craft, or farm — and shows what you already own on this character or across your account.

**Requires:** [OneWoW](Home) core. Enable **Shopping List** under [Manage Features](Getting-Started).

**Open:** `/1wsl` (see [Slash commands](Slash-Commands))

---

## Lists and status colors

* Multiple lists (pinned **Main List** plus your own); favorites, rename, import/export
* Add items by ID, drag from bags, or paste a list (unresolved names can be fixed with **Scan All**)
* Per-item quantities plus a list multiplier that scales everything
* Status colors: **green** (this character covers it), **blue** (warband / alts cover it), **yellow** (partial), **red** (none)
* Hover status for exact locations; right-click to move items or start a craft order

Slash extras: `show` / `hide` / `help` / `add <itemID>` on any Shopping List alias.

---

## Crafting

On the profession craft page:

* **Make List** / **Add to Active** / **Add to List** — push recipe reagents into a list (**Shift-click** to set craft count)
* Green **Craft** on a row creates a `Craft: …` sub-list of reagents (merges if you craft-order again)

With **OneWoW_CatalogData_Tradeskills** installed, Craft can pick recipes and show which characters know them; quality-tier reagents are treated as interchangeable when scanning. Crafting **Orders** get similar “push reagents to list” buttons.

---

## Bags, tooltips, and alts

* Cart icon on bag slots that are on a list; optional AH search and “open Shopping List” bag buttons (all toggleable)
* Tooltips show needed vs owned when the item is listed
* **Search Alts** (per list) counts alts’ bags/banks and known guild banks; warband bank always counts
* Without AltTracker **Storage**, scanning is limited to this character’s bags + warband bank
* Chat loot alert when a listed item drops (short per-item cooldown)

---

## Tips

* Enable Shopping List in Manage Features even if you leave the AltTracker hub off — Storage can still load for alt scanning.
* Keep Catalog **Tradeskills** data if you rely on Craft / recipe picker.

## Related

* [Bags](Bags)
* [Catalog](Catalog)
* [AltTracker](AltTracker)
* [Slash commands](Slash-Commands)

### Sources

* [OneWoW_ShoppingList/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_ShoppingList/README.md)
* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md)
