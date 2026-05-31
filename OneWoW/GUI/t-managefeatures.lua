-- OneWoW/GUI/t-managefeatures.lua
-- Thin wrapper so the Settings tab can list "Manage Features" alongside
-- Profiles. Actual UI is built in Core/FirstRunWizard.lua and uses only
-- OneWoW_GUI helpers (no raw SetBackdrop / UICheckButtonTemplate).
local _, OneWoW = ...

local GUI = OneWoW.GUI

function GUI:CreateManageFeaturesTab(parent)
    OneWoW.FirstRun:BuildPanel(parent)
end
