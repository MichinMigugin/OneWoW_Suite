local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["ACHIEVEUNTRACK_TITLE"] = "Untrack Completed Achievements",
    ["ACHIEVEUNTRACK_DESC"] = "Automatically scans for and untracks already-completed achievements when you log in. Frees up hidden tracking slots that can get stuck after a crash or cross-character completion.",
})
