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
        SEARCH_HEIGHT     = 28,
    }),

    QUALITY_COLORS = {
        [0] = {0.62, 0.62, 0.62, 1.0},
        [1] = {1.00, 1.00, 1.00, 1.0},
        [2] = {0.12, 1.00, 0.00, 1.0},
        [3] = {0.00, 0.44, 0.87, 1.0},
        [4] = {0.64, 0.21, 0.93, 1.0},
        [5] = {1.00, 0.50, 0.00, 1.0},
        [6] = {0.90, 0.80, 0.50, 1.0},
        [7] = {0.00, 0.80, 1.00, 1.0},
    },
}
