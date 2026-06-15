local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "autoresurrect",
    title       = "AUTORESURRECT_TITLE",
    category    = "SOCIAL",
    description = "AUTORESURRECT_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "skip_in_instance", label = "AUTORESURRECT_TOGGLE_SKIP_INSTANCE", description = "AUTORESURRECT_TOGGLE_SKIP_INSTANCE_DESC", default = false },
    },
    preview = true,
    defaultEnabled = false,
    _frame = nil,
})
