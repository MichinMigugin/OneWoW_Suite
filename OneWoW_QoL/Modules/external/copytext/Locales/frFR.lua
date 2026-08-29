local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(M._scope, "frFR", {

    ["COPYTEXT_TITLE"] = "Copier le texte",
    ["COPYTEXT_DESC"] = "Copie le texte visible des infobulles ou des éléments d'interface dans votre presse-papiers. Utilisez /1wcopytext (ou /1wct) pour copier ce qui se trouve sous votre curseur.",
    ["COPYTEXT_TOGGLE_TOOLTIPS"] = "Mode infobulle",
    ["COPYTEXT_TOGGLE_TOOLTIPS_DESC"] = "Lors de la copie, capture le texte de toutes les infobulles visibles sous votre curseur.",
    ["COPYTEXT_TOGGLE_ANYTHING"] = "Mode tout",
    ["COPYTEXT_TOGGLE_ANYTHING_DESC"] = "Lors de la copie, capture le texte de tout élément d'interface visible sous votre curseur, pas seulement les infobulles.",
    ["COPYTEXT_TOGGLE_FAST"] = "Copie rapide",
    ["COPYTEXT_TOGGLE_FAST_DESC"] = "Sélectionne automatiquement tout le texte dans la boîte de dialogue de copie pour que vous puissiez le copier instantanément sans avoir à cliquer.",
    ["COPYTEXT_NO_TEXT"] = "Aucun texte trouvé sous le curseur.",
    ["COPYTEXT_TOOLTIP_CONTENT"] = "Contenu de l'infobulle",
    ["COPYTEXT_UI_CONTENT"] = "Texte de l'interface",
})
