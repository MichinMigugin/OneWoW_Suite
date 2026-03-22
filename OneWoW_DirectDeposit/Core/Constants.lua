local _, OneWoW_DirectDeposit = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_DirectDeposit.Constants = {
    GUI = OneWoW_GUI:RegisterGUIConstants({
        WINDOW_WIDTH = 600,
        WINDOW_HEIGHT = 500,
    }),
}
