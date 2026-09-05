local _, ns = ...

local Search = OneWoW.Search
local SR = OneWoW.SearchRegistry

local portalsNav = { module = "qol", subtab = "portals" }

local function PortalsPath(leafKey)
    return {
        SR.ModuleLabel("qol"),
        SR.TabLabel("qol", "portals"),
        function() return ns.L[leafKey] end,
    }
end

Search:Register({
    id = "qol:portals-random-hearth",
    title = "PORTAL_RANDOM_HEARTHSTONE",
    description = "PORTAL_RANDOM_HEARTHSTONE_DESC",
    scope = "OneWoW_QoL",
    tags = { "hearthstone", "random", "toy", "esc" },
    addonKey = "OneWoW_QoL",
    path = PortalsPath("PORTAL_RANDOM_HEARTHSTONE"),
    nav = portalsNav,
})

Search:Register({
    id = "qol:portals-display",
    title = "PORTAL_DISPLAY_OPTIONS",
    tags = { "portals", "display", "esc" },
    addonKey = "OneWoW_QoL",
    scope = "OneWoW_QoL",
    path = PortalsPath("PORTAL_DISPLAY_OPTIONS"),
    nav = portalsNav,
})

Search:Register({
    id = "qol:portals-mage-teleports",
    title = "PORTAL_SHOW_MAGE_TELEPORTS",
    description = "PORTAL_SHOW_MAGE_TELEPORTS_DESC",
    scope = "OneWoW_QoL",
    tags = { "mage", "teleport", "esc", "hide" },
    addonKey = "OneWoW_QoL",
    path = PortalsPath("PORTAL_SHOW_MAGE_TELEPORTS"),
    nav = portalsNav,
})

Search:Register({
    id = "qol:portals-mage-portals",
    title = "PORTAL_SHOW_MAGE_PORTALS",
    description = "PORTAL_SHOW_MAGE_PORTALS_DESC",
    scope = "OneWoW_QoL",
    tags = { "mage", "portal", "esc", "hide" },
    addonKey = "OneWoW_QoL",
    path = PortalsPath("PORTAL_SHOW_MAGE_PORTALS"),
    nav = portalsNav,
})
