local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["COPYTEXT_TITLE"] = "Copia testo",
    ["COPYTEXT_DESC"] = "Copia il testo visibile dalle descrizioni o dagli elementi dell'interfaccia negli appunti. Usa /1wcopytext (o /1wct) per copiare ciò che si trova sotto il cursore.",
    ["COPYTEXT_TOGGLE_TOOLTIPS"] = "Modalità descrizione",
    ["COPYTEXT_TOGGLE_TOOLTIPS_DESC"] = "Durante la copia, cattura il testo da tutte le descrizioni visibili sotto il cursore.",
    ["COPYTEXT_TOGGLE_ANYTHING"] = "Modalità tutto",
    ["COPYTEXT_TOGGLE_ANYTHING_DESC"] = "Durante la copia, cattura il testo da qualsiasi elemento dell'interfaccia visibile sotto il cursore, non solo dalle descrizioni.",
    ["COPYTEXT_TOGGLE_FAST"] = "Copia veloce",
    ["COPYTEXT_TOGGLE_FAST_DESC"] = "Seleziona automaticamente tutto il testo nella finestra di copia così puoi copiarlo all'istante senza dover cliccare.",
    ["COPYTEXT_NO_TEXT"] = "Nessun testo trovato sotto il cursore.",
    ["COPYTEXT_TOOLTIP_CONTENT"] = "Contenuto della descrizione",
    ["COPYTEXT_UI_CONTENT"] = "Testo dell'interfaccia",
})
