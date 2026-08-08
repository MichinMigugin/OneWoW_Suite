local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["BAGBAR_TITLE"] = "背包栏",
    ["BAGBAR_DESC"] = "在可移动的栏上显示可用的背包物品。物品通过关键词表达式选择（与背包搜索相同）。可装备的装备和任务物品始终从栏中排除（自动应用，不在编辑器中显示）。",
    ["BAGBAR_LOCK_POSITION"] = "锁定位置",
    ["BAGBAR_MAX_BUTTONS"] = "最大按钮数",
    ["BAGBAR_SHIFT_RIGHT_CLICK_TO_SKIP"] = "Shift+右键点击以在本次会话中跳过",
    ["BAGBAR_ALT_RIGHT_CLICK_TO_BLACKLIST"] = "Alt+右键点击以永久加入黑名单",
    ["BAGBAR_MANUAL_ITEMS_HEADER"] = "手动物品",
    ["BAGBAR_MANUAL_DESC"] = "固定特定物品以在栏中获得更高优先级。它们仍须符合你的表达式筛选和栏的可用性规则。",
    ["BAGBAR_MACROS_HEADER"] = "手动宏",
    ["BAGBAR_MACROS_DESC"] = "将你的宏作为自定义按钮添加到栏中。从宏窗口将宏拖到放置区域，或输入宏名称并点击添加。宏显示在背包物品之前。",
    ["BAGBAR_MACRO_NAME_LABEL"] = "宏名称：",
    ["BAGBAR_DRAG_MACRO_HERE"] = "将宏拖到此处",
    ["BAGBAR_MACRO_LEFT_CLICK_TO_RUN"] = "左键点击以运行宏",
    ["BAGBAR_MACRO_MISSING"] = "（缺失）",
    ["BAGBAR_BLACKLIST_DESC"] = "Shift+右键点击栏中的物品以在本次会话中跳过。Alt+右键点击以永久加入黑名单。",
    ["BAGBAR_COLUMNS"] = "列数",
    ["BAGBAR_CONTEXT_LOCK"] = "锁定位置",
    ["BAGBAR_GROW_RIGHT"] = "右",
    ["BAGBAR_GROW_LEFT"] = "左",
    ["BAGBAR_EXPRESSION_FILTER_HEADER"] = "表达式筛选",
    ["BAGBAR_EXPRESSION_FILTER_DESC"] = "决定哪些背包物品出现的关键词表达式（与背包搜索的关键词相同）。点击 ? 获取帮助。可装备的装备和任务物品会自动从此表达式中排除。",
    ["BAGBAR_EXPRESSION_FILTER_PLACEHOLDER"] = "例如 #usable & #mount",
})
