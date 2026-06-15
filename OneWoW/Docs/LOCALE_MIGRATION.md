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
OneWoW.Locale.store[scope][locale]  -- raw registered entries (e.g. store["OneWoW_Bags"]["enUS"])
OneWoW.Locale.resolved[scope]       -- folded enUS ⊕ activeLang, mutated in place
OneWoW.Locale._views[scope]         -- cached metatable view, identity-stable
OneWoW.Locale._callbacks            -- listeners fired after each Apply
OneWoW.Locale.SUPPORTED             -- ordered { code, native } — single source for the picker
OneWoW.Locale.ALIASES               -- client-locale aliases (e.g. esMX -> esES), used by NormalizeLocale
```

`SUPPORTED` is the canonical supported-locale registry: the GUI language picker
reads it (no more hardcoded list), `NormalizeLocale` resolves `ALIASES`, and
`/owlocale` lists the supported codes and flags any registered locale not in it.
Scope keys are the addon's `ADDON_NAME` (e.g. `"OneWoW"`, `"OneWoW_DirectDeposit"`).

### API surface

| Call | Purpose |
|---|---|
| `OneWoW.Locale:Register(scope, locale, entries)` | Merge a table of `KEY=value` into `store[scope][locale]`. Safe at file-load. Re-folds `scope` if a language is already applied. |
| `OneWoW.Locale:RegisterShared(locale, entries)` | Sugar for `Register("shared", ...)`. The centralized THEME/MINIMAP/language/button cluster lives here, once. |
| `OneWoW.Locale:GetTable(scope)` | Returns the **stable** read-only view for `scope`. Cache it once: `local L = OneWoW.Locale:GetTable("Bags")`. |
| `OneWoW.Locale:SetLanguage(lang)` | Re-fold every scope in place, push `BINDING_*` globals, fire callbacks. |
| `OneWoW.Locale:OnApply(fn)` | Register a listener for addons that must rebuild cached UI strings on language change. Replaces the per-addon `ApplyLanguage` hook. |
| `OneWoW.Locale:Audit()` | Run the collision-validation pass (`shared ∩ scope`) and return violations. Backs the `/owlocale` command; not called automatically. |
| `OneWoW.Locale:GetStore(scope)` | Raw `{ [locale] = { KEY=value } }` for a scope — for consumers needing a *specific* locale's strings (import/export cross-locale maps, DB-migration defaults), not the folded view. Read-only by convention. |
| `OneWoW.Locale:GetOptional(scope, key)` | Resolved value (scope → shared) if registered, else **nil**. For *genuinely optional* localization where a translation may legitimately not exist (e.g. localize a built-in name, else use a dynamic value). The complement to the view's key-name-on-miss. |

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

### Lookup contract — `L[key]` vs `GetOptional`, and the banned fallback

> **TODO (architecture docs):** fold this contract into `ARCHITECTURE.md` (and the
> localization skill / cursorrules) when the migration completes — it is a
> suite-wide rule, not just a migration detail. Tracked in Phase 6.

Two lookups, two intents — pick by whether the key is *required* or *optional*:

- **`L[key]` (the view) — for keys that MUST exist.** On a miss it returns the
  **key name** (e.g. `"SETTINGS_TAB"`), which renders visibly on screen so the
  missing key is caught and added. This is deliberate.
- **`OneWoW.Locale:GetOptional(scope, key)` — for genuinely optional localization.**
  Returns the value or **nil**, so a dynamic fallback can take over. Use it only
  when a translation may *legitimately* be absent — e.g. a built-in category
  localizes via `CAT_*`, but a custom (SavedVariables) category has no entry and
  must show its raw user string.

**Banned: `L["LITERAL_KEY"] or "Hardcoded String"`.** A hardcoded English
duplicate of a key that should just exist in the locale. With key-name-on-miss it
also silently breaks (the truthy key name defeats the `or`). If the key must
exist, register it and use `L[key]`. If it's optional, use `GetOptional`. The
`L[key] or sameVarThatIsTheKey` form is a redundant no-op (the miss already
returns the key) — drop the `or`.

> Real example that motivated this: after Bags migrated, `ResolveCategoryName` did
> `L["CAT_"..upper(name)] or categoryName`. Custom categories (no `CAT_*` entry)
> rendered as `CAT_MY_HERBS` instead of "My Herbs", because the view returned the
> key name. Fixed by switching to `GetOptional(...) or categoryName`.

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

> **Most shared keys are intentionally retained scaffolding — do NOT dead-code
> sweep them.** Audit (2026-06-14): of the 49 shared keys, only `CANCEL` and
> `CLOSE` are currently referenced via `L` in code (DD MainWindow, QoL dialogs;
> even `OK` is unused). The `THEME_*`, `MINIMAP_*` labels, and the whole
> language-picker group have **no callers** — the GUI toolkit hardcodes its
> section titles in English (e.g. `Settings.lua` `SetText("Color Theme")`), the
> theme picker uses `Constants.THEMES[key].name`, and the language picker uses
> `OneWoW.Locale.SUPPORTED.native`. Decision (2026-06-14): **keep them as
> groundwork for a future pass that localizes the GUI toolkit's hardcoded titles**,
> with their harvested es/fr/de/ru translations. They are dead-by-design until that
> pass, not accidental. The language-name keys (`ENGLISH`…`GERMAN`) also duplicate
> `SUPPORTED.native`; if GUI localization never happens, prune the lot then.

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
- [x] Verify in-game: every core UI string renders unchanged; language switch
      works; `BINDING_*` keys still reach `_G`; missing key shows key-name not
      `nil`; `/owlocale` shows `OneWoW` + `shared` scopes, zero collisions.
      (Verified — `/owlocale`: 989 + 49 keys, no collisions. Committed.)

### Phase 2 — Standalone localized addons (Pattern D)

Smallest first as the proof of concept. Per addon: register its non-shared keys
under its own scope, point its `L` at `GetTable(scope)`, replace its local
`Locales` fold, drop the now-shared cluster, and react to language changes.

**Prerequisite discovered during the POC — core's shared scope must hold all 6
languages.** Phase 1 only created shared `enUS`/`koKR` (core never shipped more).
The Pattern-D addons carry the shared cluster in 6 languages, so before dropping
those keys, harvest the `esES`/`frFR`/`deDE`/`ruRU` translations into core
`Locales/Shared/<locale>.lua` (decision: *core owns full shared*). Otherwise a
non-en/ko user loses those translations to the enUS fallback. The first addon to
need a language seeds it; later addons whose values match are transparent, drifted
values resolve to the canonical (intended dedup — surfaced via `/owlocale`/diff).

**Scope name = `ADDON_NAME`.** Pass the addon's name (the first `...` vararg, e.g.
`"OneWoW"`, `"OneWoW_DirectDeposit"`) as the scope to `Register`/`GetTable` instead
of a string literal — no magic-string drift between the two calls. Header:
`local ADDON_NAME, OneWoW_<Addon> = ...` in the file that sets `<Addon>.L`,
`local ADDON_NAME = ...` in the rest. (QoL external modules are the exception —
they share one `ADDON_NAME` (`OneWoW_QoL`) yet need per-module scopes per decision
3, so they pass explicit `"OneWoW_QoL.<module>"` strings.)

**Header gotcha — which `OneWoW` to reference.** A locale file's `...` vararg binds
the *addon's own* private table. In a **non-core** addon, reference the **global**
`OneWoW` for the service calls (`OneWoW.Locale:…`) — core is loaded first
(`RequiredDeps`) so the global exists. Do **not** write `local _, OneWoW = ...` in
a non-core addon — that shadows the global with the addon's private table,
`OneWoW.Locale` is nil, and the file errors at `Register`. **Core itself** must use
the private table from the vararg (`local ADDON_NAME, OneWoW = ...`), because core's
locale files load before `OneWoW.lua` publishes the `_G.OneWoW` global.

**`ApplyLanguage` is kept as a thin shim**, not deleted: it now calls
`OneWoW.Locale:SetLanguage(...)`. The profile-apply path
(`t-profiles.lua` `SyncSettingToChildAddons`) still calls `addon:ApplyLanguage()`,
so the shim stays until that path moves to the service in Phase 6. The addon's
existing UI-rebuild-on-language-change wiring is preserved (refold happens inside
`SetLanguage` before the rebuild). Theme **color-name** keys (`THEME_GREEN`, …) are
dead — the picker uses `Constants.THEMES[key].name`, not `L` — so they're dropped
outright.

- [x] **OneWoW_DirectDeposit** (125 keys, 6 locales — POC). Scope
      `OneWoW_DirectDeposit` (via `ADDON_NAME`; 76 enUS / ~39 other). Harvested 27 shared keys × es/fr/de/ru into core
      `Locales/Shared/`. enUS/koKR drops verified byte-identical to canonical
      (koKR: 3 visible section-description strings now use core's wording —
      intended). esMX alias dropped (service normalizes). Lint passes; verified
      in-game and committed.
- [x] **OneWoW_Bags** (524 keys, 6 locales). Scope `OneWoW_Bags` (479 enUS / 467
      other). Harvested its shared translations into core `Locales/Shared/`
      (es/fr/de/ru: +12 keys each — the MINIMAP labels DD lacked — now 39/locale;
      9–17 drift kept as DD canonical, which had proper diacritics vs Bags'
      accent-stripped text). enUS drops verified value-identical bar one dead theme
      key (`THEME_NIGHTFAE`). Two raw readers (`Core/Database.lua`,
      `ImportExport/Applier.lua`) keep working via
      `OneWoW_Bags.Locales = OneWoW.Locale:GetStore(ADDON_NAME)`. Lint passes;
      verified in-game and committed.
- [x] **OneWoW_ShoppingList** (263 keys, 6 locales). Scope `OneWoW_ShoppingList`
      (263 enUS / 259 other). 0 shared keys → no drops, no harvest. **Aligned to
      the DD/Bags shape:** deleted the `RegisterLocale`/`SetLocale` fold helper
      from `Core/Constants.lua`; enUS sets the view; `ApplyLanguage` is the
      `SetLanguage` shim. Anti-pattern sweep done (14 `(L and L["K"]) or "lit"`
      guards in `OrdersUI.lua` + the minimap `CTX_OPEN_SL` guard simplified; all
      keys verified registered). Lint clean on touched files. Verified in-game and
      committed. (Pre-existing `_G.<name>` violations in `BagOverlays.lua` /
      `ShoppingList.lua` noted separately — unrelated to locale work.)
- [x] **OneWoW_Utility_DevTool** (579 keys, 6 locales). Scope
      `OneWoW_Utility_DevTool` (570 enUS / 292 other). Dropped 9 shared `MINIMAP_*`
      (harvest a no-op — already canonical from Bags); `MINIMAP_CTX_FALLBACK`,
      `MINIMAP_TOOLTIP_HINT`, `LANG_*`, `ADDON_TITLE` stay scoped. enUS sets view +
      `Addon.Locales = GetStore(ADDON_NAME)` for the editor-default-category raw
      readers in `Core/Database.lua`. `ApplyLanguage`→`SetLanguage` shim (service
      now pushes the `BINDING_*` keys the old code pushed explicitly). Anti-pattern
      sweep: ~51 sites — pervasive `Addon.L or {}` guards → `Addon.L`, `L[var] or
      var` no-ops, minimap fallback, and `rcLabel` (`ErrorAnalyzer`) → `GetOptional`
      (it has a code-side default). All keys verified registered. Lint clean
      (excl. generated `Data/`). Verified in-game and committed (incl. the two
      follow-up notes: `L`-capture standardization and the missing
      language/font settings callbacks).

### Phase 3 — LocaleManager addons (Pattern B)

Replace each `Locales/LocaleManager.lua` with service registration; delete
`ns.ApplyLanguage`; point `ns.L` at `GetTable(scope)`.

- [x] **OneWoW_AltTracker** (1182→1142 keys; 40 dropped: the Language/Theme/Minimap-section
      blocks, dead here — settings tab uses the shared `CreateSettingsPanel`). Largest
      addon; **real koKR translations**. Accumulation format with named vars
      (`local L_enUS = ns.Locales["enUS"]; L_enUS["K"]=v`, koKR `L_koKR`) → `Register`
      table literals; enUS sets the view. **`_G["BINDING_*"]` direct assigns** (3, in
      the enUS tail) folded into the scope table as normal keys — the service's
      `_resolveScope` pushes `BINDING_*` to `_G` on every refold, so `Bindings.xml`
      labels stay correct and update on language change (replaces both the file-load
      `_G[...]=` block and `LocaleManager.ApplyBindingGlobals`). LocaleManager → shim
      (kept — AltTracker is in profile-sync; called by OnInitialize/OnLanguageChanged).
      **Added 2 missing keys** (`BANK_SEARCH`, `BANK_NO_CHARACTERS`) surfaced by
      key-name-on-miss once their `or "Search..."`/`or "No Characters"` fallbacks were
      swept; values from the old fallbacks (koKR: "검색...", "캐릭터 없음").
      Anti-pattern sweep: 58 `L["K"] or "lit"` (bulk) + 8 manual
      (`or L["K2"]`, `or var`, own-`L`-nil guards) removed; the dynamic `BANK_<type>`
      lookup → `GetOptional` (not every type has a key); genuine `cond and L["K1"] or
      L["K2"]` ternaries left intact. Lint clean; in-game verify pending.
- [x] **OneWoW_Catalog** (397→358 keys; 39 dropped: the whole Language picker,
      Theme picker, and Minimap-section blocks — Catalog's settings tab only has the
      Data Manager; the language/theme/minimap UI is built by the shared `OneWoW_GUI`
      panel from the `shared` scope, so those keys were dead/superseded here).
      Accumulation format (`L["K"]=v`) → `Register` table literal; enUS sets the view.
      **koKR has real translations** (not a placeholder) → migrated as a normal scope;
      its 3 trailing `L["K"]=L["K"] or "…"` self-refs folded into plain keys.
      `LocaleManager.lua` → `ns.ApplyLanguage` **shim** (kept — Catalog is in
      profile-sync; also called by OnInitialize/OnLanguageChanged); its
      `ApplyBindingGlobals` dropped since the service's `_resolveScope` pushes
      `BINDING_*` to `_G` on every refold. No missing keys surfaced. Anti-pattern
      sweep: 7 `L["K"] or "lit"` removed + 3 must-exist dynamic-key fallbacks
      (`L[def.labelKey] or def.key`, `L[key] or diff.name`) dropped; genuine
      `cond and L["K"] or dynamicValue` ternaries left intact. Lint clean; in-game
      verify pending.
- [x] **OneWoW_Notes** (450→477 keys; 34 shared/theme dropped, all dead theme
      color names — live shared keys matched canonical). Accumulation format
      (`local L = ns.Locales["enUS"]; L["K"]=v`) → `Register` table literal; enUS
      sets the view. koKR is a `"TEST"` placeholder → rewired via `GetStore`.
      `LocaleManager.lua` reduced to the `ns.ApplyLanguage` **shim** (kept — Notes
      is in profile-sync; called by OnInitialize/OnLanguageChanged too). Constants
      had no locale block. **Added 28 missing keys** (surfaced by key-name-on-miss;
      values from the code's own fallbacks, except `MSG_CANNOT_SET_WAYPOINT` which
      had none — gave it a sensible message). Anti-pattern sweep: 256 dead fallbacks
      + 1 dynamic-key optional → `GetOptional`. Lint clean; in-game verify pending.
- [x] **OneWoW_Trackers** (174→182 keys; 0 shared-49 — `MINIMAP_TOOLTIP_HINT` stays
      scoped). Structurally like ShoppingList (RegisterLocale + Constants `SetLocale`):
      locale files → `Register(ADDON_NAME, …)`, enUS sets the view, removed the
      `ns.L`/`SetLocale` block from `Core/Constants.lua`, **deleted `LocaleManager.lua`**
      (its `ns.ApplyLanguage` was dead — Trackers isn't in the profile-sync list),
      `ApplyLanguage`→`SetLanguage` shim. koKR is a dev placeholder (all keys =
      `"TEST"`) — rewritten to source the enUS key set from `GetStore` instead of
      `ns.Locales`. **Added 8 genuinely-missing keys** (`BUTTON_CANCEL/CLOSE`,
      `NOTES_SAVE`, 4×`TRACKER_TYPE_QUEST_*`, `TRACKER_TYPE_CAMPAIGN`) surfaced by
      key-name-on-miss. Anti-pattern sweep: 173 dead `L["K"] or "lit"` removed
      (ternaries' inner fallbacks too), 1 no-op, 2 dynamic-key optionals →
      `GetOptional`. Lint clean; in-game verify pending.
- [x] **OneWoW_QoL** (done together with Phase 5 — see below; core 371→337 keys to
      scope `OneWoW_QoL`, `ns.L` = view, BINDING_* folded into scope). **Note:** the
      Overlays/Tooltips/Portals/ToastAlerts subsystems read `local L = OneWoW.L` (core
      "OneWoW" scope) by design — their keys were intentionally left in OneWoW core
      during the QoL feature transition ("Locale strings stay in core OneWoW.L"). Those
      are untouched here; they migrate when those features fully move (later phase).
      Anti-pattern sweep deferred (pending in-game verify).

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

- [x] **Scope-naming convention (final): `ADDON_NAME .. "." .. id`** (e.g.
      `OneWoW_QoL.afkpanel`), derived — no magic `"QoL."` literal. (Superseded an
      interim `"QoL.<module>"` string approach.) Achieved via a **`module.lua`** per
      module + a tiny `ModuleRegistry:Define`/`Current()` API: `module.lua` (first in
      the TOC block) holds the metadata literal — the single home of the module `id` —
      and `Define(ADDON_NAME, def)` computes `def._scope`/`def._view`, sets a transient
      `loading` pointer (file-local in the registry, never on `ns`), and registers.
      Every other file does `local M[, L] = ns.ModuleRegistry:Current()` at load and
      captures. `data.lua` deleted (Define registers); core `t-features.lua` reads each
      module's cached `_view` via `GetById`. Cross-scope deps: 3 generic core keys
      (`FEATURES_ON`/`FEATURES_OFF`→charinfo,framemover; `UNKNOWN`→lfgpanel) duplicated
      per decision 3; cross-**module** references go through `GetById("<id>")`
      (fixed 3: map_mini_tools→minimapbuttons, core→playmounts/copytext).
- [x] **All 34 external modules converted** (POC afkpanel → 19 single-file → 11
      multi-file → 3 hand-converts: lfgpanel/vendorpanel incremental metadata, inspectmog
      `ns.InspectMog`/no-koKR). `map_mini_tools/minimapskin/` is **dead** (not in TOC) —
      left untouched. LocaleManager → shim (QoL in profile-sync). Validated: balanced
      braces, no residual `ns.<X>Module`/`GetTable("QoL.")`, clean per-scope missing-key
      scan, no dangling cross-refs, lint clean. In-game verified.
      <br>*Pending: `L["K"] or "lit"` sweep across externals; rewrite the QoL drop-in
      SDK docs (`DEVHELP_BODY` + `DEVELOPERS.md`) for the module.lua/Current convention
      (incl. the `GetById` cross-module rule + load-order rule).*

### Phase 6 — Cleanup

- [ ] Remove the `addon:ApplyLanguage()` loop from
      [`t-profiles.lua`](../UI/t-profiles.lua) lines 45–49 once no addon defines
      `ApplyLanguage`.
- [ ] Grep the suite for stray `\.Locales`, `ApplyLanguage`, `L_enUS`,
      `LocaleManager` references; confirm none remain outside the service.
- [x] Sweep the **migrated** addons (core, DD, Bags) for `L[key] or fallback`:
      removed 35 dead `L["KEY"] or "literal"` (all keys verified registered);
      converted genuine optionals to `GetOptional` (`ResolveCategoryName`,
      `MainWindow` module name, `navigation` pointer, `BagsBar` bag-filter); dropped
      no-op `L[x] or x`. **Left intentionally:** ternaries (`cond and L[a] or L[b]`)
      and nil-guards (`(OneWoW.L and OneWoW.L["K"]) or "lit"` — defensive; could be
      simplified to `OneWoW.L["K"]` since the view is always set post-load).
- [x] Simplified the defensive nil-guards in migrated addons:
      `(OneWoW.L and OneWoW.L["K"]) or "lit"` → `OneWoW.L["K"]` (the view is always
      set post-load), and the `if L and L["K"] then …` minimap existence-guards →
      unconditional. Fixed a real key-name-on-miss bug in `GetLoadFailureText`
      (dynamic `L["LOAD_FAIL_"..reason]` was always truthy → unknown reasons skipped
      Blizzard's `ADDON_*` constant) using `GetOptional`.
- [x] **Existence-check pattern resolved:** traced `err` at all 7
      `if err and L[err] then …` sites (`Bags/GUI/CategoryManager.lua` ×4,
      `InfoBarFactory.lua` ×2, `Settings.lua`). Every `err` is a registered locale
      key (`DUPLICATE_CATEGORY_NAME`, `DUPLICATE_SECTION_NAME`, `SAVED_SEARCH_*`),
      so nothing was broken — the `and L[err]` was dead defensive code. Simplified
      all to `if err then` (a future un-translated error key now surfaces via
      key-name, the intended behavior). (`Categories.lua:1161` `key and L[key] or nil`
      left as-is — already correct; `key` is nil for the no-key case.)
- [ ] Sweep the remaining addons for `L[key] or fallback` **as each migrates**
      (un-migrated addons still use nil-returning tables, so the pattern isn't a
      live bug there yet).
- [ ] **Fold the *Lookup contract* (`L[key]` must-exist vs `GetOptional`, banned
      `L[key] or "literal"`) into `ARCHITECTURE.md` and the localization
      skill/cursorrules** — it's a suite-wide rule, not a migration detail.
- [ ] Fold remaining target-state into `ARCHITECTURE.md`; delete this file.

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
| _2026-06-14_ | 1 | OneWoW | Phase 1 verified in-game (`/owlocale`: 989 + 49, no collisions). |
| _2026-06-14_ | 2 | DirectDeposit | Migrated to scope `OneWoW_DirectDeposit` (via `ADDON_NAME`) + service view; fold replaced by `SetLanguage` shim. Harvested es/fr/de/ru shared translations into core `Locales/Shared/` (decision: core owns full shared). Drops verified value-identical to canonical (enUS) / 3 intended koKR wording changes. Lint passes; in-game verify pending. |
| _2026-06-14_ | — | OneWoW | Adopted `ADDON_NAME` as the scope key (no magic strings) for core + DirectDeposit locale files, after a header-binding bug crashed `/1wdd`. |
| _2026-06-14_ | — | OneWoW | Added `Locale.SUPPORTED` + `Locale.ALIASES` registry; GUI picker now reads it (fixes stale escaped-byte labels); `NormalizeLocale` uses `ALIASES`; `/owlocale` shows supported + flags unknown locales. Lint passes; in-game verify pending. |
| _2026-06-14_ | — | OneWoW | Dead-key audit: only `CANCEL`/`CLOSE` of the shared scope have callers; themes/minimap/language-picker keys are unused (GUI hardcodes titles). Decision: keep as GUI-localization scaffolding (no removal). Documented in Shared-key catalog. |
| _2026-06-14_ | 2 | Bags | Migrated to scope `OneWoW_Bags` + service view; fold→`SetLanguage` shim. Added `Locale:GetStore` for two raw per-locale readers (aliased `OneWoW_Bags.Locales`). Harvested shared translations into core Shared (es/fr/de/ru now 39; +12 from Bags, drift kept DD canonical). enUS transparent (1 dead-key diff). Lint passes; in-game verify pending. |
| _2026-06-14_ | 2 | Bags | Key-name-on-miss surfaced a pre-existing anti-pattern: `ResolveCategoryName` showed `CAT_*` keys for custom categories. Added `Locale:GetOptional` (optional, nil-on-miss); fixed `ResolveCategoryName`; removed no-op `L[x] or x` in BagView/BagsBar/BagEquip/InfoBarFactory. Documented the lookup contract + Phase 6 task to fold into ARCHITECTURE.md. Lint passes. |
| _2026-06-14_ | 2 | Bags | Fixed Bag View showing `BACKPACK`/`REAGENT_BAG`: `BagTypes.bagNames` used those literals but the locale keys are `BAG_BACKPACK`/`BAG_REAGENT` (numbered bags already used `BAG_N`). Aligned `bagNames` to the `BAG_*` keys; collapsed the now-redundant backpack/reagent special-cases in `BagsBar`/`BagEquip`. Values verified only used as display keys. Lint passes. |
| _2026-06-14_ | — | core/DD/Bags | Anti-pattern sweep of migrated addons: 35 dead `L["KEY"] or "literal"` removed (keys all registered, 0 missing); 4 genuine optionals → `GetOptional`; no-op `L[x] or x` dropped. Ternaries + defensive nil-guards left. Lint passes; in-game verify pending. |
| _2026-06-14_ | — | core/DD/Bags | Simplified defensive nil-guards (`(OneWoW.L and L["K"]) or "lit"` → `L["K"]`; minimap `if L and L["K"]` → unconditional). Fixed `GetLoadFailureText` key-name-on-miss bug via `GetOptional`. Flagged remaining `if err and L[err]` error-display existence-checks. Lint passes; in-game verify pending. |
| _2026-06-14_ | — | OneWoW | Key-name-on-miss surfaced a genuinely missing key: `CTX_OPEN_TRACKERS` (right-click minimap menu) was never added to core while every other `CTX_OPEN_*` was; old `or "Open Trackers"` fallback hid it. Added to core enUS + koKR. |
| _2026-06-14_ | — | Bags | Resolved the flagged `if err and L[err]` sites: traced all 7 — every `err` is a registered key (DUPLICATE_*/SAVED_SEARCH_*), so none were broken. Simplified to `if err then`. Lint passes. |
| _2026-06-14_ | 2 | ShoppingList | Migrated to scope `OneWoW_ShoppingList` + service view; aligned to DD/Bags (removed `RegisterLocale`/`SetLocale` from Constants.lua; `ApplyLanguage`→`SetLanguage` shim). 0 shared → no harvest. Anti-pattern sweep: 14 dead `(L and L["K"]) or "lit"` guards simplified, all keys verified registered. Touched files lint clean; in-game verify pending. |
| _2026-06-14_ | 2 | DevTool | Migrated to scope `OneWoW_Utility_DevTool` + service view; `GetStore` alias for Database raw readers; `ApplyLanguage`→`SetLanguage` shim (service pushes BINDING_*). 9 shared MINIMAP_* dropped (harvest no-op). Anti-pattern sweep ~51 sites (`Addon.L or {}` guards, no-ops, minimap fallback, `rcLabel`→`GetOptional`). Lint clean; in-game verify pending. **Phase 2 complete** (DD, Bags, ShoppingList, DevTool). |
| _2026-06-14_ | — | DevTool | Code-quality notes (user-reported, pre-existing): (1) standardized `L` capture — one top-level `local L = Addon.L` per file, removed `getL()`/`loc`/`LL` aliases, all reads use `L` (~90 sites). (2) Fixed live settings updates — DevTool only had `OnThemeChanged`; added `OnLanguageChanged`/`OnFontChanged`/`OnFontSizeChanged` (via new `Addon:RebuildUI()`), so language/font now apply without forcing a theme change. |
| _2026-06-14_ | 3+5 | QoL | Done as one pass (core + all 34 externals) — the shared `ns.L` made a core-only step impossible. Core → `OneWoW_QoL` scope (337 keys, BINDING_* folded). Each external → own `QoL.<module>` scope; code switched from shared `ns.L` to per-module `GetTable`. Only cross-deps were 3 generic core keys (FEATURES_ON/OFF, UNKNOWN), duplicated into the 3 modules that read them. Discovered: Overlays/Tooltips/Portals/ToastAlerts read `OneWoW.L` (core scope) by design — keys deliberately kept in OneWoW during the feature transition; left untouched. `minimapskin/` is dead (not in TOC). LocaleManager → shim. Validated clean (braces, no stale refs, per-scope missing-key scan, lint). Anti-pattern sweep + DEVHELP SDK text deferred; in-game verify pending. |
| _2026-06-14_ | 3 | AltTracker | Largest, most complex Phase-3 addon. Scope `OneWoW_AltTracker`; named-var accumulation (`L_enUS`/`L_koKR`) → service `Register`; real koKR. **3 `_G["BINDING_*"]` direct assigns folded into the scope** (service refold pushes `BINDING_*` to `_G`; `Bindings.xml` labels localize on language change). LocaleManager → shim (profile-sync); `ApplyBindingGlobals` dropped. Dropped 40 (Language/Theme/Minimap-section, dead). Added 2 missing keys (`BANK_SEARCH`, `BANK_NO_CHARACTERS`) surfaced by the sweep. Swept 58 bulk + 8 manual fallbacks; dynamic `BANK_<type>` → `GetOptional`; ternaries intact. Post-sweep fixes: restored an inner `cond and ".." .. L["K"] or ""` ternary the bulk pass over-stripped at t-progress.lua:1850-1851 (boolean-concat crash). Lint clean; in-game verify pending. |
| _2026-06-14_ | 3 | Catalog | Accumulation-format LocaleManager addon, **first Phase-3 with real koKR translations**. Scope `OneWoW_Catalog`; `L["K"]=v` → service `Register`; LocaleManager → `ns.ApplyLanguage` shim (kept for profile-sync; `ApplyBindingGlobals` dropped — service refold pushes `BINDING_*`). Dropped 39 keys (entire Language/Theme/Minimap-section blocks — dead here; built by shared GUI panel from `shared` scope). koKR migrated as a normal scope (3 trailing self-ref patches folded to plain keys). No missing keys. Swept 7 `or "lit"` + 3 must-exist dynamic-key fallbacks; ternaries left intact. Lint clean; in-game verify pending. |
| _2026-06-14_ | 3 | Notes | Accumulation-format LocaleManager addon. Scope `OneWoW_Notes`; `L["K"]=v` accumulation → service `Register`; LocaleManager → `ns.ApplyLanguage` shim (kept for profile-sync); koKR `"TEST"` placeholder via `GetStore`. Dropped 34 shared/theme (dead). Added 28 missing keys. Swept 256 fallbacks + 1 `GetOptional`. Lint clean; in-game verify pending. |
| _2026-06-14_ | 3 | Trackers | First Phase-3 (LocaleManager) addon. Scope `OneWoW_Trackers`; locale files → service `Register`; deleted dead `LocaleManager.lua`; removed `SetLocale` from Constants; `ApplyLanguage`→`SetLanguage` shim. koKR `"TEST"` placeholder rewired through `GetStore`. Added 8 missing keys (surfaced by key-name-on-miss). Swept 173 dead fallbacks + 2 `GetOptional`. Lint clean; in-game verify pending. |
| _2026-06-14_ | 0–2 | — | **Phases 0, 1, 2 complete and verified in-game + committed.** Service + `/owlocale` + `SUPPORTED` registry; core split onto the service; all 4 Pattern-D addons (DirectDeposit, Bags, ShoppingList, DevTool) migrated, with their anti-pattern sweeps. Earlier log lines marked "verify pending" reflect state when written; current truth is the Phase checklists. Next: Phase 3 (LocaleManager addons). |
