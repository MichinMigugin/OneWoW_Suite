# OneWoW - Direct Deposit

**Automatic gold and item management for your Warband Bank. Simplify managing gold across all your characters with smart automatic transfers.**

---

## Features

### How It Works
Set a target amount of gold to keep on each character, and Direct Deposit will automatically handle deposits and withdrawals from your Warband Bank whenever you open the bank interface. No more manually transferring gold between characters.

### Gold Management
- Set a target gold amount per character (leave blank to disable gold targeting until you enter a value; use **0** to keep no gold on the character and deposit everything to Warband when deposit is enabled)
- Automatically deposit excess gold to Warband Bank
- Automatically withdraw from Warband Bank when you fall below your target
- Choose which characters use account-wide settings vs. custom per-character settings
- Perfect for main characters that earn gold and alts that need funding

### Item Auto-Deposit
Beyond gold, you can also auto-deposit specific items:
- Build an item list by typing an Item ID, dragging items into the addon window, or pressing a quick-add keybinding while hovering an item
- Choose the destination per item: Warband Bank, Personal Bank, or Guild Bank
- Items are automatically deposited when you open a matching bank
- Trigger an on-demand sweep with the **Deposit Now** button or `/ddeposit`, with a **Pause** button (or `/ddeposit pause`) to stop mid-run
- Tooltip overlay shows the queued destination for any item already on the list

### Warband Auto-Deposit (Warbound Items)
Optional one-click feature: when any bank opens, automatically deposit every warbound (account-bound) item from your bags into the Warband Bank. Items already on your auto-deposit list are excluded so per-item routing still wins.

### Account-Wide vs. Per-Character Settings
- Account-wide settings that apply to all characters
- Override settings per character for special cases (bank alts, etc.)
- Perfect flexibility for different character roles

## Slash Commands

Open / close the addon window:
- `/dd` (falls back to `/directdeposit` if another addon already owns `/dd`)
- `/directdeposit`
- `/directdep`
- `/1wdd` (also registered with the OneWoW hub)

Manual deposit control:
- `/ddeposit` - Run a manual item deposit now (uses the currently open bank)
- `/ddeposit pause` or `/ddeposit stop` - Halt an in-progress deposit

## Keybindings

Bindable from **Game Menu > Key Bindings** under **OneWoW Direct Deposit**:
- **Toggle Direct Deposit Window** - open/close the addon window
- **Deposit Items Now** - run a manual item deposit
- **Quick Add: Personal Bank / Warband Bank / Guild Bank** - while hovering any item in your bags, press the matching key to add it to the auto-deposit list with that destination

The in-addon **Keybinds** tab also shows your current assignments at a glance.

## Support

**Website:** https://wow2.xyz/

**Report issues:** Through Discord community or our website

## Part of the OneWoW Suite


**Author:** MichinMuggin / Ricky

**Website:** https://wow2.xyz/

**All rights reserved. Part of the OneWoW Suite.**
