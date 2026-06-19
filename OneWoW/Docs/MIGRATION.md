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
- [ ] After AltTracker is migrated, remove `DB:NewCompat` from
  `OneWoW/GUI/Database.lua` — AltTracker (`OneWoW_AltTracker.lua`) is its only
  runtime caller, so it goes dead once the migration lands. Also clear the stale
  `DB:NewCompat` mentions in the `Database.lua` doc comments and the
  `OneWoW_Notes/Core/Database.lua` bridge comment.

---

## 2. `OneWoW/GUI/Database.lua` cleanup

Independent of items 1 and 5 — no ordering constraint. **Caveat:** the dead code
here is the `config.aceDB` *Init mode*, **not** `DB:NewCompat`. `NewCompat` is the
AceDB-*format* drop-in still used by `OneWoW_AltTracker` (and bridged by
`OneWoW_Notes`); leave it until item 1 moves AltTracker onto `DB:Init`, after
which `NewCompat`'s last caller is gone and it can be retired separately.

- [x] Remove AceDB-mode support: the `config.aceDB` branch in `DB:Init`, the
  `acedb` branches in `TryResolveSpec` / `SetActivePreset`, and the
  `DB:Init requires config.savedVar or config.aceDB` error path. Verified no
  caller passes `config.aceDB` (only the definitions reference it), so removal
  is safe. Docs (`DATABASE.md`, `onewow-database-api` skill) repointed to
  `DB:NewCompat` as the remaining AceDB-format compat path.
- [x] Annotate all public `DB:*` / `OneWoW_GUI:*` functions per
  `.cursor/rules/OneWoW-Code-Comments.mdc` (LuaCATS `---@param` / `---@return` +
  short prose on the API surface; skip trivial getters).

---

## 3. Combat/restriction checks → `OneWoW.Restriction` funnel — done

`OneWoW.Restriction` is now the single funnel for combat/restriction checks.
Decisions made:

- **Two named helpers over a `combatOnly` flag** (avoids a boolean trap):
  - `IsAddonRestricted()` — combat lockdown **or** any reviewed restriction type
    active/activating; gates secure-frame mutations / protected actions.
  - `IsInCombat()` — combat lockdown only; combat-only UX/perf gates (fade,
    deferral, suppression) that are not about secure-frame safety.
- **Explicit reviewed allowlist** (`RESTRICTED_ACTION_TYPES`: Combat / Encounter /
  ChallengeMode / PvPMatch / Map) instead of iterating `Enum.AddOnRestrictionType`,
  so a future type is not silently inherited. `Chat` (added 12.0.5) is excluded
  by default.

- [x] Refactored `Restriction.lua` (allowlist + `IsInCombat()`).
- [x] Converted every raw `InCombatLockdown()` site: broad
  `IsAddonRestricted()` for secure/protected gates (Bags binding overrides +
  bank cleanup, AltTracker_Character action-bar restore, framemover, questitembar,
  portalhub esc/housing, t-portals, t-professions, map_mini_tools protected
  toggles, bagbar); `IsInCombat()` for combat-only UX/perf
  (AddonLoader defer, cursorenhancer, coords, afkpanel, tp-enhancements,
  vendorpanel, map_mini_tools fade, notes dialog `:Raise()`).
- [x] Enforced suite-wide by the `restriction-funnel` pre-commit hook
  (`bin/check_no_restriction_bypass.py`) — bans direct `InCombatLockdown` /
  `C_RestrictedActions.GetAddOnRestrictionState` /
  `C_RestrictedActions.IsAddOnRestrictionActive` outside `Restriction.lua`.
  Documented in `ARCHITECTURE.md` §8.6, the WoW-Lua rule §5, and `AGENTS.md`.

---

## 4. Theme color usage audit

Independent of items 1 and 5. Pure UI/theme hygiene against the
`OneWoW_GUI:GetThemeColor(key)` policy.

- [ ] Replace direct theme-constant access (e.g.
  `component:SetColorTexture(unpack(themeData.ACCENT_PRIMARY))`) with
  `OneWoW_GUI:GetThemeColor(key)`. **Caveat:** some `Settings.lua` swatches
  intentionally preview a *non-active* theme's `td.ACCENT_PRIMARY` — those must
  keep reading the previewed theme's data, not the active theme, so they are not
  drop-in conversions.
- [ ] Audit direct numeric color calls (e.g. `txt:SetTextColor(0.9, 0.9, 0.9)`):
  decide per-site whether the literal is correct and whether it should become a
  named theme color instead. Dynamic/data-driven colors (toast stripe colors,
  caller-supplied `bgColor`) are legitimately not theme constants — leave those.

---

## 5. `DataManager` enforcement ramp (future)

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
