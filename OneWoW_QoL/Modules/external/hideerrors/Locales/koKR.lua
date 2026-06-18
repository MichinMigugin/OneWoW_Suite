local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["HIDEERRORS_TITLE"] = "전투 오류 도배 숨기기",
    ["HIDEERRORS_DESC"] = "가장 흔한 빨간색 오류 메시지(마나 부족, 사정거리 밖, 대상이 앞에 있어야 함, 주문 준비 안 됨 등)를 숨겨 전투 중 화면 중앙을 깔끔하게 유지합니다.",
})
