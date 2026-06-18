local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["AUTOREADYCHECK_TITLE"] = "自動接受準備確認",
    ["AUTOREADYCHECK_DESC"] = "當你的隊伍中發起準備確認時自動確認準備就緒。",
    ["AUTOREADYCHECK_TOGGLE_DEAD"] = "死亡時跳過",
    ["AUTOREADYCHECK_TOGGLE_DEAD_DESC"] = "在你死亡或為靈魂狀態時不自動接受，以便隊伍看到你尚未準備好開怪。",
})
