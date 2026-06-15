local _, ns = ...
local ESCPanelModule, L = ns.ModuleRegistry:Current()
if not ESCPanelModule then return end

local TOGGLE_TO_DB = {
    esc_show_character_info  = "escShowCharacterInfo",
    esc_show_zone_notes      = "escShowZoneNotes",
    esc_hide_zone_when_empty = "escHideZoneNotesWhenEmpty",
    esc_show_alerts          = "escShowAlerts",
    esc_show_portals         = "escPortalsEnabled",
}

local function GetPortalHubDB()
    local hub = OneWoW
    if not hub or not hub.db or not hub.db.global then return nil end
    return hub.db.global.portalHub
end

function ESCPanelModule:OnEnable()
    local ph = GetPortalHubDB()
    if not ph then return end
    ph.escEnabled = true
    for toggleId, dbKey in pairs(TOGGLE_TO_DB) do
        if ph[dbKey] ~= nil then
            ns.ModuleRegistry:SetToggleValue(self.id, toggleId, ph[dbKey])
        end
    end
    if GameMenuFrame and GameMenuFrame:IsShown() then
        ns.PortalHubEsc:ShowPortalFrames()
    end
end

function ESCPanelModule:OnDisable()
    local ph = GetPortalHubDB()
    if not ph then return end
    ph.escEnabled = false
    ns.PortalHubEsc:HidePortalFrames()
end

function ESCPanelModule:OnToggle(toggleId, value)
    local ph = GetPortalHubDB()
    if not ph then return end
    local dbKey = TOGGLE_TO_DB[toggleId]
    if dbKey then
        ph[dbKey] = value
    end
end

function ESCPanelModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled, registerRefresh)
    local OneWoW_GUI = OneWoW_GUI
    if not OneWoW_GUI then return yOffset end

    local header = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    header:SetText(L["ESCPANEL_LAYOUT_HEADER"] or "Layout")
    header:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - header:GetStringHeight() - 8

    local divider = detailScrollChild:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    divider:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 10

    local descText = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descText:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    descText:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    descText:SetText(L["ESCPANEL_LAYOUT_DESC"] or "")
    descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    descText:SetJustifyH("LEFT")
    descText:SetWordWrap(true)
    yOffset = yOffset - descText:GetStringHeight() - 12

    local ph0 = GetPortalHubDB()
    local panelsSide = (ph0 and ph0.escPanelsSide == "right") and "right" or "left"
    local portalsSide = (ph0 and ph0.escPortalsSide == "left") and "left" or "right"
    local currentIconSize = (ph0 and ph0.escIconSize) or 32

    local iconSizeLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iconSizeLabel:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    iconSizeLabel:SetText(L["ESCPANEL_ICON_SIZE_LABEL"] or "Portal icon size")
    iconSizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - iconSizeLabel:GetStringHeight() - 4

    local iconSizeSlider = OneWoW_GUI:CreateSlider(detailScrollChild, {
        width      = 220,
        minVal     = 20,
        maxVal     = 64,
        step       = 2,
        currentVal = currentIconSize,
        fmt        = "%dpx",
        onChange   = function(val)
            local p = GetPortalHubDB()
            if p then p.escIconSize = val end
            ns.PortalHubEsc:Reload()
        end,
    })
    iconSizeSlider:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    yOffset = yOffset - 36 - 14

    local panelsRowLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panelsRowLabel:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    panelsRowLabel:SetText(L["ESCPANEL_PANELS_SIDE_LABEL"] or "Info panels side")
    panelsRowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - panelsRowLabel:GetStringHeight() - 4

    local panelsDD, panelsDDText = OneWoW_GUI:CreateDropdown(detailScrollChild, {
        width = 220,
        text = panelsSide == "right" and (L["ESCPANEL_SIDE_RIGHT"] or "Right") or (L["ESCPANEL_SIDE_LEFT"] or "Left"),
    })
    OneWoW_GUI:AttachFilterMenu(panelsDD, {
        searchable = false,
        buildItems = function()
            return {
                { text = L["ESCPANEL_SIDE_LEFT"] or "Left", value = "left" },
                { text = L["ESCPANEL_SIDE_RIGHT"] or "Right", value = "right" },
            }
        end,
        onSelect = function(value, text)
            panelsDDText:SetText(text)
            local p = GetPortalHubDB()
            if p then p.escPanelsSide = value end
            ns.PortalHubEsc:Reload()
        end,
        getActiveValue = function()
            local p = GetPortalHubDB()
            return (p and p.escPanelsSide == "right") and "right" or "left"
        end,
    })
    panelsDD:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    yOffset = yOffset - 26 - 14

    local portalsRowLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    portalsRowLabel:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    portalsRowLabel:SetText(L["ESCPANEL_PORTALS_SIDE_LABEL"] or "Portals side")
    portalsRowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - portalsRowLabel:GetStringHeight() - 4

    local portalsDD, portalsDDText = OneWoW_GUI:CreateDropdown(detailScrollChild, {
        width = 220,
        text = portalsSide == "left" and (L["ESCPANEL_SIDE_LEFT"] or "Left") or (L["ESCPANEL_SIDE_RIGHT"] or "Right"),
    })
    OneWoW_GUI:AttachFilterMenu(portalsDD, {
        searchable = false,
        buildItems = function()
            return {
                { text = L["ESCPANEL_SIDE_LEFT"] or "Left", value = "left" },
                { text = L["ESCPANEL_SIDE_RIGHT"] or "Right", value = "right" },
            }
        end,
        onSelect = function(value, text)
            portalsDDText:SetText(text)
            local p = GetPortalHubDB()
            if p then p.escPortalsSide = value end
            ns.PortalHubEsc:Reload()
        end,
        getActiveValue = function()
            local p = GetPortalHubDB()
            return (p and p.escPortalsSide == "left") and "left" or "right"
        end,
    })
    portalsDD:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    yOffset = yOffset - 26 - 16

    if registerRefresh then
        registerRefresh(function()
            local p = GetPortalHubDB()
            local ps = (p and p.escPanelsSide == "right") and "right" or "left"
            local pr = (p and p.escPortalsSide == "left") and "left" or "right"
            panelsDDText:SetText(ps == "right" and (L["ESCPANEL_SIDE_RIGHT"] or "Right") or (L["ESCPANEL_SIDE_LEFT"] or "Left"))
            portalsDDText:SetText(pr == "left" and (L["ESCPANEL_SIDE_LEFT"] or "Left") or (L["ESCPANEL_SIDE_RIGHT"] or "Right"))
            local sz = (p and p.escIconSize) or 32
            if iconSizeSlider.slider:GetValue() ~= sz then
                iconSizeSlider.slider:SetValue(sz)
            end
        end)
    end

    return yOffset
end
