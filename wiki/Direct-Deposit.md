**OneWoW Direct Deposit** keeps gold and selected items moving between your bags and banks automatically — especially the **Warband Bank**.

**Requires:** [OneWoW](Home) core. Enable **Direct Deposit** under [Manage Features](Getting-Started).

**Open:** `/1wdd` (see [Slash commands](Slash-Commands)). Manual deposit: `/1wdd deposit`; pause/stop: `/1wdd pause` or `stop`.

---

## Gold targets

* Set how much gold each character should keep
* Leave blank to ignore gold targeting until you enter a value; use **0** to deposit all gold to Warband when deposit is enabled
* On bank open: deposit excess to Warband, or withdraw when below target
* Account-wide defaults with per-character overrides (handy for bank alts vs mains)

---

## Item auto-deposit

* Build a list by item ID, drag-and-drop, or **quick-add keybindings** while hovering a bag item
* Per-item destination: Warband Bank, Personal Bank, or Guild Bank
* Deposits run when you open a matching bank
* **Deposit Now** or `/1wdd deposit` for an on-demand sweep; `/1wdd pause` or `stop` to halt mid-run
* Tooltips can show the queued destination for listed items

### Warbound sweep

Optional: when a bank opens, deposit every warbound item from bags into the Warband Bank. Items already on your per-item list keep their own routing.

Keep exceptions:

* **Keep by Keyword** — expression like `#potion | #flask` (same language as [Bags search](Bags-Search-Syntax))
* **Keep Specific Items** — always leave those item IDs in bags

---

## Keybindings

Under **Game Menu → Key Bindings → OneWoW Direct Deposit** (also summarized in-addon):

* Toggle window
* Deposit items now
* Quick-add to Personal / Warband / Guild Bank while hovering an item

---

## Tips

* Set a comfortable gold target on your main and `0` (or a small float) on farming alts.
* Use Keep-by-Keyword so consumables you want in bags survive a warbound sweep.

## Related

* [Bags search syntax](Bags-Search-Syntax)
* [Slash commands](Slash-Commands)
* [Getting started](Getting-Started)

### Sources

* [OneWoW_DirectDeposit/README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW_DirectDeposit/README.md)
* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md)
