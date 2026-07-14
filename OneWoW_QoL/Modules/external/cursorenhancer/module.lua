local ADDON_NAME, ns = ...

ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "cursorenhancer",
    title       = "CURSORENHANCER_TITLE",
    category    = "INTERFACE",
    description = "CURSORENHANCER_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {
        { id = "outer_ring",    label = "CURSORENHANCER_OUTER_RING",    default = true,  group = "CURSORENHANCER_MARKER_TOGGLES" },
        { id = "middle_ring",   label = "CURSORENHANCER_MIDDLE_RING",   default = false, group = "CURSORENHANCER_MARKER_TOGGLES" },
        { id = "center_marker", label = "CURSORENHANCER_CENTER_MARKER", default = true,  group = "CURSORENHANCER_MARKER_TOGGLES" },
        { id = "mouse_trail",   label = "CURSORENHANCER_MOUSE_TRAIL",   default = false, group = "CURSORENHANCER_MARKER_TOGGLES" },
    },
    preview        = true,
    _moduleEnabled = false,
    _eventFrame    = nil,
})
