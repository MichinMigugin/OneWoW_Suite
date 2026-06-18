local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["FASTFORWARD_TITLE"] = "Avanzamento rapido",
    ["FASTFORWARD_DESC"] = "Salta automaticamente i filmati e le scene cinematiche di gioco. Tieni premuto un tasto modificatore qualsiasi mentre un filmato o una scena inizia per guardarla invece.",
    ["FASTFORWARD_TOGGLE_MOVIES"] = "Salta filmati",
    ["FASTFORWARD_TOGGLE_MOVIES_DESC"] = "Ferma automaticamente i filmati di gioco quando iniziano la riproduzione.",
    ["FASTFORWARD_TOGGLE_CINEMATICS"] = "Salta scene cinematiche",
    ["FASTFORWARD_TOGGLE_CINEMATICS_DESC"] = "Annulla automaticamente le sequenze cinematiche di gioco quando iniziano.",
    ["FASTFORWARD_TOGGLE_INSTANCE"] = "Solo nelle istanze",
    ["FASTFORWARD_TOGGLE_INSTANCE_DESC"] = "Salta filmati e scene cinematiche solo mentre sei in una spedizione, incursione o altra istanza.",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE"] = "Rispetta le non annullabili",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE_DESC"] = "Non tenta di saltare le scene cinematiche che il gioco contrassegna come non annullabili.",
})
