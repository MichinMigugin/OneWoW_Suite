local _, OneWoW_Bags = ...

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
        RECENT_EXPIRY_TICK_INTERVAL = 2,
        TRACKER_CELL_WIDTH = 76,
        TRACKER_CELL_HEIGHT = 20,
        TRACKER_CELL_GAP = 4,
    }),

    ICON_SIZES = {
        [1] = 28,
        [2] = 32,
        [3] = 37,
        [4] = 42,
    },

    -- Fixed alert palette for currency trackers near total cap (maxQuantity > 0).
    -- Levels 1–4: 75%, 80%, 90%, 95% fill bands; level 5: at cap (100%) + red glow overlay.
    TRACKER_CURRENCY_CAP = {
        [1] = {
            bg = { 0.42, 0.26, 0.10, 0.95 },
            border = { 1.0, 0.55, 0.12, 1.0 },
            countText = { 1.0, 0.82, 0.55, 1.0 },
        },
        [2] = {
            bg = { 0.38, 0.20, 0.08, 0.96 },
            border = { 0.95, 0.48, 0.10, 1.0 },
            countText = { 1.0, 0.78, 0.48, 1.0 },
        },
        [3] = {
            bg = { 0.34, 0.16, 0.06, 0.97 },
            border = { 0.88, 0.40, 0.08, 1.0 },
            countText = { 1.0, 0.72, 0.42, 1.0 },
        },
        [4] = {
            bg = { 0.30, 0.12, 0.05, 0.98 },
            border = { 0.78, 0.32, 0.06, 1.0 },
            countText = { 1.0, 0.68, 0.38, 1.0 },
        },
        [5] = {
            bg = { 0.45, 0.08, 0.08, 1.0 },
            border = { 1.0, 0.22, 0.18, 1.0 },
            countText = { 1.0, 0.55, 0.52, 1.0 },
        },
    },

    TRACKER_CURRENCY_CAP_GLOW = {
        vertex = { 1.0, 0.18, 0.12 },
        alphaMin = 0.28,
        alphaMax = 0.55,
    },
}
