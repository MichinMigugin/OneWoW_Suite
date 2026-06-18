local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["HIDEERRORS_TITLE"] = "Kampf-Fehlerspam ausblenden",
    ["HIDEERRORS_DESC"] = "Blendet die häufigsten roten Fehlermeldungen aus (nicht genug Mana, außer Reichweite, Ziel muss vor dir sein, Zauber nicht bereit usw.), sodass die Bildschirmmitte während Kämpfen frei bleibt.",
})
