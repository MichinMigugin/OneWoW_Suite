local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["QUESTTOOLS_TITLE"] = "Strumenti missione",
    ["QUESTTOOLS_DESC"] = "Automatizza l'accettazione delle missioni, la consegna, l'evidenziazione della ricompensa e il dialogo etichettato come missione opzionale. Tieni premuto Maiusc all'apertura di una finestra di missione o dialogo per saltare l'auto-accettazione o l'auto-dialogo.",
    ["QUESTTOOLS_TOGGLE_ACCEPT"] = "Accetta missioni automaticamente",
    ["QUESTTOOLS_TOGGLE_ACCEPT_DESC"] = "Accetta automaticamente le missioni quando appare la finestra della missione. Tieni premuto Maiusc all'apertura della finestra per saltare l'auto-accettazione.",
    ["QUESTTOOLS_TOGGLE_TURNIN"] = "Consegna missioni automaticamente",
    ["QUESTTOOLS_TOGGLE_TURNIN_DESC"] = "Completa e consegna automaticamente le missioni quando hai soddisfatto tutti i requisiti. Se sono disponibili più ricompense, attende la tua scelta.",
    ["QUESTTOOLS_TOGGLE_REWARDS"] = "Evidenzia la ricompensa migliore",
    ["QUESTTOOLS_TOGGLE_REWARDS_DESC"] = "Mostra un'icona a forma di moneta d'oro sull'oggetto ricompensa della missione con il valore di vendita più alto dal venditore.",
    ["QUESTTOOLS_TOGGLE_GOSSIP"] = "Auto-dialogo (righe etichettate come missione)",
    ["QUESTTOOLS_TOGGLE_GOSSIP_DESC"] = "Seleziona automaticamente le opzioni di dialogo contrassegnate come etichettate di missione (QuestLabelPrepend), cioè le stesse righe che l'interfaccia mostra con l'etichetta in stile missione. Se più di una è idonea, usa il testo visibile della riga per decidere. Tieni premuto Maiusc all'apertura del dialogo per saltare. Richiede il supporto di C_GossipInfo e QuestLabelPrepend (FlagsUtil / Enum.GossipOptionRecFlags) sul tuo client.",
})
