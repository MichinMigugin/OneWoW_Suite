local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["ACHIEVEUNTRACK_TITLE"] = "取消追踪已完成成就",
    ["ACHIEVEUNTRACK_DESC"] = "在你登录时自动扫描并取消追踪已完成的成就。释放在崩溃或跨角色完成后可能卡住的隐藏追踪栏位。",
})
