local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["AUTOREPAIR_TITLE"] = "自動修理",
    ["AUTOREPAIR_DESC"] = "當你拜訪支援修理的商人時自動修理你的全部裝備。將費用顯示到聊天。",
    ["AUTOREPAIR_TOGGLE_GUILD"] = "使用公會銀行修理",
    ["AUTOREPAIR_TOGGLE_GUILD_DESC"] = "在使用你自己的金幣之前，嘗試用公會銀行支付修理費用。",
})
