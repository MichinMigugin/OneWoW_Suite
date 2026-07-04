-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/preybar/module.lua
local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "preybar",
    title       = "PREYBAR_TITLE",
    category    = "INTERFACE",
    description = "PREYBAR_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "show_boss",       label = "PREYBAR_TOGGLE_BOSS",          description = "PREYBAR_TOGGLE_BOSS_DESC",          default = true  },
        { id = "show_difficulty", label = "PREYBAR_TOGGLE_DIFFICULTY",    description = "PREYBAR_TOGGLE_DIFFICULTY_DESC",    default = true  },
        { id = "show_affixes",    label = "PREYBAR_TOGGLE_AFFIXES",       description = "PREYBAR_TOGGLE_AFFIXES_DESC",       default = true  },
        { id = "hide_blizzard",   label = "PREYBAR_TOGGLE_HIDE_BLIZZARD", description = "PREYBAR_TOGGLE_HIDE_BLIZZARD_DESC", default = true  },
        { id = "click_waypoint",  label = "PREYBAR_TOGGLE_CLICK_WAYPOINT", description = "PREYBAR_TOGGLE_CLICK_WAYPOINT_DESC", default = true  },
        { id = "lock",            label = "PREYBAR_TOGGLE_LOCK",          description = "PREYBAR_TOGGLE_LOCK_DESC",          default = false },
    },
    preview        = false,
    defaultEnabled = true,
    _frame         = nil,
    _eventFrame    = nil,
    _widgetID      = nil,
    _refreshTimer  = nil,
    _pollTicker    = nil,
    _previewActive = false,
    _previewMarker = nil,
    _previewTicker = nil,
    _isAmbushed    = false,
    _ambushToken   = 0,
    _pewDelayTimer = nil,
    _dragActive    = false,
})
