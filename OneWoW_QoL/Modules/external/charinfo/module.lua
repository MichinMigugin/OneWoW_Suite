local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "charinfo",
    title       = "CHARINFO_TITLE",
    category    = "INTERFACE",
    description = "CHARINFO_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {
        { id = "show_durability", label = "CHARINFO_TOGGLE_DURABILITY", description = "CHARINFO_TOGGLE_DURABILITY_DESC", default = true },
        { id = "show_sockets",    label = "CHARINFO_TOGGLE_SOCKETS",    description = "CHARINFO_TOGGLE_SOCKETS_DESC",    default = true },
    },
    preview        = true,
    defaultEnabled = true,
    _eventFrame = nil,
    _hooked     = false,
})
