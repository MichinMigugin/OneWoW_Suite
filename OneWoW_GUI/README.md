# OneWoW_GUI - Quick Reference

- **Library:** `LibStub("OneWoW_GUI-1.0")`
- **Location:** `/OneWoW_GUI/`
- **Loaded by:** Suite addons (via `## RequiredDeps: OneWoW_GUI`)
- **Interface:** `120001, 120005` (see `OneWoW_GUI.toc` for the authoritative list)

---

## How To Get It

```lua
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end
```

---

## Centralized Settings (Settings.lua)

GUI owns the shared settings database (`OneWoW_GUI_DB` SavedVariables).
All ecosystem addons read/write through GUI. No more duplicate theme/language/minimap storage.

### Settings stored
- `theme` - color theme key (default: "green")
- `language` - locale key (default: GetLocale())
- `font` - font key (default: "default")
- `fontSizeOffset` - global font size adjustment, -3 to +5 (default: 0)
- `minimap.hide` - minimap button visibility (default: false)
- `minimap.theme` - faction icon: "horde", "alliance", or "neutral" (default: "horde")

### Get a setting
```lua
local theme  = OneWoW_GUI:GetSetting("theme")          -- "green", "blue", etc.
local lang   = OneWoW_GUI:GetSetting("language")        -- "enUS", "koKR", etc.
local font   = OneWoW_GUI:GetSetting("font")            -- "default", "expressway", etc.
local offset = OneWoW_GUI:GetSetting("fontSizeOffset")  -- -3 to +5 (default 0)
local hide   = OneWoW_GUI:GetSetting("minimap.hide")    -- true/false
local icon   = OneWoW_GUI:GetSetting("minimap.theme")   -- "horde"/"alliance"/"neutral"
```

### Set a setting (fires callbacks to all registered addons)
```lua
OneWoW_GUI:SetSetting("theme", "blue")
OneWoW_GUI:SetSetting("language", "koKR")
OneWoW_GUI:SetSetting("font", "expressway")
OneWoW_GUI:SetSetting("fontSizeOffset", 2)       -- range: -3 to +5
OneWoW_GUI:SetSetting("minimap.hide", true)
OneWoW_GUI:SetSetting("minimap.theme", "alliance")
```

### Register for settings change callbacks
```lua
OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", myAddon, function(self, newThemeKey)
    OneWoW_GUI:ApplyTheme(self)
    -- rebuild your UI here
end)

OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", myAddon, function(self, newLangKey)
    -- re-apply your locale tables here, rebuild UI
end)

OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", myAddon, function(self, isHidden)
    -- show/hide your minimap button
end)

OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", myAddon, function(self, newIconTheme)
    -- update your minimap icon
end)

OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", myAddon, function(self, newFontKey)
    -- refresh your UI text with the new font
end)

OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", myAddon, function(self, newOffset)
    -- reapply fonts / rebuild UI to pick up new size offset
    -- SafeSetFont automatically applies the offset, so just re-call your font application
end)
```

### Get the current font file path
```lua
local fontPath = OneWoW_GUI:GetFont()
-- Returns the font file path string, or nil if set to "WoW Default"
-- Example: "Interface\AddOns\OneWoW_GUI\Media\Fonts\Expressway.ttf"
if fontPath then
    myFontString:SetFont(fontPath, 12)
end
```

### Available font keys

Use `OneWoW_GUI:GetFontList()` for the complete list. Sample:

| Key | Label |
|-----|-------|
| default | WoW Default |
| actionman | Action Man |
| adventure | Adventure |
| bazooka | Bazooka |
| blackchancery | Black Chancery |
| celestia | Celestia Medium Redux |
| continuum | Continuum Medium |
| dejavusans | DejaVu Sans |
| dejavuserif | DejaVu Serif |
| diedidie | DieDieDie |
| dorispp | DorisPP |
| enigmatic | Enigmatic |
| expressway | Expressway |
| fitzgerald | Fitzgerald |
| gentiumplus | Gentium Plus |
| hack | Hack |
| homespun | Homespun |
| hookedup | All Hooked Up |
| liberationmono | Liberation Mono |
| liberationsans | Liberation Sans |
| liberationserif | Liberation Serif |
| ptsansnarrow | PT Sans Narrow |
| sfatarian | SF Atarian System |
| sfcovington | SF Covington |
| sfmovieposter | SF Movie Poster |
| sfwondercomic | SF Wonder Comic |
| swfit | SWF!T |
| texgyreadventor | TeX Gyre Adventor |
| texgyreadventorbold | TeX Gyre Adventor Bold |
| wenquanyi | WenQuanYi Zen Hei |
| yellowjacket | Yellowjacket |

### Font API
```lua
local fontList = OneWoW_GUI:GetFontList()           -- full list of { key, label, file }
local path = OneWoW_GUI:GetFontByKey("expressway") -- path or nil for default
OneWoW_GUI:SafeSetFont(fontString, path, 12, "")  -- applies font with offset, fallback to GameFontNormal
local offset = OneWoW_GUI:GetFontSizeOffset()      -- current offset (-3 to +5, default 0)
local key = OneWoW_GUI:MigrateLSMFontName("Expressway")  -- maps LibSharedMedia names to GUI keys
```

### Font Size Offset (global size adjustment)

`SafeSetFont` automatically adds the user's font size offset to every size it receives.
Addons do NOT need to manually add the offset - just pass your base size to `SafeSetFont`.

- Range: `-3` to `+5` (default `0`)
- Minimum final size: `6px` (enforced in `SafeSetFont`)
- Callback: `OnFontSizeChanged` fires when the user changes the offset
- The offset preserves design hierarchy: a 16px header and 12px body with +2 become 18px and 14px

```lua
OneWoW_GUI:SafeSetFont(myFontString, fontPath, 12)
-- If user set offset to +3, actual size applied = 15
-- If user set offset to -2, actual size applied = 10
```

