local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["AUTOREPAIR_TITLE"] = "Reparación automática",
    ["AUTOREPAIR_DESC"] = "Repara automáticamente todo tu equipo cuando visitas a un comerciante que admite reparaciones. Muestra el coste en el chat.",
    ["AUTOREPAIR_TOGGLE_GUILD"] = "Usar reparación del banco de hermandad",
    ["AUTOREPAIR_TOGGLE_GUILD_DESC"] = "Intenta usar el banco de hermandad para los costes de reparación antes de usar tu propio oro.",
})
