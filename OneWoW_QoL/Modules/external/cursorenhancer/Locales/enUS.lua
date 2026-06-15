local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["CURSORENHANCER_TITLE"] = "Cursor Enhancer",
    ["CURSORENHANCER_DESC"] = "Displays a customizable ring around your cursor with optional mouse trail effect.",
    ["CURSORENHANCER_OUTER_RING"] = "Show Outer Ring",
    ["CURSORENHANCER_MIDDLE_RING"] = "Show Middle Ring",
    ["CURSORENHANCER_CENTER_MARKER"] = "Show Center Marker",
    ["CURSORENHANCER_SHOW_OOC"] = "Show Out of Combat",
    ["CURSORENHANCER_SHOW_INSTANCE"] = "Show Only in Instances",
    ["CURSORENHANCER_MOUSE_TRAIL"] = "Show Mouse Trail",
    ["CURSORENHANCER_MODULE_TOGGLES"] = "Module Toggles",
    ["CURSORENHANCER_MARKER_TOGGLES"] = "Marker Toggles",
    ["CURSORENHANCER_COLORS_HEADER"] = "Ring Colors",
    ["CURSORENHANCER_OUTER_RING_COLOR"] = "Outer Ring Color",
    ["CURSORENHANCER_MIDDLE_RING_COLOR"] = "Middle Ring Color",
    ["CURSORENHANCER_CENTER_MARKER_COLOR"] = "Center Marker Color",
    ["CURSORENHANCER_TRAIL_COLOR"] = "Trail Color",
})
