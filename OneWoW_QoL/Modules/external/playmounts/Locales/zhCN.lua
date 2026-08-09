local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["PLAYMOUNTS_TITLE"] = "玩家坐骑",
    ["PLAYMOUNTS_DESC"] = "检测并显示其他玩家当前使用的坐骑或移动形态。",
    ["PLAYMOUNTS_TOGGLE_CHAT"] = "在聊天中通知",
    ["PLAYMOUNTS_TOGGLE_CHAT_DESC"] = "当你选中一名已骑乘的玩家时，在聊天窗口中显示坐骑名称。",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT"] = "匹配坐骑",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT_DESC"] = "在玩家身上添加一个右键选项，以召唤与其所骑相同类型的坐骑。",
    ["PLAYMOUNTS_COLLECTED"] = "（已收集）",
    ["PLAYMOUNTS_NOT_COLLECTED"] = "（未收集）",
    ["PLAYMOUNTS_USING"] = "%s 正在使用 %s",
    ["PLAYMOUNTS_SOURCE"] = "来源：%s",
    ["PLAYMOUNTS_DISPLAYMODE_DESC"] = "控制在工具提示和聊天输出中显示多少坐骑信息。",
    ["PLAYMOUNTS_MODE_NAME"] = "名称",
    ["PLAYMOUNTS_MODE_NAMETYPE"] = "名称 + 类型",
    ["PLAYMOUNTS_MODE_ALL"] = "完整详情",
    ["PLAYMOUNTS_TOOLTIP_HEADER"] = "工具提示集成",
    ["PLAYMOUNTS_TOOLTIP_REQUIRES"] = "需要：OneWoW Core",
    ["PLAYMOUNTS_TOOLTIP_DETECTED"] = "状态：已检测到",
    ["PLAYMOUNTS_TOOLTIP_NOT_DETECTED"] = "状态：未检测到",
    ["PLAYMOUNTS_TOOLTIP_NOTE"] = "可在 QoL → 鼠标提示 → 玩家坐骑 中启用或禁用坐骑提示行。",
    ["PLAYMOUNTS_TOOLTIP_VIEW_BTN"] = "查看设置",
})
