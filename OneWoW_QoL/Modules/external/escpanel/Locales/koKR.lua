local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "koKR", {

    ["ESCPANEL_TITLE"] = "TEST",
    ["ESCPANEL_DESC"] = "TEST",
    ["ESCPANEL_TOGGLE_ENABLED"] = "TEST",
    ["ESCPANEL_TOGGLE_ZONE_NOTES"] = "TEST",
    ["ESCPANEL_TOGGLE_HIDE_ZONE_EMPTY"] = "TEST",
    ["ESCPANEL_TOGGLE_ALERTS"] = "TEST",
    ["ESCPANEL_LAYOUT_HEADER"] = "Layout",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "Info panels side",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "Portals side",
    ["ESCPANEL_SIDE_LEFT"] = "Left of menu",
    ["ESCPANEL_SIDE_RIGHT"] = "Right of menu",
    ["ESCPANEL_LAYOUT_DESC"] = "When both are on the same side, portals sit on the outside (farther from the menu) and panels sit next to the menu.",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "Portal icon size",
})
