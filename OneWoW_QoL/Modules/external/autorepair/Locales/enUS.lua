local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["AUTOREPAIR_TITLE"] = "Auto Repair",
    ["AUTOREPAIR_DESC"] = "Automatically repairs all your equipment when you visit a merchant that supports repairs. Prints the cost to chat.",
    ["AUTOREPAIR_TOGGLE_GUILD"] = "Use Guild Bank Repair",
    ["AUTOREPAIR_TOGGLE_GUILD_DESC"] = "Attempt to use the guild bank for repair costs before using your own gold.",
})
