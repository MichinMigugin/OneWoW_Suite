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

1. `OneWoW/Docs/GUI.md` — component catalog, backdrop templates, GUI dimension keys, media asset policy, icon skinning, dropdown/menu helpers. Read first to find an existing helper before considering raw widgets.
2. `OneWoW/GUI/Buttons.lua`, `EditBoxes.lua`, `Controls.lua`, `Layout.lua`, `Panels.lua`, `Display.lua`, `Icons.lua`, `Settings.lua`, `Fonts.lua`, `ReorderDrag.lua` — implementations. Read when uncertain about a helper's option contract. Shared appearance settings UI lives in hub `OneWoW/UI/settings-shared-panel.lua` (not stamped into suite units).
3. `OneWoW/GUI/Constants.lua` — `BACKDROP_*` templates, `GUI.*` dimension defaults, `MEDIA_BASE` / `ICON_TEXTURES`, `THEMES` table (semantic color keys). Theme color keys live here.
4. `OneWoW/GUI/OneWoW_GUI.lua` — `GetThemeColor`, `RegisterGUIConstants`, `GetSetting`, `SetSetting`, theme application logic.

## Standard import

Every Lua file that uses OneWoW_GUI starts with:

```lua
local OneWoW_GUI = OneWoW_GUI
```

The toolkit is a plain global published by `OneWoW/GUI/Core.lua` (the former LibStub library was absorbed into core). Every suite unit has `RequiredDeps: OneWoW`, so no existence guard.

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
- **Links:** `LINK_IDLE`, `LINK_HOVER`, `LINK_UNDERLINE` (text links; distinct from section-header `ACCENT_PRIMARY`)
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

## Media assets

All suite media ships under `OneWoW/Media/` (shared root or `OneWoW/Media/<AddonName>/`
for unit-specific files). **Never** add `OneWoW_*/Media/` copies.

```lua
local MEDIA = OneWoW_GUI.Constants.MEDIA_BASE
texture:SetTexture(MEDIA .. "icon-gears.png")
```

Faction icons: `OneWoW_GUI:GetBrandIcon(theme)` or `Constants.ICON_TEXTURES`.
Custom overlay icons: `OneWoW.OverlayIcons:GetTexturePath("icon-mount")`.
Full layout and pre-commit policy: `OneWoW/Docs/GUI.md` (Media assets).

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

- the addon's `ns.L` translation view (preferred for displayed text)
- `Addon.Constants.X` (preferred for non-translated values: keys, numeric defaults, table data)

Localization runs through the suite-wide **Locale service** (`OneWoW.Locale`). Each
addon registers its own scope (keyed by `ADDON_NAME`) and caches a read-only view
once at file scope. Locale files **register**, they do not assign a table directly:

```lua
-- Locales/enUS.lua  (ADDON_NAME, ns = ...)
OneWoW.Locale:Register(ADDON_NAME, "enUS", {
    SAVE          = "Save",
    BUTTON_CANCEL = "Cancel",
})
ns.L = OneWoW.Locale:GetTable(ADDON_NAME)  -- identity-stable, read-only

-- usage (call sites unchanged)
OneWoW_GUI:CreateFitTextButton(parent, { text = ns.L.SAVE })
```

Contract you must follow (full detail: `OneWoW/Docs/ARCHITECTURE.md` §6 "Localization"):

- **A miss returns the key name, never nil.** Missing keys show up as `BUTTON_CANCEL`
  on screen, which is the point — it surfaces the bug instead of hiding it.
- **No `L[key] or "fallback"` literals.** The key-name-on-miss already self-documents;
  an `or "literal"` just re-hardcodes a string and masks the missing key. For
  *genuinely* optional localization ("translate if a key exists, else use a dynamic
  value") use `OneWoW.Locale:GetOptional(scope, key)`, which returns value-or-nil.
  A real `cond and L.A or L.B` ternary (both branches localized) is fine.
- **The view refolds in place** on language change, so a cached `ns.L` never goes
  stale — never re-fetch it per call. Language switching is centralized through
  `OneWoW.Locale:SetLanguage`; register `OneWoW.Locale:OnApply(fn)` only if you cache
  built strings in standalone UI that needs an explicit rebuild (hub tabs rebuild
  themselves).

Every addon should have `Addon/Core/Constants.lua` and `Addon/Locales/<locale>.lua`. Create them if missing.

**Adding new keys:** load the `onewow-locale-workflow` skill first — check Blizzard globals and `shared` before inventing scoped keys; update all 11 locale files; run `bin/locale_keydiff.py` and `bin/locale_verify.py` before finishing.

## Shared suite settings

Theme, language, font, minimap, and value-display options are owned by the suite
(`OneWoW_GUI:GetSetting` / `SetSetting`). The **UI** for those controls lives only
on the OneWoW hub Settings tab — do not embed a duplicate shared-settings panel
in suite unit windows. Feature-specific settings stay in the unit (or via
`OneWoW:RegisterSettingsPanel`).

## Live font size & re-flow ("headphones + wheels")

Users can change the suite font and font **size** at runtime. Two things must hold
for a panel to respond without a `/reload`:

1. **Re-apply fonts (headphones).** The main OneWoW window rebuilds itself on font
   change, so anything inside it is covered. Anything **outside** it is not:
   standalone dialogs and panels docked to Blizzard frames (Auction House, merchant,
   inspect, …). Those must be **font roots**.
   - **Dialogs built via `OneWoW_GUI:CreateDialog`** (and everything routed through it —
     `CreateConfirmDialog`, `ShowCopyURLDialog`, `ShowCopyLinksDialog`) are registered
     **automatically**. Nothing to do.
   - **Hand-rolled panels** (`CreateFrame` docked to a Blizzard frame) must call
     `OneWoW_GUI:RegisterFontRoot(frame, relayoutFn)` once at build. The driver then
     runs `ApplyFontToFrame(frame)` across the subtree on every font/size change.
     Never hand-register `OnFontChanged`/`OnFontSizeChanged` for this — the registry
     is the one funnel.

2. **Re-flow with measured heights (wheels).** Re-fonting alone isn't enough if the
   layout hard-codes row heights: taller text overlaps the row below it (the classic
   "status text lands on the description" bug). Stacked text rows must derive their
   height from the text — `fs:GetStringHeight()` (fall back to a fixed height only
   until the width resolves) — and the panel exposes a `relayout` function that
   re-runs the stack. Pass it as `RegisterFontRoot(frame, relayout)` (docked panels)
   or `config.relayout` (dialogs) so it runs after re-fonting.

**Standing check (do this even when the task is something else):** any time you open a
panel/dialog file, confirm both apply — it's a font root (auto via `CreateDialog`, else
`RegisterFontRoot`), and its text rows are measured, not fixed-height. Fixing the
"wheels" on a panel you're already editing is in scope, not scope creep.

