local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["AUTOREPAIR_TITLE"] = "Auto-Reparatur",
    ["AUTOREPAIR_DESC"] = "Repariert automatisch deine gesamte Ausrüstung, wenn du einen Händler besuchst, der Reparaturen unterstützt. Gibt die Kosten im Chat aus.",
    ["AUTOREPAIR_TOGGLE_GUILD"] = "Gildenbank-Reparatur verwenden",
    ["AUTOREPAIR_TOGGLE_GUILD_DESC"] = "Versucht, die Gildenbank für die Reparaturkosten zu nutzen, bevor dein eigenes Gold verwendet wird.",
})
