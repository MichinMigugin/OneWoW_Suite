local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["AUTOOPEN_TITLE"] = "Auto-Öffnen",
    ["AUTOOPEN_DESC"] = "Öffnet automatisch Taschen, Kisten und andere Behältergegenstände, wenn sie in deinem Inventar erscheinen. Öffnet keine Gegenstände an einer Bank, einem Briefkasten oder Händler. Gegenstände, die du noch nicht öffnen kannst (verschlossene Truhen, falsche Stufe/Klasse/Beruf oder während der Platz beschäftigt ist), werden automatisch übersprungen.",
    ["AUTOOPEN_OPENING"] = "Automatisch öffnen: %s",
    ["AUTOOPEN_BLACKLIST_DESC"] = "Füge Gegenstände hinzu, damit Auto-Öffnen sie nicht öffnet.",
    ["AUTOOPEN_BLACKLIST_REMOVED"] = "Von der Sperrliste entfernt: %s",
})
