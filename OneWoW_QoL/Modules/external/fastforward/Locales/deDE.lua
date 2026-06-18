local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["FASTFORWARD_TITLE"] = "Vorspulen",
    ["FASTFORWARD_DESC"] = "Überspringt automatisch Spielfilme und Zwischensequenzen. Halte eine beliebige Zusatztaste, während ein Film oder eine Zwischensequenz startet, um sie stattdessen anzusehen.",
    ["FASTFORWARD_TOGGLE_MOVIES"] = "Filme überspringen",
    ["FASTFORWARD_TOGGLE_MOVIES_DESC"] = "Stoppt automatisch Spielfilme, wenn sie zu spielen beginnen.",
    ["FASTFORWARD_TOGGLE_CINEMATICS"] = "Zwischensequenzen überspringen",
    ["FASTFORWARD_TOGGLE_CINEMATICS_DESC"] = "Bricht automatisch Zwischensequenzen ab, wenn sie beginnen.",
    ["FASTFORWARD_TOGGLE_INSTANCE"] = "Nur in Instanzen",
    ["FASTFORWARD_TOGGLE_INSTANCE_DESC"] = "Überspringt Filme und Zwischensequenzen nur, während du dich in einem Dungeon, Schlachtzug oder einer anderen Instanz befindest.",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE"] = "Nicht abbrechbare respektieren",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE_DESC"] = "Versucht nicht, Zwischensequenzen zu überspringen, die das Spiel als nicht abbrechbar markiert.",
})
