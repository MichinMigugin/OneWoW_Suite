local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "vendorpanel",
    title       = "VENDORPANEL_TITLE",
    category    = "ECONOMY",
    description = "VENDORPANEL_DESC",
    version     = "1.0",
    author      = "MichinMuggin / Ricky",
    contact     = "https://wow2.xyz/",
    link        = "https://wow2.xyz/",
    toggles     = {
        { id = "show_panel", label = "VENDORPANEL_SHOW_PANEL", description = "VENDORPANEL_SHOW_PANEL_DESC", default = true },
        { id = "show_blizz_junk", label = "VENDORPANEL_SHOW_BLIZZ_JUNK", description = "VENDORPANEL_SHOW_BLIZZ_JUNK_DESC", default = false },
    },
    preview        = true,
    defaultEnabled = true,
})
