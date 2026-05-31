---
name: onewow-gui-ui
description: Use this skill when authoring or reviewing OneWoW addon UI code — anything calling CreateFrame, building widgets, applying theme colors, sizing windows, or producing user-facing strings. Covers the OneWoW_GUI-First component policy, theme API, and constants/localization rules.
---

# OneWoW_GUI UI Skill

## Context

OneWoW_GUI is the shared UI library for the OneWoW Suite. Every addon depends on it. The policy is **OneWoW_GUI-First**: when a OneWoW_GUI helper exists for a UI need, addon code uses it. Raw `CreateFrame` / `CreateFontString` / hand-rolled backdrops are last resorts, not first reach.

Five rules govern OneWoW UI code:

1. **OneWoW_GUI-First** — check for an existing helper before building raw widgets.
2. **`(parent, options)` component API** — uniform shape across the library.
3. **`GetThemeColor` only** — never touch raw theme data, never wrap the call.
4. **No static user-facing strings** — everything goes through `L.X` translations or `Addon.Constants.X`.
5. **Auto-sizing buttons by default** — fixed width only when layout demands it.

## Authoritative sources

1. `OneWoW_GUI/README.md` — component catalog, backdrop templates, GUI dimension keys, icon skinning, dropdown/menu helpers. Read first to find an existing helper before considering raw widgets.
2. `OneWoW_GUI/Buttons.lua`, `EditBoxes.lua`, `Controls.lua`, `Layout.lua`, `Panels.lua`, `Display.lua`, `Icons.lua`, `Settings.lua`, `Minimap.lua`, `ReorderDrag.lua` — implementations. Read when uncertain about a helper's option contract.
3. `OneWoW_GUI/Constants.lua` — `BACKDROP_*` templates, `GUI.*` dimension defaults, `THEMES` table (semantic color keys). Theme color keys live here.
4. `OneWoW_GUI/OneWoW_GUI.lua` — `GetThemeColor`, `RegisterGUIConstants`, `GetSetting`, `SetSetting`, theme application logic.

## Standard import

Every Lua file that uses OneWoW_GUI starts with:

```lua
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end
```

Fail-fast: if OneWoW_GUI is unavailable, the file exits. No defensive `if OneWoW_GUI and OneWoW_GUI.X then` chains downstream — call methods directly and let missing methods error visibly.

## Component API

All component creators use `(parent, options)`:

```lua
local C = OneWoW_GUI.Constants

OneWoW_GUI:CreateFrame(parent, {
    name = "MyFrame",
    width = 400, height = 300,
    backdrop = C.BACKDROP_SOFT,            -- required
})

OneWoW_GUI:CreateFitTextButton(parent, { text = L.SAVE, height = 24 })
OneWoW_GUI:CreateScrollFrame(parent, { name = "MyScroll" })
OneWoW_GUI:CreateSectionHeader(parent, { title = L.SECTION, yOffset = 0 })
OneWoW_GUI:CreateEditBox(parent, { placeholderText = L.SEARCH, width = 200 })
OneWoW_GUI:CreateSkinnedIcon(parent, { itemID = 12345, showCount = true, count = 5 })
```

Call helpers directly. **No wrapper functions**, **no Framework shims** — they add a function-call hop for zero benefit and obscure where the dependency lives.

## Theme colors

`OneWoW_GUI:GetThemeColor(key)` returns `r, g, b, a`, suitable for `SetColorTexture`, `SetBackdropColor`, `SetTextColor`, `SetBackdropBorderColor`, etc.

Semantic keys (defined per-theme in `Constants.lua`):

- **Backgrounds:** `BG_PRIMARY`, `BG_SECONDARY`, `BG_TERTIARY`, `BG_HOVER`, `BG_ACTIVE`
- **Accents:** `ACCENT_PRIMARY`, `ACCENT_SECONDARY`, `ACCENT_HIGHLIGHT`, `ACCENT_MUTED`
- **Text:** `TEXT_PRIMARY`, `TEXT_SECONDARY`, `TEXT_MUTED`, `TEXT_ACCENT`, `TEXT_WARNING`
- **Borders:** `BORDER_DEFAULT`, `BORDER_SUBTLE`, `BORDER_FOCUS`, `BORDER_ACCENT`
- **Buttons:** `BTN_NORMAL`, `BTN_HOVER`, `BTN_PRESSED`, `BTN_BORDER`, `BTN_BORDER_HOVER`
- **Titlebar:** `TITLEBAR_BG`, `TITLEBAR_BORDER`
- **Status / features:** `TEXT_FEATURES_ENABLED/DISABLED`, `DOT_FEATURES_ENABLED/DISABLED`
- **Danger:** `BTN_DANGER_NORMAL`, `BTN_DANGER_HOVER`, `BTN_DANGER_BORDER`, `BTN_DANGER_BORDER_HOVER`

```lua
-- Direct API call — correct
preview:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
```

## Backdrops

Use templates from `OneWoW_GUI.Constants`, not hand-rolled tables:

```lua
local C = OneWoW_GUI.Constants
frame:SetBackdrop(C.BACKDROP_SOFT)              -- tooltip bg + border with insets
frame:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)   -- white8x8 + 1px edge, no insets
frame:SetBackdrop(C.BACKDROP_INNER)             -- white8x8 + 1px edge with insets
frame:SetBackdrop(C.BACKDROP_SIMPLE)            -- just bgFile
```

`OneWoW_GUI:CreateFrame` requires `backdrop` in its options table — pick from these constants.

## Buttons: auto-size by default

User-facing buttons must auto-size to their text content. Different locales need different widths; fixed widths cause truncation in some languages.

