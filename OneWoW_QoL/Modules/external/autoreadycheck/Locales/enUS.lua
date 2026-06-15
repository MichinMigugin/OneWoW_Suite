local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["AUTOREADYCHECK_TITLE"] = "Auto-Accept Ready Check",
    ["AUTOREADYCHECK_DESC"] = "Automatically confirms ready when a ready check is called in your group.",
    ["AUTOREADYCHECK_TOGGLE_DEAD"] = "Skip If Dead",
    ["AUTOREADYCHECK_TOGGLE_DEAD_DESC"] = "Don't auto-accept if you are dead or a ghost, so the group can see you are not ready to pull.",
})
