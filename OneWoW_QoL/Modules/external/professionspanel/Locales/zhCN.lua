local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["PROFPANEL_TITLE"] = "专业面板",
    ["PROFPANEL_DESC"] = "在专业窗口旁显示一个辅助面板，包含按资料片划分的技能明细、配方数量和首次制造追踪。",
    ["PROFPANEL_AUTO_SHOW"] = "自动显示面板",
    ["PROFPANEL_TOGGLE_TIP"] = "专业统计面板",
    ["PROFPANEL_HIDE_TIP"] = "点击以隐藏面板",
    ["PROFPANEL_SHOW_TIP"] = "点击以显示面板",
    ["PROFPANEL_STATS_TITLE"] = "专业面板",
    ["PROFPANEL_NO_EXPANSION_DATA"] = "没有可用的资料片数据。\n打开一项专业以进行扫描。",
    ["PROFPANEL_NO_ALT_DATA"] = "未找到拥有此专业的其他小号",
    ["PROFPANEL_OTHER_ALTS"] = "拥有此专业的其他小号",
    ["PROFPANEL_LAST_SCANNED"] = "上次扫描：%s",
})
