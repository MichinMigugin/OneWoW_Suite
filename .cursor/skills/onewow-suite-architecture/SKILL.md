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
3. `OneWoW/Core/Lifecycle.lua` — dispatch, `RegisterUnit` / `ResolveUnit`, handler registries
4. `OneWoW/Core/Facade.lua` — curated `OneWoW` global (`GetPortalHub`, `GetCoreGlobal`)
5. `OneWoW/Core/StoreBootstrap.lua` — `OneWoW:BootStore` for data stores

## Lifecycle decision table

| I need to… | Do this | Do NOT |
|------------|---------|--------|
| Init my module DB | `OnAddonLoaded()` on manifest root | `RegisterEvent("ADDON_LOADED")` |
| Arm at login | `OnPlayerLogin()` or `RegisterLoginHandler` | `RegisterEvent("PLAYER_LOGIN")` |
| React to zone / entering world | `OnPlayerEnteringWorld` with `if isZoning`, or `RegisterEnteringWorldHandler` | `RegisterEvent("PLAYER_ENTERING_WORLD")` |
| Hook Blizzard_Foo when it loads | `RegisterAddonLoadedWatcher("Blizzard_Foo", fn)` | Own `ADDON_LOADED` frame |

**Watchers fire on both load paths** — WoW `ADDON_LOADED` and suite `C_AddOns.LoadAddOn` (LoD force-load, mid-session enable) — so the same row applies to suite LoD units and external addons alike. A filtered watcher also catches up immediately if its addon already loaded before registration. Setup fns must be idempotent (guard with a `wired` flag): catch-up + notify can both reach a late registrant, and `OverlayEngine:RegisterIntegration` / `RegisterCornerWidget` are not dedup-safe. A `nil`/wildcard filter observes **every** load (mirroring WoW `ADDON_LOADED`), including suite-internal force-loads. Use `RegisterCoreLoginHandler(id, fn, phase)` only for login-scoped work, never as an "if addon loaded at login" check. `phase` is `"early"` (core feature inits, before the load banner) or `"late"` (default; integrations). Handlers within a phase must be order-independent — never rely on registration/TOC order.

**PEW vs gameplay:** lifecycle entering-world collection → `BootStore.onEnteringWorld` or `RegisterEnteringWorldHandler`. Gameplay events (`PLAYER_ALIVE`, `BAG_UPDATE`, `MAIL_SHOW`, …) may use direct `RegisterEvent`.

## Hub module template

Core guarantees at-most-once `OnAddonLoaded` dispatch per unit; authors do not
need a local `didInit` guard for lifecycle idempotency (the chain-up contract).

Global surface: `OneWoW/Docs/ARCHITECTURE.md` §6.1.

```lua
local ADDON_NAME, ns = ...

OneWoW_MyHub = {}
local OneWoW_MyHub = OneWoW_MyHub   -- optional same-name shadow; see OneWoW-Lua-Conventions

function OneWoW_MyHub:OnAddonLoaded()
    OneWoW.Lifecycle:CreateHandlerRegistry(OneWoW_MyHub)
    ns:InitializeDatabase()  -- sets ns.db
    OneWoW_GUI:MigrateSettings(ns.db.global)
end

function OneWoW_MyHub:OnPlayerLogin()
    OneWoW_MyHub:FireLoginHandlers()
end

-- Sub-module (never RegisterEvent lifecycle):
OneWoW_MyHub:RegisterLoginHandler("feature", fn)
OneWoW_MyHub:RegisterEnteringWorldHandler("feature", function(isLogin, isReload, isZoning)
    if isZoning then ... end
end)
```

- Root lua: `OneWoW_<Unit> = {}` directly — not `local addon = {}; OneWoW_<Unit> = addon`.
- Localize the lifecycle root with same-name shadowing if needed (`local OneWoW_<Unit> = OneWoW_<Unit>`) — not renamed aliases.
- DB on `ns.db`, not on the lifecycle root.
- Hub units with cross-unit readers also publish `OneWoW_<Unit>_API` (dot-functions).

## Data store template

`addonName` is **required** — `BootStore` registers the store with
`OneWoW.Lifecycle.RegisterUnit(addonName, storeNs)` so lifecycle dispatch can
resolve hooks without publishing `ns` globally. Capture `ADDON_NAME` from the
vararg, never the global:

```lua
local ADDON_NAME, ns = ...

OneWoW:BootStore(ns, {
    addonName = ADDON_NAME,
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

`BootStore` may set `ns.db` inside `initDB`; internal reads still use `ns.db`.
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

**Raw `C_AddOns.LoadAddOn` / `UIParentLoadAddOn` is banned** outside `OneWoW/Core/AddonLoader.lua` and `OneWoW/Core/Lifecycle.lua` — it bypasses soft opt-out, combat deferral, and load tracing (pre-commit `no-raw-loadaddon`). The funnel also handles Blizzard LoD addons: `EnsureLoaded("Blizzard_InspectUI")`.

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

- Within unit: `local ADDON_NAME, ns = ...`; internal DB via `ns.db`
- Across units: `OneWoW`, `OneWoW_GUI`, per-unit `_API` globals
- Prefer `_API` over `_DB`; new cross-unit reads → `DataManager:Query` when implemented
- Layering: no direct cross-family store global reads (see `check_no_data_manager_bypass.py`)

### Global surface (summary)

See `OneWoW/Docs/ARCHITECTURE.md` §6.1 for the full taxonomy.

| Symbol | Role |
|--------|------|
| `ns` / `ns.db` | private namespace + `DB:Init` handle |
| `OneWoW_<Unit>_DB` | WoW SV global (`## SavedVariables` name) |
| `OneWoW_<Unit>_API` | cross-unit dot-functions |
| `OneWoW_<Unit>` | hub lifecycle root (colon hooks only) |
| `OneWoW` | core orchestrator singleton (colon API + `OneWoW.*` services; not raw `ns`) |
| `OneWoW_GUI` | UI toolkit singleton (colon API) |

