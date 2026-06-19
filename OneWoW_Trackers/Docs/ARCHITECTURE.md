# OneWoW_Trackers — Architecture

> **See also:** [Docs index](../README.md) · [Suite architecture](../../OneWoW/Docs/ARCHITECTURE.md)

## Overview

`OneWoW_Trackers` is a `LoadOnDemand` feature module for customizable tracker lists (guides, dailies/weeklies, todos, farm value). It registers a hub tab, provides standalone UI fallback, and owns list/step data plus an event-driven auto-completion engine.

**SavedVariables:** `OneWoW_Trackers_DB` (global), `OneWoW_Trackers_CharDB` (per character).

**RequiredDeps:** `OneWoW`. **OptionalDeps:** `TradeSkillMaster`, `Auctionator` (farm value pricing).

**Slash commands** (via `OneWoW_GUI.DB:RegisterSlashCommand`): `/1wt`, `/owt`, `/tracker`.

## File Tree & Load Order

```
OneWoW_Trackers.lua          — entry, lifecycle hooks, hub registration
Core/Database.lua            — schema, migrations (incl. legacy Notes split)
Core/TrackerData.lua         — list/section/step model, import/export
Core/TrackerEngine.lua       — event engine, auto-complete, pinned lifecycle
Core/TrackerPresets.lua      — bundled presets and examples
Core/TrackerMap.lua          — world-map pin provider
Core/TrackerMigration.lua    — legacy guide migration
Core/Constants.lua           — GUI constants
UI/MainFrame.lua             — standalone shell
UI/t-tracker.lua             — hub tab (browser + detail)
UI/ui-tracker-editor.lua     — create/edit dialogs
UI/ui-tracker-pinned.lua     — pinned overlay windows
UI/ui-tracker-map.lua        — map integration hooks
UI/ui-tracker-farmvalue.lua  — farm value tab UI
UI/Framework.lua             — shared UI helpers
```

## Lifecycle

1. **`OnAddonLoaded`** — init DB, register slash commands
2. **`OnPlayerLogin`** — hub tab registration, engine init, presets, map UI wiring
3. **`OnPlayerEnteringWorld`** — engine rescan after zone/login transitions

Follows suite orchestrator hooks (no per-file `ADDON_LOADED` init) — see [ARCHITECTURE.md](../../OneWoW/Docs/ARCHITECTURE.md) §3.

## Data Model

- **Lists** — typed (`guide`, `daily`, `weekly`, `todo`, `repeating`, `farmvalue`), categorized, favoritable
- **Sections / steps** — markup-capable; step types drive auto-tracking predicates
- **Farm value** — watchlist or all unbound stacks; optional session baseline snapshot

## Integration Points

- **OneWoW hub** — `ModuleRegistry` tab `"trackers"`; minimap open path
- **Map** — `TrackerMap` pins coordinate steps for pinned lists
- **Pricing** — AH via OneWoW/Auctionator; TSM when present
