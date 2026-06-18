local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["AUTODELETE_TITLE"] = "Auto-Löschen",
    ["AUTODELETE_DESC"] = "Überspringe das Tippen von LÖSCHEN beim Zerstören von Gegenständen. Die Bestätigungsschaltfläche wird sofort verfügbar, ohne dass du etwas tippen musst.",
    ["AUTODELETE_TOGGLE_SKIP"] = "Getippte Bestätigung überspringen",
    ["AUTODELETE_TOGGLE_SKIP_DESC"] = "Aktiviert automatisch die Löschen-Schaltfläche, ohne dass du LÖSCHEN tippen musst.",
    ["AUTODELETE_TOGGLE_LINK"] = "Gegenstandslink anzeigen",
    ["AUTODELETE_TOGGLE_LINK_DESC"] = "Zeigt den Gegenstandslink im Bestätigungs-Popup an, damit du siehst, was du löschen wirst.",
})
