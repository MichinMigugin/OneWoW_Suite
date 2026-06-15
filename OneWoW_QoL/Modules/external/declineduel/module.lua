local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "declineduel",
    title       = "DECLINEDUEL_TITLE",
    category    = "SOCIAL",
    description = "DECLINEDUEL_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "pet_duels", label = "DECLINEDUEL_TOGGLE_PET", description = "DECLINEDUEL_TOGGLE_PET_DESC", default = true },
    },
    preview = true,
    defaultEnabled = false,
    _frame = nil,
})
