local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esMX (LatAm terms applied: presionar, mouse), pending native review.
OneWoW.Locale:Register(M._scope, "esMX", {

    ["AUTORESURRECT_TITLE"] = "Aceptar auto. resurrección",
    ["AUTORESURRECT_DESC"] = "Acepta automáticamente las solicitudes de resurrección cuando alguien te lanza una resurrección. Se omite mientras estás en combate.",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE"] = "No aceptar en instancias",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE_DESC"] = "Omite la auto-aceptación mientras estás dentro de una mazmorra, banda, campo de batalla o arena. Útil si quieres esperar el momento adecuado para resucitar.",
})
