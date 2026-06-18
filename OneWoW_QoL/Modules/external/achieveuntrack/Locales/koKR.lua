local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (was English; now translated), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["ACHIEVEUNTRACK_TITLE"] = "완료한 업적 추적 해제",
    ["ACHIEVEUNTRACK_DESC"] = "접속 시 이미 완료한 업적을 자동으로 검색하여 추적을 해제합니다. 충돌이나 다른 캐릭터에서의 완료 후 멈출 수 있는 숨겨진 추적 슬롯을 비웁니다.",
})
