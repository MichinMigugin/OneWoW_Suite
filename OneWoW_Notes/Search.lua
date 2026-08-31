local _, ns = ...

local Search = OneWoW.Search
local SR = OneWoW.SearchRegistry

local function NotesSettingsPath(leafKey)
    return {
        SR.ModuleLabel("settings"),
        SR.TabLabel("settings", "notes"),
        function()
            return ns.L[leafKey]
        end,
    }
end

local function OpenWayPinSettings()
    ns.UI.OpenWayPinSettings()
end

local waypinNav = { module = "settings", subtab = "notes", open = OpenWayPinSettings }

local waypinRows = {
    {
        id = "notes:waypins-enabled",
        title = "TAB_WAYPINS",
        description = "SETTINGS_WAYPINS_ENABLED_DESC",
        tags = { "waypins", "oneway", "pins", "enable", "map pins" },
    },
    {
        id = "notes:waypins-world",
        title = "WAYPINS_SHOW_WORLD",
        description = "SETTINGS_WAYPINS_WORLD_DESC",
        tags = { "world map", "pins" },
    },
    {
        id = "notes:waypins-minimap",
        title = "WAYPINS_SHOW_MINIMAP",
        description = "SETTINGS_WAYPINS_MINIMAP_DESC",
        tags = { "minimap", "pins" },
    },
    {
        id = "notes:waypins-map-panel",
        title = "WAYPINS_SHOW_MAP_PANEL",
        description = "SETTINGS_WAYPINS_MAP_PANEL_DESC",
        tags = { "legend", "map panel", "pins" },
    },
    {
        id = "notes:waypins-click-menu",
        title = "WAYPINS_MAP_CLICK_MENU",
        description = "SETTINGS_WAYPINS_MAP_CLICK_MENU_DESC",
        tags = { "map click", "right click", "pins" },
    },
}

for i = 1, #waypinRows do
    local row = waypinRows[i]
    Search:Register({
        id = row.id,
        title = row.title,
        description = row.description,
        scope = "OneWoW_Notes",
        tags = row.tags,
        addonKey = "OneWoW_Notes",
        path = NotesSettingsPath(row.title),
        nav = waypinNav,
    })
end

Search:Register({
    id = "notes:zone-pin-window",
    title = "TOOLTIP_ZONE_PIN",
    description = "TOOLTIP_ZONE_PIN_DESC",
    scope = "OneWoW_Notes",
    tags = { "popup", "pop-up", "floating", "pins", "waypins", "zone", "window" },
    addonKey = "OneWoW_Notes",
    path = {
        SR.ModuleLabel("notes"),
        SR.TabLabel("notes", "zones"),
        function() return ns.L["TOOLTIP_ZONE_PIN"] end,
    },
    nav = { module = "notes", subtab = "zones" },
})

Search:Register({
    id = "notes:pinned-scale",
    title = "SETTINGS_PINNED_SCALE",
    description = "SETTINGS_PINNED_SCALE_DESC",
    scope = "OneWoW_Notes",
    tags = { "scale", "pinned", "popup", "window" },
    addonKey = "OneWoW_Notes",
    path = NotesSettingsPath("SETTINGS_PINNED_SCALE"),
    nav = { module = "settings", subtab = "notes" },
})
