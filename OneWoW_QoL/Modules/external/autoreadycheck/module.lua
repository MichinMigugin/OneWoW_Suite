local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "autoreadycheck",
    title       = "AUTOREADYCHECK_TITLE",
    category    = "SOCIAL",
    description = "AUTOREADYCHECK_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    toggles = {
        { id = "skip_if_dead", label = "AUTOREADYCHECK_TOGGLE_DEAD", description = "AUTOREADYCHECK_TOGGLE_DEAD_DESC", default = true },
    },
    preview = true,
    defaultEnabled = false,
    _frame = nil,
})
