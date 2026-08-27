local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT, pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["CRAFTORDERS_TITLE"] = "Ordini di creazione",
    ["CRAFTORDERS_DESC"] = "Sostituisce l'elenco ordini con Creabile ora e Materiali mancanti. Aggiungi i reagenti mancanti a una lista della spesa. Avvia, crea e completa con un solo pulsante.",
    ["CRAFTORDERS_SECTION_READY"] = "Creabile ora",
    ["CRAFTORDERS_SECTION_MISSING"] = "Materiali mancanti",
    ["CRAFTORDERS_WEEKLY_NOT_ACCEPTED"] = "Settimanale: non accettata",
    ["CRAFTORDERS_WEEKLY_NOT_LEARNED"] = "Settimanale: non appresa",
    ["CRAFTORDERS_WEEKLY_COMPLETE"] = "Settimanale: completata",
    ["CRAFTORDERS_WEEKLY_PROGRESS"] = "Settimanale: %d / %d completati",
    ["CRAFTORDERS_LOADING"] = "Caricamento ordini...",
    ["CRAFTORDERS_ADD_ACTIVE"] = "Aggiungi a %s",
    ["CRAFTORDERS_MAKE_LIST"] = "Crea lista",
    ["CRAFTORDERS_ADD_MENU_HINT"] = "Clic destro per creare una lista o sceglierne un'altra.",
    ["CRAFTORDERS_ELSEWHERE_TIP"] = "Anche in: %s",
    ["CRAFTORDERS_COL_CRAFT"] = "Ordine",
    ["CRAFTORDERS_COL_YOU"] = "Fornisci tu",
    ["CRAFTORDERS_COL_CART"] = "Lista",
    ["CRAFTORDERS_COL_CUSTOMER"] = "Fornisce il cliente",
    ["CRAFTORDERS_COL_REWARD"] = "Ricevi",
    ["CRAFTORDERS_USE_WOWUI"] = "WoW UI",
    ["CRAFTORDERS_USE_ONEUI"] = "One UI",
    ["CRAFTORDERS_TOGGLE_WOWUI"] = "Usa elenco WoW",
    ["CRAFTORDERS_TOGGLE_WOWUI_DESC"] = "Mostra la tabella ordini di Blizzard al posto di Creabile ora e Materiali mancanti.",
    ["CRAFTORDERS_BUCKET_COUNT"] = "%d ordini",
    ["CRAFTORDERS_ORDER_LIST_NAME"] = "Ordine: %s",
    ["CRAFTORDERS_NO_SHOPPING"] = "Attiva la Lista della spesa per aggiungere reagenti.",
    ["CRAFTORDERS_KP"] = "%d PC",
    ["CRAFTORDERS_ACUITY"] = "Acuita x%d",
})
