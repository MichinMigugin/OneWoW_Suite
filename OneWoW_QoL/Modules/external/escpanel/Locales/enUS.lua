local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["ESCPANEL_TITLE"] = "ESC Menu Panel",
    ["ESCPANEL_DESC"] = "Display character info, alerts, zone notes, and portal strip alongside the ESC menu. Choose which side each uses below.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Display Character Info",
    ["ESCPANEL_TOGGLE_ALERTS"] = "Display Alerts",
    ["ESCPANEL_TOGGLE_ZONE_NOTES"] = "Display Zone Notes",
    ["ESCPANEL_TOGGLE_HIDE_ZONE_EMPTY"] = "Hide Zone Notes When Empty",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "Display Portals",
    ["ESCPANEL_LAYOUT_HEADER"] = "Layout",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "Info panels side",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "Portals side",
    ["ESCPANEL_SIDE_LEFT"] = "Left of menu",
    ["ESCPANEL_SIDE_RIGHT"] = "Right of menu",
    ["ESCPANEL_LAYOUT_DESC"] = "When both are on the same side, portals sit on the outside (farther from the menu) and panels sit next to the menu.",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "Portal icon size",
})
