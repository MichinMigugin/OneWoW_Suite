local addonName, ns = ...

local ESCPanelModule = {
    id          = "escpanel",
    title       = "ESCPANEL_TITLE",
    category    = "INTERFACE",
    description = "ESCPANEL_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {
        { id = "esc_show_character_info",    label = "ESCPANEL_TOGGLE_SHOW_CHARACTER",   default = true },
        { id = "esc_show_alerts",            label = "ESCPANEL_TOGGLE_ALERTS",           default = true },
        { id = "esc_show_zone_notes",        label = "ESCPANEL_TOGGLE_ZONE_NOTES",       default = true },
        { id = "esc_hide_zone_when_empty",   label = "ESCPANEL_TOGGLE_HIDE_ZONE_EMPTY",  default = true },
        { id = "esc_show_tasks",             label = "ESCPANEL_TOGGLE_SHOW_TASKS",       default = true },
        { id = "esc_show_portals",           label = "ESCPANEL_TOGGLE_SHOW_PORTALS",     default = true },
    },
    preview        = true,
    defaultEnabled = true,
}

local TOGGLE_TO_DB = {
    esc_show_character_info  = "escShowCharacterInfo",
    esc_show_tasks           = "escShowTasks",
    esc_show_zone_notes      = "escShowZoneNotes",
    esc_hide_zone_when_empty = "escHideZoneNotesWhenEmpty",
    esc_show_alerts          = "escShowAlerts",
    esc_show_portals         = "escPortalsEnabled",
}

local function GetPortalHubDB()
    local hub = _G.OneWoW
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
    if _G.OneWoW and _G.OneWoW.PortalHubEsc and GameMenuFrame and GameMenuFrame:IsShown() then
        _G.OneWoW.PortalHubEsc:ShowPortalFrames()
    end
end

function ESCPanelModule:OnDisable()
    local ph = GetPortalHubDB()
    if not ph then return end
    ph.escEnabled = false
    if _G.OneWoW and _G.OneWoW.PortalHubEsc then
        _G.OneWoW.PortalHubEsc:HidePortalFrames()
    end
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
    local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
    if not OneWoW_GUI then return yOffset end
    local L = ns.L

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
            if _G.OneWoW and _G.OneWoW.PortalHubEsc then
                _G.OneWoW.PortalHubEsc:Reload()
            end
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
            if _G.OneWoW and _G.OneWoW.PortalHubEsc then
                _G.OneWoW.PortalHubEsc:Reload()
            end
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
        end)
    end

    return yOffset
end

ns.ESCPanelModule = ESCPanelModule
