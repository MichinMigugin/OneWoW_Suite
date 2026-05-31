local addonName, ns = ...
if not ns.L_enUS then ns.L_enUS = {} end
local L = ns.L_enUS

L["MMBTNS_TITLE"]                       = "Minimap Button Collector"
L["MMBTNS_DESC"]                        = "Collects minimap addon buttons into a single themed container. Uses the OneWoW brand icon and supports grid layout, auto-close, and an enhanced OneWoW quick-launch row."

L["MMBTNS_TOOLTIP_LINE1"]               = "|cFFFFD100OneWoW|r Button Collector"
L["MMBTNS_TOOLTIP_BUTTONS"]             = "%d button(s) collected"
L["MMBTNS_TOOLTIP_HINT"]                = "Left-click to toggle"
L["MMBTNS_TOOLTIP_HINT_RIGHT"]          = "Right-click for menu"
L["MMBTNS_TOOLTIP_DRAG"]                = "Drag to move"

L["MMBTNS_CLOSE_MODE"]                  = "Close Behavior"
L["MMBTNS_STAY_OPEN"]                   = "Stay Open"
L["MMBTNS_AUTO_CLOSE"]                  = "Auto Close"
L["MMBTNS_AUTO_CLOSE_DELAY"]            = "Auto-Close Delay (seconds)"

L["MMBTNS_ENHANCED_MENU"]               = "Enhanced OneWoW Menu"
L["MMBTNS_ENHANCED_MENU_DESC"]          = "Adds a top row of quick-launch icons for loaded OneWoW addons."

L["MMBTNS_MAX_COLUMNS"]                 = "Max Columns"
L["MMBTNS_MAX_ROWS"]                    = "Max Rows"
L["MMBTNS_MAX_ROWS_DESC"]              = "0 = unlimited. Cannot be 1x1 if multiple buttons exist."
L["MMBTNS_BUTTON_SIZE"]                 = "Button Size"
L["MMBTNS_BUTTON_SCALE"]                = "Collected icon scale"
L["MMBTNS_BUTTON_SPACING"]             = "Button Spacing"

L["MMBTNS_LOCK_POSITION"]              = "Lock Position"
L["MMBTNS_GROW_DIRECTION"]             = "Grow Direction"
L["MMBTNS_GROW_DOWN"]                  = "Down"
L["MMBTNS_GROW_UP"]                    = "Up"
L["MMBTNS_GROW_LEFT"]                 = "Left"
L["MMBTNS_GROW_RIGHT"]                = "Right"

L["MMBTNS_HIDE_COLLECTED"]             = "Hide Collected from Minimap"
L["MMBTNS_HIDE_COLLECTED_DESC"]        = "Hides the original minimap buttons once collected into the container."
L["MMBTNS_SHOW_TOOLTIPS"]             = "Show Tooltips"
L["MMBTNS_SHOW_TOOLTIPS_DESC"]        = "Display original addon tooltips when hovering buttons in the container."

L["MMBTNS_ICONS_HEADER"]              = "Minimap Icons"
L["MMBTNS_ICONS_DESC"]                = "Every minimap icon detected is listed below. Pick where each one lives: Collector = inside the OneWoW panel, Map = back on the minimap, Hide = removed from sight entirely. The X removes a stale entry (only enabled once the owning addon is disabled). Your choice is remembered across reloads and addon enable/disable cycles."
L["MMBTNS_ICONS_EMPTY"]               = "No minimap icons detected yet. Open the collector once so it can scan, then reopen Settings."
L["MMBTNS_ICONS_MINI"]                = "Collector"
L["MMBTNS_ICONS_MAP"]                 = "Map"
L["MMBTNS_ICONS_HIDE"]                = "Hide"
L["MMBTNS_ICONS_MINI_STATE"]          = "Collector"
L["MMBTNS_ICONS_MAP_STATE"]           = "Map"
L["MMBTNS_ICONS_HIDE_STATE"]          = "Hide"
L["MMBTNS_ICONS_ENABLED"]             = "Enabled"
L["MMBTNS_ICONS_DISABLED"]            = "Disabled"
L["MMBTNS_ICONS_REMOVE_TT"]           = "Remove this entry from the list"
L["MMBTNS_ICONS_REMOVE_LOCKED_TT"]    = "This addon is currently loaded. Switch its icon to Hide if you don't want to see it; you can only remove the entry once the addon is disabled or uninstalled."

L["MMBTNS_SETTINGS_HEADER"]           = "Collector Settings"
L["MMBTNS_LAYOUT_HEADER"]             = "Layout"
L["MMBTNS_BEHAVIOR_HEADER"]           = "Behavior"

L["MMBTNS_SEARCH_PLACEHOLDER"]        = "Search..."

L["MMBTNS_CONTEXT_LOCK"]              = "Lock Position"
L["MMBTNS_CONTEXT_UNLOCK"]            = "Unlock Position"
L["MMBTNS_CONTEXT_SETTINGS"]          = "Open Settings"
L["MMBTNS_CONTEXT_REFRESH"]           = "Refresh Buttons"

L["MMBTNS_1X1_WARNING"]               = "Cannot set 1x1 layout with multiple buttons. Max rows reset to unlimited."

L["MMBTNS_DISABLE_RELOAD_TEXT"]       = "Turning off the Minimap Button Collector leaves LibDBIcon and other minimap hooks in a bad state until the UI reloads (icons may not drag on a square map, and re-enabling may not show the container).\n\nReload the interface now to restore normal minimap buttons?"
L["MMBTNS_DISABLE_RELOAD_BTN"]        = "Reload UI"
L["MMBTNS_DISABLE_RELOAD_CHAT"]       = "Reload later with |cFFFFD100/reload|r to fully restore minimap buttons."
