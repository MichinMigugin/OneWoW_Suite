local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["CHARINFO_TITLE"] = "角色資訊表",
    ["CHARINFO_DESC"] = "在角色面板上每件已裝備物品旁顯示一個簡潔的資訊面板，展示物品等級（依品質著色）、附魔狀態、寶石狀態和耐久度百分比。",
    ["CHARINFO_ENCHANTED"] = "已附魔",
    ["CHARINFO_MISSING_ENCHANT"] = "缺少附魔",
    ["CHARINFO_NO_ENCHANT_NEEDED"] = "無需附魔",
    ["CHARINFO_ALL_SOCKETS_EMPTY"] = "所有插槽為空",
    ["CHARINFO_SOME_SOCKETS_EMPTY"] = "部分插槽為空",
    ["CHARINFO_ALL_SOCKETS_FILLED"] = "所有插槽已鑲嵌",
    ["CHARINFO_NO_SOCKETS"] = "無插槽",
    ["CHARINFO_TOGGLE_DURABILITY"] = "顯示耐久度",
    ["CHARINFO_TOGGLE_DURABILITY_DESC"] = "在物品按鈕上顯示耐久度百分比",
    ["CHARINFO_TOGGLE_SOCKETS"] = "顯示無插槽圖示",
    ["CHARINFO_TOGGLE_SOCKETS_DESC"] = "當物品沒有插槽時顯示一個圖示",
    ["CHARINFO_ENCHANT_SLOTS_HEADER"] = "附魔欄位追蹤",
    ["CHARINFO_ENCHANT_SLOTS_DESC"] = "選擇要追蹤附魔的裝備欄位。被停用的欄位將不顯示附魔狀態圖示。",
    ["CHARINFO_SLOT_HEAD"] = "頭部",
    ["CHARINFO_SLOT_NECK"] = "頸部",
    ["CHARINFO_SLOT_SHOULDER"] = "肩部",
    ["CHARINFO_SLOT_CHEST"] = "胸部",
    ["CHARINFO_SLOT_WAIST"] = "腰部",
    ["CHARINFO_SLOT_LEGS"] = "腿部",
    ["CHARINFO_SLOT_FEET"] = "腳",
    ["CHARINFO_SLOT_WRIST"] = "手腕",
    ["CHARINFO_SLOT_HANDS"] = "手",
    ["CHARINFO_SLOT_RING1"] = "戒指 1",
    ["CHARINFO_SLOT_RING2"] = "戒指 2",
    ["CHARINFO_SLOT_BACK"] = "背部",
    ["CHARINFO_SLOT_MAINHAND"] = "主手",
    ["CHARINFO_SLOT_OFFHAND"] = "副手",
    ["FEATURES_ON"] = "開",
    ["FEATURES_OFF"] = "關",
})
