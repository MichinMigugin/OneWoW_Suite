local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["ACHIEVEUNTRACK_TITLE"] = "取消追蹤已完成成就",
    ["ACHIEVEUNTRACK_DESC"] = "在你登入時自動掃描並取消追蹤已完成的成就。釋放在當機或跨角色完成後可能卡住的隱藏追蹤欄位。",
})
