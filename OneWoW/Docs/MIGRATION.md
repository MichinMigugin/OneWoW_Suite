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
