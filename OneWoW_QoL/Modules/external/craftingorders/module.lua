local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "craftingorders",
    title       = "CRAFTORDERS_TITLE",
    category    = "INTERFACE",
    description = "CRAFTORDERS_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    preview        = true,
    defaultEnabled = true,
    toggles = {
        { id = "useBlizzardList", label = "CRAFTORDERS_TOGGLE_WOWUI", description = "CRAFTORDERS_TOGGLE_WOWUI_DESC", default = false },
        { id = "hideUnlearned", label = "CRAFTORDERS_TOGGLE_HIDE_UNLEARNED", description = "CRAFTORDERS_TOGGLE_HIDE_UNLEARNED_DESC", default = true },
    },
})