### Stamp out the standard 4-part settings panel
```lua
local yOffset = OneWoW_GUI:CreateSettingsPanel(parentFrame, {
    yOffset = -10,  -- optional, default -10
})
-- yOffset is now updated; continue adding addon-specific content below
```
This creates four themed split containers:
1. Language Selection (left) | Color Theme (right) - with dropdowns
2. Font (left) - dropdown | Font Size (right) - stepper with live preview
3. Minimap Button checkbox (left) | Icon Theme dropdown (right)
4. Discord link (left) | Buy Me A Coffee link (right) - copy-paste edit boxes

All dropdowns read/write directly to `OneWoW_GUI_DB` and fire callbacks.
The panel consumes ~695px of vertical space.

### Migrate existing settings (call once at addon init)
```lua
OneWoW_GUI:MigrateSettings(addon.db.global)
```
On first run, copies theme/language/minimap from the addon's old DB into GUI DB.
Only runs once (sets `_migrated` flag). Safe to call every load.

### Window Position Persistence

Use `SaveWindowPosition` and `RestoreWindowPosition` for movable main windows. Standard DB key: `mainFramePosition` (shape: `{ point, relativePoint, x, y, width?, height? }`). Save on `OnHide` so position persists on close, FullReset, and theme change.

```lua
-- In addon DB defaults: mainFramePosition = {}

-- After creating the main frame:
local storage = addon.db.global.mainFramePosition or {}
if not OneWoW_GUI:RestoreWindowPosition(mainFrame, storage) then
    mainFrame:SetPoint("CENTER")
end

mainFrame:SetScript("OnHide", function()
    local db = addon.db.global
    db.mainFramePosition = db.mainFramePosition or {}
    OneWoW_GUI:SaveWindowPosition(mainFrame, db.mainFramePosition)
end)
```

### Adding GUI settings to a new addon (full pattern)
```lua
function addon:OnInitialize()
    self:InitializeDatabase()
    OneWoW_GUI:MigrateSettings(self.db.global)
    OneWoW_GUI:ApplyTheme(self)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function(self2)
        OneWoW_GUI:ApplyTheme(self2)
        -- rebuild UI
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", self, function(self2)
        -- re-apply locale, rebuild UI
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", self, function(self2, hidden)
        -- show/hide minimap button
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, function(self2)
        -- update minimap icon
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", self, function(self2, newFontKey)
        -- refresh UI text with OneWoW_GUI:GetFont()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", self, function(self2, newOffset)
        -- reapply fonts to pick up new size offset (SafeSetFont handles it automatically)
    end)
end

-- In your settings tab builder:
function CreateMySettingsTab(parent)
    local yOffset = OneWoW_GUI:CreateSettingsPanel(parent, { yOffset = -10 })
    -- add addon-specific settings below using yOffset
end
```

---

## Theme System

### Apply a theme (call once at addon startup)
```lua
OneWoW_GUI:ApplyTheme(addon)
```
Checks GUI settings DB first, then OneWoW hub, then addon.db.global.theme, falls back to green.

### Get a theme color
```lua
local r, g, b, a = OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
```

### Wrap text in a theme color (color codes)
```lua
local s = OneWoW_GUI:WrapThemeColor("Hello", "ACCENT_PRIMARY")
-- Uses CreateColor(...):WrapTextInColorCode; suitable for chat or mixed-color strings
```

### Available color keys
BG_PRIMARY, BG_SECONDARY, BG_TERTIARY, BG_HOVER, BG_ACTIVE,
ACCENT_PRIMARY, ACCENT_SECONDARY, ACCENT_HIGHLIGHT, ACCENT_MUTED,
TEXT_PRIMARY, TEXT_SECONDARY, TEXT_MUTED, TEXT_ACCENT,
BORDER_DEFAULT, BORDER_SUBTLE, BORDER_FOCUS, BORDER_ACCENT,
TITLEBAR_BG, TITLEBAR_BORDER,
BTN_NORMAL, BTN_HOVER, BTN_PRESSED, BTN_BORDER, BTN_BORDER_HOVER,
TEXT_FEATURES_ENABLED, TEXT_FEATURES_DISABLED,
DOT_FEATURES_ENABLED, DOT_FEATURES_DISABLED,
TEXT_WARNING,
BTN_DANGER_NORMAL, BTN_DANGER_HOVER, BTN_DANGER_BORDER, BTN_DANGER_BORDER_HOVER

### Get spacing value
```lua
local px = OneWoW_GUI:GetSpacing("MD")
```
XS=4, SM=8, MD=12, LG=16, XL=24

### Available themes (24 total)
green, blue, purple, red, orange, teal, gold, pink, dark, amber, cyan, slate,
voidblack, charcoal, forestnight, obsidian, monochrome, twilight, neon,
glassmorphic, lightmode, retro, fantasy, nightfae

Order stored in `Constants.THEMES_ORDER`.

### Get faction brand icon
```lua
local texture = OneWoW_GUI:GetBrandIcon("horde")  -- or "alliance" or "neutral"
```

### Minimap launcher (standalone addons)

When OneWoW hub is **not** loaded, addons can create their own minimap button via `CreateMinimapLauncher`:

```lua
local launcher = OneWoW_GUI:CreateMinimapLauncher("OneWoW_MyAddon", {
    label = "My Addon",
    onClick = function(_, button)
        if button == "LeftButton" then MyAddon.GUI:Toggle() end
    end,
    onTooltip = function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
        GameTooltip:SetText("My Addon", 1, 0.82, 0)
        GameTooltip:Show()
    end,
})
-- launcher: { Initialize, Show, Hide, Toggle, IsShown, UpdateIcon, SetShown }
-- Register OnMinimapChanged to call launcher:SetShown(not hidden)
-- Register OnIconThemeChanged to call launcher:UpdateIcon()
```

When OneWoW hub **is** loaded, `CreateMinimapLauncher` returns a stub (no-ops); addons instead call `OneWoW:RegisterMinimap(addon, label, tabKey, callback)` to add an entry to the hub's context menu.

