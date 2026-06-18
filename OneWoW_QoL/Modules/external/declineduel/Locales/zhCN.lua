local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["DECLINEDUEL_TITLE"] = "自动拒绝决斗",
    ["DECLINEDUEL_DESC"] = "自动拒绝决斗请求，使弹窗永远不会停留在你的屏幕上。",
    ["DECLINEDUEL_TOGGLE_PET"] = "也拒绝宠物决斗",
    ["DECLINEDUEL_TOGGLE_PET_DESC"] = "也自动拒绝宠物对战决斗请求。",
})
