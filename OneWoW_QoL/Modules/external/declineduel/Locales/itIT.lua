local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["DECLINEDUEL_TITLE"] = "Rifiuta auto. duelli",
    ["DECLINEDUEL_DESC"] = "Rifiuta automaticamente le richieste di duello così il pop-up non resta mai sullo schermo.",
    ["DECLINEDUEL_TOGGLE_PET"] = "Rifiuta anche i duelli tra mascotte",
    ["DECLINEDUEL_TOGGLE_PET_DESC"] = "Rifiuta automaticamente anche le richieste di duello di lotta tra mascotte.",
})
