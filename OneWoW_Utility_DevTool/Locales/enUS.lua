local ADDON_NAME, Addon = ...

Addon.Locales = Addon.Locales or {}
Addon.Locales["enUS"] = {
    ["ADDON_TITLE"] = "DevTool",
    ["ADDON_SUBTITLE"] = "Frame Inspector & Development Utilities",
    ["LOADED"] = "Loaded v{version} - Use /devtools to open",

    -- Commands
    ["COMMAND_DEVTOOLS"] = "/devtools",
    ["COMMAND_DT"] = "/dt",

    -- Tab titles
    ["TAB_FRAME"] = "Frame",
    ["TAB_EVENTS"] = "Events",
    ["TAB_LUA"] = "Lua",
    ["TAB_TEXTURES"] = "Textures",
    ["TAB_COLORS"] = "Colors",
    ["COLOR_TOOLS_CLICK_TO_COPY"] = "Click to copy hex code",
    ["TAB_LAYOUT"] = "Layout",

    -- Frame Inspector
    ["BTN_PICK_FRAME"] = "Pick Frame",
    ["LABEL_SEARCH"] = "Search",
    ["BTN_SEARCH"] = "Search",
    ["LABEL_FRAME_HIERARCHY"] = "Frame Hierarchy",
    ["LABEL_FRAME_NAME"] = "Frame name...",
    ["BTN_COPY_HIERARCHY"] = "Copy All",
    ["LABEL_FRAME_DETAILS"] = "Frame Details",
    ["BTN_COPY_DETAILS"] = "Copy All",
    ["LABEL_NO_FRAME"] = "No frame selected",
    ["LABEL_ANONYMOUS"] = "Anonymous",
    ["LABEL_UNKNOWN"] = "Unknown",
    ["LABEL_NAME"] = "NAME:",
    ["LABEL_TYPE"] = "TYPE:",
    ["LABEL_SHOWN"] = "SHOWN:",
    ["LABEL_MOUSE"] = "MOUSE:",
    ["LABEL_SIZE"] = "SIZE:",
    ["LABEL_STRATA"] = "STRATA:",
    ["LABEL_LEVEL"] = "LEVEL:",
    ["LABEL_ANCHORS"] = "ANCHORS:",
    ["LABEL_YES"] = "Yes",
    ["LABEL_NO"] = "No",
    ["LABEL_CHILDREN"] = "CHILDREN:",

    -- Event Monitor
    ["BTN_START"] = "Start",
    ["BTN_STOP"] = "Stop",
    ["BTN_PAUSE"] = "Pause",
    ["BTN_UNPAUSE"] = "Unpause",
    ["BTN_CLEAR"] = "Clear",
    ["BTN_SELECT_EVENTS"] = "Select Events",
    ["LABEL_FILTER"] = "Filter:",
    ["MSG_CLICK_START"] = "Click 'Start' to begin monitoring (auto-selects common events)\nOr click 'Select Events' to customize",
    ["MSG_GRID_ENABLED"] = "Grid enabled",
    ["MSG_GRID_DISABLED"] = "Grid disabled",
    ["MSG_CENTER_LINES_ENABLED"] = "Center lines enabled",
    ["MSG_CENTER_LINES_DISABLED"] = "Center lines disabled",
    ["MSG_COPIED"] = "Copied to clipboard: {text}",

    -- Lua Console / Error Logger
    ["LABEL_ERRORS"] = "Errors:",
    ["BTN_COPY_ERROR"] = "Copy Error",
    ["LABEL_NO_ERROR"] = "No error selected",
    ["ERR_SESSION_CURRENT"] = "Current",
    ["ERR_SESSION_CURRENT_FULL"] = "Current Session",
    ["ERR_SESSION_PREFIX"] = "Session",
    ["ERR_DETAIL_TIME"] = "TIME:",
    ["ERR_DETAIL_SESSION"] = "SESSION:",
    ["ERR_DETAIL_COUNT"] = "COUNT:",
    ["ERR_DETAIL_MESSAGE"] = "MESSAGE:",
    ["ERR_DETAIL_STACK"] = "STACK TRACE:",
    ["ERR_DETAIL_LOCALS"] = "LOCALS:",
    ["ERR_MSG_NONE_SELECTED"] = "No error selected",
    ["ERR_MSG_CLEARED"] = "Error log cleared",
    ["ERR_PLAY_ALERT"] = "Play Alert",

    -- Texture Browser
    ["BTN_FAVORITES"] = "Favorites",
    ["BTN_BOOKMARK"] = "Bookmark",
    ["BTN_ZOOM_IN"] = "+",
    ["BTN_ZOOM_OUT"] = "-",
    ["BTN_RESET_ZOOM"] = "Reset",
    ["BTN_COPY_NAME"] = "Copy Name",
    ["LABEL_ATLAS_LIST"] = "Atlas List",
    ["LABEL_CUSTOM_ATLAS"] = "Custom Atlas",
    ["MSG_SELECT_ATLAS"] = "Select an atlas first",
    ["MSG_NO_BOOKMARKS"] = "No bookmarks yet",
    ["MSG_REMOVED_BOOKMARK"] = "Removed: {name}",
    ["MSG_BOOKMARKED"] = "Bookmarked: {name}",
    ["LABEL_WIDTH"] = "Width:",
    ["LABEL_HEIGHT"] = "Height:",
    ["LABEL_FILE"] = "File:",
    ["LABEL_TEX_COORDS"] = "Texture Coordinates:",
    ["LABEL_LEFT"] = "Left:",
    ["LABEL_RIGHT"] = "Right:",
    ["LABEL_TOP"] = "Top:",
    ["LABEL_BOTTOM"] = "Bottom:",
    ["LABEL_TILES"] = "Tiles:",
    ["LABEL_BOOKMARKED"] = "[Bookmarked]",

    -- Event Selector Dialog
    ["DIALOG_TITLE_SELECT_EVENTS"] = "Event Monitor - Select Events",
    ["BTN_COMMON_EVENTS"] = "Common Events",
    ["BTN_SELECT_ALL"] = "Select All",
    ["BTN_CLEAR_ALL"] = "Clear All",
    ["LABEL_ENTER_EVENT"] = "Enter event name:",
    ["BTN_ADD_EVENT"] = "Add",
    ["LABEL_EVENT_LIST"] = "Event List",
    ["BTN_CLOSE"] = "Close",
    ["HELP_TEXT_EVENTS"] = "Enter any WoW event name to monitor.\n\nCommon events:\nPLAYER_ENTERING_WORLD\nZONE_CHANGED\nPLAYER_REGEN_DISABLED\nPLAYER_REGEN_ENABLED\nBAG_UPDATE\nUNIT_HEALTH\nCHAT_MSG_SAY\nADDON_LOADED\n\nYou can find more events on:\nwarcraft.wiki.gg",

    -- Layout Tools
    ["LABEL_GRID_OVERLAY"] = "Grid Overlay",
    ["BTN_TOGGLE_GRID"] = "Toggle Grid",
    ["LABEL_GRID_SIZE"] = "Grid Size:",
    ["LABEL_OPACITY"] = "Opacity:",
    ["BTN_TOGGLE_CENTER"] = "Toggle Center Lines",

    -- Messages
    ["MSG_ADDED_COMMON_EVENTS"] = "Added common events ({count} total)",
    ["MSG_SELECTED_ALL_EVENTS"] = "Selected all events ({count} total)",
    ["MSG_CLEARED_ALL_EVENTS"] = "Cleared all events",
    ["MSG_ADDED_EVENT"] = "Added event: {event}",
    ["LABEL_SELECTED"] = "Selected:",

    -- Search Results
    ["DIALOG_TITLE_SEARCH_RESULTS"] = "Search Results",

    -- Settings
    ["SETTINGS_LANGUAGE_SELECTION"] = "Language",
    ["SETTINGS_LANGUAGE_DESC"] = "Choose your preferred language. Changes apply instantly.",
    ["SETTINGS_THEME_SELECTION"] = "Theme Selection",
    ["SETTINGS_THEME_DESC"] = "Choose a color theme. Changes apply instantly.",
    ["LANG_ENGLISH"] = "English",
    ["LANG_KOREAN"] = "한국어",
    ["LANG_SPANISH"] = "Español",
    ["LANG_FRENCH"] = "Français",
    ["LANG_RUSSIAN"] = "Русский",
    ["LANG_GERMAN"] = "Deutsch",

    -- Monitor
    ["TAB_MONITOR"] = "Monitor",
    ["MON_BTN_PLAY"] = "Play",
    ["MON_BTN_PAUSE"] = "Pause",
    ["MON_BTN_UPDATE"] = "Update",
    ["MON_BTN_RESET"] = "Reset",
    ["MON_LABEL_CPU_PROFILING"] = "CPU Profiling",
    ["MON_LABEL_SHOW_ON_LOAD"] = "Show on Load",
    ["MON_LABEL_FILTER"] = "Filter:",
    ["MON_HEADER_NAME"] = "Addon",
    ["MON_HEADER_MEMORY"] = "Memory (k)",
    ["MON_HEADER_MEM_PCT"] = "Mem %",
    ["MON_HEADER_CPU"] = "CPU (ms/s)",
    ["MON_HEADER_CPU_PCT"] = "CPU %",
    ["MON_TOTALS_ADDONS"] = "Addons:",
    ["MON_TOTALS_MEMORY"] = "Memory:",
    ["MON_TOTALS_CPU"] = "CPU:",
    ["MON_CPU_RELOAD_CONFIRM"] = "Changing CPU profiling requires a UI reload. Reload now?",
    ["MON_MSG_RESET"] = "Memory collected and CPU usage reset",
    ["MON_MSG_CPU_ENABLED"] = "CPU profiling enabled - reloading UI",
    ["MON_MSG_CPU_DISABLED"] = "CPU profiling disabled - reloading UI",
    ["MON_MSG_NO_DATA"] = "Click 'Update' or 'Play' to begin monitoring",
    ["MON_PIN_MONITOR"] = "Monitor This Addon",
    ["MON_PIN_REOPEN"] = "Reopen on /reload",

    -- Minimap
    ["MINIMAP_TOOLTIP_HINT"] = "Left-Click to toggle DevTool",
    ["MINIMAP_SECTION"] = "Minimap Button",
    ["MINIMAP_SECTION_DESC"] = "Show or hide the minimap button.",
    ["MINIMAP_SHOW_BTN"] = "Show Minimap Button",
    ["MINIMAP_ICON_SECTION"] = "Icon Theme",
    ["MINIMAP_ICON_DESC"] = "Choose your faction icon for the minimap button and title bar.",
    ["MINIMAP_ICON_CURRENT"] = "Current Icon",
    ["MINIMAP_ICON_HORDE"] = "Horde",
    ["MINIMAP_ICON_ALLIANCE"] = "Alliance",
    ["MINIMAP_ICON_NEUTRAL"] = "Neutral",
}

Addon.L = {}
for k, v in pairs(Addon.Locales["enUS"]) do
    Addon.L[k] = v
end
