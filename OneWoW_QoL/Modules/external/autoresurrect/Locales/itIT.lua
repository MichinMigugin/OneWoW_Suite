local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["AUTORESURRECT_TITLE"] = "Accetta auto. resurrezione",
    ["AUTORESURRECT_DESC"] = "Accetta automaticamente le richieste di resurrezione quando qualcuno lancia una resurrezione su di te. Saltato mentre sei in combattimento.",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE"] = "Non accettare nelle istanze",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE_DESC"] = "Salta l'auto-accettazione mentre sei in una spedizione, incursione, campo di battaglia o arena. Utile se vuoi aspettare il momento giusto per risorgere.",
})
