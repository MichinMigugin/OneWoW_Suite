local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["AUTODELETE_TITLE"] = "Borrado automático",
    ["AUTODELETE_DESC"] = "Evita teclear BORRAR al destruir objetos. El botón de confirmación queda disponible de inmediato sin que tengas que teclear nada.",
    ["AUTODELETE_TOGGLE_SKIP"] = "Omitir confirmación tecleada",
    ["AUTODELETE_TOGGLE_SKIP_DESC"] = "Activa automáticamente el botón Borrar sin obligarte a teclear BORRAR.",
    ["AUTODELETE_TOGGLE_LINK"] = "Mostrar enlace del objeto",
    ["AUTODELETE_TOGGLE_LINK_DESC"] = "Muestra el enlace del objeto en la ventana de confirmación para que veas lo que estás a punto de borrar.",
})
