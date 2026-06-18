local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["CHARINFO_TITLE"] = "角色信息表",
    ["CHARINFO_DESC"] = "在角色面板上每件已装备物品旁显示一个简洁的信息面板，展示物品等级（按品质着色）、附魔状态、宝石状态和耐久度百分比。",
    ["CHARINFO_ENCHANTED"] = "已附魔",
    ["CHARINFO_MISSING_ENCHANT"] = "缺少附魔",
    ["CHARINFO_NO_ENCHANT_NEEDED"] = "无需附魔",
    ["CHARINFO_ALL_SOCKETS_EMPTY"] = "所有插槽为空",
    ["CHARINFO_SOME_SOCKETS_EMPTY"] = "部分插槽为空",
    ["CHARINFO_ALL_SOCKETS_FILLED"] = "所有插槽已镶嵌",
    ["CHARINFO_NO_SOCKETS"] = "无插槽",
    ["CHARINFO_TOGGLE_DURABILITY"] = "显示耐久度",
    ["CHARINFO_TOGGLE_DURABILITY_DESC"] = "在物品按钮上显示耐久度百分比",
    ["CHARINFO_TOGGLE_SOCKETS"] = "显示无插槽图标",
    ["CHARINFO_TOGGLE_SOCKETS_DESC"] = "当物品没有插槽时显示一个图标",
    ["CHARINFO_ENCHANT_SLOTS_HEADER"] = "附魔栏位追踪",
    ["CHARINFO_ENCHANT_SLOTS_DESC"] = "选择要追踪附魔的装备栏位。被禁用的栏位将不显示附魔状态图标。",
    ["CHARINFO_SLOT_HEAD"] = "头部",
    ["CHARINFO_SLOT_NECK"] = "颈部",
    ["CHARINFO_SLOT_SHOULDER"] = "肩部",
    ["CHARINFO_SLOT_CHEST"] = "胸部",
    ["CHARINFO_SLOT_WAIST"] = "腰部",
    ["CHARINFO_SLOT_LEGS"] = "腿部",
    ["CHARINFO_SLOT_FEET"] = "脚",
    ["CHARINFO_SLOT_WRIST"] = "手腕",
    ["CHARINFO_SLOT_HANDS"] = "手",
    ["CHARINFO_SLOT_RING1"] = "戒指 1",
    ["CHARINFO_SLOT_RING2"] = "戒指 2",
    ["CHARINFO_SLOT_BACK"] = "背部",
    ["CHARINFO_SLOT_MAINHAND"] = "主手",
    ["CHARINFO_SLOT_OFFHAND"] = "副手",
    ["FEATURES_ON"] = "开",
    ["FEATURES_OFF"] = "关",
})
