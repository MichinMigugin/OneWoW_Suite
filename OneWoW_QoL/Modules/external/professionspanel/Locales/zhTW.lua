local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["PROFPANEL_TITLE"] = "專業面板",
    ["PROFPANEL_DESC"] = "在專業視窗旁顯示一個輔助面板，包含按資料片劃分的技能明細、配方數量和首次製造追蹤。",
    ["PROFPANEL_AUTO_SHOW"] = "自動顯示面板",
    ["PROFPANEL_TOGGLE_TIP"] = "專業統計面板",
    ["PROFPANEL_HIDE_TIP"] = "點擊以隱藏面板",
    ["PROFPANEL_SHOW_TIP"] = "點擊以顯示面板",
    ["PROFPANEL_STATS_TITLE"] = "專業面板",
    ["PROFPANEL_NO_EXPANSION_DATA"] = "沒有可用的資料片資料。\n開啟一項專業以進行掃描。",
    ["PROFPANEL_NO_ALT_DATA"] = "未找到擁有此專業的其他分身",
    ["PROFPANEL_OTHER_ALTS"] = "擁有此專業的其他分身",
    ["PROFPANEL_LAST_SCANNED"] = "上次掃描：%s",
})
