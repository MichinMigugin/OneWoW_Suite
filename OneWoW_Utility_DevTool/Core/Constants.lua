local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

Addon.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        SEARCH_HEIGHT = 32,
    }),
}
