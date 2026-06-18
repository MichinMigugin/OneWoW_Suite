local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["HIDEERRORS_TITLE"] = "隐藏战斗错误刷屏",
    ["HIDEERRORS_DESC"] = "隐藏最常见的红色错误信息（法力不足、超出距离、目标必须在面前、法术未就绪等），使屏幕中央在战斗期间保持整洁。",
})
