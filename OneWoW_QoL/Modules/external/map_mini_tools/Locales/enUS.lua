local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["MMSKIN_TITLE"] = "Map (Mini) Tools",
    ["MMSKIN_DESC"] = "Customize your minimap cluster: shape, border, zone text, clock, click actions, zoom controls, element visibility, and more. Theme-aware and fully configurable.",

    ["MMSKIN_GROUP_SHAPE"] = "Shape & Appearance",
    ["MMSKIN_GROUP_INFO"] = "Information Overlays",
    ["MMSKIN_GROUP_ZOOM"] = "Zoom & Scroll",
    ["MMSKIN_GROUP_CLICKS"] = "Click Actions",
    ["MMSKIN_GROUP_ELEMENTS"] = "Element Visibility",
    ["MMSKIN_GROUP_EXTRAS"] = "Extras",
    ["MMSKIN_GROUP_COMPAT"] = "Compatibility",

    ["MMSKIN_SQUARE"] = "Square Minimap",
    ["MMSKIN_SQUARE_DESC"] = "Change the minimap shape from round to square. Disabling requires a UI reload.",
    ["MMSKIN_BORDER"] = "Show Border",
    ["MMSKIN_BORDER_DESC"] = "Display a colored border around the minimap.",
    ["MMSKIN_CLASS_BORDER"] = "Class Color Border",
    ["MMSKIN_CLASS_BORDER_DESC"] = "Use your class color for the minimap border instead of the theme color.",
    ["MMSKIN_UNLOCK"] = "Unlock Minimap",
    ["MMSKIN_UNLOCK_DESC"] = "Detach the minimap from its default position and make it freely draggable.",
    ["MMSKIN_LOCK_POS"] = "Lock Position",
    ["MMSKIN_LOCK_POS_DESC"] = "Prevent the minimap from being dragged while keeping it at its current position.",

    ["MMSKIN_ZONE_TEXT"] = "Zone Text",
    ["MMSKIN_ZONE_TEXT_DESC"] = "Show the current zone name above the minimap with PvP-type coloring.",
    ["MMSKIN_CLOCK"] = "Clock",
    ["MMSKIN_CLOCK_DESC"] = "Show a clock below the minimap. Tooltip shows realm/local time and daily/weekly reset timers.",
    ["MMSKIN_CLASS_CLOCK_COLOR"] = "Class Color Clock",
    ["MMSKIN_CLASS_CLOCK_COLOR_DESC"] = "Use your class color for the clock text instead of the theme color.",
    ["MMSKIN_ZONE_ALIGN_LABEL"] = "Zone Name Alignment",
    ["MMSKIN_CLOCK_ALIGN_LABEL"] = "Clock Alignment",
    ["MMSKIN_ALIGN_LEFT"] = "Left",
    ["MMSKIN_ALIGN_CENTER"] = "Center",
    ["MMSKIN_ALIGN_RIGHT"] = "Right",

    ["MMSKIN_ZONE_CLOCK_INSIDE"] = "Zone & clock inside minimap",
    ["MMSKIN_ZONE_CLOCK_INSIDE_DESC"] = "Anchor the zone name and clock on the inside edges of the minimap instead of above and below it.",

    ["MMSKIN_ZONE_CLOCK_DRAG"] = "Drag zone & clock (hold Shift)",
    ["MMSKIN_ZONE_CLOCK_DRAG_DESC"] = "You must hold Shift while dragging the zone name or clock to move them on screen. Positions are saved. Release Shift for normal clicks (clock still opens the time manager).",

    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM"] = "Anchor zone & clock to minimap",
    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM_DESC"] = "While dragging is enabled, anchor the zone name and clock to the minimap so they ride along when the minimap is moved. If you stack them on top of each other, they move as one.",

    ["MMSKIN_WHEEL_ZOOM"] = "Mouse Wheel Zoom",
    ["MMSKIN_WHEEL_ZOOM_DESC"] = "Zoom the minimap in and out using the mouse wheel.",
    ["MMSKIN_AUTO_ZOOM"] = "Auto Zoom Out",
    ["MMSKIN_AUTO_ZOOM_DESC"] = "Automatically zoom the minimap back out after zooming in.",

    ["MMSKIN_CLICK_ACTIONS"] = "Click Actions",
    ["MMSKIN_CLICK_ACTIONS_DESC"] = "Enable right-click, middle-click, and extra mouse button actions on the minimap.",

    ["MMSKIN_MAIL"] = "Mail Indicator",
    ["MMSKIN_MAIL_DESC"] = "Show the mail indicator on the minimap.",
    ["MMSKIN_CRAFTING"] = "Crafting Orders",
    ["MMSKIN_CRAFTING_DESC"] = "Show the crafting order indicator on the minimap.",
    ["MMSKIN_DIFFICULTY"] = "Difficulty Icon",
    ["MMSKIN_DIFFICULTY_DESC"] = "Show the instance difficulty icon on the minimap.",

    ["MMSKIN_TRACKING"] = "Tracking Filter",
    ["MMSKIN_TRACKING_DESC"] = "Show the minimap tracking filter (resource / herb / ore / etc. dropdown). Turning it off removes the small ring/control next to the minimap.",
    ["MMSKIN_MISSIONS"] = "Missions Button",
    ["MMSKIN_MISSIONS_DESC"] = "Show the expansion landing page / missions button.",
    ["MMSKIN_GAMETIME"] = "Calendar Icon",
    ["MMSKIN_GAMETIME_DESC"] = "Show the calendar (GameTime) button on the minimap.",

    ["MMSKIN_PLUMBER_HIDE_BLIZZARD"] = "Hide duplicate Blizzard expansion button with Plumber",
    ["MMSKIN_PLUMBER_HIDE_BLIZZARD_DESC"] = "When Plumber is loaded, keep Blizzard's expansion minimap button hidden so only Plumber's Expansion Summary control shows. Turn off to show both (not recommended).",
    ["MMSKIN_PLUMBER_STATUS_ON"] = "Plumber is loaded — this option applies.",
    ["MMSKIN_PLUMBER_STATUS_OFF"] = "Plumber is not loaded — enable this before logging in, or reload after installing Plumber.",

    ["MMSKIN_HIDE_ADDONS"] = "Hide Addon Icons",
    ["MMSKIN_HIDE_ADDONS_DESC"] = "Hide addon minimap buttons until you hover over the minimap area.",
    ["MMSKIN_COMBAT_FADE"] = "Combat Fade",
    ["MMSKIN_COMBAT_FADE_DESC"] = "Reduce minimap opacity during combat.",
    ["MMSKIN_PET_HIDE"] = "Pet Battle Hide",
    ["MMSKIN_PET_HIDE_DESC"] = "Hide the minimap during pet battles.",

    ["MMSKIN_SCALE_LABEL"] = "Minimap Cluster Scale",
    ["MMSKIN_SECTION_BORDER"] = "Border Settings",
    ["MMSKIN_BORDER_SIZE"] = "Border Size",
    ["MMSKIN_BORDER_RED"] = "Red",
    ["MMSKIN_BORDER_GREEN"] = "Green",
    ["MMSKIN_BORDER_BLUE"] = "Blue",
    ["MMSKIN_USE_THEME_COLOR"] = "Use Theme Color",

    ["MMSKIN_ZONE_BG"] = "Zone Background",
    ["MMSKIN_CLOCK_BG"] = "Clock Background",

    ["MMSKIN_AUTO_ZOOM_DELAY"] = "Auto Zoom Delay",
    ["MMSKIN_SHOW_ZOOM_BTNS"] = "Show Zoom Buttons",

    ["MMSKIN_HIDE_WM_BTN"] = "Hide world map button",
    ["MMSKIN_HIDE_WM_BTN_DESC"] = "Hide the small world map toggle on the minimap (you can still open the map with its keybind).",

    ["MMSKIN_SECTION_COMBAT"] = "Combat Fade Settings",
    ["MMSKIN_COMBAT_ALPHA"] = "Combat Opacity",

    ["MMSKIN_SECTION_CLICKS"] = "Click Binding Settings",
    ["MMSKIN_CLICK_RIGHT"] = "Right Click",
    ["MMSKIN_CLICK_MIDDLE"] = "Middle Click",
    ["MMSKIN_CLICK_BTN4"] = "Button 4",
    ["MMSKIN_CLICK_BTN5"] = "Button 5",
    ["MMSKIN_ACTION_NONE"] = "None",
    ["MMSKIN_ACTION_CALENDAR"] = "Calendar",
    ["MMSKIN_ACTION_TRACKING"] = "Tracking",
    ["MMSKIN_ACTION_MISSIONS"] = "Missions",
    ["MMSKIN_ACTION_MAP"] = "Map",
    ["MMSKIN_WORLD_MAP_BUTTON"] = "World Map",

    ["MMSKIN_SHOW_COMPARTMENT"] = "Addon Compartment",

    ["MMSKIN_CLOCK_TT_TOGGLE"] = "Click to toggle the Time Manager",

    ["MMSKIN_UNCLAMP"] = "Unclamp from Screen",

    ["MMSKIN_ZONE_FONT_LABEL"] = "Font",
    ["MMSKIN_CLOCK_FONT_LABEL"] = "Font",
    ["MMSKIN_FONT_GLOBAL"] = "Global Font",
    ["MMSKIN_FONT_WOW_DEFAULT"] = "WoW default (small)",

    ["MMSKIN_SECTION_OPACITY"] = "Scale & Opacity",
    ["MMSKIN_OPACITY"] = "Minimap Opacity",

    ["MMSKIN_SECTION_DEBUG"] = "Developer Tools",
    ["MMSKIN_DEBUG_SHOW"] = "Show Debug Icons",
    ["MMSKIN_DEBUG_HIDE"] = "Hide Debug Icons",
    ["MMSKIN_DEBUG_DESC"] = "Force all tracked icons visible with colored labels. Drag any label to place that icon on the minimap; positions are saved. Hide debug to return icons to the cluster (unless the minimap is detached). Useful when icons aren't actively triggering (e.g. no mail in your mailbox).",
    ["MMSKIN_DEBUG_TT_DRAG_HINT"] = "Left-click and drag to move this icon on the minimap.",
    ["MMSKIN_DEBUG_TT_POS_FMT"] = "Saved offset: %.0f, %.0f",

    ["MMSKIN_RELOAD_PROMPT"] = "Changing minimap shape requires a UI reload.\nReload now?",
})
