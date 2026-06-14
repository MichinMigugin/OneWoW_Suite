# OneWoW Suite — Locale Service migration

Active checklist for consolidating every addon's localization onto a single
**Locale service** owned by core `OneWoW`. Read
[`ARCHITECTURE.md`](ARCHITECTURE.md) for the implemented architecture first; this
file tracks work not yet complete.

Delete this file once every box below is checked and the target-state details are
folded into `ARCHITECTURE.md`.

---

## Goal

One locale service in core. `OneWoW` fills the shared/core strings; every other
addon **reads** through the service and may **register** its own strings, which
become resolvable through the same `OneWoW.L`-style view. Model the read path on
the `ApplyTheme` → `Constants.ACTIVE_THEME` metatable wrapper
([`OneWoW_GUI.lua`](../GUI/OneWoW_GUI.lua) lines ~28–34, 123): a read-only
`__index` fallback chain with `__newindex = noop`.

### Why (problems this solves)

- **Duplication / drift.** `OneWoW_Bags` and `OneWoW_DirectDeposit` each copy the
  full `THEME_*`, `MINIMAP_*`, language-name, and `OK/CANCEL/CLOSE` clusters from
  core — 36 and 40 shared keys respectively. `OneWoW_Utility_DevTool` copies 11.
  These already drift: `THEME_NIGHTFAE` is `"Covenant Twilight"` in core but
  `"Night Fae"` in Bags.
- **Encoding inconsistency.** Core stores language names as escaped byte
  sequences (`"Espa\195\177ol"`); Bags/DirectDeposit store raw UTF-8
  (`"Español"`). Centralizing fixes this once.
- **N copies of the fold loop.** Core, every LocaleManager addon, and every
  standalone addon carries its own `ApplyLanguage()` and reacts to the language
  setting independently (via the `addon:ApplyLanguage()` hook in
  [`t-profiles.lua`](../UI/t-profiles.lua) lines 45–49). One service replaces all
  of them.
- **`nil` on missing keys.** Today a truly-missing key returns `nil`. The service
  returns the key name string instead (AceLocale-style), which never errors and
  is self-documenting on screen.

---

## Current state — four registration patterns

The migration has to absorb all four. Counts are enUS key counts (approximate
where the format hides keys from a simple scan).

| Pattern | Where | Shape |
|---|---|---|
| **A — core** | `OneWoW/Locales/{enUS,koKR}.lua` | `OneWoW.Locales["enUS"] = { ["KEY"]=v }`; `OneWoW.L = {}` at end of `enUS.lua`; folded by `ApplyLanguage()` in [`OneWoW.lua`](../OneWoW.lua) lines 40–55 |
| **B — LocaleManager** | AltTracker, Catalog, Notes, QoL, Trackers | `Locales/LocaleManager.lua` defines `ns.ApplyLanguage()`; locale files do `ns.Locales["enUS"]={}; local L_enUS=ns.Locales["enUS"]; L_enUS["KEY"]=v` |
| **C — QoL external modules** | `OneWoW_QoL/Modules/external/*/Locales/*` | `local L_enUS = ns.L_enUS; L_enUS["KEY"]=v` — every external module writes into QoL's **shared** `ns.L_enUS`/`ns.L_koKR` |
| **D — standalone localized** | DirectDeposit, Bags, ShoppingList, DevTool | `OneWoW_<Addon>.Locales[...] = {...}`; own `ApplyLanguage()` in main `.lua`; own `OneWoW_<Addon>.L` |

All four standalone-localized and LocaleManager addons declare
`## RequiredDeps: OneWoW`, so the service is guaranteed loaded before any of them
runs a file — registration at file-load time is safe.

---

## Target architecture

### Service module

New file `OneWoW/Services/LocaleService.lua` (loaded early — before any code that
reads `OneWoW.L`, and listed in the TOC ahead of `Locales/enUS.lua`). Exposes
`OneWoW.Locale`.

