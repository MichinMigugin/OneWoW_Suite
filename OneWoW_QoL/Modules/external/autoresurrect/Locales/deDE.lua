local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["AUTORESURRECT_TITLE"] = "Wiederbelebung automatisch annehmen",
    ["AUTORESURRECT_DESC"] = "Nimmt automatisch Wiederbelebungsanfragen an, wenn jemand eine Auferstehung auf dich wirkt. Wird im Kampf übersprungen.",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE"] = "In Instanzen nicht annehmen",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE_DESC"] = "Überspringt die Auto-Annahme, während du dich in einem Dungeon, Schlachtzug, Schlachtfeld oder einer Arena befindest. Nützlich, wenn du auf den richtigen Moment zum Wiederbeleben warten möchtest.",
})
