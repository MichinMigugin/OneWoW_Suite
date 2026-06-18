local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["AUTOREPAIR_TITLE"] = "Réparation auto",
    ["AUTOREPAIR_DESC"] = "Répare automatiquement tout votre équipement lorsque vous visitez un marchand qui propose des réparations. Affiche le coût dans le chat.",
    ["AUTOREPAIR_TOGGLE_GUILD"] = "Utiliser la réparation par la banque de guilde",
    ["AUTOREPAIR_TOGGLE_GUILD_DESC"] = "Tente d'utiliser la banque de guilde pour les coûts de réparation avant d'utiliser votre propre or.",
})