Reference implementation: `OneWoW_AltTracker_Auctions/UI/AHPricesPanel.lua`
(`RelayoutPanel` + `RegisterFontRoot`). Registry + driver: `OneWoW/GUI/Fonts.lua`
(`RegisterFontRoot` / `ApplyFontToFrame`).

## Review checklist — anti-patterns to flag

1. **Raw `CreateFrame`/`CreateFontString` for components OneWoW_GUI provides.** Buttons, edit boxes, scroll frames, section headers, skinned icons, dropdowns, panels — all have helpers. Search the README catalog before approving raw widget construction.

2. **Direct theme data access.** `currentThemeData.ACCENT_PRIMARY`, `unpack(theme.BG_PRIMARY)`, anything that reads the theme table. Use `OneWoW_GUI:GetThemeColor(key)` exclusively.

3. **Theme-color wrapper functions.** `local GetThemeColor = function(k) return OneWoW_GUI:GetThemeColor(k) end` adds a function-call hop for zero benefit. Same for any local `function GetColor(...)` that just delegates. Direct calls only.

4. **Framework / shim wrappers around OneWoW_GUI helpers.** `Addon.UI:Button(...)` that calls `OneWoW_GUI:CreateButton` is duplicated indirection. Call OneWoW_GUI directly.

5. **Hardcoded user-facing strings.** `text = "Save"` in Lua source. Pull from `ns.L.SAVE` (translations) or `Addon.Constants.X`. This includes `ns.L.KEY or "Save"` fallbacks — the Locale view already returns the key name on a miss; use `OneWoW.Locale:GetOptional` for genuinely optional text. **Exception:** a bare all-caps Blizzard global string (`text = CLOSE`, `text = SETTINGS`) is sanctioned — it's already localized by Blizzard. These must be whitelisted in `.luarc.json` `diagnostics.globals`; never write them as `_G.CLOSE` / `_G["CLOSE"]`.

6. **Hardcoded color literals.** `SetTextColor(1, 1, 1)`, `SetColorTexture(0.2, 0.6, 0.4)`, RGB constants in Lua source. Use `GetThemeColor` keys. Pure black/white for utility cases (overlays, masks) is the rare exception.

7. **Hardcoded backdrop tables.** `{ bgFile = "...", edgeFile = "...", tile = true, ... }` defined in addon code. Use `OneWoW_GUI.Constants.BACKDROP_*`.

8. **Hardcoded GUI dimensions.** `SetWidth(820)`, `height = 28` literals scattered through component calls. Reference `Addon.Constants.GUI.WINDOW_WIDTH` or the suite-wide `OneWoW_GUI.Constants.GUI.BUTTON_HEIGHT`.

9. **Fixed-width user-facing buttons.** `CreateButton(parent, { text = L.SAVE, width = 80 })` for buttons that display translated text. Use `CreateFitTextButton`. Fixed-width is reserved for explicit grid/rigid-layout cases.

10. **Defensive guards on OneWoW_GUI calls.** `if OneWoW_GUI and OneWoW_GUI.CreateFitTextButton then ... end`. The global is guaranteed by `RequiredDeps: OneWoW`; defensive checks downstream just hide breakage. (Overlaps with `No-Defensive-Guards` rule.)

11. **Per-addon storage of shared suite settings.** Theme key, language, minimap visibility stored in `Addon.db` instead of via `OneWoW_GUI:GetSetting/SetSetting`. (Overlaps with `wow-database-api` skill review item #6.)

12. **Custom UI patterns added without checking OneWoW_GUI first.** New widget code without evidence the OneWoW_GUI catalog was consulted. The policy requires checking — and discussing additions to OneWoW_GUI before introducing local workarounds — not just falling through to raw `CreateFrame`.

13. **Panels that don't survive a live font-size change.** A dialog/panel outside the main window that isn't a font root (built via raw `CreateFrame` without `RegisterFontRoot`), or a stacked layout with hard-coded text-row heights that overlaps when the font grows. See "Live font size & re-flow" above. Check this on every panel/dialog you touch, even incidentally.

## Related rules

- `.cursor/rules/OneWoW-Locale-Workflow.mdc` — mandatory when editing `Locales/` or adding translation keys.
- `.cursor/rules/WoW-Lua-Addon-Development.mdc` — sections 2.3, 2.3.1, 2.3.2, 2.4, 2.5 live in the big rule today; this skill replaces them on extraction.
- `.cursor/rules/No-Defensive-Guards.mdc` — overlaps with item #10.
- `wow-database-api` skill — overlaps with item #11 (shared settings).
