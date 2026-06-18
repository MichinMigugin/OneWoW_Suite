local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["AUTOREADYCHECK_TITLE"] = "自动接受准备确认",
    ["AUTOREADYCHECK_DESC"] = "当你的队伍中发起准备确认时自动确认准备就绪。",
    ["AUTOREADYCHECK_TOGGLE_DEAD"] = "死亡时跳过",
    ["AUTOREADYCHECK_TOGGLE_DEAD_DESC"] = "在你死亡或为灵魂状态时不自动接受，以便队伍看到你尚未准备好开怪。",
})
