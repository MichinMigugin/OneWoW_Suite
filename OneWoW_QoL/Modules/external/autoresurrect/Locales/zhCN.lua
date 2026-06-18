local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["AUTORESURRECT_TITLE"] = "自动接受复活",
    ["AUTORESURRECT_DESC"] = "当有人对你施放复活时自动接受复活请求。战斗中会跳过。",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE"] = "副本中不接受",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE_DESC"] = "在你身处地下城、团队副本、战场或竞技场时跳过自动接受。如果你想等待合适的时机复活，会很有用。",
})
