local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["HIDEERRORS_TITLE"] = "隱藏戰鬥錯誤洗版",
    ["HIDEERRORS_DESC"] = "隱藏最常見的紅色錯誤訊息（法力不足、超出距離、目標必須在面前、法術未就緒等），使螢幕中央在戰鬥期間保持整潔。",
})
