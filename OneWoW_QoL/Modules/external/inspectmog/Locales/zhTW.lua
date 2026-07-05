local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["INSPECTMOG_TITLE"] = "查看裝備",
    ["INSPECTMOG_DESC"] = "在查看視窗新增一個側邊面板，列出你所查看玩家已裝備的裝備。可將整個清單儲存到 OneWoW Notes 的玩家筆記中，或 Shift 點擊任意物品將其新增到你的物品筆記。",

    ["INSPECTMOG_ADD_NOTE"] = "新增到玩家筆記",
    ["INSPECTMOG_ADD_ALL"] = "全部新增",
    ["INSPECTMOG_EMPTY"] = "暫無可查看的裝備。",
    ["INSPECTMOG_PANEL_TITLE"] = "幻化查看工具",
    ["INSPECTMOG_NO_DATA"] = "沒有可用的查看資料。",
    ["INSPECTMOG_UNKNOWN_PLAYER"] = "被查看的玩家",
    ["INSPECTMOG_NATIVE_APPEARANCE"] = "原始外觀",
    ["INSPECTMOG_SOURCE_FORMAT"] = "來源 #%d",
    ["INSPECTMOG_APPEARANCE_SOURCE_FORMAT"] = "外觀來源：%d",

    ["INSPECTMOG_TT_PREVIEW"] = "Ctrl 點擊以在試衣間中預覽",
    ["INSPECTMOG_TT_NOTES"] = "Shift 點擊以新增到 Notes > 物品",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED"] = "Shift 點擊以將已裝備物品新增到 Notes > 物品",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED_COLL"] = "Shift 點擊以將此物品的外觀新增到 Notes > 收藏品",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE"] = "Shift 點擊以將幻化外觀新增到 Notes > 物品",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE_COLL"] = "Shift 點擊以將幻化外觀新增到 Notes > 收藏品",
    ["INSPECTMOG_ROUTE_COLLECTIBLES"] = "將外觀新增到收藏品",
    ["INSPECTMOG_TT_PREVIEW_EQUIPPED"] = "Ctrl 點擊以預覽已裝備物品",
    ["INSPECTMOG_TT_PREVIEW_APPEARANCE"] = "Ctrl 點擊以預覽幻化外觀",
    ["INSPECTMOG_TT_HIDDEN_APPEARANCE"] = "隱藏的外觀不會被新增到物品筆記",
    ["INSPECTMOG_TT_ADD_ALL_TITLE"] = "新增全部幻化",
    ["INSPECTMOG_TT_ADD_ALL_DESC"] = "將所有可見的幻化外觀物品新增到 Notes > 物品。",

    ["INSPECTMOG_TT_ADD_NOTE_TITLE"] = "將裝備儲存到玩家筆記",
    ["INSPECTMOG_TT_ADD_NOTE_DESC"] = "將列出的每個部位和物品寫入 OneWoW Notes 中該玩家的筆記。重新儲存會更新裝備區塊並保留筆記的其餘部分。",

    ["INSPECTMOG_NOTE_HEADER"] = "[OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_FOOTER"] = "[/OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_UPDATED"] = "已查看：%s",
    ["INSPECTMOG_NOTE_LINE"] = "%s - %s",

    ["INSPECTMOG_ITEM_STAMP"] = "TMOG 查看於 %s - %s",

    ["INSPECTMOG_STATUS_NOTE_SAVED"] = "已將裝備儲存到 %s 的筆記。",
    ["INSPECTMOG_STATUS_NOTE_UPDATED"] = "已更新 %s 筆記中的裝備。",
    ["INSPECTMOG_STATUS_ITEM_ADDED"] = "已將 %s 新增到物品筆記。",
    ["INSPECTMOG_STATUS_NOTES_MISSING"] = "未安裝 OneWoW Notes。",
    ["INSPECTMOG_STATUS_NO_DATA"] = "暫無可用的裝備資料。",
})
