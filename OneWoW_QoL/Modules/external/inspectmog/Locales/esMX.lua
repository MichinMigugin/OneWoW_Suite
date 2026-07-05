local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["INSPECTMOG_TITLE"] = "Inspeccionar equipo",
    ["INSPECTMOG_DESC"] = "Añade un panel lateral a la ventana de inspección que lista el equipo puesto del jugador que estás inspeccionando. Guarda toda la lista en una nota de jugador de OneWoW Notes, o Mayús-clic en cualquier objeto para añadirlo a tus notas de objetos.",

    ["INSPECTMOG_ADD_NOTE"] = "Añadir a la nota del jugador",
    ["INSPECTMOG_ADD_ALL"] = "Añadir todo",
    ["INSPECTMOG_EMPTY"] = "Aún no hay equipo inspeccionable.",
    ["INSPECTMOG_PANEL_TITLE"] = "Herramienta de inspección de transfig.",
    ["INSPECTMOG_NO_DATA"] = "No hay datos de inspección disponibles.",
    ["INSPECTMOG_UNKNOWN_PLAYER"] = "Jugador inspeccionado",
    ["INSPECTMOG_NATIVE_APPEARANCE"] = "Apariencia original",
    ["INSPECTMOG_SOURCE_FORMAT"] = "Fuente #%d",
    ["INSPECTMOG_APPEARANCE_SOURCE_FORMAT"] = "Fuente de apariencia: %d",

    ["INSPECTMOG_TT_PREVIEW"] = "Ctrl-clic para previsualizar en el probador",
    ["INSPECTMOG_TT_NOTES"] = "Mayús-clic para añadir a Notes > Objetos",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED"] = "Mayús-clic para añadir el objeto puesto a Notes > Objetos",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED_COLL"] = "Mayús-clic para añadir la apariencia de este objeto a Notes > Coleccionables",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE"] = "Mayús-clic para añadir la apariencia de transfiguración a Notes > Objetos",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE_COLL"] = "Mayús-clic para añadir la apariencia de transfiguración a Notes > Coleccionables",
    ["INSPECTMOG_ROUTE_COLLECTIBLES"] = "Añadir apariencias a Coleccionables",
    ["INSPECTMOG_TT_PREVIEW_EQUIPPED"] = "Ctrl-clic para previsualizar el objeto puesto",
    ["INSPECTMOG_TT_PREVIEW_APPEARANCE"] = "Ctrl-clic para previsualizar la apariencia de transfiguración",
    ["INSPECTMOG_TT_HIDDEN_APPEARANCE"] = "Las apariencias ocultas no se añaden a las notas de objetos",
    ["INSPECTMOG_TT_ADD_ALL_TITLE"] = "Añadir toda la transfiguración",
    ["INSPECTMOG_TT_ADD_ALL_DESC"] = "Añade todos los objetos de apariencia de transfiguración visibles a Notes > Objetos.",

    ["INSPECTMOG_TT_ADD_NOTE_TITLE"] = "Guardar equipo en la nota del jugador",
    ["INSPECTMOG_TT_ADD_NOTE_DESC"] = "Escribe cada ranura y objeto listado en la nota de este jugador en OneWoW Notes. Volver a guardar actualiza el bloque de equipo y conserva el resto de la nota.",

    ["INSPECTMOG_NOTE_HEADER"] = "[OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_FOOTER"] = "[/OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_UPDATED"] = "Inspeccionado: %s",
    ["INSPECTMOG_NOTE_LINE"] = "%s - %s",

    ["INSPECTMOG_ITEM_STAMP"] = "TMOG inspeccionado el %s - %s",

    ["INSPECTMOG_STATUS_NOTE_SAVED"] = "Equipo guardado en la nota de %s.",
    ["INSPECTMOG_STATUS_NOTE_UPDATED"] = "Equipo actualizado en la nota de %s.",
    ["INSPECTMOG_STATUS_ITEM_ADDED"] = "%s añadido a las notas de objetos.",
    ["INSPECTMOG_STATUS_NOTES_MISSING"] = "OneWoW Notes no está instalado.",
    ["INSPECTMOG_STATUS_NO_DATA"] = "Aún no hay datos de equipo disponibles.",
})
