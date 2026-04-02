local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

function GUI:CreateSettingsMainTab(parent)
    local L = OneWoW.L or {}

    local scrollFrame, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_SettingsScroll" })
    content:SetHeight(800)

    local yOffset = -10

    if OneWoW_GUI and OneWoW_GUI.CreateSettingsPanel then
        yOffset = OneWoW_GUI:CreateSettingsPanel(content, { yOffset = yOffset })
    end

    local linksContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    linksContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    linksContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    linksContainer:SetHeight(120)
    linksContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    linksContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    linksContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local linksTitle = OneWoW_GUI:CreateFS(linksContainer, 16)
    linksTitle:SetPoint("TOPLEFT", linksContainer, "TOPLEFT", 15, -12)
    linksTitle:SetText(L["LINKS_SECTION"] or "Support & Community")
    linksTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local discordLinkLabel = OneWoW_GUI:CreateFS(linksContainer, 12)
    discordLinkLabel:SetPoint("TOPLEFT", linksContainer, "TOPLEFT", 15, -40)
    discordLinkLabel:SetText(L["DISCORD_LABEL"] or "Discord")
    discordLinkLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local discordLinkBox = OneWoW_GUI:CreateEditBox(linksContainer, { name = "OneWoW_SettingsDiscord", width = 300, height = 24 })
    discordLinkBox:SetPoint("LEFT", discordLinkLabel, "RIGHT", OneWoW_GUI:GetSpacing("SM"), 0)
    discordLinkBox:SetText(L["DISCORD_URL"] or "https://discord.gg/6vnabDVnDu")
    discordLinkBox:SetAutoFocus(false)
    discordLinkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    discordLinkBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    local websiteLinkLabel = OneWoW_GUI:CreateFS(linksContainer, 12)
    websiteLinkLabel:SetPoint("TOPLEFT", linksContainer, "TOPLEFT", 15, -72)
    websiteLinkLabel:SetText(L["WEBSITE_LABEL"] or "Website")
    websiteLinkLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local websiteLinkBox = OneWoW_GUI:CreateEditBox(linksContainer, { name = "OneWoW_SettingsWebsite", width = 300, height = 24 })
    websiteLinkBox:SetPoint("LEFT", websiteLinkLabel, "RIGHT", OneWoW_GUI:GetSpacing("SM"), 0)
    websiteLinkBox:SetText(L["WEBSITE_URL"] or "https://wow2.xyz/")
    websiteLinkBox:SetAutoFocus(false)
    websiteLinkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    websiteLinkBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    yOffset = yOffset - 140

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
        GUI:ResetUIToDefaults()
    end)

    content:SetHeight(math.abs(yOffset) + 110)
end

local coreSettingsTabs = {
    { name = "settings", displayName = function() return (OneWoW.L and OneWoW.L["SETTINGS_SUBTAB"] or "Settings") end, create = function(parent) GUI:CreateSettingsMainTab(parent) end },
    { name = "profiles", displayName = function() return "Profiles" end, create = function(parent) GUI:CreateProfilesTab(parent) end },
}

local qolFeatureTabs = {
    { name = "overlays",    displayName = function() return (OneWoW.L and OneWoW.L["OVERLAYS_SUBTAB"]    or "Overlays")     end, create = function(parent) GUI:CreateOverlaysTab(parent)    end },
    { name = "toastalerts", displayName = function() return (OneWoW.L and OneWoW.L["TOAST_ALERTS_SUBTAB"] or "Toast Alerts") end, create = function(parent) GUI:CreateToastAlertsTab(parent) end },
    { name = "tooltips",    displayName = function() return (OneWoW.L and OneWoW.L["TOOLTIPS_SUBTAB"]    or "Tooltips")     end, create = function(parent) GUI:CreateTooltipsTab(parent)    end },
    { name = "portals",     displayName = function() return (OneWoW.L and OneWoW.L["PORTALS_SUBTAB"]     or "Portals")      end, create = function(parent) GUI:CreatePortalsTab(parent)     end },
}

function GUI:GetQoLFeatureTabs()
    return qolFeatureTabs
end

function GUI:BuildSettingsTabs()
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
    GUI.settingsTabs = tabs
end
