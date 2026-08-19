local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "lfgpanel",
    title       = "LFGPANEL_TITLE",
    category    = "INTERFACE",
    description = "LFGPANEL_DESC",
    version     = "1.0",
    author      = "MichinMuggin / Ricky",
    contact     = "https://onewow.net/",
    link        = "https://onewow.net/",
    toggles     = {
        { id = "show_panel", label = "LFGPANEL_SHOW_PANEL", description = "LFGPANEL_SHOW_PANEL_DESC", default = true },
        { id = "filter_results", label = "LFGPANEL_FILTER_RESULTS", description = "LFGPANEL_FILTER_RESULTS_DESC", default = true },
    },
    preview        = true,
    defaultEnabled = true,
})
