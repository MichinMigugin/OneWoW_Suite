local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["AUTOREADYCHECK_TITLE"] = "Bereitschaftsprüfung automatisch annehmen",
    ["AUTOREADYCHECK_DESC"] = "Bestätigt automatisch die Bereitschaft, wenn in deiner Gruppe eine Bereitschaftsprüfung gestartet wird.",
    ["AUTOREADYCHECK_TOGGLE_DEAD"] = "Überspringen, wenn tot",
    ["AUTOREADYCHECK_TOGGLE_DEAD_DESC"] = "Nicht automatisch annehmen, wenn du tot oder ein Geist bist, damit die Gruppe sieht, dass du nicht bereit zum Pullen bist.",
})
