# OneWoW Suite — Remaining migration

Active checklist for the few items still open. Implemented architecture lives in
[`ARCHITECTURE.md`](ARCHITECTURE.md) — read that first. Delete this file once the
items below are done.

The bulk of the migration is complete and folded into `ARCHITECTURE.md`: core
lifecycle hygiene, the settings-access funnel, absorbing `OneWoW_GUI` into core,
the SV → `OneWoW_GUI.DB` move (incl. AltTracker and the `DB:NewCompat` /
`config.aceDB` removals), feature moves into `OneWoW_QoL`, DevTool's in-repo
conversion, the `RunMigrations` collapse, the `OneWoW.Restriction` combat/restriction
funnel, and the **suite-wide SavedVariables encapsulation** (every cross-unit
access now routes through the owner's `OneWoW_<Unit>_API`; the
`no-data-manager-bypass` hook is enforced/hard-failing off its `ALLOWED_FOREIGN_SV`
allowlist).

---

## 1. Theme color usage — per-file remainder

The large-sweep theme-color audit is done (semantic literals → theme keys,
structural tokens added to `OneWoW_GUI.Constants`, `TintScrollReorderButtons`
helper). A handful of per-file cleanups remain and are **tracked in
[`GUI.md`](GUI.md) §Theme System** (the source of truth for this list):

- `t-quests` row backdrops
- DevTool editor chrome
- `minimapbuttons` container
- optional theme-literal lint hook

---

## 2. Retire the `_G[addonName] = ns` lifecycle stop-gap — **complete**

`OneWoW:BootStore` registers each store via `OneWoW.Lifecycle.RegisterUnit(addonName, storeNs)` in
[`OneWoW/Core/StoreBootstrap.lua`](../Core/StoreBootstrap.lua). `Lifecycle.RunUnitHook` resolves units
through `Lifecycle.ResolveUnit` (registry first, hub thin roots still in `_G` as fallback). The
`_G[config.addonName] = ns` publish was removed in step 8.

---

## 3. Global-surface cleanup (suite-wide)

Canonical rules: [`ARCHITECTURE.md`](ARCHITECTURE.md) §6.1. Enforcement:
`bin/check_no_namespace_publish.py` (pre-commit `no-namespace-publish`; **enforced**).

### Per-unit checklist

1. Vararg namespace: `local ADDON_NAME, ns = ...` (never rename to `OneWoW`, `OneWoW_Bags`, `Addon`, …).
2. DB handle: `ns.db = DB:Init(...)` in `InitializeDatabase`; internal reads via `ns.db`.
3. **Hub / feature units:** `OneWoW_<Unit> = {}` with colon hooks only (`OnAddonLoaded`, `ApplyTheme`, …).
4. **Core:** `OneWoW` stays the orchestrator global (colon API + `OneWoW.*` services) but must stop publishing raw `ns` — curated facade only.
5. Cross-unit surface: `OneWoW_<Unit>_API` dot-functions; no colon-methods on `_API`.
6. Remove hops: `ns.addon`, `ns.OneWoWAltTracker`, `local addon = {}; OneWoW_<Unit> = addon`.
7. No `.db` or `.UI` on published globals when that global is a leaked namespace; use `ns.db` internally.
8. No hand `_G[...] = ns` or `OneWoW_<Unit> = ns`.

### Full inventory (manifest roots + data stores)

**Tier A — target shape already close (start here)**

