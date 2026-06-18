local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["FASTLOOT_TITLE"] = "快速拾取",
    ["FASTLOOT_DESC"] = "在拾取視窗就緒的那一刻，自動拾取屍體或箱子中的所有物品。與遊戲的自動拾取設定協同運作。",
})