**Colon vs dot:** `_API` uses dot-functions. `OneWoW_GUI` / `OneWoW` use colon-methods
(service / orchestrator singletons). Lifecycle root uses colon for `OnAddonLoaded`, `ApplyTheme`, etc.

### Exposing a public API

A unit's public surface is an **explicit `OneWoW_<Unit>_API` global** of declared
dot-functions (stores also expose the `_DB` global the DB layer owns). `ns` is
**reserved for the addon's own files** — the per-addon table WoW hands to every
file via `local _, ns = ...`.

**Never publish the namespace as a global** — neither the bareword
`OneWoW_<Unit> = ns` nor the dynamic `_G[ADDON_NAME] = ns` / `_G[addonName] = ns`.
It leaks every internal, hides what is actually contractual, and invites
cross-unit coupling (the cross-family hook only sees `OneWoW_`-prefixed barewords,
so a leaked namespace becomes an unpoliced back door). It is also fragile: the
core lifecycle dispatcher historically resolved units through this leaked global,
so *removing* a `= ns` line silently killed a store's `OnAddonLoaded` /
`OnPlayerLogin` hooks.

The dispatcher resolves load units via `Lifecycle.ResolveUnit` (private registry
from `BootStore`, with `_G[addonName]` fallback for hub thin lifecycle roots).
**Hub modules** use a thin `OneWoW_<Unit> = {}` lifecycle object instead.
**Never hand-publish** `OneWoW_<Unit> = ns` or `_G[...] = ns` — expose
`OneWoW_<Unit>_API` for cross-unit contracts. Publish `_API` from
**`Core/API.lua`** (hub and store units); root lua does not define `_API` — stores
use a comment stub only (`OneWoW_AltTracker_Storage` TOC is the reference).

```lua
-- Good: curated, greppable, guard-friendly
OneWoW_MyUnit_API = {}

--- One-line purpose.
---@param charKey string
---@return table|nil data
function OneWoW_MyUnit_API.GetData(charKey)
    return ns.DataManager:GetData(charKey)  -- thin wrapper over a private local
end
```

- **Declared dot-functions** (`function OneWoW_MyUnit_API.Method(...)`), not a
  table literal and not colon-methods. No `if X_API then X_API = nil end` reset.
- **Annotate the public surface only** (LuaCATS `---@param`/`---@return` + short
  prose; see `OneWoW-Code-Comments.mdc`). Thin wrappers carry the same types as
  the private locals they delegate to; locals stay unannotated. Use `---@class`
  for any return shape that recurs.
- Wrap, don't re-expose: to publish a private module (e.g. a scanner or an index
  table), add an accessor (`GetItemIndex()` → `ns.ItemIndex`) rather than hanging
  the module off the global.
- **Consumer guard = table-presence only** (`if OneWoW_MyUnit_API then`). No
  per-method checks (a missing method should error in dev, not silently no-op),
  and no top-of-file capture for optional/LoD providers — the file body would not
  re-evaluate once the provider loads later, so read the global at call time.
- When removing a `= ns` export, grep the **whole suite** for bare-namespace
  readers (`OneWoW_<Unit>.Member` and `= OneWoW_<Unit>`), not just `_API`
  consumers — in-family hub/compat files and other families both read these.

**Core global settings (cross-unit):** do not read `OneWoW.db` (not on the facade).
Use `OneWoW:GetPortalHub()` for `portalHub.*`, `OneWoW:GetCoreGlobal()` for other
`OneWoW_DB` global roots, and `OneWoW.SettingsFeatureRegistry` for `settings.*`.
When writing, cache the table in a local first — never `(OneWoW:GetCoreGlobal() or {}).field = value`
(statement-start `(` is ambiguous Lua).

## PR checklist

1. `python -m pre_commit run --all-files`
2. No lifecycle `RegisterEvent` in orchestrated units (`no-suite-lifecycle-events`)
3. No raw `C_AddOns.LoadAddOn` / `UIParentLoadAddOn` outside core (`no-raw-loadaddon`)
4. No suite-internal `OptionalDeps` in changed TOCs
5. No cross-load-unit store reads off the allowlist (`no-data-manager-bypass`, enforced/hard-fail) — route through the owner's `_API`
6. No namespace publish / global-surface anti-patterns (`no-namespace-publish`; enforced — see `ARCHITECTURE.md` §6.1)
7. No per-addon `Media/` folders (`no-per-addon-media`) — use `OneWoW/Media/` + `MEDIA_BASE`; see `GUI.md`
8. `local ADDON_NAME, ns = ...`; internal reads via `ns.db`; no `ns.addon` hops; no `.db` on lifecycle root
9. Hub cross-unit surface on `_API` dot-functions only (not colon-methods on manifest root)
10. Stores use `BootStore` + `onEnteringWorld` for PEW collection work
