# OneWoW - Data: Quests

**Quest database companion for the OneWoW Catalog. Static quest data plus live scanner enrichment and per-character completion tracking.**

---

## What This Addon Does

This is a companion data addon for the OneWoW Catalog. It provides:

- **Quest Database** - Pre-cleaned static quest data (Wowhead-derived) merged from per-expansion tables
- **Live Scanner** - Enriches data from quest log events as you play
- **Completion Tracking** - Per-character completion; optional cross-alt data when **OneWoW_AltTracker** is installed

Players use quest data through the Catalog — this addon has no standalone UI.

---

## Supported Expansions

Classic through Midnight ship in full.

---

## Required Addons

- **OneWoW** - Core hub (required)
- **OneWoW_Catalog** - Parent module that consumes this data (required)

---

## Installation

1. Extract the `OneWoW_CatalogData_Quests` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
2. Install **OneWoW** and **OneWoW_Catalog**
3. Restart World of Warcraft or type `/reload` in-game
4. Open the Catalog and use the quest-related features

---

## How to Use

1. Open the OneWoW Catalog
2. Browse or search quest data through Catalog quest features
3. Play normally — the live scanner enriches data from your quest log as you quest

---

## Documentation

Technical reference: [Docs/ARCHITECTURE.md](Docs/ARCHITECTURE.md). Data rules and build sources: [Docs/QUEST_DATA.md](Docs/QUEST_DATA.md).

---

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md).

## If This Module Is Disabled

`OneWoW_Catalog` still loads. Disabling this data pack empties the Quests tab (including active-quest views), turns off the live quest scanner, and removes quest-reward data from Item Search.

**Elsewhere:** Notes no longer shows associated quests on NPCs; Journal loses quest completion and "View Quest" on quest loot; AltTracker settings no longer lists or purges quest-completion character data.

Full cross-module matrix: [OneWoW_Catalog README — Disabling Data Modules](../OneWoW_Catalog/README.md#disabling-data-modules).

## Support

**Website:** https://onewow.net/

**Report issues:** Through Discord community or our website

## OneWoW Suite

Part of the [OneWoW Suite](../README.md). See the suite README for the full addon catalog and install guide.

---

**Author:** MichinMuggin / Ricky

**Website:** https://onewow.net/

**All rights reserved.**