| Load unit | Vararg today | Global publish today | Hook / debt | Notes |
|-----------|--------------|----------------------|-------------|-------|
| `OneWoW_AltTracker` | `ns` | `OneWoW_AltTracker = {}` + `OneWoW_AltTracker_API` | **done** (hub global surface) | Reference hub — `ns.db`, `_API`, no `ns.OneWoWAltTracker` |
| AltTracker_* stores (8) | `ns` | BootStore registry + `_API` in `Core/API.lua` | **done** | reference store layout (`OneWoW_AltTracker_Storage`) |
| `OneWoW_QoL` | `ns` | `OneWoW_QoL = {}` + `OneWoW_QoL_API` | **done** (hub global surface) | Reference hub — `ns.db`, `_API` in `Core/API.lua` |
| `OneWoW_Catalog` | `ns` | `OneWoW_Catalog = {}` + `OneWoW_Catalog_API` | **done** (hub global surface) | Reference hub — `ns.db`, `_API` in `Core/API.lua` |
| CatalogData_* stores (4) | `ns` | BootStore registry + `_API` in `Core/API.lua` | **done** | reference store layout |

**Tier C — namespace published as global**

| Load unit | Vararg today | Global publish today | Hook / debt | Notes |
|-----------|--------------|----------------------|-------------|-------|
| `OneWoW_ShoppingList` | `ns` | `OneWoW_ShoppingList = {}` + `OneWoW_ShoppingList_API` | **done** (hub global surface) | Reference hub — `ns.db`, `_API` in `Core/API.lua` |
| `OneWoW_Trackers` | `ns` | `OneWoW_Trackers = {}` + `OneWoW_Trackers_API` | **done** (hub global surface) | Reference hub — `ns.db`, `_API` in `Core/API.lua` |
| `OneWoW_DirectDeposit` | `ns` | `OneWoW_DirectDeposit = {}` + `OneWoW_DirectDeposit_API` | **done** (hub global surface) | Reference hub — `ns.db`, `_API` in `Core/API.lua` |
| `OneWoW_Notes` | `ns` | `OneWoW_Notes = {}` + `OneWoW_Notes_API` | **done** (hub global surface) | Reference hub — `ns.db`, `_API` in `Core/API.lua` |
| `OneWoW_Bags` | `ns` | `OneWoW_Bags = {}` + `OneWoW_Bags_API` | **done** (hub global surface) | Reference hub — `ns.db`, `_API` in `Core/API.lua` |
| `OneWoW_Utility_DevTool` | `ns` | `OneWoW_Utility_DevTool = {}` + `OneWoW_Utility_DevTool_API` | **done** (hub global surface) | Reference hub — `ns.db`, `_API` in `Core/API.lua` |

**Tier D — namespace-as-global (largest)**

| Load unit | Vararg today | Global publish today | Hook / debt | Notes |
|-----------|--------------|----------------------|-------------|-------|
| _(none — Bags migrated to Tier C)_ | | | | |

**Tier E — core orchestrator**

| Load unit | Vararg today | Global publish today | Hook / debt | Notes |
|-----------|--------------|----------------------|-------------|-------|
| `OneWoW` | `ns` | curated `OneWoW` facade (`Core/Facade.lua`) | **done** | `ns.db` internal; unit registry; no `OneWoW.db` |

### Recommended migration order

1. **AltTracker family** — **complete**
2. **Catalog family** — **complete**
3. **QoL** — **complete**
4. **ShoppingList / Trackers / DirectDeposit** — **complete**
5. **Notes** — **complete**
6. **Bags** — **complete**
7. **DevTool** — **complete**
8. **OneWoW core** — **complete** (`OneWoW/**` → `ns`; curated facade in `Core/Facade.lua`; unit registry).

Data stores need no further global-surface migration beyond the BootStore registry (§2, complete).

### 3.1 Core/API.lua consolidation

When a unit exposes `OneWoW_<Unit>_API`, prefer **`Core/API.lua`**; root lua is
lifecycle-only (hub modules) or a comment stub (data stores). Canonical store
layout: `Core/Database.lua` → `Core/API.lua` → `Core/Core.lua` (BootStore) →
modules → root stub — see `OneWoW_AltTracker_Storage`.

**AltTracker status**

