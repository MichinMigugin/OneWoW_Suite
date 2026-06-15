local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "screenshotachievements",
    title       = "SCREENSHOTACH_TITLE",
    category    = "AUTOMATION",
    description = "SCREENSHOTACH_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {},
    preview     = true,
    defaultEnabled = false,
    _frame      = nil,
})
