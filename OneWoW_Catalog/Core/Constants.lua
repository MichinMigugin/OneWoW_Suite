-- OneWoW Addon File
-- OneWoW_Catalog/Core/Constants.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        WINDOW_WIDTH  = 1400,
        WINDOW_HEIGHT = 900,
        MIN_WIDTH         = 900,
        MIN_HEIGHT        = 600,
    }),
}
