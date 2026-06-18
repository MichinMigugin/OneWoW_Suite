local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — esES, pending native review.
OneWoW.Locale:Register(M._scope, "esES", {

    ["AUTOREADYCHECK_TITLE"] = "Aceptar auto. comprobación de preparación",
    ["AUTOREADYCHECK_DESC"] = "Confirma automáticamente que estás listo cuando se lanza una comprobación de preparación en tu grupo.",
    ["AUTOREADYCHECK_TOGGLE_DEAD"] = "Omitir si estás muerto",
    ["AUTOREADYCHECK_TOGGLE_DEAD_DESC"] = "No aceptar automáticamente si estás muerto o eres un fantasma, para que el grupo vea que no estás listo para iniciar.",
})
