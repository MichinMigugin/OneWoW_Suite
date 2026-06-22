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

## 3. Addon global-surface cleanup

Canonical rules: [`ARCHITECTURE.md`](ARCHITECTURE.md) §6.1. Enforcement:
`bin/check_no_namespace_publish.py` (pre-commit `no-namespace-publish`; **warn-only**
until the inventory is drained).

### Per-unit checklist

1. Vararg namespace: `local ADDON_NAME, ns = ...` (not `local ADDON_NAME, OneWoW_Bags = ...`).
2. DB handle: `ns.db = DB:Init(...)` in `InitializeDatabase`; internal reads via `ns.db`.
3. Lifecycle root: `OneWoW_<Unit> = {}` with colon hooks only (`OnAddonLoaded`, `ApplyTheme`, …).
4. Cross-unit surface: `OneWoW_<Unit>_API` dot-functions; no colon-methods on `_API`.
5. Remove hops: `ns.addon`, `ns.OneWoWAltTracker`, `local addon = {}; OneWoW_<Unit> = addon`.
6. No `.db` or `.UI` on the lifecycle root; no hand `_G[...] = ns`.

### Suggested migration order

1. **AltTracker family** — hub + stores mostly compliant; hub needs `OneWoW_AltTracker_API` and `ns.db`.
2. **Catalog / Notes** — separate lifecycle object vs `ns`; Notes still publishes `ns`.
3. **Bags** — largest (namespace renamed to global; full module graph on `_G`).

### Grandfathered (hook allowlist)

Remove each path from `ALLOWED_NAMESPACE_PUBLISH` in
`bin/check_no_namespace_publish.py` when that unit's migration is complete:

- `OneWoW/Core/StoreBootstrap.lua` (until unit registry — §2)
- `OneWoW_Bags/OneWoW_Bags.lua`
- `OneWoW_Notes/OneWoW_Notes.lua`

### Flip to enforced

Set `WARN_ONLY = False` in `check_no_namespace_publish.py` when:

- The warn-only worklist is empty (or only BootStore remains), and
- Hub/store migrations above are landed.

Per-unit `Docs/ARCHITECTURE.md` files that still say "access `_DB` directly" should
be scrubbed when each unit migrates (not blocking this doc pass).
