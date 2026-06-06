---
name: onewow-suite-architecture
description: Use when authoring or reviewing OneWoW suite load units — lifecycle hooks, BootStore, BringUp/EnsureLoaded, enable/opt-out, ModuleManifest, hub tab order, OptionalDeps, or cross-unit integration.
---

# OneWoW Suite Architecture Skill

## Context

The suite ships as separate load units (TOCs) but behaves as one product. The **core orchestrator** (`OneWoW/Core/AddonLoader.lua`) owns when units load and drives lifecycle hooks — feature modules and stores must **chain up**, not register `ADDON_LOADED` / `PLAYER_LOGIN` / `PLAYER_ENTERING_WORLD` for init.

Full rationale and tables: `OneWoW/Docs/ARCHITECTURE.md`.

## Authoritative sources

1. `OneWoW/Docs/ARCHITECTURE.md` — source of truth
2. `OneWoW/Core/AddonLoader.lua` — `ModuleManifest`, `BringUp`, `EnsureLoaded`, enable API
3. `OneWoW/Core/Lifecycle.lua` — dispatch, handler registries
4. `OneWoW/Core/StoreBootstrap.lua` — `OneWoW:BootStore` for data stores

## Lifecycle decision table

| I need to… | Do this | Do NOT |
|------------|---------|--------|
| Init my module DB | `OnAddonLoaded()` on manifest root | `RegisterEvent("ADDON_LOADED")` |
| Arm at login | `OnPlayerLogin()` or `RegisterLoginHandler` | `RegisterEvent("PLAYER_LOGIN")` |
| React to zone / entering world | `OnPlayerEnteringWorld` with `if isZoning`, or `RegisterEnteringWorldHandler` | `RegisterEvent("PLAYER_ENTERING_WORLD")` |
| Hook Blizzard_Foo when it loads | `RegisterAddonLoadedWatcher("Blizzard_Foo", fn)` | Own `ADDON_LOADED` frame |

**PEW vs gameplay:** lifecycle entering-world collection → `BootStore.onEnteringWorld` or `RegisterEnteringWorldHandler`. Gameplay events (`PLAYER_ALIVE`, `BAG_UPDATE`, `MAIL_SHOW`, …) may use direct `RegisterEvent`.

## Feature module template

```lua
function ns.OnAddonLoaded()
    OneWoW.Lifecycle:CreateHandlerRegistry(ns)
    -- init DB, register sub-module handlers
end

function ns.OnPlayerLogin()
    -- arm passive hooks
    ns:FireLoginHandlers()
end

function ns.OnPlayerEnteringWorld(isLogin, isReload, isZoning)
    ns:FireEnteringWorldHandlers(isLogin, isReload, isZoning)
end

-- Sub-module (never RegisterEvent lifecycle):
ns:RegisterLoginHandler("feature", fn)
ns:RegisterEnteringWorldHandler("feature", function(isLogin, isReload, isZoning)
    if isZoning then ... end
end)
```

## Data store template

```lua
OneWoW:BootStore(ns, {
    savedVar = "OneWoW_MyStore_DB",
    onLogin = function()
        ns.DataManager:Initialize()
        ns.DataManager:RegisterEvents()  -- gameplay events only
    end,
    onEnteringWorld = function()
        ns.DataManager:OnEnteringWorld()  -- PEW work via core dispatch
    end,
})
```

`PLAYER_ALIVE` (resurrection) stays on the gameplay event frame; it is not a lifecycle substitute for PEW.

## Mid-session load

`OneWoW:BringUp(addon)` loads `{ addon, ...stores }`, runs `OnPlayerLogin` via `Settle`, then synthetic `OnPlayerEnteringWorld(true, false, false)` for units that missed the real PEW. Raw `RegisterEvent("PLAYER_ENTERING_WORLD")` **misses** mid-session enable.

## Enable model

- **Blizzard enable** — hard layer; reload to load login-disabled units.
- **Soft opt-out** (`featureOptOut`) — orchestrator skips; reload-free re-enable via `EnsureLoaded`.
- Read: `IsFeatureWanted`, `GetFeatureUnitState` (includes `pending_disable`).
- Writes: Manage Features only (`FirstRunWizard.lua`); Home is read-only.

## Loader API

```lua
OneWoW:EnsureLoaded(name [, opts])     -> ok, reason?
OneWoW:WithAddon(name, onReady, onFail, opts)
OneWoW:BringUp(addonName)
OneWoW:GetLoadFailureText(reason)
```

Use `WithAddon` / `EnsureLoaded` for **explicit user actions** only (e.g. AH scan pulling `OneWoW_AltTracker_Auctions`), not speculative tab opens.

## Hub UI

**Load order** is manifest array order (`RunStartupPhase`). **Row-1 tab display
order** is the explicit `tabOrder` field on hub manifest entries — required when
adding a hub tab (`module` + `tabOrder` on the manifest entry).

```lua
-- Manifest (AddonLoader.lua): module + tabOrder decouple display from load order
{ addon = "OneWoW_Catalog", module = "catalog", tabOrder = 3, loadPhase = "login", ... }

-- Module registration (unchanged API)
OneWoW:RegisterModule({
    name = "catalog",
    order = OneWoW:GetModuleTabOrder("catalog"),
    addonName = "OneWoW_Catalog",
    -- ...
})
```

Placeholder tabs when unloaded: `OneWoW:GetAlwaysShowModules()`.

## OptionalDeps / TOC

- **Never** list suite-internal `OneWoW_*` in `## OptionalDeps` — Blizzard auto-load bypasses soft opt-out.
- External deps (TSM, Auctionator, Baganator, Masque, `!BugGrabber`) are fine.

## Cross-unit sharing

- Within unit: `local _, ns = ...`
- Across units: `OneWoW`, `OneWoW_GUI`, per-unit `_API` globals
- Prefer `_API` over `_DB`; new cross-unit reads → `DataManager:Query` when implemented
- Layering: no direct cross-family store global reads (see `check_no_data_manager_bypass.py`)

## PR checklist

1. `python -m pre_commit run --all-files`
2. No lifecycle `RegisterEvent` in orchestrated units (`no-suite-lifecycle-events`)
3. No suite-internal `OptionalDeps` in changed TOCs
4. No new cross-family store reads (data-manager hook; Phase 1 warns)
5. Stores use `BootStore` + `onEnteringWorld` for PEW collection work
