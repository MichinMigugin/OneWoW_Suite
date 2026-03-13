# OneWoW_GUI - Quick Reference

**Library:** `LibStub("OneWoW_GUI-1.0")`
**Location:** `/OneWoW_GUI/`
**Loaded by:** OneWoW, OneWoW_QoL (via RequiredDeps)

---

## How To Get It

```lua
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end
```

Any addon that depends on OneWoW or OneWoW_GUI can use it.

---

## Centralized Settings (Settings.lua)

GUI owns the shared settings database (`OneWoW_GUI_DB` SavedVariables).
All ecosystem addons read/write through GUI. No more duplicate theme/language/minimap storage.

### Settings stored
- `theme` - color theme key (default: "green")
- `language` - locale key (default: GetLocale())
- `font` - font key (default: "default")
- `minimap.hide` - minimap button visibility (default: false)
- `minimap.theme` - faction icon: "horde", "alliance", or "neutral" (default: "horde")

### Get a setting
```lua
local theme = OneWoW_GUI:GetSetting("theme")         -- "green", "blue", etc.
local lang  = OneWoW_GUI:GetSetting("language")       -- "enUS", "koKR", etc.
local font  = OneWoW_GUI:GetSetting("font")           -- "default", "expressway", etc.
local hide  = OneWoW_GUI:GetSetting("minimap.hide")   -- true/false
local icon  = OneWoW_GUI:GetSetting("minimap.theme")  -- "horde"/"alliance"/"neutral"
```

