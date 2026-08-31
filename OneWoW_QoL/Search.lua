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
