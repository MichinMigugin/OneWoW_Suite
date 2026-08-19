local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "hideerrors",
    title       = "HIDEERRORS_TITLE",
    category    = "INTERFACE",
    description = "HIDEERRORS_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    toggles     = {},
    preview     = true,
    defaultEnabled = false,
    _hooked     = false,
    _origAddMessage = nil,
    _filterSet  = nil,
})
