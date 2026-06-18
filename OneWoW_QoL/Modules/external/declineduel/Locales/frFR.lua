local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["DECLINEDUEL_TITLE"] = "Refuser auto les duels",
    ["DECLINEDUEL_DESC"] = "Refuse automatiquement les demandes de duel pour que la fenêtre ne reste jamais affichée à l'écran.",
    ["DECLINEDUEL_TOGGLE_PET"] = "Refuser aussi les duels de mascottes",
    ["DECLINEDUEL_TOGGLE_PET_DESC"] = "Refuse aussi automatiquement les demandes de duel de combat de mascottes.",
})
