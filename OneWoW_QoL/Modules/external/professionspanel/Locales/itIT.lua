local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["PROFPANEL_TITLE"] = "Pannello professioni",
    ["PROFPANEL_DESC"] = "Mostra un pannello complementare accanto alla finestra della professione con suddivisione delle abilità per espansione, conteggio delle ricette e tracciamento della prima creazione.",
    ["PROFPANEL_AUTO_SHOW"] = "Mostra pannello automaticamente",
    ["PROFPANEL_TOGGLE_TIP"] = "Pannello statistiche professione",
    ["PROFPANEL_HIDE_TIP"] = "Clicca per nascondere il pannello",
    ["PROFPANEL_SHOW_TIP"] = "Clicca per mostrare il pannello",
    ["PROFPANEL_STATS_TITLE"] = "Pannello professioni",
    ["PROFPANEL_NO_EXPANSION_DATA"] = "Nessun dato di espansione disponibile.\nApri una professione per eseguire la scansione.",
    ["PROFPANEL_NO_ALT_DATA"] = "Nessun altro alt trovato con questa professione",
    ["PROFPANEL_OTHER_ALTS"] = "Altri alt con questa professione",
    ["PROFPANEL_LAST_SCANNED"] = "Ultima scansione: %s",
})