### Get minimap button frame

```lua
local btn = OneWoW_GUI:GetMinimapButton("OneWoW_MyAddon")
-- When OneWoW loaded: returns OneWoW_MinimapButton (hub button)
-- When standalone: returns LibDBIcon's button for addons that registered via CreateMinimapLauncher
-- Use case: attach UI (e.g. error badge) to the minimap button
```

### RegisterMinimap (OneWoW hub)

Addons that load with OneWoW call `OneWoW:RegisterMinimap(addon, label, tabKey, callback)` to add an entry to the hub minimap's right-click context menu:

```lua
if _G.OneWoW then
    _G.OneWoW:RegisterMinimap("OneWoW_MyAddon", "Open My Addon", "myaddon", nil)  -- tabKey opens hub tab
    -- or
    _G.OneWoW:RegisterMinimap("OneWoW_MyAddon", "Open My Addon", nil, function() MyAddon.GUI:Toggle() end)
end
```

### Register GUI constants with fallback

Addons can override or add GUI constants (especially window sizes). Missing keys fall back to `Constants.GUI`, then to `0`. The returned table is read-only.

**Signature:** `OneWoW_GUI:RegisterGUIConstants(guiConstants)` — takes a table, returns a table with metatable.

**Typical usage** — store as `addon.Constants.GUI` in Core/Constants.lua:

```lua
OneWoW_MyAddon.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        WINDOW_WIDTH  = 820,
        WINDOW_HEIGHT = 580,
        MIN_WIDTH     = 820,
        MIN_HEIGHT    = 500,
        LEFT_PANEL_WIDTH = 300,
        SEARCH_HEIGHT = 28,
        ROW_HEIGHT    = 38,  -- addon-specific; falls back to 0 if unused
    }),
}
```

**Base GUI keys** (override any; add custom keys as needed):
WINDOW_WIDTH, WINDOW_HEIGHT, MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT,
PADDING, BUTTON_HEIGHT, BUTTON_WIDTH, SEARCH_HEIGHT, SEARCH_WIDTH,
CHECKBOX_SIZE, ROW1_HEIGHT, ROW2_HEIGHT, LEFT_PANEL_WIDTH, PANEL_GAP, TAB_BUTTON_HEIGHT,
TOGGLE_BUTTON_WIDTH, TOGGLE_BUTTON_HEIGHT

**Common overrides:** WINDOW_WIDTH, WINDOW_HEIGHT, MIN_WIDTH, MIN_HEIGHT, LEFT_PANEL_WIDTH, SIDEBAR_WIDTH, SEARCH_HEIGHT, ROW_HEIGHT, SUBTAB_BUTTON_HEIGHT. Use WINDOW_WIDTH and WINDOW_HEIGHT for main window dimensions.

---

## Frames & Layout

### Component API Conventions

All component creation functions use the **`(parent, options)`** pattern: parent first (when applicable), all other parameters in an options table. This improves discoverability and extensibility.

```lua
local C = OneWoW_GUI.Constants
local frame = OneWoW_GUI:CreateFrame(parent, {
    name = "MyFrame",
    width = 400,
    height = 300,
    backdrop = C.BACKDROP_SOFT,  -- required; use Constants.BACKDROP_SOFT, BACKDROP_INNER_NO_INSETS, etc.
})
```

### Basic themed frame
```lua
local C = OneWoW_GUI.Constants
local frame = OneWoW_GUI:CreateFrame(parent, {
    name = "MyFrame",
    width = 400,
    height = 300,
    backdrop = C.BACKDROP_SOFT,
})
```
Returns a BackdropTemplate frame with theme BG_PRIMARY + BORDER_DEFAULT.
`backdrop` is required; use `OneWoW_GUI.Constants.BACKDROP_SOFT`, `BACKDROP_INNER_NO_INSETS`, etc.

### Dialog
```lua
local result = OneWoW_GUI:CreateDialog({
    name = "MyDialog",              -- frame name (nil = anonymous, but needed for ESC close)
    title = "Export Profile",       -- title bar text
    width = 620,                    -- required
    height = 500,                   -- required
    strata = "DIALOG",             -- optional, default "DIALOG"
    movable = true,                -- optional, default true
    escClose = true,               -- optional, default true (adds to UISpecialFrames)
    showBrand = false,             -- optional, OneWoW brand icon in title bar
    titleIcon = nil,               -- optional, texture path for icon left of title
    titleHeight = 28,              -- optional, default 28
    onClose = function() end,      -- optional, called when X button or ESC closes
    showScrollFrame = false,       -- optional, creates scroll frame in content area
    buttons = {                    -- optional footer button row
        { text = "Import", onClick = function(dialog) end },
        { text = "Cancel", onClick = function(dialog) dialog:Hide() end, color = {0.6, 0.2, 0.2} },
    },
})
```
Returns a table:
- `result.frame` - main frame (call `:Show()` / `:Hide()`)
- `result.titleBar` - title bar frame from CreateTitleBar
- `result.contentFrame` - area between title bar and button row (add your content here)
- `result.scrollFrame` / `result.scrollContent` - if `showScrollFrame = true`
- `result.buttons` - indexed table of button frames matching `buttons` order

Button `color` option: `{r, g, b}` overrides the button background (useful for green confirm, red destructive).
Buttons are right-aligned in footer. A 1px divider separates content from buttons.
Frame starts hidden - call `result.frame:Show()` when ready.

### Confirm dialog (simple yes/no)
```lua
local result = OneWoW_GUI:CreateConfirmDialog({
    name = "MyConfirm",             -- optional frame name
    title = "Confirm Restore",      -- accent header text
    message = "Are you sure?",      -- body text below title
    width = 420,                    -- optional, default 420
    buttons = {
        { text = "Confirm", color = {0.2, 0.6, 0.2}, onClick = function(dialog) end },
        { text = "Cancel", onClick = function(dialog) dialog:Hide() end },
    },
})
```
Convenience wrapper around `CreateDialog` with `movable = false` and auto-calculated height.
Returns the same table as `CreateDialog` plus:
- `result.titleLabel` - FontString for the title text
- `result.messageLabel` - FontString for the message text

