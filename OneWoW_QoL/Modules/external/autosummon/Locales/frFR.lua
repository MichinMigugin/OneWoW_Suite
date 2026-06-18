local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["AUTOSUMMON_TITLE"] = "Accepter auto les invocations",
    ["AUTOSUMMON_DESC"] = "Accepte automatiquement les demandes d'invocation des démonistes et des pierres d'invocation.",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT"] = "Ignorer en combat",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT_DESC"] = "Ne pas accepter automatiquement pendant que vous êtes en combat. Recommandé activé pour ne pas être emmené au milieu d'un combat.",
})
