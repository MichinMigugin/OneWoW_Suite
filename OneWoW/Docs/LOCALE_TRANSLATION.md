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

- **Semantic check before adopting a global (B).** Confirm the global means the
  same thing in context; its translation must be right in all 11 languages, not
  just match English. Verify the value against `.wow_docs/general/GlobalStrings.lua`.
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

### Phase 2 — Blizzard global adoption (pending)
Baseline: **145 strings / 424 sites**. Per-addon sub-phases. For each addon:
- [ ] `python bin/locale_keydiff.py --scope <addon>` → review the **BLIZZARD** bucket.
- [ ] Curate: confirm each global is the semantically-correct one (drop any wrong fit).
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

### Phase 3 — Consolidate to shared (pending)
Baseline: **430 strings**. Per-addon sub-phases. For each value group:
- [ ] Pick the canonical key name (often the simplest existing one) and value.
- [ ] Register it once in `shared` (`OneWoW/Locales/Shared/*.lua`), all locales.
- [ ] Delete every per-scope copy; update call sites to the canonical key.
- [ ] Proper nouns: consolidate but mark do-not-translate.
- [ ] `/owlocale` audit (no new collisions); in-game verify; commit.

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
