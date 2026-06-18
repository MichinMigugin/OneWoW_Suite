local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["AUTOREPAIR_TITLE"] = "Riparazione automatica",
    ["AUTOREPAIR_DESC"] = "Ripara automaticamente tutto il tuo equipaggiamento quando visiti un mercante che offre riparazioni. Mostra il costo in chat.",
    ["AUTOREPAIR_TOGGLE_GUILD"] = "Usa riparazione dalla banca di gilda",
    ["AUTOREPAIR_TOGGLE_GUILD_DESC"] = "Tenta di usare la banca di gilda per i costi di riparazione prima di usare il tuo oro.",
})
