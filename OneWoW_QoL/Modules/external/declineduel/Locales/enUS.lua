local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["DECLINEDUEL_TITLE"] = "Auto-Decline Duels",
    ["DECLINEDUEL_DESC"] = "Automatically declines duel requests so the popup never lingers on your screen.",
    ["DECLINEDUEL_TOGGLE_PET"] = "Also Decline Pet Duels",
    ["DECLINEDUEL_TOGGLE_PET_DESC"] = "Also automatically decline pet battle duel requests.",
})
