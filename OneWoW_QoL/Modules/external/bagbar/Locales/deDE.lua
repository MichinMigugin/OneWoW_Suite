local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["BAGBAR_TITLE"] = "Taschenleiste",
    ["BAGBAR_DESC"] = "Zeigt nutzbare Taschengegenstände auf einer beweglichen Leiste. Gegenstände werden mit einem Schlüsselwort-Ausdruck ausgewählt (wie bei der Taschensuche). Anlegbare Ausrüstung und Questgegenstände werden immer von der Leiste ausgeschlossen (automatisch angewendet, nicht im Editor angezeigt).",
    ["BAGBAR_LOCK_POSITION"] = "Position sperren",
    ["BAGBAR_MAX_BUTTONS"] = "Maximale Buttons",
    ["BAGBAR_SHIFT_RIGHT_CLICK_TO_SKIP"] = "Umschalt+Rechtsklick, um diese Sitzung zu überspringen",
    ["BAGBAR_ALT_RIGHT_CLICK_TO_BLACKLIST"] = "Alt+Rechtsklick, um dauerhaft auf die Sperrliste zu setzen",
    ["BAGBAR_MANUAL_ITEMS_HEADER"] = "Manuelle Gegenstände",
    ["BAGBAR_MANUAL_DESC"] = "Hefte bestimmte Gegenstände an, um ihnen in der Leiste höhere Priorität zu geben. Sie müssen weiterhin deinem Ausdrucksfilter und den Nutzbarkeitsregeln der Leiste entsprechen.",
    ["BAGBAR_MACROS_HEADER"] = "Manuelle Makros",
    ["BAGBAR_MACROS_DESC"] = "Füge deine Makros als eigene Buttons zur Leiste hinzu. Ziehe ein Makro aus dem Makrofenster auf den Ablagebereich oder gib einen Makronamen ein und klicke auf „Hinzufügen“. Makros erscheinen vor Taschengegenständen.",
    ["BAGBAR_MACRO_NAME_LABEL"] = "Makroname:",
    ["BAGBAR_DRAG_MACRO_HERE"] = "Makro hierher ziehen",
    ["BAGBAR_MACRO_LEFT_CLICK_TO_RUN"] = "Linksklick, um das Makro auszuführen",
    ["BAGBAR_MACRO_MISSING"] = "(fehlt)",
    ["BAGBAR_BLACKLIST_DESC"] = "Umschalt+Rechtsklick auf Gegenstände in der Leiste, um sie für diese Sitzung zu überspringen. Alt+Rechtsklick, um sie dauerhaft auf die Sperrliste zu setzen.",
    ["BAGBAR_COLUMNS"] = "Spalten",
    ["BAGBAR_CONTEXT_LOCK"] = "Position sperren",
    ["BAGBAR_GROW_RIGHT"] = "Rechts",
    ["BAGBAR_GROW_LEFT"] = "Links",
    ["BAGBAR_EXPRESSION_FILTER_HEADER"] = "Ausdrucksfilter",
    ["BAGBAR_EXPRESSION_FILTER_DESC"] = "Schlüsselwort-Ausdruck dafür, welche Taschengegenstände erscheinen (dieselben Schlüsselwörter wie bei der Taschensuche). Klicke auf ? für Hilfe. Anlegbare Ausrüstung und Questgegenstände werden automatisch von diesem Ausdruck ausgeschlossen.",
    ["BAGBAR_EXPRESSION_FILTER_PLACEHOLDER"] = "z. B. #usable & #mount",
})