Not movable, centered on screen, ESC closes. Title displayed as large accent text (no title bar).

### Filter bar (horizontal control container)
```lua
local filterBar = OneWoW_GUI:CreateFilterBar(parent, {
    height = 40,              -- optional, default 40
    anchorBelow = someFrame,  -- optional, anchor below this frame instead of parent top
    offset = -5,              -- optional, vertical gap from anchor
})
```
Creates a themed container bar (BG_SECONDARY + BORDER_DEFAULT) anchored across the top of parent.
Add your own controls inside (dropdowns, search boxes, buttons) using existing library functions.

### Sort controls (field dropdown + ascending/descending)
```lua
local sort = OneWoW_GUI:CreateSortControls(parent, {
    sortFields = {
        { key = "name", label = "Name" },
        { key = "level", label = "Level" },
    },
    defaultField = "name",
    defaultAsc = true,
    dropdownWidth = 110,
    onChange = function(field, ascending)
        -- refresh list using field / ascending
    end,
})
sort.dirBtn:SetPoint("LEFT", sort.dropdown, "RIGHT", 4, 0)
local field, asc = sort:GetSort()
sort:SetSort("level", false)
```
Returns a handle: `dropdown`, `dirBtn`, `GetSort()`, `SetSort(field, ascending)`. The direction button toggles ascending vs descending and uses collapse/expand atlases for the icon.

### Title bar
```lua
local titleBar = OneWoW_GUI:CreateTitleBar(parent, {
    title = "My Title",
    height = 20,           -- optional, default 20
    onClose = function() parent:Hide() end,  -- optional close button
    showBrand = true,      -- optional OneWoW brand icon + text
    factionTheme = "horde" -- optional, auto-reads from GUI settings if omitted
})
```
Access title text via `titleBar._titleText`.
Access close button via `titleBar._closeBtn` (nil if no `onClose` provided).
When `showBrand = true` and `factionTheme` is omitted, the icon is auto-read from
`OneWoW_GUI:GetSetting("minimap.theme")` (horde/alliance/neutral). This means all
title bars automatically update when the user changes their faction icon setting.

---

## Buttons & Controls

### Button (base - fixed size)
```lua
local btn = OneWoW_GUI:CreateButton(parent, {
    name = "CloseBtn",
    text = "X",
    width = 20,
    height = 20,
})
```
Fixed-size button. Use only for icon buttons (e.g. "X" close). For text buttons, use FitText or FitFrame.

### Fit Text Button (auto-sizes to text)
```lua
local btn = OneWoW_GUI:CreateFitTextButton(parent, {
    text = "Click Me",
    height = 28,      -- optional, default BUTTON_HEIGHT
    minWidth = 40,    -- optional, default 40
    paddingX = 24,    -- optional, default 24 (12 each side)
})
```
Auto-sizes width to fit text content. Handles localization where translated text may be longer.
Call `btn:SetFitText("New Text")` to update text and auto-resize.
Access label via `btn.text`.

### Fit Frame Buttons (fill container width)
```lua
local buttons, finalY = OneWoW_GUI:CreateFitFrameButtons(parent, {
    yOffset = 0,
    items = {
        { text = "Option A", value = "a", isActive = true },
        { text = "Option B", value = "b" },
        { text = "Option C", value = "c" },
    },
    height = 26,      -- optional, default 26
    gap = 4,          -- optional, default 4
    marginX = 12,     -- optional, default 12
    width = 400,      -- optional, defaults to parent:GetWidth()
    onSelect = function(value, text, btn)
        -- handle selection
    end,
})
```
Creates N equal-width buttons that fill the available width. Auto-wraps to next row if needed.
Active button: BG_ACTIVE + BORDER_ACCENT + TEXT_ACCENT. Inactive: BTN_NORMAL + TEXT_MUTED.
Clicking a button auto-toggles active state across all buttons.
Use `buttons.SetActiveByValue(value)` to update selection externally.
Returns buttons table and finalY offset for layout continuation.

### On/Off toggle pair
```lua
local onBtn, offBtn, refresh, statusPfx, statusVal = OneWoW_GUI:CreateOnOffToggleButtons(parent, {
    yOffset = 0,
    onLabel = "On",
    offLabel = "Off",
    width = 50,
    height = 22,
    isEnabled = true,
    value = true,
    onValueChange = function(newValue)
        -- handle value change
    end,
})
-- Update state later:
refresh(isEnabled, newValue)
```
Layout: `Status: On [On] [Off]` - statusPfx anchors TOPLEFT at x=12, buttons follow.
Active button: BG_ACTIVE + BORDER_ACCENT + TEXT_ACCENT. Inactive: BTN_NORMAL + TEXT_MUTED.
Status text: TEXT_FEATURES_ENABLED (green) when on, TEXT_FEATURES_DISABLED (red) when off.
When disabled (isEnabled=false): all elements muted, buttons non-interactive.
To right-align, clear points on offBtn/onBtn/statusVal/statusPfx and re-anchor from TOPRIGHT.
To reposition the cluster after a label, call `statusPfx:ClearAllPoints()` + `statusPfx:SetPoint(...)`.

