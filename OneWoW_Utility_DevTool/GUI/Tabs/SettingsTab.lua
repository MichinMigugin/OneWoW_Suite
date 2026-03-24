local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local floor = math.floor

function Addon.UI:CreateSettingsTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local nextOffset = OneWoW_GUI:CreateSettingsPanel(tab, { yOffset = -10, addonName = "OneWoW_UtilityDevTool" }) or -195

    local section = OneWoW_GUI:CreateFrame(tab, {
        backdrop = BACKDROP_INNER_NO_INSETS,
        width = 100,
        height = 100,
    })
    section:ClearAllPoints()
    section:SetPoint("TOPLEFT", tab, "TOPLEFT", 10, nextOffset)
    section:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -10, 10)
    self:StyleContentPanel(section)

    local title = section:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", section, "TOPLEFT", 15, -12)
    title:SetText(Addon.L["SETTINGS_DEVTOOL_TABS_SECTION"])
    title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local description = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    description:SetPoint("TOPLEFT", section, "TOPLEFT", 15, -38)
    description:SetPoint("TOPRIGHT", section, "TOPRIGHT", -15, -38)
    description:SetJustifyH("LEFT")
    description:SetWordWrap(true)
    description:SetText(Addon.L["SETTINGS_DEVTOOL_TABS_DESC"])
    description:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local rowHeight = 28
    local startY = -78
    for index, tabKey in ipairs(self:GetOrderedTabKeys()) do
        local definition = self:GetTabDefinition(tabKey)
        local checkbox = OneWoW_GUI:CreateCheckbox(section, {
            label = self:GetTabLabel(tabKey),
        })
        local row = floor((index - 1) / 2)
        local y = startY - row * rowHeight
        if ((index - 1) % 2) == 0 then
            checkbox:SetPoint("TOPLEFT", section, "TOPLEFT", 15, y)
        else
            checkbox:SetPoint("TOPLEFT", section, "TOP", 15, y)
        end
        checkbox:SetChecked(self:IsTabEnabled(tabKey))

        if definition and definition.alwaysEnabled then
            checkbox:Disable()
            if checkbox.label then
                checkbox.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        else
            checkbox:SetScript("OnClick", function(cb)
                self:SetTabEnabled(tabKey, cb:GetChecked())
                self:RefreshTabs("settings")
            end)
        end
    end

    return tab
end
