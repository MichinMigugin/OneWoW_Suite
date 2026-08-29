local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["COPYTEXT_TITLE"] = "Text kopieren",
    ["COPYTEXT_DESC"] = "Kopiert sichtbaren Text aus Tooltips oder UI-Elementen in deine Zwischenablage. Verwende /1wcopytext (oder /1wct), um zu kopieren, was sich unter deinem Cursor befindet.",
    ["COPYTEXT_TOGGLE_TOOLTIPS"] = "Tooltip-Modus",
    ["COPYTEXT_TOGGLE_TOOLTIPS_DESC"] = "Erfasst beim Kopieren Text aus allen sichtbaren Tooltips unter deinem Cursor.",
    ["COPYTEXT_TOGGLE_ANYTHING"] = "Alles-Modus",
    ["COPYTEXT_TOGGLE_ANYTHING_DESC"] = "Erfasst beim Kopieren Text aus jedem sichtbaren UI-Element unter deinem Cursor, nicht nur aus Tooltips.",
    ["COPYTEXT_TOGGLE_FAST"] = "Schnellkopie",
    ["COPYTEXT_TOGGLE_FAST_DESC"] = "Wählt automatisch den gesamten Text im Kopierdialog aus, sodass du ihn sofort kopieren kannst, ohne klicken zu müssen.",
    ["COPYTEXT_NO_TEXT"] = "Kein Text unter dem Cursor gefunden.",
    ["COPYTEXT_TOOLTIP_CONTENT"] = "Tooltip-Inhalt",
    ["COPYTEXT_UI_CONTENT"] = "UI-Text",
})
