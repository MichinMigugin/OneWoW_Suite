local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted (Phase 4) — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["CURSORENHANCER_TITLE"] = "Cursor-Verbesserung",
    ["CURSORENHANCER_DESC"] = "Zeigt einen anpassbaren Ring um deinen Cursor mit optionalem Mausspur-Effekt an.",
    ["CURSORENHANCER_OUTER_RING"] = "Äußeren Ring anzeigen",
    ["CURSORENHANCER_MIDDLE_RING"] = "Mittleren Ring anzeigen",
    ["CURSORENHANCER_CENTER_MARKER"] = "Mittelmarkierung anzeigen",
    ["CURSORENHANCER_SHOW_OOC"] = "Außerhalb des Kampfes anzeigen",
    ["CURSORENHANCER_SHOW_INSTANCE"] = "Nur in Instanzen anzeigen",
    ["CURSORENHANCER_MOUSE_TRAIL"] = "Mausspur anzeigen",
    ["CURSORENHANCER_MODULE_TOGGLES"] = "Modulschalter",
    ["CURSORENHANCER_MARKER_TOGGLES"] = "Markierungsschalter",
    ["CURSORENHANCER_COLORS_HEADER"] = "Ringfarben",
    ["CURSORENHANCER_OUTER_RING_COLOR"] = "Farbe des äußeren Rings",
    ["CURSORENHANCER_MIDDLE_RING_COLOR"] = "Farbe des mittleren Rings",
    ["CURSORENHANCER_CENTER_MARKER_COLOR"] = "Farbe der Mittelmarkierung",
    ["CURSORENHANCER_TRAIL_COLOR"] = "Spurfarbe",
})
