local _, ns = ...
local ESCPanelModule, L = ns.ModuleRegistry:Current()
if not ESCPanelModule then return end

local OneWoW_GUI = OneWoW_GUI

-- Session-only collapse memory (survives tab switches; cleared on /reload)
local collapsedCards = {}

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

function ESCPanelModule:CreateCustomDetail(detailScrollChild, yOffset, _, registerRefresh)
    local cardsHost = CreateFrame("Frame", nil, detailScrollChild)
    cardsHost:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
    cardsHost:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)

    local stack = OneWoW_GUI:CreateCardStack(cardsHost, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })

    local function applyHostHeight()
        local h = math.max(1, cardsHost:GetHeight())
        if detailScrollChild.UpdateDetailHeight then
            detailScrollChild:SetHeight(h)
            detailScrollChild.UpdateDetailHeight()
        else
            detailScrollChild:SetHeight(math.abs(yOffset) + h + 20)
            if detailScrollChild.updateThumb then
                detailScrollChild.updateThumb()
            end
        end
    end
    stack.OnRelayout = applyHostHeight

    local layoutRefresh

    stack:AddCard("escpanel:layout", L["ESCPANEL_LAYOUT_HEADER"], function(content, contentWidth)
        local gap = 8
        local descText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        descText:SetJustifyH("LEFT")
        descText:SetWordWrap(true)
        descText:SetSpacing(2)
        local w = tonumber(contentWidth) or 0
        if w < 1 then
            w = content:GetWidth() or 0
        end
        if w >= 1 then
            descText:SetWidth(w)
        else
            descText:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
        end
        descText:SetText(L["ESCPANEL_LAYOUT_DESC"])
        descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local ph0 = GetPortalHubDB()
        local panelsSide = (ph0 and ph0.escPanelsSide == "right") and "right" or "left"
        local portalsSide = (ph0 and ph0.escPortalsSide == "left") and "left" or "right"
        local currentIconSize = (ph0 and ph0.escIconSize) or 40

        local iconSizeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        iconSizeLabel:SetPoint("TOPLEFT", descText, "BOTTOMLEFT", 0, -gap)
        iconSizeLabel:SetText(L["ESCPANEL_ICON_SIZE_LABEL"])
        iconSizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local iconSizeSlider = OneWoW_GUI:CreateSlider(content, {
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
        iconSizeSlider:SetPoint("TOPLEFT", iconSizeLabel, "BOTTOMLEFT", 0, -4)

        local panelsRowLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        panelsRowLabel:SetPoint("TOPLEFT", iconSizeSlider, "BOTTOMLEFT", 0, -14)
        panelsRowLabel:SetText(L["ESCPANEL_PANELS_SIDE_LABEL"])
        panelsRowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local panelsDD, panelsDDText = OneWoW_GUI:CreateDropdown(content, {
            width = 220,
            text = panelsSide == "right" and (L["ESCPANEL_SIDE_RIGHT"]) or (L["ESCPANEL_SIDE_LEFT"]),
        })
        OneWoW_GUI:AttachFilterMenu(panelsDD, {
            searchable = false,
            buildItems = function()
                return {
                    { text = L["ESCPANEL_SIDE_LEFT"], value = "left" },
                    { text = L["ESCPANEL_SIDE_RIGHT"], value = "right" },
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
        panelsDD:SetPoint("TOPLEFT", panelsRowLabel, "BOTTOMLEFT", 0, -4)

        local portalsRowLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        portalsRowLabel:SetPoint("TOPLEFT", panelsDD, "BOTTOMLEFT", 0, -14)
        portalsRowLabel:SetText(L["ESCPANEL_PORTALS_SIDE_LABEL"])
        portalsRowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local portalsDD, portalsDDText = OneWoW_GUI:CreateDropdown(content, {
            width = 220,
            text = portalsSide == "left" and (L["ESCPANEL_SIDE_LEFT"]) or (L["ESCPANEL_SIDE_RIGHT"]),
        })
        OneWoW_GUI:AttachFilterMenu(portalsDD, {
            searchable = false,
            buildItems = function()
                return {
                    { text = L["ESCPANEL_SIDE_LEFT"], value = "left" },
                    { text = L["ESCPANEL_SIDE_RIGHT"], value = "right" },
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
        portalsDD:SetPoint("TOPLEFT", portalsRowLabel, "BOTTOMLEFT", 0, -4)

        layoutRefresh = function()
            local p = GetPortalHubDB()
            local ps = (p and p.escPanelsSide == "right") and "right" or "left"
            local pr = (p and p.escPortalsSide == "left") and "left" or "right"
            panelsDDText:SetText(ps == "right" and (L["ESCPANEL_SIDE_RIGHT"]) or (L["ESCPANEL_SIDE_LEFT"]))
            portalsDDText:SetText(pr == "left" and (L["ESCPANEL_SIDE_LEFT"]) or (L["ESCPANEL_SIDE_RIGHT"]))
            local sz = (p and p.escIconSize) or 40
            if iconSizeSlider.slider:GetValue() ~= sz then
                iconSizeSlider.slider:SetValue(sz)
            end
        end

        local descH = descText:GetStringHeight() or 14
        local iconLabelH = iconSizeLabel:GetStringHeight() or 12
        local panelsLabelH = panelsRowLabel:GetStringHeight() or 12
        local portalsLabelH = portalsRowLabel:GetStringHeight() or 12
        local sliderH = iconSizeSlider:GetHeight() or 36
        return math.max(1,
            descH + gap
            + iconLabelH + 4 + sliderH + 14
            + panelsLabelH + 4 + 26 + 14
            + portalsLabelH + 4 + 26 + 4)
    end)

    stack:Finish()
    applyHostHeight()

    if registerRefresh then
        registerRefresh(function()
            if layoutRefresh then
                layoutRefresh()
            end
        end)
    end

    return yOffset - cardsHost:GetHeight()
end