### Toggle row (label + description/custom + On/Off)
```lua
local newYOffset, refresh, refs = OneWoW_GUI:CreateToggleRow(parent, {
    yOffset = 0,
    label = "Show Lockouts Panel",
    description = "Show the lockouts panel when the Group Finder opens.",  -- optional
    value = true,
    isEnabled = true,
    onValueChange = function(newVal) SaveSetting("show_panel", newVal) end,
    onLabel = "On",   -- optional
    offLabel = "Off", -- optional
})
-- Update state later:
refresh(isEnabled, newValue)
-- refs.label, refs.contentArea (nil if description used)
```
Layout: Row 1: [Label] ... [Status: On] [On] [Off] (right-aligned by default). Row 2: [Description] or custom content.
Use `align = "left"` for module-level Enable: [Label] [Status: On] [On] [Off] all left-aligned.
Use `createContent` instead of `description` for custom widgets (e.g. mount picker). Must return `(widget, height)`:
```lua
local newYOffset, refresh, refs = OneWoW_GUI:CreateToggleRow(parent, {
    yOffset = 0,
    label = "Ground Mount",
    createContent = function(container)
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetSize(220, 30)
        btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        -- ... setup btn ...
        return btn, 30  -- widget, height (required)
    end,
    value = true,
    isEnabled = true,
    onValueChange = function(newVal) ... end,
})
```

### Checkbox
```lua
local cb = OneWoW_GUI:CreateCheckbox(parent, {
    name = "MyCheckbox",        -- optional, global frame name
    label = "Label text",       -- optional, default ""
    checked = true,             -- optional, initial checked state
    onClick = function(self)    -- optional, fires on click
        local isChecked = self:GetChecked()
    end,
})
```
Uses UICheckButtonTemplate. Access label via `cb.label`.
Call `cb:GetChecked()` / `cb:SetChecked(bool)` for state.

### Edit box
```lua
local box = OneWoW_GUI:CreateEditBox(parent, {
    name = "MyEditBox",
    width = 200,           -- optional, omit for anchor-based width (flexible)
    height = 22,           -- optional, default SEARCH_HEIGHT
    placeholderText = "Search...",  -- optional
    maxLetters = 50,       -- optional
    onTextChanged = function(text)  -- optional, text has placeholder filtered out
        FilterMyList(text)
    end,
})
```
Themed with focus border highlight and placeholder text behavior.
When `width` is omitted, only height is set - use anchor points for flexible width.
Use `box:GetSearchText()` to get current text with placeholder filtered out.

Use `CreateEditBox` with `placeholderText` for search boxes. The deprecated `CreateSearchBox` wrapper has been removed.

### Status dot
```lua
local dot = OneWoW_GUI:CreateStatusDot(parent, {
    size = 8,          -- optional, default 8
    enabled = true,    -- optional, sets initial color (true=green, false=red)
})
dot:SetPoint("RIGHT", row, "RIGHT", -8, 0)
dot:SetStatus(true)   -- update: true=DOT_FEATURES_ENABLED, false=DOT_FEATURES_DISABLED
```

### List row (basic)
```lua
local row = OneWoW_GUI:CreateListRowBasic(parent, {
    height = 30,                -- optional, default 30
    label = "Item Name",        -- optional, default ""
    showDot = true,             -- optional, adds status dot on right
    dotEnabled = true,          -- optional, initial dot state
    showValueText = false,      -- optional, adds right-aligned value text
    valueText = "1.50",         -- optional, initial value text
    onClick = function(self)    -- optional
        previousRow:SetActive(false)
        self:SetActive(true)
    end,
})
row:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, yOffset)
row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, yOffset)
```
Returns a Button with themed hover/active states. Properties:
- `row.label` - FontString (GameFontNormal)
- `row.dot` - StatusDot texture (if showDot=true), has `:SetStatus(bool)`
- `row.valueText` - FontString (if showValueText=true)
- `row:SetActive(bool)` - toggle active/selected styling
- `row.isActive` - current active state

Future variants: `CreateListRowExtended` (expandable content section on click).

---

## Text & Dividers

### Header (large accent text)
```lua
local header = OneWoW_GUI:CreateHeader(parent, {
    text = "Section Title",
    yOffset = -12,
})
```

### Divider (1px horizontal line)
```lua
local divider = OneWoW_GUI:CreateDivider(parent, {
    yOffset = 0,
})
```

### Section (header + divider combo)
```lua
local newYOffset = OneWoW_GUI:CreateSection(parent, {
    title = "Section Title",
    yOffset = 0,
})
-- Returns updated yOffset to continue laying out below
```

### Vertical pane resizer (list + detail columns)
```lua
local rightPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
-- Apply your addon’s backdrop styling to left/right panels before calling.
OneWoW_GUI:CreateVerticalPaneResizer({
    parent = tab,
    leftPanel = leftPanel,
    rightPanel = rightPanel,
    dividerWidth = 6,
    leftMinWidth = 200,
    rightMinWidth = 280,
    splitPadding = 16,              -- optional; default dividerWidth + 10
    bottomOuterInset = 5,
    rightOuterInset = 5,
    resizeCap = 0.95,
    mainFrame = hostWindow,         -- optional: iteratively widen until the tab fits desired left + min right
    getMinRightWidth = function() return 320 end,  -- optional dynamic minimum (e.g. unwrapped text width)
    maxAutoGrowSteps = 12,          -- optional; extra SetWidth passes if child width lags the host
    onWidthChanged = function(leftW) db.listPaneWidth = leftW end,
})
```
Caller anchors the left panel; only `SetWidth` on the left is updated. The right panel is re-anchored from the divider. **Clamp** (max left width and host resize) uses `rightMinWidth` only: `maxLeft = parentWidth - rightMinWidth - splitPadding`. With `mainFrame` and optionally `getMinRightWidth`, each drag tick **grows** the host (up to `resizeCap`) until `parent:GetWidth()` can satisfy `desiredLeft + max(rightMinWidth, getMinRightWidth()) + splitPadding`, so the window widens when the dynamic right column would be too narrow, without locking the divider when `getMinRightWidth()` is very large.

### Horizontal pane resizer (top + bottom stacks)
```lua
OneWoW_GUI:CreateHorizontalPaneResizer({
    parent = tab,
    topPanel = topPanel,
    bottomPanel = bottomPanel,
    dividerHeight = 6,
    topMinHeight = 100,
    bottomMinHeight = 60,
    onHeightChanged = function(bottomHeight)
        -- optional: persist after mouse release (callback receives bottom panel height)
    end,
})
```
Caller anchors the top panel from the parent top; only `SetHeight` on the top panel is updated during drag. The bottom panel is re-anchored from the divider to the parent bottom.

