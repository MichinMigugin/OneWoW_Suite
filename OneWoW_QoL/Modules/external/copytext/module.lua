local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "copytext",
    title       = "COPYTEXT_TITLE",
    category    = "UTILITY",
    description = "COPYTEXT_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    toggles = {
        { id = "mode_tooltips", label = "COPYTEXT_TOGGLE_TOOLTIPS", description = "COPYTEXT_TOGGLE_TOOLTIPS_DESC", default = true  },
        { id = "mode_anything", label = "COPYTEXT_TOGGLE_ANYTHING", description = "COPYTEXT_TOGGLE_ANYTHING_DESC", default = false },
        { id = "fast_copy",     label = "COPYTEXT_TOGGLE_FAST",     description = "COPYTEXT_TOGGLE_FAST_DESC",     default = false },
    },
    preview        = true,
    defaultEnabled = true,
})
