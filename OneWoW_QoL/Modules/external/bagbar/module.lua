local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "bagbar",
    title       = "BAGBAR_TITLE",
    category    = "INTERFACE",
    description = "BAGBAR_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {},
    preview     = true,
    defaultEnabled = true,
})
