local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["AUTOREPAIR_TITLE"] = "자동 수리",
    ["AUTOREPAIR_DESC"] = "수리를 지원하는 상인을 방문하면 모든 장비를 자동으로 수리합니다. 비용을 대화창에 표시합니다.",
    ["AUTOREPAIR_TOGGLE_GUILD"] = "길드 은행 수리 사용",
    ["AUTOREPAIR_TOGGLE_GUILD_DESC"] = "자신의 골드를 사용하기 전에 길드 은행으로 수리 비용을 충당하려고 시도합니다.",
})