---

## Section Headers

### Themed section header bar
```lua
local section = OneWoW_GUI:CreateSectionHeader(parent, {
    title = "Section Title",
    yOffset = 0,
})
-- section.bottomY = yOffset below the header for continued layout
```
Creates a themed bar with background, border, and accent-colored title text.

---

## Scroll Frames

### Standalone scroll frame
```lua
local scrollFrame, content = OneWoW_GUI:CreateScrollFrame(parent, {
    name = "MyScroll",  -- optional, nil for anonymous
    width = 400,        -- optional; omit for auto-sync on resize
})
```
Uses UIPanelScrollFrameTemplate (Lesson 3 compliant).
ScrollBar anchored to parent container.
- Without width: content width auto-syncs on resize.
- With width: content width set to (width - 32).

### Scrollable multiline edit box
```lua
local scrollFrame, editBox = OneWoW_GUI:CreateScrollEditBox(parent, {
    name = "MyEditBox",        -- optional; scrollFrame gets name.."Scroll"
    font = fontPath,           -- optional; falls back to user's chosen GUI font, then ChatFontNormal
    fontSize = 12,             -- optional, default 12 (used when font is set)
    fontFlags = "",            -- optional, default ""
    maxLetters = 0,            -- optional, default 0 (unlimited)
    textInsets = { 4, 4, 4, 4 },  -- optional, {left, right, top, bottom}, default 4px all sides
    textColor = { r, g, b },  -- optional; defaults to TEXT_PRIMARY theme color
    onTextChanged = function(self, userInput)  -- optional
        -- fires on every keystroke
    end,
    onEscapePressed = function(self)  -- optional
        -- fires after ClearFocus() is already called
    end,
})
```
Correct pattern for multiline text entry areas. Fixes the focus dead-zone bug inherent to
`SetHeight(1)` scroll children: clicking anywhere in the visible area always focuses the edit box.

- ScrollFrame uses `UIPanelScrollFrameTemplate` with styled scrollbar.
- EditBox is the scroll child, starts at height 1 and auto-expands with content.
- Width auto-syncs to scrollFrame on resize.
- `scrollFrame:HookScript("OnMouseDown")` calls `editBox:SetFocus()` so clicks anywhere in the
  visible area work, not just the first pixel row.
- Font defaults to the user's active GUI font setting, then `ChatFontNormal`.
- Default anchor: TOPLEFT +8,-8 / BOTTOMRIGHT -8,8 relative to parent. Override after creation if needed.

Use this instead of manually creating `ScrollFrame + EditBox` pairs. Migrate existing scroll+editbox
combos to this function to get the focus fix for free.

### Virtualized list (large row counts)
```lua
local list = OneWoW_GUI:CreateVirtualizedList(listHostFrame, {
    name = "MyList",
    rowHeight = 22,
    numVisibleRows = 40,
    getCount = function() return #myData end,
    getEntry = function(index) return myData[index] end,
    onSelect = function(index, entry) end,
    renderRow = function(btn, index, entry, isSelected)
        btn:SetText(entry.displayName or tostring(entry))
        btn._tooltipFullText = entry.tooltipText
    end,
    enableKeyboardNav = true,
    focusCompetitor = searchEditBox,
})
list.Refresh()
list.SetSelectedIndex(1)
local idx = list.GetSelectedIndex()
```
Requires `getCount`, `getEntry`, and `onSelect`. Reuses a fixed pool of row buttons (`numVisibleRows`) and reparents them while scrolling. Optional `renderRow(btn, index, entry, isSelected)`; default row text uses `entry.displayName`. Set `btn._tooltipFullText` on a row button to show a simple `GameTooltip` on hover. With `enableKeyboardNav`, UP/DOWN moves selection; `focusCompetitor` should be an edit box that hooks focus so keyboard nav yields while typing.

Returns: `listPanel` (the parent passed in), `listScroll`, `listContent`, `Refresh`, `SetSelectedIndex`, `GetSelectedIndex`.

### Style an existing scroll bar
```lua
OneWoW_GUI:StyleScrollBar(scrollFrame, {
    container = parentFrame,  -- optional, anchors scrollbar to this
    offset = -2,              -- optional, right offset
})
```

Lower-level (same styling as above): `OneWoW_GUI:ApplyScrollBarStyle(scrollFrame.ScrollBar, containerFrame, -2)`

---

## Split Panel (List + Detail Layout)

```lua
local panels = OneWoW_GUI:CreateSplitPanel(parent, {
    showSearch = true,              -- optional search box in list panel
    searchPlaceholder = "Search...",-- optional placeholder text for search box
})
```

Returns a table with:
- `panels.listPanel` - left panel frame
- `panels.listTitle` - left title font string
- `panels.listScrollFrame` / `panels.listScrollChild` - left scroll area
- `panels.detailPanel` - right panel frame
- `panels.detailTitle` - right title font string
- `panels.detailScrollFrame` / `panels.detailScrollChild` - right scroll area
- `panels.searchBox` - search edit box (if showSearch=true)
- `panels.leftStatusBar` / `panels.leftStatusText` - left status bar
- `panels.rightStatusBar` / `panels.rightStatusText` - right status bar

Left panel width: 320px. Gap between panels: 10px.

---

## Dropdowns

### Simple dropdown (no search)
```lua
local dropdown, text = OneWoW_GUI:CreateDropdown(parent, {
    width = 200,     -- optional, default 200
    height = 26,     -- optional, default 26
    text = "All",    -- optional, default display text
})
dropdown:SetPoint("LEFT", someFrame, "RIGHT", 8, 0)

OneWoW_GUI:AttachFilterMenu(dropdown, {
    searchable = false,  -- default is true
    buildItems = function()
        return {
            { value = nil, text = "All Characters" },
            { value = "char1", text = "Arthas" },
            { value = "char2", text = "Thrall" },
        }
    end,
    onSelect = function(value, displayText)
        text:SetText(displayText)
        -- do something with value
    end,
    getActiveValue = function() return currentSelection end,
})
```

