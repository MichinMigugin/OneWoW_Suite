local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["LFGPANEL_TITLE"] = "隊伍尋找器入場限制",
    ["LFGPANEL_DESC"] = "在開啟隊伍尋找器時，於側邊面板顯示你目前的團隊副本和地城入場限制。",
    ["LFGPANEL_SHOW_PANEL"] = "顯示入場限制面板",
    ["LFGPANEL_SHOW_PANEL_DESC"] = "在隊伍尋找器開啟時顯示入場限制面板。",
    ["LFGPANEL_FILTER_RESULTS"] = "篩選隊伍尋找結果",
    ["LFGPANEL_FILTER_RESULTS_DESC"] = "依所選難度篩選隊伍尋找搜尋結果。",

    ["LFGPANEL_TT_REFRESH"] = "重新整理入場限制",
    ["LFGPANEL_TT_REFRESH_DESC"] = "向伺服器請求最新的入場限制資料。",
    ["LFGPANEL_TT_TOGGLE"] = "顯示入場限制面板",
    ["LFGPANEL_TT_TOGGLE_DESC"] = "點擊以顯示入場限制面板。",

    ["LFGPANEL_FILTER_DIFFICULTY"] = "難度",
    ["LFGPANEL_DIFFICULTY_NORMAL"] = "普通",
    ["LFGPANEL_DIFFICULTY_HEROIC"] = "英雄",
    ["LFGPANEL_DIFFICULTY_MYTHIC"] = "史詩",
    ["LFGPANEL_DIFFICULTY_MYTHICPLUS"] = "史詩+",
    ["LFGPANEL_DIFFICULTY_LFR"] = "LFR",

    ["LFGPANEL_NO_LOCKOUTS"] = "沒有作用中的入場限制。",
    ["LFGPANEL_NO_LOCKOUTS_FILTERED"] = "沒有符合所選難度的入場限制。",
    ["LFGPANEL_EXPIRED"] = "已過期",
    ["LFGPANEL_EXTENDED"] = "已延長",
    ["LFGPANEL_TT_EXTENDED"] = "已延長的入場限制",
    ["LFGPANEL_TT_EXTENDED_DESC"] = "此入場限制已被手動延長，超過其正常重置時間。",

    ["LFGPANEL_TIME_DAYS"] = "%d天%d時",
    ["LFGPANEL_TIME_HOURS"] = "%d時%d分",
    ["LFGPANEL_TIME_MINUTES"] = "%d分",
    ["LFGPANEL_PROGRESS"] = "%d/%d",

    ["LFGPANEL_TT_LOCKOUT"] = "副本入場限制",
    ["LFGPANEL_TT_LOCKOUT_PROGRESS"] = "首領進度：%d/%d",
    ["LFGPANEL_TT_LOCKOUT_TIME"] = "重置剩餘：%s",
    ["LFGPANEL_TT_LOCKOUT_DIFFICULTY"] = "難度：%s",

    ["LFGPANEL_OPT_FILTER_LFG"] = "篩選隊伍尋找結果",
    ["LFGPANEL_TT_FILTER_LFG"] = "篩選隊伍尋找結果",
    ["LFGPANEL_TT_FILTER_LFG_DESC"] = "啟用後，隊伍尋找搜尋結果將依你所選的難度進行篩選。",
})
