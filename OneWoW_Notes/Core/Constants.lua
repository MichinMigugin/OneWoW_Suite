-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/Constants.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local lib = LibStub("OneWoW_GUI-1.0", true)

ns.Constants = {
    VERSION = "R6.2602.2000",

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

local function T(key)
    if lib then return lib:GetThemeColor(key) end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if lib then return lib:GetSpacing(key) end
    return 8
end

ns.T = T
ns.S = S

function ns.ApplyTheme()
    if not lib then lib = LibStub("OneWoW_GUI-1.0", true) end
    if lib then
        lib:ApplyTheme()
    end
end

function ns.GetVersionString()
    return ns.Constants.VERSION
end
