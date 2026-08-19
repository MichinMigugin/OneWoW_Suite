local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "professionspanel",
    title       = "PROFPANEL_TITLE",
    category    = "INTERFACE",
    description = "PROFPANEL_DESC",
    version     = "2.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    toggles     = {
        { id = "auto_show", label = "PROFPANEL_AUTO_SHOW", default = true },
    },
    preview        = true,
    defaultEnabled = true,
    _panel           = nil,
    _toggleTab       = nil,
    _sidebarIndex    = nil,
    _toggleHandler   = nil,
    _eventFrame      = nil,
    _currentProf     = nil,
    _cachedData      = nil,
    _lastScanTime    = 0,
    _scanThrottle    = 2,
})
