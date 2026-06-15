local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["FASTLOOT_TITLE"] = "Fast Loot",
    ["FASTLOOT_DESC"] = "Automatically loots all items from a corpse or chest the moment the loot window is ready. Works alongside the game's auto-loot setting.",
})
