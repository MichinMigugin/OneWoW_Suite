local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["CRAFTORDERS_TITLE"] = "制造订单",
    ["CRAFTORDERS_DESC"] = "用“现在可制造”和“缺少材料”替换订单列表。把缺少的材料加入购物清单。用一个按钮开始、制造并完成。",
    ["CRAFTORDERS_SECTION_READY"] = "现在可制造",
    ["CRAFTORDERS_SECTION_MISSING"] = "缺少材料",
    ["CRAFTORDERS_WEEKLY_NOT_ACCEPTED"] = "周常：未接受",
    ["CRAFTORDERS_WEEKLY_NOT_LEARNED"] = "周常：未学会",
    ["CRAFTORDERS_WEEKLY_COMPLETE"] = "周常：已完成",
    ["CRAFTORDERS_WEEKLY_PROGRESS"] = "周常：已完成 %d / %d",
    ["CRAFTORDERS_LOADING"] = "正在载入订单...",
    ["CRAFTORDERS_ADD_ACTIVE"] = "加入%s",
    ["CRAFTORDERS_MAKE_LIST"] = "创建清单",
    ["CRAFTORDERS_ADD_MENU_HINT"] = "右键可创建清单或选择其他清单。",
    ["CRAFTORDERS_ELSEWHERE_TIP"] = "也在：%s",
    ["CRAFTORDERS_COL_CRAFT"] = "订单",
    ["CRAFTORDERS_COL_YOU"] = "你提供",
    ["CRAFTORDERS_COL_CART"] = "清单",
    ["CRAFTORDERS_COL_CUSTOMER"] = "顾客提供",
    ["CRAFTORDERS_COL_REWARD"] = "你获得",
    ["CRAFTORDERS_USE_WOWUI"] = "WoW UI",
    ["CRAFTORDERS_USE_ONEUI"] = "One UI",
    ["CRAFTORDERS_TOGGLE_WOWUI"] = "使用 WoW 列表",
    ["CRAFTORDERS_TOGGLE_WOWUI_DESC"] = "显示暴雪订单表，而不是“现在可制造”和“缺少材料”。",
    ["CRAFTORDERS_BUCKET_COUNT"] = "%d份订单",
    ["CRAFTORDERS_ORDER_LIST_NAME"] = "订单：%s",
    ["CRAFTORDERS_NO_SHOPPING"] = "启用购物清单才能加入材料。",
    ["CRAFTORDERS_KP"] = "知识 %d",
    ["CRAFTORDERS_ACUITY"] = "敏锐 x%d",
})