```
OneWoW.Locale.store[scope][locale]  -- raw registered entries (e.g. store["Bags"]["enUS"])
OneWoW.Locale.resolved[scope]       -- folded enUS ⊕ activeLang, mutated in place
OneWoW.Locale._views[scope]         -- cached metatable view, identity-stable
OneWoW.Locale._callbacks            -- listeners fired after each Apply
```

### API surface

| Call | Purpose |
|---|---|
| `OneWoW.Locale:Register(scope, locale, entries)` | Merge a table of `KEY=value` into `store[scope][locale]`. Safe at file-load. Re-folds `scope` if a language is already applied. |
| `OneWoW.Locale:RegisterShared(locale, entries)` | Sugar for `Register("shared", ...)`. The centralized THEME/MINIMAP/language/button cluster lives here, once. |
| `OneWoW.Locale:GetTable(scope)` | Returns the **stable** read-only view for `scope`. Cache it once: `local L = OneWoW.Locale:GetTable("Bags")`. |
| `OneWoW.Locale:SetLanguage(lang)` | Re-fold every scope in place, push `BINDING_*` globals, fire callbacks. |
| `OneWoW.Locale:OnApply(fn)` | Register a listener for addons that must rebuild cached UI strings on language change. Replaces the per-addon `ApplyLanguage` hook. |
| `OneWoW.Locale:Audit()` | Run the collision-validation pass (`shared ∩ scope`) and return violations. Backs the `/owlocale` command; not called automatically. |

### View metatable (mirrors `ACTIVE_THEME`)

```lua
__index = function(_, key)
    local r = OneWoW.Locale.resolved
    local scoped = r[scope] and r[scope][key]
    if scoped ~= nil then return scoped end
    local shared = r.shared and r.shared[key]
    if shared ~= nil then return shared end
    return key            -- self-documenting miss, never nil
end,
__newindex = noop,        -- read-only, like the theme wrapper
```

Resolution order per lookup: **scope (active lang ⊕ enUS) → shared (active lang ⊕
enUS) → key name**.

### Two hard rules (where locales differ from `ApplyTheme`)

1. **Mutate `resolved` in place; never reassign the view.** `ApplyTheme` does
   `Constants.ACTIVE_THEME = setmetatable(newTable, ...)` on each apply because
   theme consumers call `GetThemeColor(key)` fresh every time. Locale consumers
   cache `local L = ...L` at file scope, so the view table identity **must
   survive** language changes. Build the view once; on `SetLanguage`, wipe and
   refill `resolved[scope]`, don't swap it. (Core's existing `ApplyLanguage`
   already mutates `OneWoW.L` in place — keep that discipline.)
2. **Shared and scope keysets are disjoint — enforced.** A key is *either* shared
   (identical everywhere) *or* scoped (per-addon), never both. `ADDON_TITLE` and
   `MINIMAP_TOOLTIP_HINT` are therefore **not** shared keys: core registers them
   under its own `"OneWoW"` scope, exactly like every other addon registers them
   in theirs. The `shared` table must contain neither. The service validates this
   (see *Collision validation*) and treats any `shared ∩ scope ≠ ∅` as a contract
   violation, surfaced on demand via `/owlocale`. The view's scope→shared lookup
   order is kept only as a defensive fallback if a collision slips past at
   runtime — not a feature to rely on.
   Scope-vs-**scope** duplicate keys are fine and expected (every addon has its
   own `ADDON_TITLE`); only scope-vs-**shared** overlap is forbidden.

### Collision validation

Validation is **on-demand** through a single slash command, **`/owlocale`** —
matching the suite's other debug commands (`/owbperf`, `/owblayout`, `/owtrace`).
There are no debug builds, so this command is the *sole* locale-debug mechanism:
nothing prints or throws automatically at load.

