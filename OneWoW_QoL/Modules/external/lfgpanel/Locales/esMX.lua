local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["LFGPANEL_TITLE"] = "Bloqueos de BdG",
    ["LFGPANEL_DESC"] = "Muestra tus bloqueos actuales de banda y mazmorra en un panel lateral cuando el Buscador de grupo está abierto.",
    ["LFGPANEL_SHOW_PANEL"] = "Mostrar panel de bloqueos",
    ["LFGPANEL_SHOW_PANEL_DESC"] = "Muestra el panel de bloqueos cuando se abre el Buscador de grupo.",
    ["LFGPANEL_FILTER_RESULTS"] = "Filtrar resultados de BdG",
    ["LFGPANEL_FILTER_RESULTS_DESC"] = "Filtra los resultados de búsqueda de BdG por la dificultad seleccionada.",

    ["LFGPANEL_TT_REFRESH"] = "Actualizar bloqueos",
    ["LFGPANEL_TT_REFRESH_DESC"] = "Solicita los datos de bloqueo más recientes al servidor.",
    ["LFGPANEL_TT_TOGGLE"] = "Mostrar panel de bloqueos",
    ["LFGPANEL_TT_TOGGLE_DESC"] = "Haz clic para mostrar el panel de bloqueos.",

    ["LFGPANEL_FILTER_DIFFICULTY"] = "Dificultad",
    ["LFGPANEL_DIFFICULTY_NORMAL"] = "Normal",
    ["LFGPANEL_DIFFICULTY_HEROIC"] = "Heroico",
    ["LFGPANEL_DIFFICULTY_MYTHIC"] = "Mítico",
    ["LFGPANEL_DIFFICULTY_MYTHICPLUS"] = "Mítico+",
    ["LFGPANEL_DIFFICULTY_LFR"] = "LFR",

    ["LFGPANEL_NO_LOCKOUTS"] = "No hay bloqueos activos.",
    ["LFGPANEL_NO_LOCKOUTS_FILTERED"] = "Ningún bloqueo coincide con la dificultad seleccionada.",
    ["LFGPANEL_EXPIRED"] = "Caducado",
    ["LFGPANEL_EXTENDED"] = "Ampliado",
    ["LFGPANEL_TT_EXTENDED"] = "Bloqueo ampliado",
    ["LFGPANEL_TT_EXTENDED_DESC"] = "Este bloqueo se ha ampliado manualmente más allá de su reinicio normal.",

    ["LFGPANEL_TIME_DAYS"] = "%dd %dh",
    ["LFGPANEL_TIME_HOURS"] = "%dh %dm",
    ["LFGPANEL_TIME_MINUTES"] = "%dm",
    ["LFGPANEL_PROGRESS"] = "%d/%d",

    ["LFGPANEL_TT_LOCKOUT"] = "Bloqueo de instancia",
    ["LFGPANEL_TT_LOCKOUT_PROGRESS"] = "Progreso de jefes: %d/%d",
    ["LFGPANEL_TT_LOCKOUT_TIME"] = "Se reinicia en: %s",
    ["LFGPANEL_TT_LOCKOUT_DIFFICULTY"] = "Dificultad: %s",

    ["LFGPANEL_OPT_FILTER_LFG"] = "Filtrar resultados de BdG",
    ["LFGPANEL_TT_FILTER_LFG"] = "Filtrar resultados de BdG",
    ["LFGPANEL_TT_FILTER_LFG_DESC"] = "Cuando está activado, los resultados de búsqueda de BdG se filtrarán según la dificultad seleccionada.",
})
