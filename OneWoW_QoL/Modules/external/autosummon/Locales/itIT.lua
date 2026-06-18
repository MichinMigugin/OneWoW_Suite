local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["AUTOSUMMON_TITLE"] = "Accetta auto. evocazione",
    ["AUTOSUMMON_DESC"] = "Accetta automaticamente le richieste di evocazione da stregoni e pietre dell'evocazione.",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT"] = "Salta in combattimento",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT_DESC"] = "Non accettare automaticamente mentre sei in combattimento. Consigliato attivo così non vieni trascinato via durante uno scontro.",
})
