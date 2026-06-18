local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["AUTOSUMMON_TITLE"] = "自动接受召唤",
    ["AUTOSUMMON_DESC"] = "自动接受来自术士和召唤石的召唤请求。",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT"] = "战斗中跳过",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT_DESC"] = "在你处于战斗中时不自动接受。建议开启，以免战斗中被拉走。",
})
