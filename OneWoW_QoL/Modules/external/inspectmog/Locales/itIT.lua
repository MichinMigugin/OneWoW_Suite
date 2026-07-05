local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["INSPECTMOG_TITLE"] = "Ispeziona equipaggiamento",
    ["INSPECTMOG_DESC"] = "Aggiunge un pannello laterale alla finestra di ispezione che elenca l'equipaggiamento indossato dal giocatore che stai ispezionando. Salva l'intera lista in una nota giocatore di OneWoW Notes, oppure Maiusc-clicca un oggetto per aggiungerlo alle tue note oggetti.",

    ["INSPECTMOG_ADD_NOTE"] = "Aggiungi alla nota del giocatore",
    ["INSPECTMOG_ADD_ALL"] = "Aggiungi tutto",
    ["INSPECTMOG_EMPTY"] = "Ancora nessun equipaggiamento ispezionabile.",
    ["INSPECTMOG_PANEL_TITLE"] = "Strumento di ispezione transmog",
    ["INSPECTMOG_NO_DATA"] = "Nessun dato di ispezione disponibile.",
    ["INSPECTMOG_UNKNOWN_PLAYER"] = "Giocatore ispezionato",
    ["INSPECTMOG_NATIVE_APPEARANCE"] = "Aspetto originale",
    ["INSPECTMOG_SOURCE_FORMAT"] = "Fonte #%d",
    ["INSPECTMOG_APPEARANCE_SOURCE_FORMAT"] = "Fonte dell'aspetto: %d",

    ["INSPECTMOG_TT_PREVIEW"] = "Ctrl-clic per l'anteprima nel camerino",
    ["INSPECTMOG_TT_NOTES"] = "Maiusc-clic per aggiungere a Notes > Oggetti",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED"] = "Maiusc-clic per aggiungere l'oggetto equipaggiato a Notes > Oggetti",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED_COLL"] = "Maiusc-clic per aggiungere l'aspetto di questo oggetto a Notes > Oggetti da collezione",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE"] = "Maiusc-clic per aggiungere l'aspetto transmog a Notes > Oggetti",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE_COLL"] = "Maiusc-clic per aggiungere l'aspetto transmog a Notes > Oggetti da collezione",
    ["INSPECTMOG_ROUTE_COLLECTIBLES"] = "Aggiungi aspetti agli Oggetti da collezione",
    ["INSPECTMOG_TT_PREVIEW_EQUIPPED"] = "Ctrl-clic per l'anteprima dell'oggetto equipaggiato",
    ["INSPECTMOG_TT_PREVIEW_APPEARANCE"] = "Ctrl-clic per l'anteprima dell'aspetto transmog",
    ["INSPECTMOG_TT_HIDDEN_APPEARANCE"] = "Gli aspetti nascosti non vengono aggiunti alle note oggetti",
    ["INSPECTMOG_TT_ADD_ALL_TITLE"] = "Aggiungi tutto il transmog",
    ["INSPECTMOG_TT_ADD_ALL_DESC"] = "Aggiunge tutti gli oggetti aspetto transmog visibili a Notes > Oggetti.",

    ["INSPECTMOG_TT_ADD_NOTE_TITLE"] = "Salva equipaggiamento nella nota del giocatore",
    ["INSPECTMOG_TT_ADD_NOTE_DESC"] = "Scrive ogni slot e oggetto elencato nella nota di questo giocatore in OneWoW Notes. Salvare di nuovo aggiorna il blocco dell'equipaggiamento e mantiene il resto della nota.",

    ["INSPECTMOG_NOTE_HEADER"] = "[OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_FOOTER"] = "[/OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_UPDATED"] = "Ispezionato: %s",
    ["INSPECTMOG_NOTE_LINE"] = "%s - %s",

    ["INSPECTMOG_ITEM_STAMP"] = "TMOG ispezionato il %s - %s",

    ["INSPECTMOG_STATUS_NOTE_SAVED"] = "Equipaggiamento salvato nella nota di %s.",
    ["INSPECTMOG_STATUS_NOTE_UPDATED"] = "Equipaggiamento aggiornato nella nota di %s.",
    ["INSPECTMOG_STATUS_ITEM_ADDED"] = "%s aggiunto alle note oggetti.",
    ["INSPECTMOG_STATUS_NOTES_MISSING"] = "OneWoW Notes non è installato.",
    ["INSPECTMOG_STATUS_NO_DATA"] = "Ancora nessun dato di equipaggiamento disponibile.",
})