`/owlocale` runs the pass — compute `shared ∩ keys(scope)` for every scope — and
reports any non-empty intersection (plus useful context: registered scopes, key
counts, active language). The check is order-independent by construction: it runs
after everything has registered, so it doesn't matter whether a scope registered a
key before or after `shared` was populated.

Register it the usual way, e.g. `SLASH_OWLOCALE1 = "/owlocale"`. It never throws —
a collision is reported as text, never an `error()`, so it is safe to run any
time without risk to the load chain.

---

## Shared-key catalog (centralize into `shared` scope)

Define these **once** via `RegisterShared`, in `OneWoW/Locales/Shared/<locale>.lua`
(separate from the OneWoW-scoped `Locales/<locale>.lua`). The cluster below is the
confirmed overlap (49 keys).

- **Themes:** all `THEME_*` (~24 keys) + `THEME_SECTION`, `THEME_DESC`,
  `THEME_CURRENT`.
- **Language picker:** `LANGUAGE_SELECTION`, `LANGUAGE_DESC`, `CURRENT_LANGUAGE`,
  `SELECT_LANGUAGE`, `ENGLISH`, `SPANISH`, `KOREAN`, `FRENCH`, `RUSSIAN`,
  `GERMAN`.
- **Minimap section labels:** `MINIMAP_SECTION`, `MINIMAP_SECTION_DESC`,
  `MINIMAP_SHOW_BTN`, `MINIMAP_ICON_SECTION`, `MINIMAP_ICON_DESC`,
  `MINIMAP_ICON_CURRENT`, `MINIMAP_ICON_HORDE`, `MINIMAP_ICON_ALLIANCE`,
  `MINIMAP_ICON_NEUTRAL`.
- **Common buttons:** `OK`, `CANCEL`, `CLOSE`.

**Not shared at all — each scope registers its own:** `ADDON_TITLE`,
`MINIMAP_TOOLTIP_HINT`. Core registers these under scope `"OneWoW"`, **not**
`shared`. The `shared` table must contain neither key — if it does, any addon that
registers its own value trips the collision check (see *Collision validation*).

While centralizing, normalize the language-name encoding to **one** form (pick
escaped-bytes or raw UTF-8; raw UTF-8 is more readable if the build tooling
preserves it).

---

## Phased rollout

Each phase is independently shippable and behavior-preserving. Do not start a
phase until the previous one is verified in-game.

### Phase 0 — Build the service (no consumers yet)

- [x] Add `OneWoW/Services/LocaleService.lua` implementing `store`, `resolved`,
      `_views`, `Register`, `RegisterShared`, `GetTable`, `SetLanguage`,
      `OnApply`, `Audit`, and the read-only view metatable.
- [x] Implement the `/owlocale` command backing `Audit()` (`shared ∩ scope` +
      scope/key/lang context). On-demand only, reports as text, never throws.
- [x] List it in `OneWoW.toc` **before** `Locales/enUS.lua` and before any reader.
- [x] Unit-sanity in-game: register a throwaway scope, confirm
      scope→shared→keyname resolution and that writes are no-ops.
- [x] Confirm view identity survives a `SetLanguage` call (cache a ref, switch
      language, ref still resolves).

### Phase 1 — Migrate core `OneWoW` onto the service

- [x] Move the shared-key catalog out of `OneWoW/Locales/enUS.lua` (and `koKR`)
      into `RegisterShared("enUS"/"koKR", {...})`. (49 shared keys.) Shared lives in
      its own files `Locales/Shared/{enUS,koKR}.lua`, loaded before the
      OneWoW-scoped `Locales/{enUS,koKR}.lua` (load order is for clarity — the view
      resolves scope→shared live regardless).
- [x] Register the remaining core keys under scope `"OneWoW"`. (989 keys each.)
- [x] Replace `OneWoW.L = {}` + `ApplyLanguage()` in [`OneWoW.lua`](../OneWoW.lua)
      with `OneWoW.L = OneWoW.Locale:GetTable("OneWoW")` and route the language
      setting to `OneWoW.Locale:SetLanguage()`.
