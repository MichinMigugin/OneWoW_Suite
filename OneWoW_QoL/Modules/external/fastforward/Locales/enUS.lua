local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["FASTFORWARD_TITLE"] = "Fast Forward",
    ["FASTFORWARD_DESC"] = "Automatically skips in-game movies and cinematics. Hold any modifier key while a movie or cinematic starts to watch it instead.",
    ["FASTFORWARD_TOGGLE_MOVIES"] = "Skip Movies",
    ["FASTFORWARD_TOGGLE_MOVIES_DESC"] = "Automatically stop in-game movies when they begin playing.",
    ["FASTFORWARD_TOGGLE_CINEMATICS"] = "Skip Cinematics",
    ["FASTFORWARD_TOGGLE_CINEMATICS_DESC"] = "Automatically cancel in-game cinematic sequences when they begin.",
    ["FASTFORWARD_TOGGLE_INSTANCE"] = "Instances Only",
    ["FASTFORWARD_TOGGLE_INSTANCE_DESC"] = "Only skip movies and cinematics while inside a dungeon, raid, or other instance.",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE"] = "Respect Uncancellable",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE_DESC"] = "Do not attempt to skip cinematics that the game marks as unable to be cancelled.",
})
