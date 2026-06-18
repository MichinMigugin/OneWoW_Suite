local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["AUTODELETE_TITLE"] = "Eliminazione automatica",
    ["AUTODELETE_DESC"] = "Evita di digitare ELIMINA quando distruggi oggetti. Il pulsante di conferma diventa subito disponibile senza che tu debba digitare nulla.",
    ["AUTODELETE_TOGGLE_SKIP"] = "Salta la conferma digitata",
    ["AUTODELETE_TOGGLE_SKIP_DESC"] = "Attiva automaticamente il pulsante Elimina senza richiederti di digitare ELIMINA.",
    ["AUTODELETE_TOGGLE_LINK"] = "Mostra link dell'oggetto",
    ["AUTODELETE_TOGGLE_LINK_DESC"] = "Mostra il link dell'oggetto nel pop-up di conferma così puoi vedere cosa stai per eliminare.",
})
