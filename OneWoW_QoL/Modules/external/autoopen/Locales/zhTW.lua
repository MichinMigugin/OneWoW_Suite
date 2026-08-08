local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["AUTOOPEN_TITLE"] = "自動開啟",
    ["AUTOOPEN_DESC"] = "當背包、箱子和其他容器物品出現在你的物品欄中時自動開啟它們。在銀行、信箱或商人處不會開啟物品。你尚無法開啟的物品（上鎖的保險箱、等級/職業/專業不符，或欄位忙碌時）會被自動跳過。",
    ["AUTOOPEN_OPENING"] = "正在自動開啟：%s",
    ["AUTOOPEN_BLACKLIST_DESC"] = "新增物品以防止自動開啟將其開啟。",
    ["AUTOOPEN_BLACKLIST_REMOVED"] = "已從黑名單移除：%s",
})
