local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local abs = math.abs
local max = math.max
local tinsert = tinsert

local UNLOAD_COL_OFFSET = 248

local function attachUnloadTooltip(widget, tooltipTitle, tooltipBody)
    if not widget or not tooltipBody or tooltipBody == "" then
        return
    end
    local function showTip(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if tooltipTitle and tooltipTitle ~= "" then
            GameTooltip:AddLine(tooltipTitle, 1, 1, 1)
            GameTooltip:AddLine(" ", 1, 1, 1)
        end
        GameTooltip:AddLine(tooltipBody, nil, nil, nil, true)
        GameTooltip:Show()
    end
    local function hideTip()
        GameTooltip:Hide()
    end
    widget:SetScript("OnEnter", showTip)
    widget:SetScript("OnLeave", hideTip)
    if widget.label then
        widget.label:SetScript("OnEnter", function()
            showTip(widget)
        end)
        widget.label:SetScript("OnLeave", hideTip)
    end
end

function Addon.UI:CreateSettingsTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    self.settingsUnloadCheckboxes = {}

    local _, scrollContent = OneWoW_GUI:CreateScrollFrame(tab, {})
    local nextOffset = OneWoW_GUI:CreateSettingsPanel(scrollContent, { yOffset = -10, addonName = "OneWoW_UtilityDevTool" }) or -195

    local section = OneWoW_GUI:CreateFrame(scrollContent, {
        backdrop = BACKDROP_INNER_NO_INSETS,
        width = 100,
        height = 100,
    })
    section:ClearAllPoints()
    section:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 10, nextOffset)
    section:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -10, nextOffset)
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
    local row = 0
    local lowestY = startY

    local ordered = self:GetOrderedTabKeys()
    local entries = {}
    for _, tabKey in ipairs(ordered) do
        if tabKey == "textures" or tabKey == "sounds" then
            tinsert(entries, { kind = "assetPair", key = tabKey })
        else
            tinsert(entries, { kind = "single", key = tabKey })
        end
    end

    local L = Addon.L or {}
    local unloadTipTitle = L["SETTINGS_TAB_UNLOAD_ASSETS_TOOLTIP_TITLE"]
    local unloadTipBody = L["SETTINGS_TAB_UNLOAD_ASSETS_TOOLTIP"]

    local i = 1
    while i <= #entries do
        local e = entries[i]
        if e.kind == "assetPair" then
            row = row + 1
            local y = startY - row * rowHeight
            if y < lowestY then
                lowestY = y
            end
            local tabKey = e.key
            local definition = self:GetTabDefinition(tabKey)

            local parentCb = OneWoW_GUI:CreateCheckbox(section, {
                label = self:GetTabLabel(tabKey),
            })
            parentCb:SetPoint("TOPLEFT", section, "TOPLEFT", 15, y)
            parentCb:SetChecked(self:IsTabEnabled(tabKey))

            local unloadCb = OneWoW_GUI:CreateCheckbox(section, {
                label = L["SETTINGS_TAB_UNLOAD_ASSETS"],
            })
            unloadCb:SetPoint("TOPLEFT", section, "TOPLEFT", 15 + UNLOAD_COL_OFFSET, y)
            if unloadCb.label then
                unloadCb.label:SetFontObject("GameFontNormalSmall")
            end
            unloadCb:SetChecked(self:GetUnloadOnDisable(tabKey))
            self.settingsUnloadCheckboxes[tabKey] = unloadCb
            attachUnloadTooltip(unloadCb, unloadTipTitle, unloadTipBody)

            if definition and definition.alwaysEnabled then
                parentCb:Disable()
                if parentCb.label then
                    parentCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                end
                unloadCb:Disable()
                if unloadCb.label then
                    unloadCb.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                end
            else
                parentCb:SetScript("OnClick", function(cb)
                    local enabled = cb:GetChecked()
                    if enabled then
                        self:ApplyUnloadAssetSetting(tabKey, false)
                    end
                    self:SetTabEnabled(tabKey, enabled)
                    self:UpdateUnloadCheckboxEnableState(tabKey)
                    self:RefreshTabs("settings")
                end)
                unloadCb:SetScript("OnClick", function(cb)
                    self:ApplyUnloadAssetSetting(tabKey, cb:GetChecked())
                end)
                self:UpdateUnloadCheckboxEnableState(tabKey)
            end

            i = i + 1
        else
            row = row + 1
            local y = startY - row * rowHeight
            if y < lowestY then
                lowestY = y
            end
            local eRight = entries[i + 1]
            if eRight and eRight.kind == "single" then
                local tabKeyL = e.key
                local tabKeyR = eRight.key
                local defL = self:GetTabDefinition(tabKeyL)
                local defR = self:GetTabDefinition(tabKeyR)

                local cbL = OneWoW_GUI:CreateCheckbox(section, {
                    label = self:GetTabLabel(tabKeyL),
                })
                cbL:SetPoint("TOPLEFT", section, "TOPLEFT", 15, y)
                cbL:SetChecked(self:IsTabEnabled(tabKeyL))

                local cbR = OneWoW_GUI:CreateCheckbox(section, {
                    label = self:GetTabLabel(tabKeyR),
                })
                cbR:SetPoint("TOPLEFT", section, "TOP", 15, y)
                cbR:SetChecked(self:IsTabEnabled(tabKeyR))

                if defL and defL.alwaysEnabled then
                    cbL:Disable()
                    if cbL.label then
                        cbL.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    end
                else
                    cbL:SetScript("OnClick", function(cb)
                        self:SetTabEnabled(tabKeyL, cb:GetChecked())
                        self:RefreshTabs("settings")
                    end)
                end

                if defR and defR.alwaysEnabled then
                    cbR:Disable()
                    if cbR.label then
                        cbR.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    end
                else
                    cbR:SetScript("OnClick", function(cb)
                        self:SetTabEnabled(tabKeyR, cb:GetChecked())
                        self:RefreshTabs("settings")
                    end)
                end

                i = i + 2
            else
                local tabKey = e.key
                local definition = self:GetTabDefinition(tabKey)
                local checkbox = OneWoW_GUI:CreateCheckbox(section, {
                    label = self:GetTabLabel(tabKey),
                })
                checkbox:SetPoint("TOPLEFT", section, "TOPLEFT", 15, y)
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

                i = i + 1
            end
        end
    end

    local sectionHeight = abs(lowestY) + 42
    section:SetHeight(max(120, sectionHeight))
    scrollContent:SetHeight(max(1, abs(nextOffset - sectionHeight) + 24))

    for _, assetKey in ipairs({ "textures", "sounds" }) do
        if self:IsTabEnabled(assetKey) and self:GetUnloadOnDisable(assetKey) then
            self:ApplyUnloadAssetSetting(assetKey, false)
        end
    end

    return tab
end
