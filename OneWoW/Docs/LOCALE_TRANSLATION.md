# OneWoW Suite — Locale translation rollout

Active checklist for the post-migration localization effort: dedupe the suite's
locale keys, replace strings with Blizzard globals where exact, and translate the
minimized set into all 11 Blizzard locales. The **implemented Locale service
contract** lives in [`ARCHITECTURE.md`](ARCHITECTURE.md) §6 ("Localization") —
read that first. This file is the plan + working notes; delete it when Phases 2–4
are complete.

The driving rule: pursue the **best outcome, not the fewest phases**. Every
string is translated once, in one place; common strings resolve from `shared` or
Blizzard globals so a translation is never duplicated.

---

## Contract reminders (enforced; do not regress)

- **Disjoint scopes.** A key is EITHER `shared` (identical everywhere) OR scoped
  (per-addon), never both. `/owlocale` reports collisions.
- **A miss returns the key name, never nil** — surfaces missing keys on screen.
- **No `L[key] or "literal"` fallbacks.** The miss is already visible; for
  genuinely optional text use `OneWoW.Locale:GetOptional(scope, key)`.
- **Value identity ≠ translation identity.** Two strings equal in English
  (`Close` the verb vs `Close` the adjective) can diverge in es/fr/de. Collapsing
  by value is a *candidate* decision that needs a meaning check.

---

## The analysis tool — `bin/locale_keydiff.py`

Read-only; run from the repo root. The unit of analysis is the **value**, so two
keys holding the same string collapse together regardless of key name.

```
python bin/locale_keydiff.py                    # full suite report (sections A–E)
python bin/locale_keydiff.py --scope OneWoW_Bags  # per-addon curation worklist
```

**Suite report sections**

| | Meaning | Route |
|---|---|---|
| A | a scope re-defines a key `shared` owns | delete from scope (contract) |
| B | value equals a **canonically-named** Blizzard global (`Delete`→`DELETE`) | Phase 2 (bare global) |
| C | value has no usable global but appears at ≥2 sites | Phase 3 (consolidate to shared) |
| D | per-scope keys remaining after B/C routing | Phase 4 translation baseline |
| E | a global shares a key's NAME but a different value (trap) | never route by name |

A global is "usable" (section B) **only if its name is the canonical upper-snake
of the value**. Incidental same-value globals (`KEY_NUMLOCK_MAC = "Clear"`,
`CDMSND_WAR3_GOLD = "Gold"`) are gated out and fall into C with an
`[incidental global, IGNORE unless apt]` hint.

**`--scope` worklist** buckets one addon's own keys into DELETE / BLIZZARD /
CONSOLIDATE / TRANSLATE — the unit of work for Phases 2–4.

> Counts are a static parse and run ~few% off the runtime `/owlocale` totals
> (programmatic keys, etc.); use them for classification, `/owlocale` for ground
> truth.

---

## Curation rules (the judgment calls the tool can't make)

- **Adopt/consolidate ONLY keys referenced purely via literal `L["KEY"]`.** Before
  removing any key, audit the code for *dynamic* references — the swap can only
  redirect literal call sites, and removal of a dynamically-referenced key is a
  regression (the view returns the key name on a miss, so an `L[var] or fallback`
  shows the raw key; a `GetOptional(...) or x` silently drops to English). Two
  forms to grep for, both excluded from adoption:
  - **Stored key strings:** the key appears quoted in a map/list/arg, e.g.
    `BUILTIN_LOCALE_KEYS = { ["Armor"] = "CAT_ARMOR" }`, `BuildLabelRow("COLOR")`,
    `SETTINGS_SECTION_KEYS = { "TAB_GENERAL", ... }`, `labelKey = "SORT_X"`.
    Audit: `grep -rnE '"KEY"' <addon> --include=*.lua | grep -v Locales`.
  - **Constructed keys:** the key is built at runtime, e.g.
    `"CAT_" .. upper(name)` (Bags `ResolveCategoryName`). No literal to grep — find
    the construction site and exclude every key it can produce.
- **Semantic check before adopting a global (B).** Confirm the global means the
  same thing in context; its translation must be right in all 11 languages, not
  just match English. Verify the value against `.wow_docs/general/GlobalStrings.lua`.
  (e.g. `RESOLUTION` = screen resolution, wrong for an import-conflict "Resolution".)
