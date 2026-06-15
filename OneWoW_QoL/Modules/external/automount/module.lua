local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "automount",
    title       = "AUTOMOUNT_TITLE",
    category    = "AUTOMATION",
    description = "AUTOMOUNT_DESC",
    version     = "1.1",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {},
    preview     = true,
    _ticker     = nil,
    _eventFrame = nil,
})
