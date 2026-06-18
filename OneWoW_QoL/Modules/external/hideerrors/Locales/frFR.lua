local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["HIDEERRORS_TITLE"] = "Masquer le spam d'erreurs de combat",
    ["HIDEERRORS_DESC"] = "Masque les messages d'erreur rouges les plus courants (plus de mana, hors de portée, la cible doit être devant vous, sort pas prêt, etc.) pour que le centre de votre écran reste épuré pendant les combats.",
})
