local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "escpanel",
    title       = "ESCPANEL_TITLE",
    category    = "INTERFACE",
    description = "ESCPANEL_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@onewow.net",
    link        = "https://www.onewow.net",
    toggles     = {
        { id = "esc_show_character_info",    label = "ESCPANEL_TOGGLE_SHOW_CHARACTER",   default = true },
        { id = "esc_show_endeavors",         label = "ESCPANEL_TOGGLE_ENDEAVORS",        default = true },
        { id = "esc_show_alerts",            label = "ESCPANEL_TOGGLE_ALERTS",           default = true },
        { id = "esc_show_zone_notes",        label = "ESCPANEL_TOGGLE_ZONE_NOTES",       default = true },
        { id = "esc_hide_zone_when_empty",   label = "ESCPANEL_TOGGLE_HIDE_ZONE_EMPTY",  default = true },
        { id = "esc_show_portals",           label = "ESCPANEL_TOGGLE_SHOW_PORTALS",     default = true },
    },
    preview        = true,
    defaultEnabled = true,
})
