local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id             = "inspectmog",
    title          = "INSPECTMOG_TITLE",
    category       = "INTERFACE",
    description    = "INSPECTMOG_DESC",
    version        = "1.1",
    author         = "OneWoW",
    contact        = "https://wow2.xyz/",
    link           = "https://wow2.xyz/",
    toggles        = {
        { id = "route_to_collectibles", label = "INSPECTMOG_ROUTE_COLLECTIBLES", default = false },
    },
    preview        = true,
    defaultEnabled = false,
})
