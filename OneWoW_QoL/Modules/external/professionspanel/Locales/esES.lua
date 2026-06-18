local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["PROFPANEL_TITLE"] = "Panel de profesiones",
    ["PROFPANEL_DESC"] = "Muestra un panel complementario junto a la ventana de profesión con desgloses de habilidad por expansión, recuentos de recetas y seguimiento de primera fabricación.",
    ["PROFPANEL_AUTO_SHOW"] = "Mostrar panel automáticamente",
    ["PROFPANEL_TOGGLE_TIP"] = "Panel de estadísticas de profesión",
    ["PROFPANEL_HIDE_TIP"] = "Haz clic para ocultar el panel",
    ["PROFPANEL_SHOW_TIP"] = "Haz clic para mostrar el panel",
    ["PROFPANEL_STATS_TITLE"] = "Panel de profesiones",
    ["PROFPANEL_NO_EXPANSION_DATA"] = "No hay datos de expansión disponibles.\nAbre una profesión para escanear.",
    ["PROFPANEL_NO_ALT_DATA"] = "No se encontraron otros alters con esta profesión",
    ["PROFPANEL_OTHER_ALTS"] = "Otros alters con esta profesión",
    ["PROFPANEL_LAST_SCANNED"] = "Último escaneo: %s",
})
