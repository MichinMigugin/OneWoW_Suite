local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["ESCPANEL_TITLE"] = "Panel del menú ESC",
    ["ESCPANEL_DESC"] = "Muestra info del personaje, alertas, notas de zona y una tira de portales junto al menú ESC. Elige abajo qué lado usa cada uno.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Mostrar info del personaje",
    ["ESCPANEL_TOGGLE_ALERTS"] = "Mostrar alertas",
    ["ESCPANEL_TOGGLE_ZONE_NOTES"] = "Mostrar notas de zona",
    ["ESCPANEL_TOGGLE_HIDE_ZONE_EMPTY"] = "Ocultar notas de zona si están vacías",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "Mostrar portales",
    ["ESCPANEL_LAYOUT_HEADER"] = "Disposición",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "Lado de los paneles de info",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "Lado de los portales",
    ["ESCPANEL_SIDE_LEFT"] = "A la izquierda del menú",
    ["ESCPANEL_SIDE_RIGHT"] = "A la derecha del menú",
    ["ESCPANEL_LAYOUT_DESC"] = "Cuando ambos están en el mismo lado, los portales se sitúan en el exterior (más lejos del menú) y los paneles junto al menú.",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "Tamaño de los iconos de portal",
})
