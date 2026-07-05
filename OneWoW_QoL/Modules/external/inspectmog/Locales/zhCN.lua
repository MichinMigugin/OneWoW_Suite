local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["INSPECTMOG_TITLE"] = "查看装备",
    ["INSPECTMOG_DESC"] = "在查看窗口添加一个侧边面板，列出你所查看玩家已装备的装备。可将整个列表保存到 OneWoW Notes 的玩家笔记中，或 Shift 点击任意物品将其添加到你的物品笔记。",

    ["INSPECTMOG_ADD_NOTE"] = "添加到玩家笔记",
    ["INSPECTMOG_ADD_ALL"] = "全部添加",
    ["INSPECTMOG_EMPTY"] = "暂无可查看的装备。",
    ["INSPECTMOG_PANEL_TITLE"] = "幻化查看工具",
    ["INSPECTMOG_NO_DATA"] = "没有可用的查看数据。",
    ["INSPECTMOG_UNKNOWN_PLAYER"] = "被查看的玩家",
    ["INSPECTMOG_NATIVE_APPEARANCE"] = "原始外观",
    ["INSPECTMOG_SOURCE_FORMAT"] = "来源 #%d",
    ["INSPECTMOG_APPEARANCE_SOURCE_FORMAT"] = "外观来源：%d",

    ["INSPECTMOG_TT_PREVIEW"] = "Ctrl 点击以在试衣间中预览",
    ["INSPECTMOG_TT_NOTES"] = "Shift 点击以添加到 Notes > 物品",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED"] = "Shift 点击以将已装备物品添加到 Notes > 物品",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED_COLL"] = "Shift 点击以将此物品的外观添加到 Notes > 收藏品",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE"] = "Shift 点击以将幻化外观添加到 Notes > 物品",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE_COLL"] = "Shift 点击以将幻化外观添加到 Notes > 收藏品",
    ["INSPECTMOG_ROUTE_COLLECTIBLES"] = "将外观添加到收藏品",
    ["INSPECTMOG_TT_PREVIEW_EQUIPPED"] = "Ctrl 点击以预览已装备物品",
    ["INSPECTMOG_TT_PREVIEW_APPEARANCE"] = "Ctrl 点击以预览幻化外观",
    ["INSPECTMOG_TT_HIDDEN_APPEARANCE"] = "隐藏的外观不会被添加到物品笔记",
    ["INSPECTMOG_TT_ADD_ALL_TITLE"] = "添加全部幻化",
    ["INSPECTMOG_TT_ADD_ALL_DESC"] = "将所有可见的幻化外观物品添加到 Notes > 物品。",

    ["INSPECTMOG_TT_ADD_NOTE_TITLE"] = "将装备保存到玩家笔记",
    ["INSPECTMOG_TT_ADD_NOTE_DESC"] = "将列出的每个部位和物品写入 OneWoW Notes 中该玩家的笔记。重新保存会更新装备区块并保留笔记的其余部分。",

    ["INSPECTMOG_NOTE_HEADER"] = "[OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_FOOTER"] = "[/OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_UPDATED"] = "已查看：%s",
    ["INSPECTMOG_NOTE_LINE"] = "%s - %s",

    ["INSPECTMOG_ITEM_STAMP"] = "TMOG 查看于 %s - %s",

    ["INSPECTMOG_STATUS_NOTE_SAVED"] = "已将装备保存到 %s 的笔记。",
    ["INSPECTMOG_STATUS_NOTE_UPDATED"] = "已更新 %s 笔记中的装备。",
    ["INSPECTMOG_STATUS_ITEM_ADDED"] = "已将 %s 添加到物品笔记。",
    ["INSPECTMOG_STATUS_NOTES_MISSING"] = "未安装 OneWoW Notes。",
    ["INSPECTMOG_STATUS_NO_DATA"] = "暂无可用的装备数据。",
})
