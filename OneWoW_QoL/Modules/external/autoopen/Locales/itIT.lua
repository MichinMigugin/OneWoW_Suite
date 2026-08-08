local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["AUTOOPEN_TITLE"] = "Apertura automatica",
    ["AUTOOPEN_DESC"] = "Apre automaticamente borse, scatole e altri oggetti contenitore quando appaiono nel tuo inventario. Non apre oggetti presso una banca, una cassetta postale o un mercante. Gli oggetti che non puoi ancora aprire (scrigni chiusi, livello/classe/professione errati, o mentre lo slot è occupato) vengono saltati automaticamente.",
    ["AUTOOPEN_OPENING"] = "Apertura automatica: %s",
    ["AUTOOPEN_BLACKLIST_DESC"] = "Aggiungi oggetti per impedire all'Apertura automatica di aprirli.",
    ["AUTOOPEN_BLACKLIST_REMOVED"] = "Rimosso dalla lista nera: %s",
})
