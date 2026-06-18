local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["ESCPANEL_TITLE"] = "Pannello menu ESC",
    ["ESCPANEL_DESC"] = "Mostra info del personaggio, avvisi, note della zona e una striscia di portali accanto al menu ESC. Scegli sotto quale lato usa ciascuno.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "Mostra info del personaggio",
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
