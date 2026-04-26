-- OneWoW/GUI/t-managefeatures.lua
-- Thin wrapper so the Settings tab can list "Manage Features" alongside
-- Profiles. Actual UI is built in Core/FirstRunWizard.lua and uses only
-- OneWoW_GUI helpers (no raw SetBackdrop / UICheckButtonTemplate).
local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI

function GUI:CreateManageFeaturesTab(parent)
    if OneWoW.FirstRun and OneWoW.FirstRun.BuildPanel then
        OneWoW.FirstRun:BuildPanel(parent)
    end
end
