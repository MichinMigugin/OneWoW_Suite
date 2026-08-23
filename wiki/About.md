OneWoW is a modular **World of Warcraft** addon suite for **Retail**. One shared hub, optional features you turn on only when you need them, and eleven client languages.

Official site: [https://onewow.net/](https://onewow.net/). Source: [GitHub](https://github.com/kellewic/OneWoW_Suite).

## Open source

The suite is public. Anyone can read the code, open an issue, or send a pull request. If you want to know how a feature works, start in the repo rather than guessing from a screenshot.

## Who ships it

Two full-time developers maintain OneWoW. AI is a tool in the workflow, the same way most modern shops write software. Humans set the architecture, review what ships, and stand behind it.

We do not hide that. We also do not ask anyone to take it on faith. The code is there to inspect.

## Quality bar

We target **Retail 12.1+** Wow API. The repo uses LuaLS / Ketho-style API definitions and the same class of checks people talk about when they review addons. Feature modules unload when you turn them off. Shared UI and SavedVariables go through one toolkit instead of eleven one-off copies.

If you think the suite is slop, read it. We stand by what is in GitHub.

## What the suite covers

* [AltTracker](AltTracker) — account-wide alts, gold, professions, and progress
* [Catalog](Catalog) — instances, vendors, professions, recipes, and quests
* [Trackers](Trackers) — custom lists for guides, dailies, todos, and farm value
* [Bags](Bags) — bag organization and search
* [QoL](QoL), [Notes](Notes), [Shopping List](Shopping-List), [Mail](Mail), [Direct Deposit](Direct-Deposit)

You do not need every folder. Enable what you use under Manage Features.

For how OneWoW sits next to Altoholic, All The Things, and Bagnon, see [Compare](Compare).

## Related

* [Compare](Compare)
* [FAQ](FAQ)
* [Install](Install)
* [Developers](Developers)

### Sources

* [README.md](https://github.com/kellewic/OneWoW_Suite/blob/main/README.md)
* [CONTRIBUTING.md](https://github.com/kellewic/OneWoW_Suite/blob/main/CONTRIBUTING.md)
* [OneWoW/Docs/ARCHITECTURE.md](https://github.com/kellewic/OneWoW_Suite/blob/main/OneWoW/Docs/ARCHITECTURE.md)