| Unit | API location | Status |
|------|--------------|--------|
| `OneWoW_AltTracker` | `Core/API.lua` | done |
| `OneWoW_AltTracker_Storage` | `Core/API.lua` | done |
| `OneWoW_AltTracker_Accounting` | `Core/API.lua` | done |
| `OneWoW_AltTracker_Endgame` | `Core/API.lua` | done |
| `OneWoW_AltTracker_Character` | `Core/API.lua` | done |
| `OneWoW_AltTracker_Collections` | `Core/API.lua` | done |
| `OneWoW_AltTracker_Professions` | `Core/API.lua` | done |
| `OneWoW_AltTracker_Auctions` | `Core/API.lua` | done |

**Catalog + CatalogData status**

| Unit | API location | Status |
|------|--------------|--------|
| `OneWoW_Catalog` | `Core/API.lua` | done |
| `OneWoW_CatalogData_Quests` | `Core/API.lua` | done |
| `OneWoW_CatalogData_Journal` | `Core/API.lua` | done |
| `OneWoW_CatalogData_Tradeskills` | `Core/API.lua` | done |
| `OneWoW_CatalogData_Vendors` | `Core/API.lua` | done |

**QoL status**

| Unit | API location | Status |
|------|--------------|--------|
| `OneWoW_QoL` | `Core/API.lua` | done |

**ShoppingList status**

| Unit | API location | Status |
|------|--------------|--------|
| `OneWoW_ShoppingList` | `Core/API.lua` | done |

**Trackers status**

| Unit | API location | Status |
|------|--------------|--------|
| `OneWoW_Trackers` | `Core/API.lua` | done |

**DirectDeposit status**

| Unit | API location | Status |
|------|--------------|--------|
| `OneWoW_DirectDeposit` | `Core/API.lua` | done |

**Notes status**

| Unit | API location | Status |
|------|--------------|--------|
| `OneWoW_Notes` | `Core/API.lua` | done |

**Bags status**

| Unit | API location | Status |
|------|--------------|--------|
| `OneWoW_Bags` | `Core/API.lua` | done |

**DevTool status**

| Unit | API location | Status |
|------|--------------|--------|
| `OneWoW_Utility_DevTool` | `Core/API.lua` | done |

**Backlog (file placement only)**

| Load unit | API location today | Notes |
|-----------|-------------------|-------|
| _(none)_ | — | Notes backlog cleared |

### Run the inventory

Warn-only hook (prints worklist at end):

```bash
python -m pre_commit run no-namespace-publish --all-files
```

Or per-file (worklist prints when violations exist):

```bash
python bin/check_no_namespace_publish.py path/to/file.lua
```

First full-repo scan (Jun 2026, expanded hook): **153 unique `path::pattern`
entries** (~327 line-level `[warn]` hits), dominated by:

| Pattern | Count | Meaning |
|---------|------:|---------|
| `renamed_ns_vararg` | 73 | `local ADDON_NAME, OneWoW_* = ...` (mostly Bags) |
| `lifecycle_root_db` | 43 | `OneWoW.db` / `OneWoW_<Unit>.db` instead of `ns.db` |
| `renamed_core_vararg` | 17 | `local ADDON_NAME, OneWoW = ...` in `OneWoW/**` |
| `renamed_addon_vararg` | 14 | `local ADDON_NAME, Addon = ...` (DevTool) |
| `g_assign_*` / `assign_ns` | 4 | namespace published as global |
| `ns_addon_backref` | 0 | `ns.addon =` (Catalog migrated) |

By load unit (unique `path::pattern` entries): Bags 67, core 29, DevTool 14, QoL 11,
DirectDeposit 9, Trackers 4, ShoppingList 3, AltTracker 3.

### Grandfathered (hook allowlist)

- `OneWoW/Core/Facade.lua::g_assign_core_ns` — sole `_G["OneWoW"]` publish (curated facade table, not `ns`).

### Enforcement

