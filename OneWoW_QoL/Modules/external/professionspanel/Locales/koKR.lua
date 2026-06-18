local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["PROFPANEL_TITLE"] = "전문기술 패널",
    ["PROFPANEL_DESC"] = "전문기술 창 옆에 확장팩별 숙련도 분석, 제조법 수, 첫 제작 추적이 담긴 보조 패널을 표시합니다.",
    ["PROFPANEL_AUTO_SHOW"] = "패널 자동 표시",
    ["PROFPANEL_TOGGLE_TIP"] = "전문기술 통계 패널",
    ["PROFPANEL_HIDE_TIP"] = "클릭하여 패널 숨기기",
    ["PROFPANEL_SHOW_TIP"] = "클릭하여 패널 표시",
    ["PROFPANEL_STATS_TITLE"] = "전문기술 패널",
    ["PROFPANEL_NO_EXPANSION_DATA"] = "사용할 수 있는 확장팩 데이터가 없습니다.\n전문기술을 열어 검색하세요.",
    ["PROFPANEL_NO_ALT_DATA"] = "이 전문기술을 가진 다른 부캐릭터가 없습니다",
    ["PROFPANEL_OTHER_ALTS"] = "이 전문기술을 가진 다른 부캐릭터",
    ["PROFPANEL_LAST_SCANNED"] = "마지막 검색: %s",
})
