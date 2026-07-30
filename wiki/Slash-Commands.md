Player-facing chat commands for the OneWoW suite. Commands only work if that addon is **installed and enabled** (see [Manage Features](Getting-Started)).

The Home tab lists the **canonical** `/1w…` set below. Other aliases (for example `/ow`, `/dd`, long `/onewow…` names) still work this release; the **next** release will remove every slash command that is not shown on Home. See [What’s New](Release-Notes) / the in-game What’s New dialog.

Debug and developer-only commands are omitted here.

## Hub (OneWoW)

| Command | What it does |
|---------|----------------|
| `/1w` | Toggle the OneWoW hub |

Re-open the feature picker anytime from **Settings → Manage Features** (link on the Home tab).

## Feature modules

| Feature | Command | What it does |
|---------|---------|----------------|
| [Bags](Bags) | `/1wbags` | Toggle the Bags UI |
| [Notes](Notes) | `/1wn` | Open Notes in the hub |
| [AltTracker](AltTracker) | `/1wat` | Open AltTracker in the hub |
| [Catalog](Catalog) | `/1wcat` | Open Catalog in the hub |
| [Trackers](Trackers) | `/1wt` | Open Trackers in the hub |
| [QoL](QoL) | `/1wqol` | Open QoL in the hub |
| [Shopping List](Shopping-List) | `/1wsl` | Toggle the shopping-list window |
| [Mail](Mail) | `/1wmail` | Toggle the Mail UI |
| [Direct Deposit](Direct-Deposit) | `/1wdd` | Toggle the Direct Deposit window |
| Direct Deposit | `/1wdd deposit` | Start a manual deposit |
| Direct Deposit | `/1wdd pause` or `stop` | Stop an in-progress deposit |

### Shopping List extras

| Args | Effect |
|------|--------|
| *(none)* | Toggle the window |
| `show` / `hide` | Show or hide |
| `help` | Print help |
| `add <itemID>` | Add that item to the active list (quantity 1) |

## Related

* [Getting started](Getting-Started)
* [Install](Install)
* [Release notes](Release-Notes)
* [Bags search syntax](Bags-Search-Syntax) — expressions used in Bags search (and related suite search UIs), not slash commands

### Sources

* [suitecommands.md](https://github.com/kellewic/OneWoW_Suite/blob/main/suitecommands.md) — full slash command inventory (includes aliases still registered this release)
* [OneWoW/UI/t-home.lua](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/UI/t-home.lua) — Home Available Commands list (canonical contract)