### Searchable dropdown (with filter box)
```lua
local dropdown, text = OneWoW_GUI:CreateDropdown(parent, {
    width = 200,
    text = "All Zones",
})
dropdown:SetPoint(...)

OneWoW_GUI:AttachFilterMenu(dropdown, {
    searchable = true,  -- default; adds search box at top of menu
    buildItems = function()
        local items = {}
        tinsert(items, { value = nil, text = "All Zones" })
        for _, zone in ipairs(GetZoneList()) do
            tinsert(items, { value = zone, text = zone })
        end
        return items
    end,
    onSelect = function(value, displayText)
        text:SetText(displayText)
    end,
    getActiveValue = function() return currentZone end,
    maxVisible = 20,     -- optional, default 20 (unlimited when searching)
    menuHeight = 314,    -- optional, default 314
})
```

### Dropdown behavior
- Click to open, click again to close
- Active item highlighted with ACCENT_PRIMARY
- Hover: BG_HOVER + TEXT_ACCENT
- Auto-closes after 0.5s when mouse leaves both menu and trigger button
- ESC: clears search text first, closes menu on second press (searchable only)
- Menu opens at DIALOG strata (above the host window)
- buildItems() called fresh each click (supports dynamic lists)
- Scroll uses UIPanelScrollFrameTemplate (Lesson 3 compliant)

### Dismiss architecture (OnUpdate hybrid)

`AttachFilterMenu` uses a two-layer dismiss system to close the menu when the user clicks outside it, without consuming the click:

1. **OnUpdate watcher** — The menu runs an `OnUpdate` script that detects mouse-button-down transitions (via `IsMouseButtonDown`) while `IsMouseOver()` is false. Because WoW processes input (delivering `OnClick` to the topmost control) **before** running `OnUpdate`, the clicked control fires first and then the menu hides — both in the same frame. This gives single-click tab switching, sidebar navigation, etc. while a menu is open.

2. **Game-world overlay** — A fullscreen `UIParent` Button sits **below** the host window (`hostLevel - 2`, same strata). It only catches clicks in areas not covered by the host — primarily the 3D game world — preventing unintended NPC targeting or spell casts while a dropdown is open.

Callers do **not** need to add `CloseAttachFilterMenu()` at navigation boundaries (tab switches, list selection, etc.) — the OnUpdate handles dismiss automatically.

`OneWoW_GUI:CloseAttachFilterMenu()` remains available for programmatic teardown (e.g. before reparenting a host frame) but is not required for normal use.

### Reset dropdown text externally
```lua
text:SetText("All Zones")
dropdown._activeValue = nil
```

---

## Icon Skinning System

Unified icon/item slot skinning for all suite addons. Replaces default WoW icon borders with themed, consistent styling.

### Style presets

| Preset | Border | Trim | Highlight | Use case |
|--------|--------|------|-----------|----------|
| `clean` | 1px | Yes | 0.3 alpha | Default - item slots, gear displays |
| `thick` | 2px | Yes | 0.3 alpha | Emphasized icons, headers |
| `minimal` | 1px | Yes | 0.2 alpha | Compact lists, small icons |
| `none` | 0 | Yes | None | Raw icon, no decoration |

### Create a new skinned icon
```lua
local icon = OneWoW_GUI:CreateSkinnedIcon(parent, {
    size = 36,                -- optional, default 36
    preset = "clean",         -- optional, style preset name
    iconTexture = texturePath,-- optional, icon texture
    itemID = 12345,           -- optional, auto-resolves texture via GetItemIcon
    itemLink = link,          -- optional, enables item tooltip on hover
    quality = 4,              -- optional, colors border by rarity (>1 overrides theme border)
    showIlvl = true,          -- optional, item level text bottom-right
    itemLevel = 623,          -- optional, displayed when showIlvl is true
    showCount = true,         -- optional, stack count text bottom-right
    count = 5,                -- optional, displayed when showCount is true (hidden if <= 1)
    tooltip = "My tooltip",   -- optional, string or function(self) for custom tooltip
    onClick = function(self, button) end,  -- optional, click handler
    onEnter = function(self) end,          -- optional, additional hover behavior
    onLeave = function(self) end,          -- optional, additional leave behavior
    borderColorKey = "BORDER_DEFAULT",     -- optional, theme color key for border
    hoverBorderColorKey = "BORDER_ACCENT", -- optional, theme color key on hover
    desaturate = false,       -- optional, gray out icon
})
icon:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
```

Returns a frame with skinned internals. Access via:
- `icon._skinnedIcon` — the icon texture
- `icon._skinBorder` — the border frame
- `icon._skinHighlight` — the highlight texture
- `icon._ilvlText` / `icon._countText` — overlay text FontStrings

### Skin an existing icon frame
```lua
OneWoW_GUI:SkinIconFrame(existingFrame, {
    preset = "clean",         -- optional, style preset
    quality = 3,              -- optional, rarity border color
    trimIcon = true,          -- optional, trims blurry WoW icon edges
    borderSize = 1,           -- optional, override preset border
    desaturate = false,       -- optional, gray out
    iconTexture = newTexture, -- optional, swap texture
    borderColorKey = "BORDER_DEFAULT",
    hoverBorderColorKey = "BORDER_ACCENT",
})
```
Finds the first texture on the frame and applies trimming, border, background, and highlight. Works on any frame that has a texture child (item buttons, action buttons, etc.).

### Update helpers
```lua
OneWoW_GUI:UpdateIconQuality(frame, 4)           -- change rarity border color
OneWoW_GUI:UpdateIconTexture(frame, newTexture)   -- swap icon texture
OneWoW_GUI:SetIconDesaturated(frame, true)        -- toggle grayscale
```

