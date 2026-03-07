-- OneWoW_QoL Addon File
-- OneWoW_QoL/Core/Constants.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

ns.Constants = {
    VERSION = "R5.2602.2000",

    GUI = {
        MAIN_FRAME_WIDTH = 1400,
        MAIN_FRAME_HEIGHT = 900,
        MIN_WIDTH = 900,
        MIN_HEIGHT = 600,
        MAX_WIDTH = 2000,
        MAX_HEIGHT = 1200,

        LEFT_PANEL_WIDTH = 300,
        PANEL_GAP = 10,

        TAB_BUTTON_HEIGHT = 30,
        BUTTON_HEIGHT = 28,
    },
}

function ns.ApplyTheme()
    local themeKey
    local hub = _G.OneWoW
    if hub and hub.db and hub.db.global then
        themeKey = hub.db.global.theme or "green"
    else
        local addon = _G.OneWoW_QoL
        themeKey = (addon and addon.db and addon.db.global.theme) or "green"
    end
    OneWoW_GUI:ApplyTheme(themeKey)
end

function ns.GetVersionString()
    return ns.Constants.VERSION
end
