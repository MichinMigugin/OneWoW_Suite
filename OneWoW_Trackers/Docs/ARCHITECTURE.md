# OneWoW_Trackers — Architecture

> **See also:** [Docs index](../README.md) · [Suite architecture](../../OneWoW/Docs/ARCHITECTURE.md)

## Overview

`OneWoW_Trackers` is a `LoadOnDemand` feature module for customizable tracker lists (guides, dailies/weeklies, todos, farm value). It registers a hub tab and owns list/step data plus an event-driven auto-completion engine.

**SavedVariables:** `OneWoW_Trackers_DB` (global), `OneWoW_Trackers_CharDB` (per character). Internal reads use `ns.db` after `DB:Init` in `Core/Database.lua`.

**Public cross-unit surface:** `OneWoW_Trackers_API` in `Core/API.lua` (UI Toggle/Show/Hide, weekly-reset region picker for QoL settings). Lifecycle colon hooks live on `OneWoW_Trackers = {}` only (`OneWoW_Trackers.lua`).

**RequiredDeps:** `OneWoW`. **OptionalDeps:** `TradeSkillMaster`, `Auctionator` (farm value pricing).

**Slash commands** (via `OneWoW_GUI.DB:RegisterSlashCommand`): `/1wt`, `/owt`, `/tracker`.

## File Tree & Load Order

```
OneWoW_Trackers.lua          — thin lifecycle root, hub registration
Core/Database.lua            — schema, init bridges (incl. legacy Notes SV drain)
Core/API.lua                 — OneWoW_Trackers_API (cross-unit surface)
Core/TrackerData.lua         — list/section/step model, import/export
Core/TrackerEngine.lua       — event engine, auto-complete, pinned lifecycle
Core/TrackerPresets.lua      — bundled presets and examples
Core/TrackerMap.lua          — world-map pin provider
Core/Constants.lua           — GUI constants (inherits suite defaults)
UI/t-tracker.lua             — hub tab (browser + detail)
UI/ui-tracker-editor.lua     — create/edit dialogs
UI/ui-tracker-pinned.lua     — pinned overlay windows
UI/ui-tracker-map.lua        — map integration hooks
UI/ui-tracker-farmvalue.lua  — farm value tab UI
UI/Framework.lua             — shared UI helpers
```

## Lifecycle

1. **`OnAddonLoaded`** — init DB (`ns.db`), register slash commands
2. **`OnPlayerLogin`** — hub tab registration, engine init, presets, map UI wiring
3. **`OnPlayerEnteringWorld`** — engine rescan after zone/login transitions

Follows suite orchestrator hooks (no per-file `ADDON_LOADED` init) — see [ARCHITECTURE.md](../../OneWoW/Docs/ARCHITECTURE.md) §3.

## Data Model

- **Lists** — typed (`guide`, `daily`, `weekly`, `todo`, `repeating`, `farmvalue`), categorized, favoritable
- **Sections / steps** — markup-capable; step types drive auto-tracking predicates
- **Farm value** — watchlist or all unbound stacks; optional session baseline snapshot

## Integration Points

- **OneWoW hub** — `ModuleRegistry` tab `"trackers"`; minimap open path
- **OneWoW_QoL** — weekly reset region picker via `OneWoW_Trackers_API`
- **Map** — `TrackerMap` pins coordinate steps for pinned lists
- **Pricing** — AH via OneWoW/Auctionator; TSM when present