```lua
-- Correct: text drives width
OneWoW_GUI:CreateFitTextButton(parent, { text = L.SAVE, height = 24 })
```

`CreateButton` (fixed-width) is reserved for grids and rigid layouts where the button must match a column.

## GUI dimensions

Per-addon dimension overrides go through `RegisterGUIConstants`, which produces a read-only table that falls back to suite-wide `Constants.GUI` defaults, then to `0`:

```lua
-- MyAddon/Core/Constants.lua
Addon.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        WINDOW_WIDTH  = 820,
        WINDOW_HEIGHT = 580,
        MIN_WIDTH     = 820,
        MIN_HEIGHT    = 500,
        ROW_HEIGHT    = 38,  -- addon-specific custom key
    }),
}
```

Common overridable keys: `WINDOW_WIDTH`, `WINDOW_HEIGHT`, `MIN_WIDTH`, `MIN_HEIGHT`, `MAX_WIDTH`, `MAX_HEIGHT`, `PADDING`, `BUTTON_HEIGHT`, `BUTTON_WIDTH`, `SEARCH_HEIGHT`, `SEARCH_WIDTH`, `CHECKBOX_SIZE`, `LEFT_PANEL_WIDTH`, `PANEL_GAP`, `TAB_BUTTON_HEIGHT`. Reference dimensions through `Addon.Constants.GUI.X`, never hardcoded numerics in component-creation calls.

## Constants & localization

**No static strings in code.** All user-facing text — labels, tooltips, titles, button text, error messages — references either:

- `Addon.Locales/<locale>.lua` translations via the addon's `L.KEY` table (preferred for displayed text)
- `Addon.Constants.X` (preferred for non-translated values: keys, numeric defaults, table data)

```lua
-- Locales/enUS.lua
L.SAVE = "Save"
L.BUTTON_CANCEL = "Cancel"

-- usage
OneWoW_GUI:CreateFitTextButton(parent, { text = L.SAVE })
```

Every addon should have `Addon/Core/Constants.lua` and `Addon/Locales/<locale>.lua`. Create them if missing.

## Shared suite settings

Theme, language, minimap state — owned by the suite. Use `OneWoW_GUI:GetSetting(key)` / `OneWoW_GUI:SetSetting(key, value)` rather than per-addon storage.

## Review checklist — anti-patterns to flag

1. **Raw `CreateFrame`/`CreateFontString` for components OneWoW_GUI provides.** Buttons, edit boxes, scroll frames, section headers, skinned icons, dropdowns, panels — all have helpers. Search the README catalog before approving raw widget construction.

2. **Direct theme data access.** `currentThemeData.ACCENT_PRIMARY`, `unpack(theme.BG_PRIMARY)`, anything that reads the theme table. Use `OneWoW_GUI:GetThemeColor(key)` exclusively.

3. **Theme-color wrapper functions.** `local GetThemeColor = function(k) return OneWoW_GUI:GetThemeColor(k) end` adds a function-call hop for zero benefit. Same for any local `function GetColor(...)` that just delegates. Direct calls only.

4. **Framework / shim wrappers around OneWoW_GUI helpers.** `Addon.UI:Button(...)` that calls `OneWoW_GUI:CreateButton` is duplicated indirection. Call OneWoW_GUI directly.

5. **Hardcoded user-facing strings.** `text = "Save"` in Lua source. Pull from `L.SAVE` (translations) or `Addon.Constants.X`.

6. **Hardcoded color literals.** `SetTextColor(1, 1, 1)`, `SetColorTexture(0.2, 0.6, 0.4)`, RGB constants in Lua source. Use `GetThemeColor` keys. Pure black/white for utility cases (overlays, masks) is the rare exception.

7. **Hardcoded backdrop tables.** `{ bgFile = "...", edgeFile = "...", tile = true, ... }` defined in addon code. Use `OneWoW_GUI.Constants.BACKDROP_*`.

8. **Hardcoded GUI dimensions.** `SetWidth(820)`, `height = 28` literals scattered through component calls. Reference `Addon.Constants.GUI.WINDOW_WIDTH` or the suite-wide `OneWoW_GUI.Constants.GUI.BUTTON_HEIGHT`.

9. **Fixed-width user-facing buttons.** `CreateButton(parent, { text = L.SAVE, width = 80 })` for buttons that display translated text. Use `CreateFitTextButton`. Fixed-width is reserved for explicit grid/rigid-layout cases.

10. **Defensive guards on OneWoW_GUI calls.** `if OneWoW_GUI and OneWoW_GUI.CreateFitTextButton then ... end`. The `LibStub("OneWoW_GUI-1.0", true) ... if not OneWoW_GUI then return end` pattern at the top of the file already covers this. Defensive checks downstream just hide breakage. (Overlaps with `No-Defensive-Guards` rule.)

11. **Per-addon storage of shared suite settings.** Theme key, language, minimap visibility stored in `Addon.db` instead of via `OneWoW_GUI:GetSetting/SetSetting`. (Overlaps with `wow-database-api` skill review item #6.)

12. **Custom UI patterns added without checking OneWoW_GUI first.** New widget code without evidence the OneWoW_GUI catalog was consulted. The policy requires checking — and discussing additions to OneWoW_GUI before introducing local workarounds — not just falling through to raw `CreateFrame`.

## Related rules

- `.cursor/rules/WoW-Lua-Addon-Development.mdc` — sections 2.3, 2.3.1, 2.3.2, 2.4, 2.5 live in the big rule today; this skill replaces them on extraction.
- `.cursor/rules/No-Defensive-Guards.mdc` — overlaps with item #10.
- `wow-database-api` skill — overlaps with item #11 (shared settings).