`WARN_ONLY = False` in `check_no_namespace_publish.py` (Jun 2026, step 8 landed).

Per-unit `Docs/ARCHITECTURE.md` files that still say "access `_DB` directly" should
be scrubbed when each unit migrates.

---

## 4. Follow-ups (deferred / post-migration analysis)

Items intentionally deferred from landed migration PRs or awaiting a **full
addon-by-addon pass** after steps 4–8. Not blocking the current order; delete or
move entries to `ARCHITECTURE.md` when resolved.

### QoL — deferred from item 3 PR

| Item | Where | Notes |
|------|-------|-------|
| `ModuleRegistry:GetModuleBucket(id)` | `OneWoW_QoL/Modules/ModuleRegistry.lua` | Optional DRY helper for ~17 external `GetDB()` copies; not required for `ns.db` sweep |
| `RegisterAddonLoadedWatcher` consolidation | `map_mini_tools-engine.lua`, `map_world_tools-engine.lua`, `framemover-core.lua` | Prefer `OneWoW:RegisterAddonLoadedWatcher` (pattern in `tp-technicalids.lua`) over lifecycle-root `OneWoW_QoL:RegisterAddonLoadedWatcher` fallbacks |
| In-game smoke (QoL) | manual | Hub tabs, module enable/disable, profiles capture/apply, context-menu playmounts, `/1wqol` |

### Catalog — deferred from item 2 PR

| Item | Where | Notes |
|------|-------|-------|
| In-game smoke (Catalog) | manual | Vendor `OpenToVendor`, quests favorites, item search, hub tab |

### ShoppingList — deferred from step 4a PR

| Item | Where | Notes |
|------|-------|-------|
| In-game smoke (ShoppingList) | manual | `/1wsl`, keybindings, lists/add item, bag/AH buttons, profession integration, Bags title-bar icon, core search, alt counts, quality variants |

### Trackers — deferred from step 4b PR

| Item | Where | Notes |
|------|-------|-------|
| In-game smoke (Trackers) | manual | `/1wt`, hub tab vs standalone, lists/edit/pinned, auto-complete, bundled presets, farm value, QoL weekly-reset picker, profile theme refresh |

### DirectDeposit — deferred from step 4c PR

| Item | Where | Notes |
|------|-------|-------|
| In-game smoke (DirectDeposit) | manual | `/1wdd`, `/dd`, keybindings, main window tabs, Bags title-bar icon, core search, profile theme, manual/auto deposit |

### Notes — deferred from step 5 PR

| Item | Where | Notes |
|------|-------|-------|
| In-game smoke (Notes) | manual | `/1wn`, hub tabs, pins, context-menu player/NPC navigation, keybinding, help panel dismiss on hub switch |

### DevTool — deferred from step 7 PR

| Item | Where | Notes |
|------|-------|-------|
| In-game smoke (DevTool) | manual | `/1wdt`, all tabs, error logger + binding, minimap badge, profile theme, editor snippets, pinned monitors |

### Core — deferred from step 8 PR

| Item | Where | Notes |
|------|-------|-------|
| In-game smoke (Core) | manual | `/ow`, hub tabs, minimap, profiles/theme/language, `EnsureLoaded`/`BringUp`, store login + hub login, portal hub favorites, zone transition lifecycle |

### Suite-wide (cross-link — see sections above)

| Item | Tracked in | Notes |
|------|------------|-------|
| BootStore `_G[addonName] = ns` retirement | §2 | **complete** — unit registry |
| DirectDeposit → Notes → Bags → DevTool → core | §3 order steps 6–8 | **complete** |
| Theme color per-file remainder | §1 / `GUI.md` | `t-quests` backdrops, DevTool chrome, `minimapbuttons` container, optional lint |
| `no-namespace-publish` enforce flip | §3 end | **complete** |
| Per-unit ARCHITECTURE scrub | §3 closing note | Remove stale "access `_DB` directly" language per unit |
