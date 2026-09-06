local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["ESCPANEL_TITLE"] = "Panel del menú ESC",
    ["ESCPANEL_DESC"] = "Muestra una ficha de personaje, las colecciones y notas de este lugar, y una tira de portales junto al menu ESC. La ficha muestra el correo, la durabilidad, la Gran camara y el Puesto comercial, con Proyectos opcionales. La ficha del lugar tiene iconos de Alerta de objeto para Shopping List, notas, Trackers y Farming. Pasa el cursor para ver detalles; haz clic en un icono encendido para abrirlo. Haz clic en ella para abrir la ventana de personaje, o en la ficha del lugar para abrir esa zona en el Catalogo. Elige abajo que lado usa cada uno.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Mostrar info del personaje",
    ["ESCPANEL_TOGGLE_ENDEAVORS"] = "Mostrar Proyectos",
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
