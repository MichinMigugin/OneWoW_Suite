local addonName, ns = ...
if not ns.L_enUS then ns.L_enUS = {} end
local L = ns.L_enUS

L["MMSKIN_TITLE"]                   = "Map (Mini) Tools"
L["MMSKIN_DESC"]                    = "Customize your minimap cluster: shape, border, zone text, clock, click actions, zoom controls, element visibility, and more. Theme-aware and fully configurable."

L["MMSKIN_GROUP_SHAPE"]             = "Shape & Appearance"
L["MMSKIN_GROUP_INFO"]              = "Information Overlays"
L["MMSKIN_GROUP_ZOOM"]              = "Zoom & Scroll"
L["MMSKIN_GROUP_CLICKS"]            = "Click Actions"
L["MMSKIN_GROUP_ELEMENTS"]          = "Element Visibility"
L["MMSKIN_GROUP_EXTRAS"]            = "Extras"
L["MMSKIN_GROUP_COMPAT"]            = "Compatibility"

L["MMSKIN_SQUARE"]                  = "Square Minimap"
L["MMSKIN_SQUARE_DESC"]             = "Change the minimap shape from round to square. Disabling requires a UI reload."
L["MMSKIN_BORDER"]                  = "Show Border"
L["MMSKIN_BORDER_DESC"]             = "Display a colored border around the minimap."
L["MMSKIN_CLASS_BORDER"]            = "Class Color Border"
L["MMSKIN_CLASS_BORDER_DESC"]       = "Use your class color for the minimap border instead of the theme color."
L["MMSKIN_UNLOCK"]                  = "Unlock Minimap"
L["MMSKIN_UNLOCK_DESC"]             = "Detach the minimap from its default position and make it freely draggable."
L["MMSKIN_LOCK_POS"]                = "Lock Position"
L["MMSKIN_LOCK_POS_DESC"]           = "Prevent the minimap from being dragged while keeping it at its current position."

L["MMSKIN_ZONE_TEXT"]               = "Zone Text"
L["MMSKIN_ZONE_TEXT_DESC"]          = "Show the current zone name above the minimap with PvP-type coloring."
L["MMSKIN_CLOCK"]                   = "Clock"
L["MMSKIN_CLOCK_DESC"]              = "Show a clock below the minimap. Tooltip shows realm/local time and daily/weekly reset timers."

L["MMSKIN_ZONE_CLOCK_INSIDE"]       = "Zone & clock inside minimap"
L["MMSKIN_ZONE_CLOCK_INSIDE_DESC"]  = "Anchor the zone name and clock on the inside edges of the minimap instead of above and below it."

L["MMSKIN_ZONE_CLOCK_DRAG"]         = "Drag zone & clock (hold Shift)"
L["MMSKIN_ZONE_CLOCK_DRAG_DESC"]    = "You must hold Shift while dragging the zone name or clock to move them on screen. Positions are saved. Release Shift for normal clicks (clock still opens the time manager)."

L["MMSKIN_WHEEL_ZOOM"]              = "Mouse Wheel Zoom"
L["MMSKIN_WHEEL_ZOOM_DESC"]         = "Zoom the minimap in and out using the mouse wheel."
L["MMSKIN_AUTO_ZOOM"]               = "Auto Zoom Out"
L["MMSKIN_AUTO_ZOOM_DESC"]          = "Automatically zoom the minimap back out after zooming in."

L["MMSKIN_CLICK_ACTIONS"]           = "Click Actions"
L["MMSKIN_CLICK_ACTIONS_DESC"]      = "Enable right-click, middle-click, and extra mouse button actions on the minimap."

L["MMSKIN_MAIL"]                    = "Mail Indicator"
L["MMSKIN_MAIL_DESC"]               = "Show the mail indicator on the minimap."
L["MMSKIN_CRAFTING"]                = "Crafting Orders"
L["MMSKIN_CRAFTING_DESC"]           = "Show the crafting order indicator on the minimap."
L["MMSKIN_DIFFICULTY"]              = "Difficulty Icon"
L["MMSKIN_DIFFICULTY_DESC"]         = "Show the instance difficulty icon on the minimap."

L["MMSKIN_TRACKING"]               = "Tracking Filter"
L["MMSKIN_TRACKING_DESC"]           = "Show the minimap tracking filter (resource / herb / ore / etc. dropdown). Turning it off removes the small ring/control next to the minimap."
L["MMSKIN_MISSIONS"]                = "Missions Button"
L["MMSKIN_MISSIONS_DESC"]           = "Show the expansion landing page / missions button."

