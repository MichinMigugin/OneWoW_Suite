local ADDON_NAME, OneWoW = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        WINDOW_WIDTH = 860,
        WINDOW_HEIGHT = 720,
        MIN_WIDTH = 860,
        MIN_HEIGHT = 560,
    }),
}
