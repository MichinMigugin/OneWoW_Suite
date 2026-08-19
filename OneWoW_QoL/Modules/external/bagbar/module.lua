local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "bagbar",
    title       = "BAGBAR_TITLE",
    category    = "INTERFACE",
    description = "BAGBAR_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    toggles     = {},
    preview     = true,
    defaultEnabled = true,
})
