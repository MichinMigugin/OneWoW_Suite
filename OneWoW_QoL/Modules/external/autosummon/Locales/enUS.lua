local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["AUTOSUMMON_TITLE"] = "Auto-Accept Summon",
    ["AUTOSUMMON_DESC"] = "Automatically accepts summon requests from warlocks and summoning stones.",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT"] = "Skip While In Combat",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT_DESC"] = "Don't auto-accept while you are in combat. Recommended on so you don't get pulled away mid-fight.",
})
