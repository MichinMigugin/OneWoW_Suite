local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["AUTOOPEN_TITLE"] = "자동 열기",
    ["AUTOOPEN_DESC"] = "가방, 상자 및 기타 보관 아이템이 가방에 나타나면 자동으로 엽니다. 은행, 우편함 또는 상인에서는 아이템을 열지 않습니다. 아직 열 수 없는 아이템(잠긴 자물쇠 상자, 잘못된 레벨/직업/전문기술, 또는 칸이 사용 중일 때)은 자동으로 건너뜁니다.",
    ["AUTOOPEN_OPENING"] = "자동 열기: %s",
    ["AUTOOPEN_BLACKLIST_DESC"] = "자동 열기가 열지 않도록 아이템을 추가하세요.",
    ["AUTOOPEN_BLACKLIST_REMOVED"] = "차단 목록에서 제거됨: %s",
})
