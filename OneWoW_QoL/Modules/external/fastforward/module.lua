local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "fastforward",
    title       = "FASTFORWARD_TITLE",
    category    = "AUTOMATION",
    description = "FASTFORWARD_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    toggles = {
        { id = "skip_movies",           label = "FASTFORWARD_TOGGLE_MOVIES",           description = "FASTFORWARD_TOGGLE_MOVIES_DESC",           default = true  },
        { id = "skip_cinematics",       label = "FASTFORWARD_TOGGLE_CINEMATICS",       description = "FASTFORWARD_TOGGLE_CINEMATICS_DESC",       default = true  },
        { id = "instance_only",         label = "FASTFORWARD_TOGGLE_INSTANCE",         description = "FASTFORWARD_TOGGLE_INSTANCE_DESC",         default = false },
        { id = "respect_uncancellable", label = "FASTFORWARD_TOGGLE_UNCANCELLABLE",    description = "FASTFORWARD_TOGGLE_UNCANCELLABLE_DESC",    default = false },
    },
    preview = true,
    _frame = nil,
})
