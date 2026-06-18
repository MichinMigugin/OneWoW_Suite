local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["AUTOREPAIR_TITLE"] = "自动修理",
    ["AUTOREPAIR_DESC"] = "当你拜访支持修理的商人时自动修理你的全部装备。将费用显示到聊天。",
    ["AUTOREPAIR_TOGGLE_GUILD"] = "使用公会银行修理",
    ["AUTOREPAIR_TOGGLE_GUILD_DESC"] = "在使用你自己的金币之前，尝试用公会银行支付修理费用。",
})
