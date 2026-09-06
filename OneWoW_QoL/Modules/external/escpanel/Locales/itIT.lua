local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["ESCPANEL_TITLE"] = "Pannello menu ESC",
    ["ESCPANEL_DESC"] = "Mostra una scheda personaggio, le collezioni e le note di questo luogo e una striscia di portali accanto al menu ESC. La scheda mostra la posta, l'Integrita, la Gran Banca e l'Emporio, con Iniziative opzionali. La scheda del luogo ha icone Avviso oggetto per Shopping List, note, Trackers e Farming. Passa il mouse per i dettagli; clicca un'icona accesa per aprirla. Cliccala per aprire la finestra personaggio, o la scheda del luogo per aprire quella zona nel Catalogo. Scegli sotto quale lato usa ciascuno.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Mostra info del personaggio",
    ["ESCPANEL_TOGGLE_ENDEAVORS"] = "Mostra Iniziative",
    ["ESCPANEL_TOGGLE_ALERTS"] = "Mostra avvisi",
    ["ESCPANEL_TOGGLE_ZONE_NOTES"] = "Mostra note della zona",
    ["ESCPANEL_TOGGLE_HIDE_ZONE_EMPTY"] = "Nascondi note della zona se vuote",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "Mostra portali",
    ["ESCPANEL_LAYOUT_HEADER"] = "Disposizione",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "Lato dei pannelli info",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "Lato dei portali",
    ["ESCPANEL_SIDE_LEFT"] = "A sinistra del menu",
    ["ESCPANEL_SIDE_RIGHT"] = "A destra del menu",
    ["ESCPANEL_LAYOUT_DESC"] = "Quando entrambi sono sullo stesso lato, i portali stanno all'esterno (più lontani dal menu) e i pannelli accanto al menu.",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "Dimensione icone portale",
})
