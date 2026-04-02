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
        MAX_WIDTH         = 2560,
        MAX_HEIGHT        = 1600,
    }),
    SPECIAL_COLORS = {
        TMog    = { 0.8, 0.4, 1.0 },
        Recipe  = { 1.0, 0.8, 0.2 },
        Mount   = { 0.4, 0.8, 1.0 },
        Pet     = { 1.0, 0.5, 0.5 },
        Quest   = { 1.0, 1.0, 0.2 },
        Toy     = { 1.0, 0.6, 0.8 },
        Housing = { 0.5, 1.0, 0.5 },
    },
}
