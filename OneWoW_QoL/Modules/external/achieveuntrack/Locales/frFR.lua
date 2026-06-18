local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["ACHIEVEUNTRACK_TITLE"] = "Ne plus suivre les hauts faits terminés",
    ["ACHIEVEUNTRACK_DESC"] = "Recherche et arrête automatiquement le suivi des hauts faits déjà terminés à la connexion. Libère des emplacements de suivi cachés qui peuvent rester bloqués après un plantage ou un achèvement inter-personnages.",
})
