local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "autosummon",
    title       = "AUTOSUMMON_TITLE",
    category    = "SOCIAL",
    description = "AUTOSUMMON_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "skip_in_combat", label = "AUTOSUMMON_TOGGLE_SKIP_COMBAT", description = "AUTOSUMMON_TOGGLE_SKIP_COMBAT_DESC", default = true },
    },
    preview = true,
    defaultEnabled = false,
    _frame = nil,
})
