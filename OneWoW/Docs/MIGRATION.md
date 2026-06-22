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

## 2. Retire the `_G[addonName] = ns` lifecycle stop-gap

`OneWoW:BootStore` currently publishes `_G[config.addonName] = ns` so the core
lifecycle dispatcher (`Lifecycle.RunUnitHook`) can resolve a load unit and call
its `OnAddonLoaded` / `OnPlayerLogin` / `OnPlayerEnteringWorld` hooks. This is the
**one sanctioned namespace publish** in the suite (centralized so its removal is a
single edit) but it still leaks each store's namespace globally — the practice the
encapsulation work otherwise retired. Authors must never hand-write it; the rule is
documented in `ARCHITECTURE.md` §6, the `OneWoW-Suite-Architecture.mdc` rule, and
the `onewow-suite-architecture` skill.

Longer-term replacement:

- Add a core-private unit registry: `BootStore` (and the manifest roots) register
  `addonName → ns`; `Lifecycle.RunUnitHook` resolves that registry instead of
  `_G[addonName]`.
- Delete the `_G[config.addonName] = ns` line in `OneWoW/Core/StoreBootstrap.lua`.
- Drop the remaining manifest-root `OneWoW_<Root> = ns` / `_G[...]` publishes.
- Migrate the last bare-namespace reader — `OneWoW_ShoppingList/Modules/DataAccess.lua`
  reads `OneWoW_CatalogData_Tradeskills` — to a `OneWoW_CatalogData_Tradeskills_API`
  getter.

---

## 3. Global-surface cleanup (suite-wide)

Canonical rules: [`ARCHITECTURE.md`](ARCHITECTURE.md) §6.1. Enforcement:
`bin/check_no_namespace_publish.py` (pre-commit `no-namespace-publish`; **warn-only**
until the inventory is drained).

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
| `OneWoW_AltTracker` | `ns` | `OneWoW_AltTracker = {}` | `lifecycle_root_db`, colon `GetProgressList` → `_API` | **First migration** — hub + stores |
| AltTracker_* stores (8) | `ns` | BootStore + `_API` | StoreBootstrap publish only | Stores are reference shape |
| `OneWoW_QoL` | `ns` | `OneWoW_QoL = {}` | scattered `OneWoW_QoL.db` in UI/modules | Thin root; small `.db` sweep |
| CatalogData_* stores (4) | `ns` | BootStore + `_API` | StoreBootstrap publish only | Reference shape |

**Tier B — thin lifecycle root, namespace mostly private**

| Load unit | Vararg today | Global publish today | Hook / debt | Notes |
|-----------|--------------|----------------------|-------------|-------|
| `OneWoW_Catalog` | `ns` | `OneWoW_Catalog = addon` | `ns.addon`, `OneWoW_Catalog.db` | Drop `addon` hop; `_API` for ItemDataLoader |
| `OneWoW_AltTracker_Accounting` | `ns` | `_API` only | minimal | Already compliant |

**Tier C — namespace published as global**

| Load unit | Vararg today | Global publish today | Hook / debt | Notes |
|-----------|--------------|----------------------|-------------|-------|
| `OneWoW_ShoppingList` | `ns` | `OneWoW_ShoppingList = ns` | `assign_ns`, locale vararg | Small unit |
| `OneWoW_Trackers` | `ns` | `_G["OneWoW_Trackers"] = ns` | `g_assign_ns`, `OneWoW_Trackers.db` | |
| `OneWoW_DirectDeposit` | `OneWoW_DirectDeposit` | `_G["OneWoW_DirectDeposit"] = …` | `renamed_ns_vararg`, many `.db` | Bags-like |
| `OneWoW_Notes` | `ns` | `_G["OneWoW_Notes"] = ns` | root grandfathered; 11 child hits (mostly `.db`) | |
| `OneWoW_Utility_DevTool` | `Addon` | `OneWoW_Utility_DevTool = Addon` | `renamed_addon_vararg` | DevTool rename |

**Tier D — namespace-as-global (largest)**

| Load unit | Vararg today | Global publish today | Hook / debt | Notes |
|-----------|--------------|----------------------|-------------|-------|
| `OneWoW_Bags` | `OneWoW_Bags` (all files) | `_G["OneWoW_Bags"] = …` | root grandfathered; 67 hook entries (vararg + `.db`) | Largest unit |

**Tier E — core orchestrator (last; ties to §2)**

| Load unit | Vararg today | Global publish today | Hook / debt | Notes |
|-----------|--------------|----------------------|-------------|-------|
| `OneWoW` | `OneWoW` (all `OneWoW/**` files) | `_G["OneWoW"] = OneWoW` | `renamed_core_vararg`, `g_assign_core_ns`, `OneWoW.db` | Facade refactor + unit registry |

### Recommended migration order

1. **AltTracker family** — hub first (`ns.db`, `OneWoW_AltTracker_API`, drop `ns.OneWoWAltTracker`); stores already on BootStore + `_API`.
2. **Catalog** — drop `ns.addon` hop; move colon helpers to `OneWoW_Catalog_API`; `ns.db`.
3. **QoL** — thin root is done; sweep `OneWoW_QoL.db` → `ns.db` in UI/modules.
4. **ShoppingList, Trackers, DirectDeposit** — stop `= ns` / renamed-vararg publish; thin lifecycle root + `ns.db`.
5. **Notes** — migrate children off `OneWoW_Notes.db`; then remove root `_G` publish.
6. **Bags** — rename vararg suite-wide; split facade vs `ns`; remove root publish last in unit.
7. **DevTool** — `Addon` → `ns`; thin root.
8. **OneWoW core** — `OneWoW/**` → `ns`; curated `OneWoW` facade; pair with §2 unit registry.

Data stores (AltTracker_*, CatalogData_*) need no global-surface migration beyond
retiring BootStore's `_G[addonName] = ns` when §2 lands.

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
| `ns_addon_backref` | 1 | `ns.addon =` (Catalog) |

By load unit (unique `path::pattern` entries): Bags 67, core 29, DevTool 14, QoL 11,
Notes 11, DirectDeposit 9, Trackers 4, ShoppingList 3, AltTracker 3, Catalog 2.

### Grandfathered (hook allowlist)

Remove each path from `ALLOWED_NAMESPACE_PUBLISH` in
`bin/check_no_namespace_publish.py` when that unit's migration is complete:

- `OneWoW/Core/StoreBootstrap.lua` (until unit registry — §2)
- `OneWoW_Bags/OneWoW_Bags.lua` (publish line only; **not** the whole Bags tree)
- `OneWoW_Notes/OneWoW_Notes.lua` (publish line only; **not** the whole Notes tree)

### Flip to enforced

Set `WARN_ONLY = False` in `check_no_namespace_publish.py` when:

- The warn-only worklist is empty (or only BootStore remains), and
- Tiers A–E migrations above are landed.

Per-unit `Docs/ARCHITECTURE.md` files that still say "access `_DB` directly" should
be scrubbed when each unit migrates.
