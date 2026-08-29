local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["COPYTEXT_TITLE"] = "Copiar texto",
    ["COPYTEXT_DESC"] = "Copia el texto visible de la información o de los elementos de interfaz a tu portapapeles. Usa /1wcopytext (o /1wct) para copiar lo que está bajo tu cursor.",
    ["COPYTEXT_TOGGLE_TOOLTIPS"] = "Modo información",
    ["COPYTEXT_TOGGLE_TOOLTIPS_DESC"] = "Al copiar, captura el texto de cualquier información visible bajo tu cursor.",
    ["COPYTEXT_TOGGLE_ANYTHING"] = "Modo todo",
    ["COPYTEXT_TOGGLE_ANYTHING_DESC"] = "Al copiar, captura el texto de cualquier elemento de interfaz visible bajo tu cursor, no solo de la información.",
    ["COPYTEXT_TOGGLE_FAST"] = "Copia rápida",
    ["COPYTEXT_TOGGLE_FAST_DESC"] = "Selecciona automáticamente todo el texto en el diálogo de copia para que puedas copiarlo al instante sin tener que hacer clic.",
    ["COPYTEXT_NO_TEXT"] = "No se encontró texto bajo el cursor.",
    ["COPYTEXT_TOOLTIP_CONTENT"] = "Contenido de la información",
    ["COPYTEXT_UI_CONTENT"] = "Texto de interfaz",
})
