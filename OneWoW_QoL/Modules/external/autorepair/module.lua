local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "autorepair",
    title       = "AUTOREPAIR_TITLE",
    category    = "AUTOMATION",
    description = "AUTOREPAIR_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    toggles = {
        { id = "use_guild_bank", label = "AUTOREPAIR_TOGGLE_GUILD", description = "AUTOREPAIR_TOGGLE_GUILD_DESC", default = true },
    },
    preview = true,
    _frame = nil,
})
