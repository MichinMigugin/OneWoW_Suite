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

L["MMBTNS_WHITELIST_HEADER"]           = "Whitelist"
L["MMBTNS_WHITELIST_DESC"]            = "Add frame names of minimap buttons that aren't auto-detected."
L["MMBTNS_WHITELIST_ADD"]             = "Add"
L["MMBTNS_WHITELIST_PLACEHOLDER"]     = "Frame name..."
L["MMBTNS_WHITELIST_REMOVE"]          = "Remove"

L["MMBTNS_BLACKLIST_HEADER"]           = "Blacklist"
L["MMBTNS_BLACKLIST_DESC"]            = "Frame names to never collect."
L["MMBTNS_BLACKLIST_ADD"]             = "Add"
L["MMBTNS_BLACKLIST_PLACEHOLDER"]     = "Frame name..."
L["MMBTNS_BLACKLIST_REMOVE"]          = "Remove"
L["MMBTNS_BLACKLIST_CLEAR"]           = "Clear Blacklist"

L["MMBTNS_SETTINGS_HEADER"]           = "Collector Settings"
L["MMBTNS_LAYOUT_HEADER"]             = "Layout"
L["MMBTNS_BEHAVIOR_HEADER"]           = "Behavior"
L["MMBTNS_LISTS_HEADER"]              = "Whitelist / Blacklist"

L["MMBTNS_SEARCH_PLACEHOLDER"]        = "Search..."

L["MMBTNS_CONTEXT_LOCK"]              = "Lock Position"
L["MMBTNS_CONTEXT_UNLOCK"]            = "Unlock Position"
L["MMBTNS_CONTEXT_SETTINGS"]          = "Open Settings"
L["MMBTNS_CONTEXT_REFRESH"]           = "Refresh Buttons"

L["MMBTNS_1X1_WARNING"]               = "Cannot set 1x1 layout with multiple buttons. Max rows reset to unlimited."
