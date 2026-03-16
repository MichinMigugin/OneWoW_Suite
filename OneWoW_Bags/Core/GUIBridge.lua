local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0")
OneWoW_Bags.GUILib = OneWoW_GUI

OneWoW_Bags.Constants = {
    VERSION = "R7.2603.0100",
    ADDON_NAME = "OneWoW_Bags",

    GUI = {
        WINDOW_WIDTH = 620,
        WINDOW_HEIGHT = 520,
        PADDING = 12,
        BUTTON_HEIGHT = 28,
        SEARCH_HEIGHT = 28,
        ITEM_BUTTON_SIZE = 37,
        ITEM_BUTTON_SPACING = 3,
        INFOBAR_HEIGHT = 30,
        BAGSBAR_HEIGHT = 36,
        TITLEBAR_HEIGHT = 20,
    },

    ICON_SIZES = {
        [1] = 28,
        [2] = 32,
        [3] = 37,
        [4] = 42,
    },
}

local Constants = OneWoW_Bags.Constants

Constants.SPACING = OneWoW_GUI.Constants.SPACING

setmetatable(Constants, {
    __index = function(self, key)
        if key == "THEME" then
            return setmetatable({}, {
                __index = function(_, colorKey)
                    local r, g, b, a = OneWoW_GUI:GetThemeColor(colorKey)
                    return { r, g, b, a }
                end
            })
        elseif key == "THEMES" then
            return OneWoW_GUI.Constants.THEMES
        elseif key == "THEMES_ORDER" then
            return OneWoW_GUI.Constants.THEMES_ORDER
        end
    end
})

OneWoW_Bags.THEME = Constants.THEME
OneWoW_Bags.SPACING = Constants.SPACING
