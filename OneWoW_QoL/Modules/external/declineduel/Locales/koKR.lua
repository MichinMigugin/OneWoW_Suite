local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["DECLINEDUEL_TITLE"] = "결투 자동 거절",
    ["DECLINEDUEL_DESC"] = "결투 요청을 자동으로 거절하여 팝업이 화면에 남아 있지 않게 합니다.",
    ["DECLINEDUEL_TOGGLE_PET"] = "애완동물 결투도 거절",
    ["DECLINEDUEL_TOGGLE_PET_DESC"] = "애완동물 대전 결투 요청도 자동으로 거절합니다.",
})
