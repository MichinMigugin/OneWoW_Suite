local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["PLAYMOUNTS_TITLE"] = "Monturas de jugadores",
    ["PLAYMOUNTS_DESC"] = "Detecta y muestra la montura o forma de desplazamiento que otros jugadores están usando actualmente.",
    ["PLAYMOUNTS_TOGGLE_CHAT"] = "Anunciar en el chat",
    ["PLAYMOUNTS_TOGGLE_CHAT_DESC"] = "Muestra el nombre de la montura en tu ventana de chat cuando seleccionas a un jugador montado.",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT"] = "Igualar montura",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT_DESC"] = "Añade una opción de clic derecho sobre los jugadores para invocar una montura del mismo tipo que la que están usando.",
    ["PLAYMOUNTS_COLLECTED"] = "(Conseguida)",
    ["PLAYMOUNTS_NOT_COLLECTED"] = "(No conseguida)",
    ["PLAYMOUNTS_USING"] = "%s está usando %s",
    ["PLAYMOUNTS_SOURCE"] = "Fuente: %s",
    ["PLAYMOUNTS_DISPLAYMODE_DESC"] = "Controla cuánta información de montura se muestra en la información y en la salida del chat.",
    ["PLAYMOUNTS_MODE_NAME"] = "Nombre",
    ["PLAYMOUNTS_MODE_NAMETYPE"] = "Nombre + tipo",
    ["PLAYMOUNTS_MODE_ALL"] = "Detalles completos",
    ["PLAYMOUNTS_TOOLTIP_HEADER"] = "Integración de información",
    ["PLAYMOUNTS_TOOLTIP_REQUIRES"] = "Requiere: OneWoW Core",
    ["PLAYMOUNTS_TOOLTIP_DETECTED"] = "Estado: detectado",
    ["PLAYMOUNTS_TOOLTIP_NOT_DETECTED"] = "Estado: no detectado",
    ["PLAYMOUNTS_TOOLTIP_NOTE"] = "Activa o desactiva las líneas de montura en los tooltips en QoL → Tooltips → Monturas de jugadores.",
    ["PLAYMOUNTS_TOOLTIP_VIEW_BTN"] = "Ver ajustes",
})
