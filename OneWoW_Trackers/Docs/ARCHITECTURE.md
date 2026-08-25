# OneWoW_Trackers — Architecture

> **See also:** [Docs index](../README.md) · [Suite architecture](../../OneWoW/Docs/ARCHITECTURE.md) ·
> [TRACKERS_IDEAS.md](TRACKERS_IDEAS.md) (direction parking lot, not committed scope)

## Overview

`OneWoW_Trackers` is a `LoadOnDemand` feature module for customizable tracker lists (guides, dailies/weeklies, todos, farm value). It registers a hub tab and owns list/step data plus an event-driven auto-completion engine.

**SavedVariables:** `OneWoW_Trackers_DB` (global), `OneWoW_Trackers_CharDB` (per character). Internal reads use `ns.db` after `DB:Init` in `Core/Database.lua`.

**Public cross-unit surface:** `OneWoW_Trackers_API` in `Core/API.lua` (UI Toggle/Show/Hide, weekly-reset region picker for QoL settings). Lifecycle colon hooks live on `OneWoW_Trackers = {}` only (`OneWoW_Trackers.lua`).

**RequiredDeps:** `OneWoW`. **OptionalDeps:** `TradeSkillMaster`, `Auctionator` (farm value pricing).

**Slash commands** (via `OneWoW_GUI.DB:RegisterSlashCommand`): `/1wt`.

## File Tree & Load Order

```
OneWoW_Trackers.lua          — thin lifecycle root, hub registration
Core/Database.lua            — schema, init bridges (incl. legacy Notes SV drain)
Core/API.lua                 — OneWoW_Trackers_API (cross-unit surface)
Core/TrackerData.lua         — list/section/step CRUD, progress, roster
Core/Resets.lua              — daily/weekly/custom-timer + weekly-reset region
ImportExport/Serialize.lua   — OWT1 export/import (methods on TrackerData)
ImportExport/Markup.lua      — markup parse → list CRUD (methods on TrackerData)
Core/Evaluators/             — live step evaluation by family (registry first)
Core/Encounter.lua           — dungeon/raid boss fill + raid-lock evaluator (`kill_encounter`)
Core/TrackerEngine.lua       — event engine, auto-complete; pin show/destroy is thin
Core/TrackerPresets.lua      — bundled presets and examples
Core/TrackerMap.lua          — world-map pin provider
Core/Constants.lua           — GUI constants (inherits suite defaults)
UI/t-tracker.lua             — hub tab (browser + detail)
UI/ui-tracker-editor.lua     — create/edit dialogs
UI/ui-tracker-pinned.lua     — pinned overlay windows (owns overlay frames)
UI/ui-tracker-map.lua        — map integration hooks
UI/ui-tracker-farmvalue.lua  — farm value tab UI
```

## Progress contract

`ns.TrackerEvaluators.Evaluate(obj) -> current, goal | nil` is the source of truth for live step types (currency, item, quest, level, ilvl, reputation, renown, collections, professions, vault, location). Hub rows, pinned rows, tooltips, and auto-complete all use that pair.

- **Live types:** complete when `goal > 0` and `current >= goal`. Display `current/goal`.
- **`step.noMax`:** show quantity only; do not auto-complete from a comparison.
- **`nil` (unregistered or incomplete live):** session/manual types (`kill_creature`, loot, enter instance, NPC, custom timer). `kill_encounter` is live `1,1` when the raid lock is complete, else `nil` so a session latch from `ENCOUNTER_END` is not wiped. The engine uses session bumps and `step.max`.
- **`step.max`:** not the live target. The editor may copy `amount` / `level` / `ilvl` / `standing` onto `max` for export symmetry only.

`FullScan` and event indices cover **pinned lists plus the hub-selected list** (`TE:SetObservedList`). Calendar-gated sections fail open until `CALENDAR_UPDATE_EVENT_LIST` has fired, then hide when the event is known-inactive.

## Lifecycle

1. **`OnAddonLoaded`** — init DB (`ns.db`), register slash commands
2. **`OnPlayerLogin`** — hub tab registration, engine init, presets, map UI wiring
3. **`OnPlayerEnteringWorld`** — engine rescan after zone/login transitions

Follows suite orchestrator hooks (no per-file `ADDON_LOADED` init) — see [ARCHITECTURE.md](../../OneWoW/Docs/ARCHITECTURE.md) §3.

## Data Model

- **Lists** — typed (`guide`, `daily`, `weekly`, `todo`, `repeating`, `farmvalue`). Categories are topic folders (not cadence). Repeating lists clear when `resetInterval` (seconds) elapses.
- **Sections / steps** — markup-capable; step types drive auto-tracking predicates. Open-world kills use `kill_creature` (`PARTY_KILL` + fill from target). Dungeon and raid bosses use `kill_encounter` (`ENCOUNTER_END` combat ID + `C_RaidLocks`); unit GUIDs are secret in instances so creature fill cannot work there.
- **Farm value** — watchlist or all unbound stacks; optional session baseline snapshot

## Integration Points

- **OneWoW hub** — `ModuleRegistry` tab `"trackers"`; minimap open path
- **OneWoW_QoL** — weekly reset region picker via `OneWoW_Trackers_API`
- **Map** — `TrackerMap` pins coordinate steps for pinned lists
- **Pricing** — AH via OneWoW/Auctionator; TSM when present