- [x] Keep the `BINDING_*` → `_G` push inside `SetLanguage` (handled by the
      service's `_resolveScope`, fired on every refold).
- [x] Normalize language-name encoding to raw UTF-8 here (decision 2). (5 escaped
      values converted: SPANISH/KOREAN/FRENCH/RUSSIAN + the `MANAGE_FEATURES_DESC`
      em-dash.)
- [ ] Verify in-game: every core UI string renders unchanged; language switch
      works; `BINDING_*` keys still reach `_G`; missing key shows key-name not
      `nil`; `/owlocale` shows `OneWoW` + `shared` scopes, zero collisions.

### Phase 2 — Standalone localized addons (Pattern D)

Smallest first as the proof of concept. Per addon: register its non-shared keys
under its own scope, point its `L` at `GetTable(scope)`, delete its local
`Locales` fold and `ApplyLanguage`, drop the now-shared cluster, convert its
`addon:ApplyLanguage` hook usage to `OnApply` if it rebuilds cached strings.

- [ ] **OneWoW_DirectDeposit** (125 keys, 6 locales — POC)
- [ ] **OneWoW_Bags** (524 keys, 6 locales)
- [ ] **OneWoW_ShoppingList** (263 keys, 6 locales — 0 shared today, but adopt
      the service for consistency + future shared keys)
- [ ] **OneWoW_Utility_DevTool** (579 keys, 6 locales)

### Phase 3 — LocaleManager addons (Pattern B)

Replace each `Locales/LocaleManager.lua` with service registration; delete
`ns.ApplyLanguage`; point `ns.L` at `GetTable(scope)`.

- [ ] **OneWoW_AltTracker**
- [ ] **OneWoW_Catalog**
- [ ] **OneWoW_Notes**
- [ ] **OneWoW_Trackers** (174 keys; 1 shared — `MINIMAP_TOOLTIP_HINT`, which
      stays scoped)
- [ ] **OneWoW_QoL** (core of the QoL namespace; see Phase 5 for its externals)

### Phase 4 — Data sub-addons (Pattern B, mostly enUS-only)

Small key counts; each becomes its own scope.

- [ ] OneWoW_AltTracker_Accounting
- [ ] OneWoW_AltTracker_Auctions
- [ ] OneWoW_AltTracker_Character
- [ ] OneWoW_AltTracker_Collections
- [ ] OneWoW_AltTracker_Endgame
- [ ] OneWoW_AltTracker_Professions
- [ ] OneWoW_AltTracker_Storage
- [ ] OneWoW_CatalogData_Journal
- [ ] OneWoW_CatalogData_Quests
- [ ] OneWoW_CatalogData_Tradeskills
- [ ] OneWoW_CatalogData_Vendors

### Phase 5 — QoL external modules (Pattern C)

These ~45 modules all write into QoL's shared `ns.L_enUS`/`ns.L_koKR` today. Per
decision 3, each external module becomes its **own scope** (e.g. `"QoL.autorepair"`
or `"autorepair"`) so two modules can reuse a key with different values without
colliding. Convert each module's `L_enUS["KEY"]=v` block to a per-module
`Register(scope, locale, {...})` call (decision 4 — no shared-table shim).

- [ ] Settle the scope-naming convention for externals (`"QoL.<module>"` vs
      bare `"<module>"`) and apply consistently.
- [ ] achieveuntrack, afkpanel, auctionhouse, autodelete, autoinvite, automount,
      autoopen, autoreadycheck, autorepair, autoresurrect, autosummon, bagbar,
      charinfo, coords, copytext, cursorenhancer, declineduel, escpanel,
      fastforward, fastloot, framemover, hideerrors, inspectmog, lfgpanel,
      map_mini_tools (+ minimapskin), map_world_tools, minimapbuttons, playmounts,
      preybar, professionspanel, questitembar, questtools, screenshotachievements,
      vendorpanel
      <br>*(one scope per module; check each box as converted)*

### Phase 6 — Cleanup

- [ ] Remove the `addon:ApplyLanguage()` loop from
      [`t-profiles.lua`](../UI/t-profiles.lua) lines 45–49 once no addon defines
      `ApplyLanguage`.
- [ ] Grep the suite for stray `\.Locales`, `ApplyLanguage`, `L_enUS`,
      `LocaleManager` references; confirm none remain outside the service.
- [ ] Fold target-state into `ARCHITECTURE.md`; delete this file.

---

## Decisions — locked

1. **Missing-key return:** *key-name string.* A missing key resolves to its own
   name (AceLocale-style), never `nil`. Applies suite-wide.
2. **Language-name encoding:** *raw UTF-8.* Language names (and all strings) use
   raw UTF-8, not escaped byte sequences. Normalize core's existing
   escaped-bytes during Phase 1; confirm the build/packaging tooling preserves
   UTF-8.
3. **QoL external scope granularity:** *per-module.* Each external module gets its
   own scope (~45 scopes), so two modules can use the same key with different
   values without colliding. No shared `"QoL"` bucket for module strings.
4. **Registration style:** *Register API.* End state is
   `OneWoW.Locale:Register(scope, locale, {...})` / `:RegisterShared(...)` calls.
   No `<ns>.Locales` table-ingest shim — locale files call the API directly.
5. **Collision reporting:** the `shared ∩ scope` invariant is disjoint/enforced,
   surfaced on demand via `/owlocale` (no debug builds; this is the sole
   locale-debug command, mirroring `/owbperf`/`/owblayout`/`/owtrace`). Never
   auto-prints, never throws.

---

## Testing checklist (run per phase, in-game)

- [ ] All strings for the migrated addon render identically to pre-migration.
- [ ] Switch language in OneWoW settings → migrated addon updates without reload.
- [ ] `esMX` still aliases to `esES`.
- [ ] Locale with a missing key falls back to enUS, then to key-name.
- [ ] `BINDING_*` keys still reach `_G`.
- [ ] `/owlocale` reports zero `shared ∩ scope` collisions for the migrated addon
      (catches keys that should have been scoped, not shared).
- [ ] No Lua errors at login with only OneWoW + the migrated addon enabled.
- [ ] No errors with the migrated addon's `RequiredDeps` order respected.

## Rollback

Each phase is one addon's worth of changes behind `RequiredDeps: OneWoW`. If a
phase regresses, revert that addon's commit — the service and already-migrated
addons keep working because the view contract (`GetTable`) is stable and
additive. The service itself (Phase 0) is inert until something registers.

---

## Progress log

| Date | Phase | Addon | Notes |
|---|---|---|---|
| _2026-06-13_ | — | — | Plan created. No code changes yet. |
| _2026-06-13_ | — | — | Decisions locked: key-name miss, raw UTF-8, per-module QoL scopes, Register API. |
| _2026-06-13_ | 0 | OneWoW | `Services/LocaleService.lua` + `/owlocale` added; TOC line before Locales. Code complete, all suite lint checks pass. In-game sanity checks pending. |
| _2026-06-14_ | 0 | OneWoW | In-game sanity checks passed. Phase 0 complete. |
| _2026-06-14_ | 1 | OneWoW | `Locales/enUS.lua` + `koKR.lua` converted to `RegisterShared` + `Register("OneWoW", ...)` (49 shared / 989 scoped); `OneWoW.L` now a service view; `ApplyLanguage` routes to `SetLanguage`; `OneWoW.Locales` table removed; lang-name + em-dash escapes → UTF-8. Lint passes; in-game verify pending. |
| _2026-06-14_ | 1 | OneWoW | Shared scope split into `Locales/Shared/{enUS,koKR}.lua`; OneWoW-scoped strings stay in `Locales/{enUS,koKR}.lua`. TOC loads Shared first. Lint passes. |
