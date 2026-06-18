local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["AUTOSUMMON_TITLE"] = "소환 자동 수락",
    ["AUTOSUMMON_DESC"] = "흑마법사와 소환의 돌의 소환 요청을 자동으로 수락합니다.",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT"] = "전투 중에는 건너뛰기",
    ["AUTOSUMMON_TOGGLE_SKIP_COMBAT_DESC"] = "전투 중에는 자동으로 수락하지 않습니다. 전투 도중 끌려가지 않도록 켜는 것을 권장합니다.",
})
