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

- [x] Migrated `OneWoW_AltTracker`'s inline `InitializeDatabase` to the
  `DB:Init` + defaults-table pattern the other hub modules use, relocated into
  `OneWoW_AltTracker/Core/Database.lua`. The AltTracker data stores use
  account-wide per-character aggregation via `OneWoW:BootStore` (shape from
  `defaults`) and the `DB:GetCharData` helper family, reading/writing the live
  SavedVariable global directly. Progress
  "overrides" moved to a static baseline (`Data/d-overrides.lua`) with SV holding
  only user customizations behind `ns:GetProgressList` / `ns:EnsureProgressList`,
  and AltTracker data units read the effective lists via the public
  `OneWoW_AltTracker:GetProgressList`.
- [x] Removed `DB:NewCompat` from `OneWoW/GUI/Database.lua` — AltTracker was the
  last runtime caller and went dead once the migration landed. Cleared the
  `DB:NewCompat` mention in the `Database.lua` canonicalizer doc comment; the
  `OneWoW_Notes/Core/Database.lua` bridge comment is historical provenance for an
  on-disk layout and stays.

---

## 2. `OneWoW/GUI/Database.lua` cleanup

Independent of items 1 and 5 — no ordering constraint. Both the `config.aceDB`
*Init mode* and the AceDB-*format* drop-in `DB:NewCompat` are now gone:
`config.aceDB` had no callers, and `DB:NewCompat`'s last caller (`OneWoW_AltTracker`)
was retired by item 1. `DB:Init` is `single`/`split` only.

- [x] Remove AceDB-mode support: the `config.aceDB` branch in `DB:Init`, the
  `acedb` branches in `TryResolveSpec` / `SetActivePreset`, and the
  `DB:Init requires config.savedVar or config.aceDB` error path. Verified no
  caller passes `config.aceDB` (only the definitions reference it), so removal
  is safe.
- [x] Remove `DB:NewCompat` (AceDB-format drop-in) once item 1 retired its last
  caller. Docs (`DATABASE.md`, `onewow-database-api` skill) repointed off the
  AceDB-format compat path.
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

- [x] Replace direct theme-constant access (e.g.
  `component:SetColorTexture(unpack(themeData.ACCENT_PRIMARY))`) with
  `OneWoW_GUI:GetThemeColor(key)` or `GetThemeColor(key, themeKey)` for
  non-active preview swatches (`Settings.lua` theme picker).
- [x] Large-sweep audit of direct numeric color calls: semantic status/muted/danger
  literals converted to theme keys; structural tokens added to
  `OneWoW_GUI.Constants` (`WOW_QUEST_GOLD`, `OVERLAY_DIM`, `ICON_OVERLAY_TEXT`);
  `TintScrollReorderButtons` helper added. **Remaining per-file work** (documented
  in `GUI.md` §Theme System): `t-quests` row backdrops, DevTool editor chrome,
  `minimapbuttons` container, optional lint hook.

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
