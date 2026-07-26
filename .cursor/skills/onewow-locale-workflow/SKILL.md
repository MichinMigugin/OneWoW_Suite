---
name: onewow-locale-workflow
description: Use when adding, changing, or removing user-facing strings or locale keys in any OneWoW addon — UI labels, errors, tooltips, new L["KEY"] entries, or edits under Locales/*.lua. Covers Blizzard globals vs shared vs scoped keys, all 11 locales, and locale_keydiff / locale_verify.
---

# OneWoW Locale Workflow

Load this skill **before** adding any user-facing string or locale key. The mandatory
rule is `.cursor/rules/OneWoW-Locale-Workflow.mdc` (auto-attached when `Locales/`
files are open). Follow it even when only editing UI `.lua` files.

## Routing decision (30 seconds)

| English text | Action |
|---|---|
| Matches a Blizzard global exactly (`Add`, `Cancel`, `Custom`, …) | `text = ADD` / `CLOSE` / `CUSTOM` — **zero locale keys** |
| Same phrase already in `OneWoW/Locales/Shared/enUS.lua` | Reuse `L["SHARED_KEY"]` — **zero new keys** |
| Unique to one addon or module | New key in **that scope's** `Locales/enUS.lua` + **all 10 other locales** |

Quick checks:

```bash
# Does this scope already have adoptable globals for my new keys?
python bin/locale_keydiff.py --scope OneWoW_QoL

# Is parity intact after my edit?
python bin/locale_verify.py OneWoW_QoL/Locales
```

Global name lookup: `.wow_docs/blizzard-interface-resources/Resources/GlobalStrings/enUS.lua`
(canonical upper-snake must match the value — e.g. `ADD = "Add"`). The same folder holds all
11 locales — use them as the source of truth for official translated terms (see "Blizzard
terms" below); they're indexed in `.wow_docs/manifest.json`.

## Scopes (where keys live)

- **`shared`** — `OneWoW/Locales/Shared/` — common UI reused across addons.
- **Core hub** — `OneWoW/Locales/` — hub chrome, search, overlays registry, etc.
- **Load units** — `<Addon>/Locales/` — e.g. `OneWoW_Bags`, `OneWoW_QoL`.
- **QoL external modules** — `OneWoW_QoL/Modules/external/<id>/Locales/` — scope is
  `OneWoW_QoL.<id>`; use `local _, L = ns.ModuleRegistry:Current()` in module files.

A key is **either** shared **or** scoped — never both. `/owlocale` reports collisions.

## All 11 locales (non-negotiable)

Every new key goes into **every** file in the scope's `Locales/` folder:

`enUS`, `koKR`, `frFR`, `deDE`, `zhCN`, `esES`, `zhTW`, `esMX`, `ruRU`, `ptBR`, `itIT`

Draft translations for the 10 non-enUS files in the same edit. Flag as machine-drafted.
**Don't hand-author `esMX`** — run `python bin/gen_esmx.py <Locales>` (mirrors `esES` + applies
LatAm terms).

## Blizzard terms (align, don't guess)

For established WoW terminology (Warband, Auction House, professions, difficulties, slots, …) use
the **official Blizzard term per language**, not a plausible alternative. Source of truth:
`.wow_docs/blizzard-interface-resources/Resources/GlobalStrings/<loc>.lua` (all 11 locales, indexed
in `.wow_docs/manifest.json`). Find the English value's key in `enUS.lua`, then read that key in each
locale. **Verify — do not assume an existing suite translation is canonical** (the suite's pre-rollout
terms were partly non-official). Mind per-language grammar (articles, gender, compounds).

### Two uses of GlobalStrings

1. **UI labels / official terms** — bare globals at call sites (`text = ADD`) or drafting suite
   locale values from Blizzard wording. Covered by this skill + `locale_keydiff` /
   `locale_verify`.
2. **Match-source format strings** — deriving Lua `strfind` patterns from globals like
   `ITEM_SPELL_CHARGES` for tooltip/PE scanning. Format placeholders (`|4…;`, `%d`, `%1$s`)
   vary by locale; suite `locale_verify` does **not** cover Blizzard GlobalStrings.

For (2), follow `wow-tooltip-system` (structured line types first; placeholder-first pattern
conversion; no empty-pattern fallbacks) and run / rely on pre-commit
`tooltip-globalstrings-patterns` (`bin/check_tooltip_patterns.py`).

## Different meanings per language

Value identity ≠ translation identity. A single English string can need different translations by
sense (`Close` verb vs adjective) or agreement (`Rested`, color names — gender/number). Don't fold
distinct senses onto one shared key; keep matched pairs (`ON`/`OFF`) and verb-vs-state
(`ENABLE` vs `ENABLED`) as separate keys.

## Call-site patterns

```lua
-- Blizzard global (already localized by the client)
OneWoW_GUI:CreateFitTextButton(parent, { text = ADD })

-- Shared or scoped key via the addon view
OneWoW_GUI:CreateFitTextButton(parent, { text = L["ADD_ITEM"] })

-- Dialog built-in close — global, not a locale key
buttons = { { text = CLOSE, onClick = function(f) f:Hide() end } }
```

## Common mistake (what not to do)

```lua
-- BAD: duplicates Blizzard ADD in 11 locale files × N languages of maintenance
["PORTAL_CUSTOM_ADD"] = "Add",
text = L["PORTAL_CUSTOM_ADD"]

-- GOOD
text = ADD
```

```lua
-- BAD: duplicates shared ITEM_ID
["PORTAL_CUSTOM_ID_LABEL"] = "Item ID:",

-- GOOD
label:SetText(L["ITEM_ID"])
```

## Verification gate

Task is **not done** until:

1. `python bin/locale_keydiff.py --scope <Scope>` — no new keys in BLIZZARD/CONSOLIDATE buckets.
2. `python bin/locale_verify.py <Locales/path>` — exit 0, all locales `N/N OK`.

`locale_verify.py` is also wired as the **`locale-parity` pre-commit hook** — it runs
automatically on changed locale files and blocks the commit on any parity/spec/duplicate
failure. Still run it yourself before marking the task done; don't rely on the hook to catch
problems late.

## Deep reference

`OneWoW/Docs/LOCALES.md` — durable guide: full tooling catalog (`locale_gen`, `locale_migrate`,
`locale_usage`, `gen_esmx`, `/owlocale`), routing rationale, what's-not-translated-and-why,
Blizzard-term alignment + Warband table, dynamic-key audit rules.

Related: `onewow-gui-ui` skill (anti-pattern #5 — bare globals vs `L["KEY"]`).
