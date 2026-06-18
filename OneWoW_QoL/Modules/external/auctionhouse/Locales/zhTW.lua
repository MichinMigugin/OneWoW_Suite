local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["AUCTIONHOUSE_TITLE"] = "拍賣場 - 目前資料片",
    ["AUCTIONHOUSE_DESC"] = "在你開啟拍賣場時自動將其篩選為僅顯示目前資料片的物品。",
})
