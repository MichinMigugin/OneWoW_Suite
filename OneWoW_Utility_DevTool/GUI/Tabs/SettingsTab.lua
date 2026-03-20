local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

function Addon.UI:CreateSettingsTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    OneWoW_GUI:CreateSettingsPanel(tab, { yOffset = -10, addonName = "OneWoW_UtilityDevTool" })

    return tab
end
