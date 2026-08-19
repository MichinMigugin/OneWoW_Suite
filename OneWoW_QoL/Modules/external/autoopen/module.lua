local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "autoopen",
    title       = "AUTOOPEN_TITLE",
    category    = "AUTOMATION",
    description = "AUTOOPEN_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    toggles     = {},
    preview     = true,
    _frame      = nil,
    _atMail     = false,
    _tempBlacklist = {},
})
