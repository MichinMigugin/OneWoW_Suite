local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

ns.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        COLLECTIBLE_ROW_HEIGHT = 30,
        COLLECTIBLE_HEADER_H = 70,
        COLLECTIBLE_SOURCE_BTN_H = 22,
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
