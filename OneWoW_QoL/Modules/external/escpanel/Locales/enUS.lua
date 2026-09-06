local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["ESCPANEL_TITLE"] = "ESC Menu Panel",
    ["ESCPANEL_DESC"] = "Display a character card, this place's collections and notes, and a portal strip alongside the ESC menu. The character card shows mail, durability, Great Vault, and Trading Post, with optional Housing Endeavors. The place card has Item Alert icons for Shopping List, notes, Trackers, and Farming. Hover an icon for details; click a lit icon to open it. Click the character card to open the character screen, or the place card to open that zone in Catalog. Choose which side each uses below.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Display Character Info",
    ["ESCPANEL_TOGGLE_ENDEAVORS"] = "Display Endeavors",
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