- **Proper nouns never translate.** Addon/brand names — `"OneWoW"`, `"Notes"`,
  `"Shopping List"`, `"Direct Deposit"` — consolidate to one `shared` key but are
  left identical across every locale.
- **Keep pairs together.** `ON`/`OFF`: only `OFF` has a usable global, so keep
  *both* in `shared` rather than splitting the pair. Same for any matched set.
- **`ENABLE`/`DISABLE` (verbs) ≠ `ENABLED`/`DISABLED` (states).** Distinct keys;
  the verbs are Blizzard globals, the adjectives consolidate to shared.

---

## Phase plan

### Phase 0 — Groundwork ✅ (done 2026-06-15)
- [x] `Locale.SUPPORTED` expanded 6 → 11 locales (enUS, koKR, frFR, deDE, zhCN,
  esES, zhTW, esMX, ruRU, ptBR, itIT); `esMX` promoted to its own locale.
- [x] `ALIASES` = `{ enGB = "enUS" }` (British-English clients share enUS).
- [x] `bin/locale_keydiff.py` analysis tool (value-based, `--scope` worklist).
- [x] Verified in-game: language picker lists 11 and switches correctly.

### Phase 1 — Shared collision fix ✅ (done 2026-06-15)
- [x] Removed redundant `["CLOSE"]` from `OneWoW_QoL` (inherits from `shared`).
  `/owlocale` and section A now report 0 collisions.

### Phase 2 — Blizzard global adoption ✅ (done 2026-06-15)
Baseline: **145 strings / 424 sites**. **Verified complete:** a full
`bin/locale_keydiff.py` re-run reports **0 adoptable candidates remaining** in any
of the 56 scopes — the residual B bucket (59 strings) is entirely (a) OneWoW-core
dead/dynamic keys deferred below, (b) `*_OFF` keys kept for `*_ON` pairing, or
(c) dynamic/constructed refs excluded by the curation rules. Nothing clean was
missed. Per-addon sub-phases (template). For each addon:
- [ ] `python bin/locale_keydiff.py --scope <addon>` → review the **BLIZZARD** bucket.
- [ ] Curate: confirm each global is the semantically-correct one (drop any wrong fit).
- [ ] **Audit each candidate for dynamic references** (see Curation rules) and drop
  any key referenced as a stored/constructed key string, not just literal `L["KEY"]`.
- [ ] Replace `L["KEY"]` call sites with the **bare global** (`CLOSE`, not
  `_G["CLOSE"]` / `_G.CLOSE` — `check_no_g_literal.py` + Lua-Conventions). Use
  `local CLOSE = CLOSE` at file top for heavy users. No nil guards (Retail 12+).
- [ ] Delete the adopted entries from the addon's `Locales/*.lua`.
- [ ] Add each adopted global to `.luarc.json` `diagnostics.globals` (verify it
  exists first; `UNKNOWN` is already listed).
- [ ] `/owlocale` clean + in-game verify the screens; commit.
- [x] After the first addon: add the carve-out to the `onewow-gui-ui` skill
  anti-pattern #5 so `text = CLOSE` (bare whitelisted global) isn't misflagged.

**Sub-phase progress:**
- [x] `OneWoW_DirectDeposit` — 5 used keys swapped to bare globals (`GUILD`,
  `ITEMS`, `SETTINGS`, `STATUS`); 2 dead keys (`SETTINGS`, `ITEM_DEPOSIT_REMOVE`)
  dropped. 7 keys removed across all 6 locale files; globals added to `.luarc.json`.
- [x] `OneWoW_Trackers` — 17 used keys swapped to bare globals (`CANCEL`, `CLOSE`,
  `SAVE`, `SETTINGS`, `DELETE`, `EDIT`, `DAILY`, `GUIDE`, `WEEKLY`, `NEW`, `RESET`,
  `CURRENCY`, `LEVEL`, `ZONE`, `MOUNT`, `REPUTATION`, `TOY`; 29 call sites); dead
  key `TRACKER_PIN_OPACITY` dropped. 18 keys removed from enUS (koKR had none);
  11 new globals added to `.luarc.json`.
