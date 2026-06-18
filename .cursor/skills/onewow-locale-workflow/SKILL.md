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

Global name lookup: `.wow_docs/general/GlobalStrings.lua` (canonical upper-snake must
match the value — e.g. `ADD = "Add"`).

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

Draft translations for the 10 non-enUS files in the same edit. Flag as machine-drafted;
`esMX` copies from `esES` unless LatAm wording is known.

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

Optional human gate: add `python bin/locale_verify.py …` to pre-commit for the paths you
touch often (tool exits non-zero on failure by design).

## Deep reference

`OneWoW/Docs/LOCALE_TRANSLATION.md` — Phase history, dynamic-key audit rules, `locale_gen.py`,
`locale_migrate.py`, esMX automation.

Related: `onewow-gui-ui` skill (anti-pattern #5 — bare globals vs `L["KEY"]`).
