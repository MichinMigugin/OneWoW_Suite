-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/Constants.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        MAIN_FRAME_WIDTH = 1400,
        MAIN_FRAME_HEIGHT = 900,
        MIN_WIDTH = 900,
        MIN_HEIGHT = 600,
        LEFT_PANEL_WIDTH = 300,
    }),
}
