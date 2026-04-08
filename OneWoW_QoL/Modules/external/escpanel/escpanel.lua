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

ns.ESCPanelModule = ESCPanelModule
