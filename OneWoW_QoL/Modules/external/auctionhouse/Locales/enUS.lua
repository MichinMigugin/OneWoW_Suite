local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "enUS", {

    ["AUCTIONHOUSE_TITLE"] = "Auction House - Current Expansion",
    ["AUCTIONHOUSE_DESC"] = "Automatically filters the Auction House to show only current expansion items when you open it.",
})