### Create a row of icons
```lua
local row = OneWoW_GUI:CreateIconRow(parent, {
    icons = {
        { iconTexture = tex1, quality = 3, itemLink = link1 },
        { iconTexture = tex2, quality = 4, itemLink = link2 },
    },
    iconSize = 36,        -- optional, default 36
    spacing = 4,          -- optional, gap between icons
    preset = "clean",     -- optional, default preset for all icons
})
row:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
-- Access individual icons: row._icons[1], row._icons[2], etc.
```

### Skin a cooldown frame
```lua
OneWoW_GUI:SkinCooldown(cooldownFrame, {
    swipeR = 0, swipeG = 0, swipeB = 0, -- optional, swipe color (default black)
    swipeAlpha = 0.6,    -- optional, swipe opacity
    hideEdge = true,     -- optional, hide edge texture (default true)
    hideBling = true,    -- optional, hide bling texture (default true)
})
```

### Get a preset table
```lua
local preset = OneWoW_GUI:GetIconStylePreset("clean")
-- Returns: { borderSize=1, padding=1, trimIcon=true, showHighlight=true, highlightAlpha=0.3, bgAlpha=0.9 }
```

---

## Additional Components

These components exist in the library but are not fully documented here. See source for option keys.

- **CreateSlider(parent, options)** — minVal, maxVal, step, currentVal, onChange, width, fmt
- **CreateProgressBar(parent, options)** — progress bar with theme colors
- **CreateDataTable(parent, options)** — table with `ClearDataRows`, `LayoutDataRows`, `CreateDataRow`
- **CreateOverviewPanel(parent, options)** — overview layout
- **CreateStatusBar(parent, anchorFrame, options)** — status bar
- **CreateRosterPanel(parent, anchorFrame)** — roster layout
- **CreateItemIcon(parent, options)** — item icon frame (legacy, use CreateSkinnedIcon for new code)
- **CreateFactionIcon(parent, options)** — faction icon
- **CreateMailIcon(parent, options)** — mail icon
- **CreateExpandedPanelGrid(ef, options)** — expanded panel grid

**Utility:**
- `GetAddonVersion(addonName)` — returns addon version via C_AddOns
- `GetProgressColor(current, max)` — returns color from PROGRESS_COLORS (NONE/LOW/MID/FULL)
- `GetItemQualityColor(quality)` — returns r, g, b, a for item rarity (respects accessibility settings)
- `IsSecret(value)` — true if the value is a secret value or secret table (Midnight restrictions)
- `FormatNumber(n)` — thousands separators for integers (string digits)
- `FormatGold(copper)` — colored gold/silver/copper string

---

## Utility

### Secret values (Midnight)
```lua
if OneWoW_GUI:IsSecret(nameOrGuid) then
    -- do not branch, persist, or stringify for addon logic
end
```

### Formatting helpers
```lua
local s = OneWoW_GUI:FormatNumber(1234567)  -- "1,234,567"
local goldStr = OneWoW_GUI:FormatGold(copperAmount)
```

### Clear all children from a frame
```lua
OneWoW_GUI:ClearFrame(frame)
```
Hides and orphans all child frames and regions.

---

## Available Backdrop Templates

```lua
Constants.BACKDROP_SIMPLE        -- just bgFile (white8x8)
Constants.BACKDROP_SOFT          -- tooltip bg + tooltip border, with insets
Constants.BACKDROP_INNER         -- white8x8 bg + 1px edge, with 1px insets
Constants.BACKDROP_INNER_NO_INSETS  -- white8x8 bg + 1px edge, no insets
```

---

## GUI Dimension Defaults

```
WINDOW_WIDTH = 1075     MIN_WIDTH = 1075      MAX_WIDTH = 2000
WINDOW_HEIGHT = 900     MIN_HEIGHT = 700      MAX_HEIGHT = 1200
PADDING = 12            BUTTON_HEIGHT = 28    BUTTON_WIDTH = 100
SEARCH_HEIGHT = 22      SEARCH_WIDTH = 200    CHECKBOX_SIZE = 24
ROW1_HEIGHT = 35        ROW2_HEIGHT = 30
LEFT_PANEL_WIDTH = 320  PANEL_GAP = 10        TAB_BUTTON_HEIGHT = 30
TOGGLE_BUTTON_WIDTH = 50  TOGGLE_BUTTON_HEIGHT = 22
```

### Adding OneWoW_GUI to a new addon

**Standard (recommended):** Add `## RequiredDeps: OneWoW_GUI` to your TOC. No need to add `OneWoW_GUI_DB` — OneWoW_GUI declares it. All suite addons use this approach.

**Embedding (legacy):** Only if embedding the library files into your addon. Add `OneWoW_GUI_DB` to SavedVariables and mirror `OneWoW_GUI.toc` load order (embedded Libs first, then Core → Constants → `OneWoW_GUI.lua`, then widget files in TOC order, then Settings and Minimap last). Do not modify vendored files under `Libs\`. Embedding is uncommon in this suite.

```
## SavedVariables: MyAddon_DB, OneWoW_GUI_DB

Libs\LibStub\LibStub.lua
Libs\CallbackHandler-1.0\CallbackHandler-1.0.lua
Libs\LibDataBroker-1.1\LibDataBroker-1.1.lua
Libs\LibDBIcon-1.0\LibDBIcon-1.0.lua
Libs\OneWoW_GUI\Core.lua
Libs\OneWoW_GUI\Constants.lua
Libs\OneWoW_GUI\OneWoW_GUI.lua
Libs\OneWoW_GUI\Buttons.lua
Libs\OneWoW_GUI\Display.lua
Libs\OneWoW_GUI\Controls.lua
Libs\OneWoW_GUI\EditBoxes.lua
Libs\OneWoW_GUI\Layout.lua
Libs\OneWoW_GUI\Panels.lua
Libs\OneWoW_GUI\Icons.lua
Libs\OneWoW_GUI\Settings.lua
Libs\OneWoW_GUI\Minimap.lua
```
