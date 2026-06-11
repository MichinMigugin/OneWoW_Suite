local _, OneWoW = ...

local UI = OneWoW.UI

local OneWoW_GUI = OneWoW_GUI

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

function UI:CreateSettingsMainTab(parent)
    local L = OneWoW.L or {}

    local _, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_SettingsScroll" })
    content:SetHeight(800)

    local yOffset = -10

    yOffset = OneWoW_GUI:CreateSettingsPanel(content, { yOffset = yOffset })

    yOffset = yOffset - 10

    local resetContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    resetContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    resetContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    resetContainer:SetHeight(90)
    resetContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    resetContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    resetContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local resetTitle = OneWoW_GUI:CreateFS(resetContainer, 16)
    resetTitle:SetPoint("TOPLEFT", resetContainer, "TOPLEFT", 15, -12)
    resetTitle:SetText(L["RESET_UI_SECTION"] or "Window Layout")
    resetTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local resetDesc = OneWoW_GUI:CreateFS(resetContainer, 12)
    resetDesc:SetPoint("TOPLEFT", resetContainer, "TOPLEFT", 15, -38)
    resetDesc:SetPoint("TOPRIGHT", resetContainer, "TOPRIGHT", -15, -38)
    resetDesc:SetText(L["RESET_UI_DESC"] or "Reset the OneWoW window to its default size and position.")
    resetDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    resetDesc:SetJustifyH("LEFT")
    resetDesc:SetWordWrap(true)

    local resetBtn = OneWoW_GUI:CreateFitTextButton(resetContainer, { text = L["RESET_UI_BTN"] or "Reset Window", height = 28 })
    resetBtn:SetPoint("TOPLEFT", resetContainer, "TOPLEFT", 15, -58)
    resetBtn:SetScript("OnClick", function()
        UI:ResetUIToDefaults()
    end)

    content:SetHeight(math.abs(yOffset) + 110)
end

local coreSettingsTabs = {
    { name = "settings",       displayName = function() return (OneWoW.L and OneWoW.L["SETTINGS_SUBTAB"] or "Settings") end, create = function(parent) UI:CreateSettingsMainTab(parent) end },
    { name = "profiles",       displayName = function() return OneWoW.L["PROFILES_SUBTAB"] end, create = function(parent) UI:CreateProfilesTab(parent) end },
    { name = "managefeatures", displayName = function() return OneWoW.L["MANAGE_FEATURES_SUBTAB"] end, create = function(parent) UI:CreateManageFeaturesTab(parent) end },
}

local qolFeatureTabs = {
    { name = "overlays",    displayName = function() return (OneWoW.L and OneWoW.L["OVERLAYS_SUBTAB"]    or "Overlays")     end, create = function(parent) UI:CreateOverlaysTab(parent)    end },
    { name = "portals",     displayName = function() return (OneWoW.L and OneWoW.L["PORTALS_SUBTAB"]     or "Portals")      end, create = function(parent) UI:CreatePortalsTab(parent)     end },
}

function UI:GetQoLFeatureTabs()
    return qolFeatureTabs
end

function UI:BuildSettingsTabs()
    local tabs = {}
    for _, tab in ipairs(coreSettingsTabs) do
        table.insert(tabs, tab)
    end
    if not OneWoW.ModuleRegistry:IsRegistered("qol") then
        for _, tab in ipairs(qolFeatureTabs) do
            table.insert(tabs, tab)
        end
    end
    local addonPanels = OneWoW.ModuleRegistry:GetSettingsPanels()
    for _, panel in ipairs(addonPanels) do
        local capturedCreate = panel.create
        table.insert(tabs, {
            name        = panel.name,
            displayName = panel.displayName,
            create      = capturedCreate,
        })
    end
    UI.settingsTabs = tabs
end
