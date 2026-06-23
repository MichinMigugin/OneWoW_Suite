# OneWoW Suite — Remaining migration

Active checklist for the few items still open. Implemented architecture lives in
[`ARCHITECTURE.md`](ARCHITECTURE.md) — read that first. Delete this file once the
items below are done.

**Global-surface migration is complete** (hubs, stores, core facade, unit registry).
Canonical rules and enforcement: [`ARCHITECTURE.md`](ARCHITECTURE.md) §6.1 and
`bin/check_no_namespace_publish.py` (pre-commit `no-namespace-publish`; enforced).

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

## 2. Optional follow-ups (non-blocking)

| Item | Where | Notes |
|------|-------|-------|
| `ModuleRegistry:GetModuleBucket(id)` | `OneWoW_QoL/Modules/ModuleRegistry.lua` | Optional DRY helper for ~17 external `GetDB()` copies |
