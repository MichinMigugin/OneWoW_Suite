local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "autoinvite",
    title       = "AUTOINVITE_TITLE",
    category    = "SOCIAL",
    description = "AUTOINVITE_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    toggles = {
        { id = "from_friends", label = "AUTOINVITE_TOGGLE_FRIENDS", description = "AUTOINVITE_TOGGLE_FRIENDS_DESC", default = true },
        { id = "from_guild",   label = "AUTOINVITE_TOGGLE_GUILD",   description = "AUTOINVITE_TOGGLE_GUILD_DESC",   default = true },
        { id = "from_all",     label = "AUTOINVITE_TOGGLE_ALL",     description = "AUTOINVITE_TOGGLE_ALL_DESC",     default = false },
    },
    preview = true,
    defaultEnabled = false,
    _frame = nil,
})
