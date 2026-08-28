# OneWoW - Quality of Life

**Quality of life features and automation tools that make gameplay smoother. Enable or disable each feature independently in the QoL Features UI.**

Open **OneWoW → Quality of Life** or type `/1wqol`. Full module catalog: [MODULES.md](MODULES.md).

---

## Automation

Hands-off helpers for repairs, looting, mounts, quests, and cinematics.

- **Auto Repair** — repair at merchants (optional guild bank)
- **Fast Loot** — loot corpses and chests as soon as the window opens
- **Auto Mount** — mount when you start moving; smart terrain and dismount rules
- **Auto Open** — open containers from your bags (skips bank/mail/vendor and locked items)
- **Fast Forward** — skip movies and cinematics (hold a modifier to watch)
- **Quest Tools** — auto-accept, turn-in, reward highlight, quest gossip (Shift to skip)
- **Untrack Completed Achievements** — clear stuck achievement tracking slots on login
- **Screenshot On Achievement** — capture achievement toasts to Screenshots

## Interface

UI panels, map tools, bars, and screen customization.

- **AFK Panel** — full-screen AFK overlay with character info, alerts, and notes
- **Auto Delete** — skip typing DELETE when destroying items
- **ESC Menu Panel** — character info, alerts, zone notes, and portal strip beside the ESC menu
- **Bag Bar** — movable bar of bag items matched by keyword expression
- **Quest Item Bar** — clickable quest-item buttons with sorting and filters ([details](Modules/external/questitembar/README.md))
- **Professions Panel** — expansion skills, recipe counts, and first-craft tracking beside the profession window
- **Crafting Orders** — Craftable now / Missing mats / Recipe Unlearned on the profession orders page; add missing mats to a Shopping List; start, craft, and complete from one button
- **Character Info Sheet** — ilvl, enchants, gems, and durability on the character sheet
- **Coords Display** — map coordinates near the minimap (right-click to copy)
- **Cursor Enhancer** — ring and optional mouse trail
- **Frame Mover** — reposition Blizzard frames; Ctrl+Scroll to scale
- **Hide Combat Error Spam** — suppress common red combat error text
- **Inspect Gear** — gear list on inspect; save to Notes
- **LFG Lockouts** — raid and dungeon lockouts beside Group Finder
- **Map (Mini) Tools** — minimap shape, border, clock, zoom, and layout
- **Map (World) Tools** — world map reveal, tints, coordinates, and comfort options
- **Minimap Button Collector** — themed container for minimap addon buttons
- **Player Mounts** — show mounts/forms other players are using
- **Prey Hunt Bar** — prey hunt progress bar for the current zone

## Social

Group and interaction automation.

- **Auto-Accept Party Invites** — from trusted sources you configure
- **Auto-Accept Ready Check** — confirm ready automatically
- **Auto-Accept Resurrection** — accept rezzes (skipped in combat)
- **Auto-Accept Summon** — accept warlock and summoning-stone requests
- **Auto-Decline Duels** — dismiss duel popups

## Economy

Auction House and vendor convenience.

- **Auction House - Current Expansion** — filter AH to current-expansion items on open
- **Vendor Panel** — junk filters and quick sell at vendor windows

## Utility

Clipboard and text tools.

- **Copy Text** — copy tooltip or UI text under the cursor (`/copytext`, `/ct`)

## Built-in (always available)

These ship with QoL core code (not separate external modules):

- **Toast notifications** — loot, collection, and instance alerts (`Features/`)
- **Portal hub data** — hearthstones, teleports, and custom portals integrated with ESC Panel and the [OneWoW](../OneWoW/README.md) hub (`Portals/`)

---

## Customization

### Modular system
Each external module toggles independently. See [MODULES.md](MODULES.md) for all 36 modules, folder paths, and module ids.

### Theme support
All QoL UI integrates with suite-wide themes via **OneWoW** — switch instantly with no reload.

### Language support
Supports all 11 suite locales — see [LOCALES.md](../OneWoW/Docs/LOCALES.md).

## Documentation

- [MODULES.md](MODULES.md) — full external module catalog (by category)
- [DEVELOPERS.md](DEVELOPERS.md) — authoring new modules
- [OneWoW/Docs/README.md](../OneWoW/Docs/README.md) — suite technical docs

---

## Installation

1. Extract the `OneWoW_QoL` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
2. Extract the `OneWoW` folder (required dependency) to the same directory
3. Restart World of Warcraft or type `/reload` in-game
4. Type `/1wqol` to open the addon

## Requirements

- **OneWoW** - Required as the core hub addon

## Slash Commands

- `/1wqol` - Open Quality of Life

## Localization

Supports all 11 suite locales — see [LOCALES.md](../OneWoW/Docs/LOCALES.md).

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md). Original modules: set `author` in
`module.lua` to your name ([DEVELOPERS.md](DEVELOPERS.md),
[MODULE_CREDITS.md](../MODULE_CREDITS.md)).

## Support

**Website:** https://onewow.net/

**Report issues:** Through Discord community or our website

## OneWoW Suite

Part of the [OneWoW Suite](../README.md). See the suite README for the full addon catalog and install guide.

---

**Author:** OneWoW Development Team

**Website:** https://onewow.net/

**License:** See [LICENSE.md](../LICENSE.md). Copyright the OneWoW Development Team except third-party files and community modules that name their own license ([MODULE_CREDITS.md](../MODULE_CREDITS.md)). All rights reserved.
