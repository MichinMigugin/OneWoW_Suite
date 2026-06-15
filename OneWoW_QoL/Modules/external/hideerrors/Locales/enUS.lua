local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["HIDEERRORS_TITLE"] = "Hide Combat Error Spam",
    ["HIDEERRORS_DESC"] = "Hides the most common red error messages (out of mana, out of range, target needs to be in front, spell not ready, etc.) so the center of your screen stays clean during fights.",
})
