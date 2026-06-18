local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["AUTORESURRECT_TITLE"] = "自動接受復活",
    ["AUTORESURRECT_DESC"] = "當有人對你施放復活時自動接受復活請求。戰鬥中會跳過。",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE"] = "副本中不接受",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE_DESC"] = "在你身處地城、團隊副本、戰場或競技場時跳過自動接受。如果你想等待合適的時機復活，會很有用。",
})
