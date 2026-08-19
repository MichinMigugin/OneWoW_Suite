local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id             = "minimapbuttons",
    title          = "MMBTNS_TITLE",
    category       = "INTERFACE",
    description    = "MMBTNS_DESC",
    version        = "1.0",
    author         = "Ricky",
    contact        = "ricky@onewow.net",
    link           = "https://www.onewow.net",
    toggles        = {},
    preview        = false,
    defaultEnabled = true,
})
