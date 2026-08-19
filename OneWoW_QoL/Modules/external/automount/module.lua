local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "automount",
    title       = "AUTOMOUNT_TITLE",
    category    = "AUTOMATION",
    description = "AUTOMOUNT_DESC",
    version     = "1.1",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    toggles     = {},
    preview     = true,
    _ticker     = nil,
    _eventFrame = nil,
})
