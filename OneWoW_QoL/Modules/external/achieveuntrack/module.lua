local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "achieveuntrack",
    title       = "ACHIEVEUNTRACK_TITLE",
    category    = "AUTOMATION",
    description = "ACHIEVEUNTRACK_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {},
    preview     = false,
    _frame      = nil,
})
