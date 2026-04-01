local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_Bags.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        WINDOW_WIDTH = 620,
        WINDOW_HEIGHT = 520,
        SEARCH_HEIGHT = 28,
        ITEM_BUTTON_SIZE = 37,
        ITEM_BUTTON_SPACING = 3,
        INFOBAR_HEIGHT = 56,
        BAGSBAR_HEIGHT = 58,
        TITLEBAR_HEIGHT = 20,
    }),

    ICON_SIZES = {
        [1] = 28,
        [2] = 32,
        [3] = 37,
        [4] = 42,
    },
}
