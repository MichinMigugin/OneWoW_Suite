local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["FASTFORWARD_TITLE"] = "快进",
    ["FASTFORWARD_DESC"] = "自动跳过游戏内影片和过场动画。在影片或过场动画开始时按住任意修饰键即可改为观看。",
    ["FASTFORWARD_TOGGLE_MOVIES"] = "跳过影片",
    ["FASTFORWARD_TOGGLE_MOVIES_DESC"] = "在游戏内影片开始播放时自动停止。",
    ["FASTFORWARD_TOGGLE_CINEMATICS"] = "跳过过场动画",
    ["FASTFORWARD_TOGGLE_CINEMATICS_DESC"] = "在游戏内过场动画序列开始时自动取消。",
    ["FASTFORWARD_TOGGLE_INSTANCE"] = "仅在副本中",
    ["FASTFORWARD_TOGGLE_INSTANCE_DESC"] = "仅在你身处地下城、团队副本或其他副本中时跳过影片和过场动画。",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE"] = "尊重不可取消项",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE_DESC"] = "不尝试跳过游戏标记为无法取消的过场动画。",
})
