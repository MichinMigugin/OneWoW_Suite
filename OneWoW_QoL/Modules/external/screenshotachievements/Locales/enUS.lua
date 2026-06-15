local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["SCREENSHOTACH_TITLE"] = "Screenshot On Achievement",
    ["SCREENSHOTACH_DESC"] = "Takes a screenshot a moment after you earn an achievement so the toast is captured. Files are saved as 'WoWScrnShot_*.jpg' in your World of Warcraft\\_retail_\\Screenshots folder.",
})
