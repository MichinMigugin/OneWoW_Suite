local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["LFGPANEL_TITLE"] = "随机查找入场限制",
    ["LFGPANEL_DESC"] = "在打开队伍查找器时，于侧边面板显示你当前的团队副本和地下城入场限制。",
    ["LFGPANEL_SHOW_PANEL"] = "显示入场限制面板",
    ["LFGPANEL_SHOW_PANEL_DESC"] = "在队伍查找器打开时显示入场限制面板。",
    ["LFGPANEL_FILTER_RESULTS"] = "筛选随机查找结果",
    ["LFGPANEL_FILTER_RESULTS_DESC"] = "按所选难度筛选随机查找搜索结果。",

    ["LFGPANEL_TT_REFRESH"] = "刷新入场限制",
    ["LFGPANEL_TT_REFRESH_DESC"] = "向服务器请求最新的入场限制数据。",
    ["LFGPANEL_TT_TOGGLE"] = "显示入场限制面板",
    ["LFGPANEL_TT_TOGGLE_DESC"] = "点击以显示入场限制面板。",

    ["LFGPANEL_FILTER_DIFFICULTY"] = "难度",
    ["LFGPANEL_DIFFICULTY_NORMAL"] = "普通",
    ["LFGPANEL_DIFFICULTY_HEROIC"] = "英雄",
    ["LFGPANEL_DIFFICULTY_MYTHIC"] = "史诗",
    ["LFGPANEL_DIFFICULTY_MYTHICPLUS"] = "史诗+",
    ["LFGPANEL_DIFFICULTY_LFR"] = "LFR",

    ["LFGPANEL_NO_LOCKOUTS"] = "没有活动的入场限制。",
    ["LFGPANEL_NO_LOCKOUTS_FILTERED"] = "没有符合所选难度的入场限制。",
    ["LFGPANEL_EXPIRED"] = "已过期",
    ["LFGPANEL_EXTENDED"] = "已延长",
    ["LFGPANEL_TT_EXTENDED"] = "已延长的入场限制",
    ["LFGPANEL_TT_EXTENDED_DESC"] = "此入场限制已被手动延长，超过其正常重置时间。",

    ["LFGPANEL_TIME_DAYS"] = "%d天%d时",
    ["LFGPANEL_TIME_HOURS"] = "%d时%d分",
    ["LFGPANEL_TIME_MINUTES"] = "%d分",
    ["LFGPANEL_PROGRESS"] = "%d/%d",

    ["LFGPANEL_TT_LOCKOUT"] = "副本入场限制",
    ["LFGPANEL_TT_LOCKOUT_PROGRESS"] = "首领进度：%d/%d",
    ["LFGPANEL_TT_LOCKOUT_TIME"] = "重置剩余：%s",
    ["LFGPANEL_TT_LOCKOUT_DIFFICULTY"] = "难度：%s",

    ["LFGPANEL_OPT_FILTER_LFG"] = "筛选随机查找结果",
    ["LFGPANEL_TT_FILTER_LFG"] = "筛选随机查找结果",
    ["LFGPANEL_TT_FILTER_LFG_DESC"] = "启用后，随机查找搜索结果将按你所选的难度进行筛选。",
})
