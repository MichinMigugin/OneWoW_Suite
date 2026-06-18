local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["HIDEERRORS_TITLE"] = "Ocultar spam de errores de combate",
    ["HIDEERRORS_DESC"] = "Oculta los mensajes de error rojos más comunes (sin maná, fuera de alcance, el objetivo debe estar delante, hechizo no listo, etc.) para que el centro de tu pantalla se mantenga limpio durante las peleas.",
})
