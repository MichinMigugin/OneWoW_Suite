local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["PLAYMOUNTS_TITLE"] = "Cavalcature dei giocatori",
    ["PLAYMOUNTS_DESC"] = "Rileva e mostra la cavalcatura o la forma di movimento attualmente usata da altri giocatori.",
    ["PLAYMOUNTS_TOGGLE_CHAT"] = "Annuncia in chat",
    ["PLAYMOUNTS_TOGGLE_CHAT_DESC"] = "Stampa il nome della cavalcatura nella tua finestra di chat quando selezioni un giocatore in sella.",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT"] = "Abbina cavalcatura",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT_DESC"] = "Aggiunge un'opzione col clic destro sui giocatori per evocare una cavalcatura dello stesso tipo che stanno usando.",
    ["PLAYMOUNTS_COLLECTED"] = "(Ottenuta)",
    ["PLAYMOUNTS_NOT_COLLECTED"] = "(Non ottenuta)",
    ["PLAYMOUNTS_USING"] = "%s sta usando %s",
    ["PLAYMOUNTS_SOURCE"] = "Fonte: %s",
    ["PLAYMOUNTS_DISPLAYMODE_DESC"] = "Controlla quante informazioni sulla cavalcatura vengono mostrate nelle descrizioni e nell'output della chat.",
    ["PLAYMOUNTS_MODE_NAME"] = "Nome",
    ["PLAYMOUNTS_MODE_NAMETYPE"] = "Nome + tipo",
    ["PLAYMOUNTS_MODE_ALL"] = "Dettagli completi",
    ["PLAYMOUNTS_TOOLTIP_HEADER"] = "Integrazione descrizioni",
    ["PLAYMOUNTS_TOOLTIP_REQUIRES"] = "Richiede: OneWoW Core",
    ["PLAYMOUNTS_TOOLTIP_DETECTED"] = "Stato: rilevato",
    ["PLAYMOUNTS_TOOLTIP_NOT_DETECTED"] = "Stato: non rilevato",
    ["PLAYMOUNTS_TOOLTIP_NOTE"] = "Attiva o disattiva le righe sul tooltip della cavalcatura in QoL → Tooltip → Cavalcature dei giocatori.",
    ["PLAYMOUNTS_TOOLTIP_VIEW_BTN"] = "Mostra impostazioni",
})
