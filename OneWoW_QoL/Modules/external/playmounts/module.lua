local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "playmounts",
    title       = "PLAYMOUNTS_TITLE",
    category    = "INTERFACE",
    description = "PLAYMOUNTS_DESC",
    version     = "1.1",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "announce_chat",    label = "PLAYMOUNTS_TOGGLE_CHAT",       description = "PLAYMOUNTS_TOGGLE_CHAT_DESC",       default = false },
        { id = "enableMatchMount", label = "PLAYMOUNTS_TOGGLE_MATCHMOUNT", description = "PLAYMOUNTS_TOGGLE_MATCHMOUNT_DESC", default = true  },
    },
    preview        = true,
    defaultEnabled = true,
    _frame = nil,
})
