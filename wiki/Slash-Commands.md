Player-facing chat commands for the OneWoW suite. Commands only work if that addon is **installed and enabled** (see [Manage Features](Getting-Started)).

Debug and developer-only commands are omitted here.

## Hub (OneWoW)

| Command | What it does |
|---------|----------------|
| `/ow` `/1w` `/one` `/onewow` | Toggle the OneWoW hub |
| `/ow-wizard` | Re-open the first-run / feature-picker wizard |
| `/owkeys` `/1wkeys` `/onewowkeywords` | Open the keyword / search-help dialog |

## Feature modules

| Feature | Command | What it does |
|---------|---------|----------------|
| [Bags](Bags) | `/1wb` `/1wbags` `/onewowbags` | Toggle the Bags UI |
| Bags | `/owbags-export` | Export Bags settings into the copy dialog |
| [Notes](Notes) | `/1wn` `/own` `/onewownotes` | Open Notes in the hub |
| [AltTracker](AltTracker) | `/1wat` `/owat` `/onewowat` | Open AltTracker in the hub |
| [Catalog](Catalog) | `/1wcat` `/owcat` `/onewowcatalog` | Open Catalog in the hub |
| [Trackers](Trackers) | `/1wt` `/owt` `/tracker` | Open Trackers in the hub |
| [QoL](QoL) | `/1wqol` `/owqol` `/onewowqol` | Open QoL in the hub |
| [Shopping List](Shopping-List) | `/1wsl` `/owsl` `/shoppinglist` | Toggle the shopping-list window |
| [Mail](Mail) | `/1wmail` `/owmail` | Toggle the Mail UI |
| [Direct Deposit](Direct-Deposit) | `/1wdd` `/dd` `/directdeposit` `/directdep` | Toggle the Direct Deposit window |
| Direct Deposit | `/ddeposit` | Start a manual deposit run |

`/dd` is skipped if another addon already registered that slash command.

### Shopping List extras

Any Shopping List alias accepts:

| Args | Effect |
|------|--------|
| *(none)* | Toggle the window |
| `show` / `hide` | Show or hide |
| `help` | Print help |
| `add <itemID>` | Add that item to the active list (quantity 1) |

### Direct Deposit extras

| Command | Effect |
|---------|--------|
| `/ddeposit` | Start a manual deposit |
| `/ddeposit pause` or `stop` | Stop an in-progress deposit |

## QoL module shortcuts

These require **QoL** loaded. Some only exist while that module is enabled.

| Command | Module | What it does |
|---------|--------|----------------|
| `/bagbar` `/owbb` | Bag Bar | Toggle the Bag Bar module on or off |
| `/copytext` `/ct` | Copy Text | Capture UI text under the cursor into the copy dialog (only while Copy Text is enabled) |

## Related

* [Getting started](Getting-Started)
* [Install](Install)
* [Bags search syntax](Bags-Search-Syntax) — expressions used in Bags search (and related suite search UIs), not slash commands

### Sources

* [suitecommands.md](../suitecommands.md) — full slash command inventory (this page uses the User-kind subset)
