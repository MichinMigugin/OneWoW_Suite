local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["AUTOSUMMON_TITLE"] = "自動接受召喚",
    ["AUTOSUMMON_DESC"] = "自動接受來自術士和召喚石的召喚請求。",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT"] = "戰鬥中跳過",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT_DESC"] = "在你處於戰鬥中時不自動接受。建議開啟，以免戰鬥中被拉走。",
})
