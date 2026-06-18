local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["AUTODELETE_TITLE"] = "自动删除",
    ["AUTODELETE_DESC"] = "销毁物品时无需输入 DELETE。确认按钮会立即可用，无需你输入任何内容。",
    ["AUTODELETE_TOGGLE_SKIP"] = "跳过输入确认",
    ["AUTODELETE_TOGGLE_SKIP_DESC"] = "自动启用删除按钮，无需你输入 DELETE。",
    ["AUTODELETE_TOGGLE_LINK"] = "显示物品链接",
    ["AUTODELETE_TOGGLE_LINK_DESC"] = "在确认弹窗中显示物品链接，让你看清将要删除的内容。",
})
