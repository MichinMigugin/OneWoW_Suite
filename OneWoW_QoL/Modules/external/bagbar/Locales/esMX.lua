local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["BAGBAR_TITLE"] = "Barra de bolsa",
    ["BAGBAR_DESC"] = "Muestra objetos usables de la bolsa en una barra movible. Los objetos se eligen con una expresión de palabras clave (igual que la búsqueda de bolsa). El equipo equipable y los objetos de misión siempre se excluyen de la barra (se aplica automáticamente, no se muestra en el editor).",
    ["BAGBAR_LOCK_POSITION"] = "Bloquear posición",
    ["BAGBAR_MAX_BUTTONS"] = "Botones máximos",
    ["BAGBAR_SHIFT_RIGHT_CLICK_TO_SKIP"] = "Mayús+clic derecho para omitir esta sesión",
    ["BAGBAR_ALT_RIGHT_CLICK_TO_BLACKLIST"] = "Alt+clic derecho para añadir a la lista negra permanentemente",
    ["BAGBAR_MANUAL_ITEMS_HEADER"] = "Objetos manuales",
    ["BAGBAR_MANUAL_DESC"] = "Fija objetos específicos para darles mayor prioridad en la barra. Aún deben coincidir con tu filtro de expresión y las reglas de usabilidad de la barra.",
    ["BAGBAR_MACROS_HEADER"] = "Macros manuales",
    ["BAGBAR_MACROS_DESC"] = "Añade tus macros a la barra como botones personalizados. Arrastra una macro desde la ventana de macros al área de soltar, o escribe un nombre de macro y haz clic en Añadir. Las macros aparecen antes que los objetos de bolsa.",
    ["BAGBAR_MACRO_NAME_LABEL"] = "Nombre de macro:",
    ["BAGBAR_DRAG_MACRO_HERE"] = "Arrastra la macro aquí",
    ["BAGBAR_MACRO_LEFT_CLICK_TO_RUN"] = "Clic izquierdo para ejecutar la macro",
    ["BAGBAR_MACRO_MISSING"] = "(falta)",
    ["BAGBAR_BLACKLIST_DESC"] = "Mayús+clic derecho en los objetos de la barra para omitirlos esta sesión. Alt+clic derecho para añadirlos a la lista negra permanentemente.",
    ["BAGBAR_COLUMNS"] = "Columnas",
    ["BAGBAR_CONTEXT_LOCK"] = "Bloquear posición",
    ["BAGBAR_GROW_RIGHT"] = "Derecha",
    ["BAGBAR_GROW_LEFT"] = "Izquierda",
    ["BAGBAR_EXPRESSION_FILTER_HEADER"] = "Filtro de expresión",
    ["BAGBAR_EXPRESSION_FILTER_DESC"] = "Expresión de palabras clave que determina qué objetos de bolsa aparecen (mismas palabras clave que la búsqueda de bolsa). Haz clic en ? para ayuda. El equipo equipable y los objetos de misión se excluyen automáticamente de esta expresión.",
    ["BAGBAR_EXPRESSION_FILTER_PLACEHOLDER"] = "p. ej. #usable & #mount",
})
