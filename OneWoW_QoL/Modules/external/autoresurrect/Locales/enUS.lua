local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["AUTORESURRECT_TITLE"] = "Auto-Accept Resurrection",
    ["AUTORESURRECT_DESC"] = "Automatically accepts resurrection requests when someone casts a rez on you. Skipped while you are in combat.",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE"] = "Don't Accept In Instances",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE_DESC"] = "Skip auto-accept while you are inside a dungeon, raid, battleground, or arena. Useful if you want to wait for the right moment to rez.",
})
