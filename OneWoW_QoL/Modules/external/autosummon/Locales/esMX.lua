local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["AUTOSUMMON_TITLE"] = "Aceptar auto. invocación",
    ["AUTOSUMMON_DESC"] = "Acepta automáticamente las solicitudes de invocación de brujos y piedras de invocación.",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT"] = "Omitir en combate",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT_DESC"] = "No aceptar automáticamente mientras estás en combate. Recomendado activado para que no te saquen a mitad de la pelea.",
})