### Set a setting (fires callbacks to all registered addons)
```lua
OneWoW_GUI:SetSetting("theme", "blue")
OneWoW_GUI:SetSetting("language", "koKR")
OneWoW_GUI:SetSetting("font", "expressway")
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
| Key | Label | File |
|-----|-------|------|
| default | WoW Default | (nil - game default) |
| expressway | Expressway | Expressway.ttf |
| ptsansnarrow | PT Sans Narrow | PTSansNarrow.ttf |
| continuum | Continuum Medium | ContinuumMedium.ttf |
| actionman | Action Man | ActionMan.ttf |
| homespun | Homespun | Homespun.ttf |
| diedidie | DieDieDie | DieDieDie.ttf |

### Stamp out the standard 4-part settings panel
```lua
local yOffset = OneWoW_GUI:CreateSettingsPanel(parentFrame, {
    yOffset = -10,  -- optional, default -10
})
-- yOffset is now updated; continue adding addon-specific content below
```
This creates three themed containers:
1. Language Selection (left) | Color Theme (right) - with dropdowns
2. Font (full width) - dropdown with live preview text
3. Minimap Button checkbox (left) | Icon Theme dropdown (right)

All dropdowns read/write directly to `OneWoW_GUI_DB` and fire callbacks.
The panel consumes ~495px of vertical space.

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

### Available color keys
BG_PRIMARY, BG_SECONDARY, BG_TERTIARY, BG_HOVER, BG_ACTIVE,
ACCENT_PRIMARY, ACCENT_SECONDARY, ACCENT_HIGHLIGHT, ACCENT_MUTED,
TEXT_PRIMARY, TEXT_SECONDARY, TEXT_MUTED, TEXT_ACCENT,
BORDER_DEFAULT, BORDER_SUBTLE, BORDER_FOCUS, BORDER_ACCENT,
TITLEBAR_BG, TITLEBAR_BORDER,
BTN_NORMAL, BTN_HOVER, BTN_PRESSED, BTN_BORDER, BTN_BORDER_HOVER,
TEXT_FEATURES_ENABLED, TEXT_FEATURES_DISABLED,
DOT_FEATURES_ENABLED, DOT_FEATURES_DISABLED

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

### Register GUI constants with fallback
```lua
local myConstants = OneWoW_GUI:RegisterGUIConstants({ MY_WIDTH = 500 })
-- Missing keys fall back to Constants.GUI values, then 0
```

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

### Title bar
```lua
local titleBar = OneWoW_GUI:CreateTitleBar(parent, "My Title", {
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
local btn = OneWoW_GUI:CreateButton(name, parent, "X", 20, 20)
```
Fixed-size button. Use only for icon buttons (e.g. "X" close). For text buttons, use FitText or FitFrame.

### Fit Text Button (auto-sizes to text)
```lua
local btn = OneWoW_GUI:CreateFitTextButton(parent, "Click Me", {
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
local buttons, finalY = OneWoW_GUI:CreateFitFrameButtons(parent, yOffset, {
    { text = "Option A", value = "a", isActive = true },
    { text = "Option B", value = "b" },
    { text = "Option C", value = "c" },
}, {
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
local onBtn, offBtn, refresh, statusPfx, statusVal = OneWoW_GUI:CreateOnOffToggleButtons(
    parent, yOffset, "On", "Off", width, height,
    isEnabled, currentValue, function(newValue)
        -- handle value change
    end
)
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
local newYOffset, refresh, refs = OneWoW_GUI:CreateToggleRow(parent, yOffset, {
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
Use `createContent` instead of `description` for custom widgets (e.g. mount picker):
```lua
local newYOffset, refresh, refs = OneWoW_GUI:CreateToggleRow(parent, yOffset, {
    label = "Ground Mount",
    createContent = function(container)
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetSize(220, 30)
        btn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        -- ... setup btn ...
        return btn, 30  -- widget, height
    end,
    value = true,
    isEnabled = true,
    onValueChange = function(newVal) ... end,
})
```

### Checkbox
```lua
local cb = OneWoW_GUI:CreateCheckbox(name, parent, "Label text")
```
Uses UICheckButtonTemplate. Access label via `cb.label`.

### Edit box
```lua
local box = OneWoW_GUI:CreateEditBox(name, parent, {
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

### Search box (deprecated - use CreateEditBox instead)
```lua
local searchBox = OneWoW_GUI:CreateSearchBox(parent, options)
```
Thin wrapper that calls `CreateEditBox(nil, parent, options)`. Kept for backward compatibility.
Use `CreateEditBox` directly with no `width` option for the same flexible-width behavior.

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
local header = OneWoW_GUI:CreateHeader(parent, "Section Title", yOffset)
```

### Divider (1px horizontal line)
```lua
local divider = OneWoW_GUI:CreateDivider(parent, yOffset)
```

### Section (header + divider combo)
```lua
local newYOffset = OneWoW_GUI:CreateSection(parent, "Section Title", yOffset)
-- Returns updated yOffset to continue laying out below
```

---

## Section Headers

### Themed section header bar
```lua
local section = OneWoW_GUI:CreateSectionHeader(parent, "Section Title", yOffset)
-- section.bottomY = yOffset below the header for continued layout
```
Creates a themed bar with background, border, and accent-colored title text.

---

## Scroll Frames

### Standalone scroll frame
```lua
local scrollFrame, content = OneWoW_GUI:CreateScrollFrame(name, parent)
local scrollFrame, content = OneWoW_GUI:CreateScrollFrame(name, parent, width, height)
```
Uses UIPanelScrollFrameTemplate (Lesson 3 compliant).
ScrollBar anchored to parent container.
- Without width/height: content width auto-syncs on resize.
- With width: content width set to (width - 32). Name param can be nil for anonymous frames.

### Style an existing scroll bar
```lua
OneWoW_GUI:StyleScrollBar(scrollFrame, {
    container = parentFrame,  -- optional, anchors scrollbar to this
    offset = -2,              -- optional, right offset
})
```

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

OneWoW_GUI:AttachFilterMenu(dropdown, text, {
    searchable = false,
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

OneWoW_GUI:AttachFilterMenu(dropdown, text, {
    searchable = true,  -- adds search box at top of menu
    buildItems = function()
        local items = {}
        table.insert(items, { value = nil, text = "All Zones" })
        for _, zone in ipairs(GetZoneList()) do
            table.insert(items, { value = zone, text = zone })
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
- Menu opens at FULLSCREEN_DIALOG strata
- buildItems() called fresh each click (supports dynamic lists)
- Scroll uses UIPanelScrollFrameTemplate (Lesson 3 compliant)

### Reset dropdown text externally
```lua
text:SetText("All Zones")
dropdown._activeValue = nil
```

---

## Utility

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


Adding to new addon - Same thing as OneWoW's TOC. add:                                        
 
  1. OneWoW_GUI_DB to the SavedVariables line                                   
  2. The 4 library files to the load order (after LibStub, before any UI code)
 
  So in DirectDeposit's TOC it would look like:                   

  ## SavedVariables: OneWoW_DirectDeposit_DB, OneWoW_GUI_DB

  Libs\LibStub\LibStub.lua
  Libs\OneWoW_GUI\Core.lua
  Libs\OneWoW_GUI\Constants.lua
  Libs\OneWoW_GUI\OneWoW_GUI.lua
  Libs\OneWoW_GUI\Settings.lua


```
