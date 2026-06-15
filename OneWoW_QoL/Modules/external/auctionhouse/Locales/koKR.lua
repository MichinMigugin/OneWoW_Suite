local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "koKR", {

    ["AUCTIONHOUSE_TITLE"] = "경매장 - 현재 확장팩",
    ["AUCTIONHOUSE_DESC"] = "경매장을 열 때 자동으로 현재 확장팩 아이템만 표시하도록 필터링합니다.",
})
