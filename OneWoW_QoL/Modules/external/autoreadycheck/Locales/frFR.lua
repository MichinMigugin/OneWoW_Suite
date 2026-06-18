local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["AUTOREADYCHECK_TITLE"] = "Accepter auto la vérification de préparation",
    ["AUTOREADYCHECK_DESC"] = "Confirme automatiquement que vous êtes prêt lorsqu'une vérification de préparation est lancée dans votre groupe.",
    ["AUTOREADYCHECK_TOGGLE_DEAD"] = "Ignorer si mort",
    ["AUTOREADYCHECK_TOGGLE_DEAD_DESC"] = "Ne pas accepter automatiquement si vous êtes mort ou fantôme, pour que le groupe voie que vous n'êtes pas prêt à engager.",
})