- [x] `OneWoW_Bags` — 30 keys adopted (49 call sites across 9 files); 16 new
  globals whitelisted. **Curation exclusions (kept in locale):**
  - `IMPORT_PREVIEW_RESOLUTION` — conflict- not screen-resolution → would mistranslate.
  - `TOGGLE_OFF` — paired with `TOGGLE_ON` (no global); keep the pair for Phase 3.
  - `CAT_ARMOR`/`CAT_EMPTY`/`CAT_MISCELLANEOUS`/`CAT_OTHER`/`COLOR`/`TAB_GENERAL`/
    `TAB_GUILD_BANK` — **dynamic references** (`"CAT_"..upper(name)` construction,
    `BUILTIN_LOCALE_KEYS` map, `BuildLabelRow("COLOR")`, `SETTINGS_SECTION_KEYS`
    list). Adopting them broke category names on the first pass; reverted + redone.
  Dead key `STATUS` dropped. `.luarc.json` globals array also normalized (one-time
  case-insensitive sort) so future inserts stay clean. (`OneWoW_DirectDeposit` and
  `OneWoW_Trackers` re-audited for the same dynamic-ref issue — both clean.) Also
  fixed a latent bug exposed by the investigation: `CategoryManager` resolved
  built-in category names with `(locKey and L[locKey]) or name`, where the
  key-name-on-miss defeats the fallback — switched the 3 sites to
  `OneWoW.Locale:GetOptional(ADDON_NAME, locKey)` to match the view's idiom.

- [x] `OneWoW_Catalog` — 31 keys adopted (48 call sites across 8 files; includes an
  `ns.L["KEY"]` form handled before `L["KEY"]`); 12 new globals whitelisted. **8
  dynamic-ref keys excluded** (kept in locale): `JOURNAL_FILTER_MOUNTS`/`_PETS`
  (`labelKey` fields), `JOURNAL_SPECIAL_MOUNT`/`_PET`/`_TOY` and
  `VENDORS_CATEGORY_BMAH`/`_OTHER`/`_VOID_STORAGE` (map values resolved via `L[var]`).
  9 dead keys (`JOURNAL_COL_HDR_TYPE`, `JOURNAL_STATUS_COLLECTED`/`_NOT_COLLECTED`,
  `QUESTS_FILTER_CLASS_ALL`, `QUESTS_GROUP_TYPE`, `QUESTS_TYPE_LABEL`,
  `TRADESKILLS_BACK`/`_REAGENT_QUAL`/`_TYPE_SECONDARY`) stripped as cleanup.