L["MMSKIN_PLUMBER_HIDE_BLIZZARD"]     = "Hide duplicate Blizzard expansion button with Plumber"
L["MMSKIN_PLUMBER_HIDE_BLIZZARD_DESC"] = "When Plumber is loaded, keep Blizzard's expansion minimap button hidden so only Plumber's Expansion Summary control shows. Turn off to show both (not recommended)."
L["MMSKIN_PLUMBER_STATUS_ON"]        = "Plumber is loaded — this option applies."
L["MMSKIN_PLUMBER_STATUS_OFF"]       = "Plumber is not loaded — enable this before logging in, or reload after installing Plumber."

L["MMSKIN_HIDE_ADDONS"]             = "Hide Addon Icons"
L["MMSKIN_HIDE_ADDONS_DESC"]        = "Hide addon minimap buttons until you hover over the minimap area."
L["MMSKIN_COMBAT_FADE"]             = "Combat Fade"
L["MMSKIN_COMBAT_FADE_DESC"]        = "Reduce minimap opacity during combat."
L["MMSKIN_PET_HIDE"]                = "Pet Battle Hide"
L["MMSKIN_PET_HIDE_DESC"]           = "Hide the minimap during pet battles."

L["MMSKIN_SCALE_LABEL"]             = "Minimap Cluster Scale"
L["MMSKIN_SECTION_BORDER"]          = "Border Settings"
L["MMSKIN_BORDER_SIZE"]             = "Border Size"
L["MMSKIN_BORDER_RED"]              = "Red"
L["MMSKIN_BORDER_GREEN"]            = "Green"
L["MMSKIN_BORDER_BLUE"]             = "Blue"
L["MMSKIN_USE_THEME_COLOR"]         = "Use Theme Color"

L["MMSKIN_AUTO_ZOOM_DELAY"]         = "Auto Zoom Delay"
L["MMSKIN_SHOW_ZOOM_BTNS"]          = "Show Zoom Buttons"

L["MMSKIN_HIDE_WM_BTN"]             = "Hide world map button"
L["MMSKIN_HIDE_WM_BTN_DESC"]        = "Hide the small world map toggle on the minimap (you can still open the map with its keybind)."

L["MMSKIN_SECTION_COMBAT"]          = "Combat Fade Settings"
L["MMSKIN_COMBAT_ALPHA"]            = "Combat Opacity"

L["MMSKIN_SECTION_CLICKS"]          = "Click Binding Settings"
L["MMSKIN_CLICK_RIGHT"]             = "Right Click"
L["MMSKIN_CLICK_MIDDLE"]            = "Middle Click"
L["MMSKIN_CLICK_BTN4"]              = "Button 4"
L["MMSKIN_CLICK_BTN5"]              = "Button 5"
L["MMSKIN_ACTION_NONE"]             = "None"
L["MMSKIN_ACTION_CALENDAR"]         = "Calendar"
L["MMSKIN_ACTION_TRACKING"]         = "Tracking"
L["MMSKIN_ACTION_MISSIONS"]         = "Missions"
L["MMSKIN_ACTION_MAP"]              = "Map"

L["MMSKIN_SHOW_COMPARTMENT"]        = "Addon Compartment"

L["MMSKIN_CLOCK_TT_TOGGLE"]         = "Click to toggle the Time Manager"

L["MMSKIN_UNCLAMP"]                 = "Unclamp from Screen"

L["MMSKIN_ZONE_FONT_LABEL"]         = "Font"
L["MMSKIN_ZONE_FONT_SIZE"]          = "Font Size"
L["MMSKIN_CLOCK_FONT_LABEL"]        = "Font"
L["MMSKIN_CLOCK_FONT_SIZE"]         = "Font Size"
L["MMSKIN_FONT_GLOBAL"]             = "Global Font"
L["MMSKIN_FONT_WOW_DEFAULT"]        = "WoW default (small)"

L["MMSKIN_SECTION_OPACITY"]         = "Scale & Opacity"
L["MMSKIN_OPACITY"]                 = "Minimap Opacity"

L["MMSKIN_SECTION_DEBUG"]           = "Developer Tools"
L["MMSKIN_DEBUG_SHOW"]              = "Show Debug Icons"
L["MMSKIN_DEBUG_HIDE"]              = "Hide Debug Icons"
L["MMSKIN_DEBUG_DESC"]              = "Force all tracked icons visible with colored labels. Drag any label to place that icon on the minimap; positions are saved. Hide debug to return icons to the cluster (unless the minimap is detached). Useful when icons aren't actively triggering (e.g. no mail in your mailbox)."
L["MMSKIN_DEBUG_TT_DRAG_HINT"]      = "Left-click and drag to move this icon on the minimap."
L["MMSKIN_DEBUG_TT_POS_FMT"]        = "Saved offset: %.0f, %.0f"

L["MMSKIN_RELOAD_PROMPT"]           = "Changing minimap shape requires a UI reload.\nReload now?"
