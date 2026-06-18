local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["DECLINEDUEL_TITLE"] = "Rechazar auto. duelos",
    ["DECLINEDUEL_DESC"] = "Rechaza automáticamente las solicitudes de duelo para que la ventana nunca se quede en tu pantalla.",
    ["DECLINEDUEL_TOGGLE_PET"] = "Rechazar también duelos de mascotas",
    ["DECLINEDUEL_TOGGLE_PET_DESC"] = "Rechaza también automáticamente las solicitudes de duelo de combate de mascotas.",
})
