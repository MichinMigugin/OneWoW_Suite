local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "autodelete",
    title       = "AUTODELETE_TITLE",
    category    = "INTERFACE",
    description = "AUTODELETE_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "skip_typing", label = "AUTODELETE_TOGGLE_SKIP", description = "AUTODELETE_TOGGLE_SKIP_DESC", default = true },
        { id = "show_link",   label = "AUTODELETE_TOGGLE_LINK", description = "AUTODELETE_TOGGLE_LINK_DESC", default = true },
    },
    preview         = true,
    _frame          = nil,
    _linkFontString = nil,
})
