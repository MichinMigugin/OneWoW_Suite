local ADDON_NAME, OneWoW = ...

local lib = LibStub("OneWoW_GUI-1.0", true)

OneWoW.Constants = {
    VERSION = C_AddOns.GetAddOnMetadata("OneWoW", "Version") or "Unknown",
    ADDON_NAME = "OneWoW",

    GUI = {
        WINDOW_WIDTH = 860,
        WINDOW_HEIGHT = 720,
        MIN_WIDTH = 860,
        MIN_HEIGHT = 560,
        MAX_WIDTH = 2000,
        MAX_HEIGHT = 1200,
        PADDING = 12,
        BUTTON_HEIGHT = 28,
        SEARCH_HEIGHT = 32,
        ROW1_HEIGHT = 35,
        ROW2_HEIGHT = 30,
        LEFT_PANEL_WIDTH = 320,
        PANEL_GAP = 10,
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

function OneWoW.ApplyTheme()
    if not lib then lib = LibStub("OneWoW_GUI-1.0", true) end
    if lib then
        lib:ApplyTheme(OneWoW)
    end
end
