local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "fastloot",
    title       = "FASTLOOT_TITLE",
    category    = "AUTOMATION",
    description = "FASTLOOT_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {},
    preview     = true,
    _frame      = nil,
    _epoch      = 0,
})
