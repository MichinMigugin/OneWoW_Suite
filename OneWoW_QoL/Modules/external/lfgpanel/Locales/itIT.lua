local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["LFGPANEL_TITLE"] = "Blocchi CdG",
    ["LFGPANEL_DESC"] = "Mostra i tuoi blocchi attuali di incursione e spedizione in un pannello laterale quando lo Strumento Cerca Gruppo è aperto.",
    ["LFGPANEL_SHOW_PANEL"] = "Mostra pannello dei blocchi",
    ["LFGPANEL_SHOW_PANEL_DESC"] = "Mostra il pannello dei blocchi quando si apre lo Strumento Cerca Gruppo.",
    ["LFGPANEL_FILTER_RESULTS"] = "Filtra risultati CdG",
    ["LFGPANEL_FILTER_RESULTS_DESC"] = "Filtra i risultati di ricerca CdG in base alla difficoltà selezionata.",

    ["LFGPANEL_TT_REFRESH"] = "Aggiorna blocchi",
    ["LFGPANEL_TT_REFRESH_DESC"] = "Richiede al server i dati di blocco più recenti.",
    ["LFGPANEL_TT_TOGGLE"] = "Mostra pannello dei blocchi",
    ["LFGPANEL_TT_TOGGLE_DESC"] = "Clicca per mostrare il pannello dei blocchi.",

    ["LFGPANEL_FILTER_DIFFICULTY"] = "Difficoltà",
    ["LFGPANEL_DIFFICULTY_NORMAL"] = "Normale",
    ["LFGPANEL_DIFFICULTY_HEROIC"] = "Eroica",
    ["LFGPANEL_DIFFICULTY_MYTHIC"] = "Mitica",
    ["LFGPANEL_DIFFICULTY_MYTHICPLUS"] = "Mitica+",
    ["LFGPANEL_DIFFICULTY_LFR"] = "LFR",

    ["LFGPANEL_NO_LOCKOUTS"] = "Nessun blocco attivo.",
    ["LFGPANEL_NO_LOCKOUTS_FILTERED"] = "Nessun blocco corrisponde alla difficoltà selezionata.",
    ["LFGPANEL_EXPIRED"] = "Scaduto",
    ["LFGPANEL_EXTENDED"] = "Esteso",
    ["LFGPANEL_TT_EXTENDED"] = "Blocco esteso",
    ["LFGPANEL_TT_EXTENDED_DESC"] = "Questo blocco è stato esteso manualmente oltre il suo normale azzeramento.",

    ["LFGPANEL_TIME_DAYS"] = "%dd %dh",
    ["LFGPANEL_TIME_HOURS"] = "%dh %dm",
    ["LFGPANEL_TIME_MINUTES"] = "%dm",
    ["LFGPANEL_PROGRESS"] = "%d/%d",

    ["LFGPANEL_TT_LOCKOUT"] = "Blocco dell'istanza",
    ["LFGPANEL_TT_LOCKOUT_PROGRESS"] = "Progresso boss: %d/%d",
    ["LFGPANEL_TT_LOCKOUT_TIME"] = "Si azzera tra: %s",
    ["LFGPANEL_TT_LOCKOUT_DIFFICULTY"] = "Difficoltà: %s",

    ["LFGPANEL_OPT_FILTER_LFG"] = "Filtra risultati CdG",
    ["LFGPANEL_TT_FILTER_LFG"] = "Filtra risultati CdG",
    ["LFGPANEL_TT_FILTER_LFG_DESC"] = "Quando attivo, i risultati di ricerca CdG verranno filtrati in base alla difficoltà selezionata.",
})