- [x] `OneWoW_Notes` — 33 keys adopted (136 call sites across 10 files; recurring
  `NOTE_SORT_*`/`CTX_*`/`UI_HELP_LINK_*` across 5 entity tabs); 11 new globals. **2
  excluded:** `TAB_ITEMS` (dynamic `label="TAB_ITEMS"`), `SETTINGS_DISABLED` (paired
  with `SETTINGS_ENABLED="On"`, no global). 13 dead keys stripped (per-entity
  `*_DELETE`/`*_SAVE` superseded by generic `BUTTON_*`; `CORE_PIN_OPACITY` etc.).
  koKR defined none of the 46. **Tooling:** `bin/locale_keydiff.py --scope` now
  auto-classifies each Blizzard candidate as `[literal]` (adoptable) / `[DYNAMIC ->
  exclude]` / `[dead -> strip only]` by scanning the addon's code — the dynamic-ref
  audit is now built in (still manually confirm `dead` keys aren't runtime-constructed).

- [x] `OneWoW_AltTracker` — 81 keys adopted (145 call sites); 22 new globals
  (incl. stat abbreviations `AGI`/`INT`/`STA`/`STR`, `HEALER`/`TANK`,
  `SPECIALIZATION`, `DURABILITY`, `ENCHANTS`, `BID`, `RATING`, …). 2 dynamic
  excluded (`FIN_CAT_VENDOR_BUYBACK`, `Unknown`); 26 dead keys stripped. Worklist
  driven by parsing the tool's auto-classified output (109 candidates). Construction
  audit confirmed clean before trusting `dead` tags.

- [x] `OneWoW_Utility_DevTool` — 30 keys adopted (51 call sites); 10 new globals.
  5 excluded: 4 dynamic (`ERR_RC_UNKNOWN`, `TAB_COLORS`/`_ERRORS`/`_SETTINGS` —
  tab-list label keys) + **`FONT_WIDGET_SIZE_NONE`** (tool tagged it literal, but a
  manual construction audit found `L["FONT_WIDGET_SIZE_"..n]` — the tool's known
  blind spot, caught by the still-required manual check). 6 dead keys stripped.
  6 locale files (non-English had partial coverage, ~17 keys each).

- [x] `OneWoW_ShoppingList` — 7 keys adopted (14 call sites): `OWSL_BTN_*` →
  `BACK`/`CANCEL`/`CLOSE`/`DELETE`/`SETTINGS`, `OWSL_SETTINGS_NO_KEYBIND` →
  `NOT_BOUND`, `OWSL_SETTINGS_TITLE` → `SETTINGS`. 2 new globals (`BACK`,
  `NOT_BOUND`). 3 dead keys stripped. No dynamic refs; full 6-language coverage.

- [x] **Data sub-addons** (11 scopes) — almost nothing to do (mostly 0 candidates).
  `OneWoW_CatalogData_Journal`: adopted 2 (`JOURNAL_STATUS_COLLECTED`→`COLLECTED`,
  `JOURNAL_STATUS_NOT_COLLECTED`→`NOT_COLLECTED` at `JournalData.lua:167`), stripped
  dead `JOURNAL_LIVE_EJ_TAG`. `OneWoW_CatalogData_Tradeskills`: stripped 3 dead
  (`PROF_INSCRIPTION`, `REAGENT_QUALITY`, `TYPE_SECONDARY`). Construction-audited
  first (these data addons looked constructible — `EXP_*`/`PROF_*`/`TYPE_*` — but
  none are constructed). Both globals already whitelisted. Other 9 sub-addons: none.

- [x] `OneWoW_QoL` **core scope** — 4 keys adopted (`DEVHELP_CLOSE`→`CLOSE`,
  `FEATURES_FAVORITES_SECTION`/`TOGGLES_FAVORITES_SECTION`→`FAVORITES`,
  `TAB_SETTINGS`→`SETTINGS`); 5 dead stripped. **Kept:** `CATEGORY_COMBAT`
  (constructed via `ns.L["CATEGORY_"..cat]` — tool mis-tagged it dead; manual
  construction audit caught it), `FEATURES_OFF`/`TOGGLES_OFF` (paired with `*_ON`),
  8 dynamic `TOGGLE_NAME_*`/`TOGGLE_OPT_*`. **Swap restricted to core files**
  (excludes `Modules/external/`) since core and module files share the `L` variable
  bound to different scopes. Globals already whitelisted. Module scopes handled
  separately (next).

- [x] `OneWoW_QoL` **34 external modules** — 11 had candidates (24 keys, 38 call
  sites): automount, autoopen, bagbar, inspectmog, lfgpanel, map_mini_tools,
  map_world_tools, minimapbuttons, playmounts, questitembar, vendorpanel. 6 new
  globals (`DISABLE`, `DISPLAY_MODE`, `EMPTY`, `HIDE`, `OPTIONS`, `PLAYER`). Excluded
  by pairing: `AUTOMOUNT_CAT_OFF`, `charinfo`/`framemover` `FEATURES_OFF` (paired
  with `*_ON`) — which left charinfo/framemover with nothing to adopt. Other 23
  modules: no candidates. **Tooling:** `load_scope_code` fixed so a dotted scope
  (`OneWoW_QoL.<mod>`) classifies against only that module's folder, and a bare QoL
  scope excludes `Modules/external/` — per-module swaps stay correctly isolated
  (core and module files share the `L` name bound to different scopes).

- [x] `OneWoW` **core hub scope** — 8 keys adopted (`SETTINGS_SUBTAB`/`SETTINGS_TAB`
  →`SETTINGS`, `UNIT_CTX_MOUNT_COLLECTED`/`_NOT_COLLECTED_STATUS`→`COLLECTED`/
  `NOT_COLLECTED`, `WIZARD_APPLY`→`APPLY`, `WIZARD_PRESET_RECOMMENDED`→`RECOMMENDED`,
  `WIZARD_RELOAD_LATER`→`LATER`, `WIZARD_SUMMARY_READY`→`READY`); 2 new globals
  (`LATER`, `RECOMMENDED`). 6 dynamic excluded. **26 "dead" tags DEFERRED, not
  stripped** — core has pervasive dynamic locale access (`OneWoW.L[key]`,
  `L[localeKey]`/`L[info.localeKey]`, `L[entry.labelKey]`/`[summaryKey]`,
  `GetOptional(scope,"LOAD_FAIL_"..reason)`, and a `local function L(key)` wrapper in
  SearchData), so a "dead" tag can't be trusted without tracing each dynamic index.
  The 8 adoptions were each confirmed to have exactly one literal `OneWoW.L["K"]`/
  `L["K"]` site and no stored/wrapped/constructed form. (Note: tool's substring count
  correctly treats `OneWoW.L["K"]` as literal.)

- [x] `shared` **scope** (was 49 keys → **51** after fully localizing the General
  panel). The audit found 46/49 keys *unused*:
  `OneWoW/GUI/Settings.lua` (the General panel) hardcoded its English labels instead
  of reading the shared keys — a localization gap, not just dead keys. Fixed by
  wiring the panel to the locale view (`local L = OneWoW.L` at runtime inside
  `CreateSettingsPanel`, which builds post-login; the GUI block itself loads before
  the locale files so file-scope capture is impossible). Scope of this pass = the
  **Language / Theme / Minimap** sections + theme names:
  - **Adopted Blizzard globals:** `CLOSE`, `CANCEL` (dropped from shared; 3 call
    sites swapped — `OneWoW_QoL/UI/t-features.lua`, `t-overlays.lua`,
    `OneWoW_DirectDeposit/GUI/MainWindow.lua`), `SPECIAL` (theme-menu header),
    `FACTION_HORDE`/`FACTION_ALLIANCE`/`FACTION_NEUTRAL` (minimap icon labels — the
    whole trio has globals, set at file scope in `ICON_THEMES`). Only `FACTION_NEUTRAL`
    was new to `.luarc.json`.
  - **Dropped as dead:** `OK` (no exact global — `OKAY`="Okay" differs), the six
    language-name keys `ENGLISH`/`SPANISH`/`KOREAN`/`FRENCH`/`RUSSIAN`/`GERMAN` (picker
    uses `Locale.SUPPORTED[].native`), `SELECT_LANGUAGE`, and the three redundant
    `CURRENT_LANGUAGE`/`THEME_CURRENT`/`MINIMAP_ICON_CURRENT` (replaced by one
    `CURRENT_VALUE="Current: %s"` format used at all 6 "Current:" sites).
  - **Added:** `THEME_HIGHCONTRAST` (coverage gap — 25th theme had no key),
    `THEME_RANDOM`, `THEME_RANDOM_CURRENT` (`"Random (%s)"`), 4 `THEME_GROUP_*`
    titles, `CURRENT_VALUE`.
  - **Theme names** resolve at runtime via new `OneWoW_GUI:GetThemeName(key)` →
    `THEME_<UPPER key>` (e.g. `green`→`THEME_GREEN`), English `Constants.THEMES[key].name`
    as fallback. `GetThemeDisplayName` routes through it. Group titles / random label
    resolve via new `titleKey`/`labelKey` fields on `THEME_MENU_GROUPS` /
    `THEME_SPECIAL_OPTIONS` (greppable, not runtime-constructed).
  - **Full-panel follow-up (done same pass):** the **Font**, **Font Size**, **Value
    display**, and **Donate link** sections too — 10 new keys (`FONT_SECTION`,
    `FONT_DESC`, `FONT_SIZE_DESC`, `FONT_SIZE_WARNING`, `VALUE_DISPLAY_SECTION`/`_DESC`/
    `_LETTERS`/`_REGIONAL`/`_WHITE`, `LINK_DONATE`); `"Font Size"` uses the existing
    `FONT_SIZE` global. **Left as-is:** font family names (proper nouns + `LSM_NAME_TO_KEY`
    lookup identifiers — `"WoW Default"` included), the `"AaBbCc 123"` glyph sample, and
    the `Discord`/`OneWoW Home` link labels (proper nouns). The entire General settings
    panel is now localized (shared scope total: 51 keys).
  - **Phase 4 note:** the 5 translated shared files (koKR/deDE/esES/frFR/ruRU) now
    carry stale keys and miss the ~8 new ones; missing keys fall back to enUS in-game.
    They get regenerated wholesale in Phase 4 — left untouched here.

**Phase 2 remaining:** none. All call-site swaps done; tool confirms 0 adoptable
candidates left.

---

## Post-Phase-2 assessment (2026-06-15)

A full re-run of `bin/locale_keydiff.py` + a locale-file coverage scan, taken before
starting Phase 3, to confirm nothing was missed in Phase 2. Findings:

1. **Phase 2 is complete** — 0 adoptable Blizzard candidates remain (verified above).
2. **Phase 3 (consolidate) is next.** Section C reports **425 strings** that hold the
   same enUS value across ≥2 scopes (e.g. duplicated section titles, status labels).
   Consolidating each to a single `shared` key means translating it once instead of
   per-scope — the core point of the rollout. This is the immediate next phase.
3. **OneWoW-core dead-key sweep still owed.** Core's B bucket is 32 keys, **0
   adoptable**: ~24 tagged `[dead -> strip only]` + 8 `[DYNAMIC]`. Core uses pervasive
   runtime-constructed locale access, so a `dead` tag is untrustworthy without tracing
   each dynamic index. These must be resolved (strip true-dead, keep live) *before*
   Phase 4 so we neither translate dead keys nor drop dynamically-used ones.
4. **Locale-file coverage is sparse — Phase 4 is a large fill.** Only 3 scopes
   (`OneWoW`, `OneWoW_Bags`, `OneWoW_DirectDeposit`) have the original 6 languages;
   every other scope has just 1–2 (enUS, sometimes koKR). **No scope has all 11.**
   Phase 4 must add koKR/frFR/deDE/zhCN/esES/zhTW/esMX/ruRU/ptBR/itIT to every scope.
5. **5 stale `shared` translations** (koKR/deDE/esES/frFR/ruRU) carry pre-rebuild keys
   (`CANCEL`/`CLOSE`/`ENGLISH`/`THEME_CURRENT`/`MINIMAP_ICON_*`) and miss the new ones;
   they fall back to enUS in-game and get regenerated in Phase 4.
6. **E. name-match traps (4)** confirmed informational, not misses —
   `GUILD_BANK_MONEY_LOG`/`NO_BIDS`/`RESETS_IN`/`SETTINGS_TITLE` share a global's *name*
   but mean something different; they stay scoped and translate normally.

### Phase 3 — Consolidate to shared (in progress)
**Tooling:** `python bin/locale_keydiff.py --consolidate` classifies every value-group
(value at ≥2 sites, no usable global) by each site's ref-type and buckets them:
`ALREADY-IN-SHARED` (redirect to the existing shared key), `CROSS-SCOPE SAFE`
(→ new shared key), `INTRA-SCOPE SAFE` (dedupe within one scope), `BLOCKED`
(≥1 dynamic/dead site — can't redirect, same rule as Phase 2). Initial split:
1 already-shared / 69 cross-scope / 90 intra-scope / 265 blocked (the blocked set is
mostly OneWoW-core's dynamic locale access). Decisions (locked): **cross-scope first**,
then intra-scope; **consolidate unambiguous phrases + proper nouns first, flag bare
single words** for review before collapsing.

**Curation rule learned (collision):** a new canonical key name must not equal an
existing key in any *surviving* non-shared scope that holds a *different* value — else
that scope shadows shared and the swapped sites silently show the wrong string. Hit on
`TOTAL_GOLD`: `AltTracker.TOTAL_GOLD`="Gold" already existed, so consolidating "Total
Gold" under that name made AltTracker's swapped sites resolve to "Gold". Fixed by
renaming the shared key to `GOLD_TOTAL`; the driver's collision guard now checks
existing scope keys too.

**Sub-phase progress:**
- [x] **Cross-scope batch 1 — phrases + proper nouns (36 groups).** 35 new shared keys
  + 1 redirect (`Current: %s`→`CURRENT_VALUE`). Multi-word phrases, format strings, and
  the proper noun `Discord`. Applied via a driver that reuses `--consolidate`'s
  classification (only touches verified-safe groups): add-to-shared + swap
  `L["old"]`→`L["CANON"]` + strip the old key from every locale of each owning scope.
  Verified: 0 collisions, 0 orphaned refs, cross-scope-safe 69→34. Shared scope 51→86.
  (`TOTAL_GOLD`→`GOLD_TOTAL` rename per the collision rule above.)
- [x] **Cross-scope batch 2 — bare-word terms (27 groups).** After reviewing all 33
  bare words by part-of-speech, collapsed the 27 with a single consistent sense
  (nouns/verbs/directions/field labels): `Item Rename Expansion Search... Mail Up Down
  Achievement Create Duplicate Filter: Keep Pause Progress Stop Blacklist Campaign Decor
  Discard File: Guild: ID: Lockouts Race: Session Slot Summary`. Verified: 0 collisions,
  0 orphaned refs, no leftover scope defs. Shared scope 86→113; cross-scope-safe 34→7.
  **6 kept per-scope** (`Active Expired Personal Minimal Manual Pin`) — adjectives that
  need gender/number agreement, or `Pin` (noun "map pin" vs verb). Reason recorded as a
  comment block in `OneWoW/Locales/Shared/enUS.lua` so a later pass doesn't re-collapse
  them. (`"%d"` excluded — format placeholder.)

**Remaining (cross-scope):** none actionable — the 7 still flagged by `--consolidate`
are the 6 intentionally-kept adjectives/`Pin` + `"%d"` (all documented in the shared
ledger). Cross-scope track is **complete**.

**Remaining (intra-scope):**
- [ ] **Intra-scope dedup (90 groups)** — dedupe within each scope (AltTracker-heavy:
  `Attention`/`Characters`/`Expanded Details - Coming Soon`, etc.).

Per value group: pick canonical key + value, register once in `shared`, delete every
per-scope copy + repoint call sites, proper nouns marked do-not-translate, `/owlocale`
audit (0 new collisions), in-game verify, commit.

### Phase 4 — Translate the minimized set (pending)
Baseline: ~4,117 unique + ~430 shared canonicals. Per-addon sub-phases:
- [ ] For each scope, the tool's **TRANSLATE** bucket is the must-do list.
- [ ] Fill every missing locale file for the scope (and for `shared`). Source of
  truth for existing Blizzard terms: `.wow_docs/general/GlobalStrings.lua`.
- [ ] `BINDING_*` keys translate normally (the service pushes them to `_G`).
- [ ] In-game spot-check per language where feasible; commit.

---

## Phase-0 baseline (2026-06-15)

| Bucket | Count | Notes |
|---|---|---|
| A. Shared collisions | 1 → 0 | `CLOSE` (fixed in Phase 1) |
| B. Blizzard-by-value | 145 strings / 424 sites | translate 0× |
| C. Consolidate-by-value | 430 strings | translate 1× in shared |
| D. Unique remainder | ~4,117 | genuine per-addon translation |
| E. Name-match traps | 4 | informational |

Naive cost ≈ 5,725 keys × 10 new locales ≈ 57k translations; after routing,
the must-translate set is ~4,550 distinct strings (≈ 20% reduction, plus every
future reuse of the 575 common strings is free).

---

## Notes

- **DevTool is included** — no scope exclusions; consistency over shortcuts.
- **Why bare globals translate 0×:** a Blizzard global resolves to its localized
  value at file load in the player's client, so the key leaves the Locale system
  entirely and never needs an entry in any locale file.
- **esMX vs esES / enGB:** Blizzard treats `esMX` as a distinct client locale (its
  own SUPPORTED entry, alias dropped). `enGB` is a real `GetLocale()` value that
  shares enUS strings, hence the lone alias.
- **Suggested Phase-2 order:** start with a small, self-contained addon
  (`OneWoW_DirectDeposit`, `OneWoW_Trackers`) to prove the call-site-swap +
  `.luarc.json` + verify loop, then the large scopes (`OneWoW`, `OneWoW_AltTracker`,
  `OneWoW_Utility_DevTool`).
