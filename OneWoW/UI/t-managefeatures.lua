-- OneWoW/UI/t-managefeatures.lua
-- Thin wrapper so the Settings tab can list "Manage Features" alongside
-- Profiles. Actual UI is built in Core/FirstRunWizard.lua and uses only
-- OneWoW_GUI helpers (no raw SetBackdrop / UICheckButtonTemplate).
local _, ns = ...

local UI = ns.UI

function UI:CreateManageFeaturesTab(parent)
    ns.FirstRun:BuildPanel(parent)
end
