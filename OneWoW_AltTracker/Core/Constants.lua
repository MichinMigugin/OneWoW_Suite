local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        MAIN_FRAME_WIDTH = 1400,
        MAIN_FRAME_HEIGHT = 900,
        MIN_WIDTH = 1000,
        LEFT_PANEL_WIDTH = 350,
        SUBTAB_BUTTON_HEIGHT = 28,
        CONTROL_PANEL_HEIGHT = 75,
        SEARCH_HEIGHT = 32,
    }),
}
