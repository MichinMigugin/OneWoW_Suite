# OneWoW Suite — Remaining migration

Active checklist for the few items still open. Implemented architecture lives in
[`ARCHITECTURE.md`](ARCHITECTURE.md) — read that first.

The bulk of the migration is done and folded into `ARCHITECTURE.md`: core
lifecycle hygiene, the settings-access funnel, absorbing `OneWoW_GUI` into core
(incl. retiring the SV-handoff stub), the OneWoW half of the SV → `OneWoW_GUI.DB`
move, all feature moves into `OneWoW_QoL`, and DevTool's in-repo conversion. The
`RunMigrations` collapse for every unit is also complete (assumes users have
logged in on a recent build). Delete this file once the items below are done.

---

## 1. AltTracker SV → `OneWoW_GUI.DB` API

The last load unit not fully on the DB API. Independent — no ordering constraint.

- [ ] Migrate `OneWoW_AltTracker`'s inline `InitializeDatabase` (~80 lines in
  `OneWoW_AltTracker.lua`) to the `DB:Init` + defaults-table pattern the other
  hub modules use; fold any ad-hoc shape fixes into `DB:RunMigrations`.

---

## 2. DevTool packaging (external — CurseForge-side)

In-repo work is complete: `LoadOnDemand: 1` + manifest `loadPhase = "login"`,
`utility`-tagged in Manage Features (Recommended preset opts it out), and no
standalone AddonCompartment (reachable via slash + the OneWoW minimap
right-click). In-repo TOC branding already matches the suite and there is no
in-repo packaging manifest, so these are CurseForge listing tasks only:

- [ ] Fold into the suite package branding (single distributable).
- [ ] Retire the standalone CurseForge page.

---

## 3. ModuleRegistry conditional-UI audit

- [ ] Audit for `ModuleRegistry:IsRegistered(...)` / `GetModule(...)`-conditional
  UI placement to confirm every spot degrades cleanly when a module is not
  loaded (opted out / Blizzard-disabled / LoD-not-yet-loaded). The known step-9
  hazards are already gone — the `UI/t-settings.lua` `BuildSettingsTabs` fallback
  and `portalhub-esc.lua`'s branch were removed, and placeholder row-1 tabs now
  route through `OneWoW:GetAlwaysShowModules()`. Only a benign re-select guard
  remains in `UI/MainWindow.lua`. Verify nothing else branches on module
  presence, then close this out.

---

## 4. `DataManager` enforcement ramp (future)

`bin/check_no_data_manager_bypass.py` (hook `no-data-manager-bypass`) phases direct
cross-family store reads toward `DataManager:Query` (see `ARCHITECTURE.md` §7).
Blocked on `DataManager:Query` actually being implemented and on cross-family
reads being migrated onto it.

| Phase | Lint behavior | Allowlist | Exit code |
|---|---|---|---|
| **1 — now** | warn-only on cross-family reads | all grandfathered reads listed | `0` |
| **2 — migrating** | warn on allowlisted; **fail** on new off-list reads | shrinks per migration PR | `1` for off-list only |
| **3 — rule** | hard-fail on every cross-family read | empty (removed) | `1` |

- [ ] Phase 2: populate `ALLOWLIST` from warn output, set `WARN_ONLY = False`.
- [ ] Phase 3: empty allowlist, hard-fail all cross-family reads.

Each migration PR deletes allowlist `path::symbol` keys. When the allowlist is
empty, flip to Phase 3.
