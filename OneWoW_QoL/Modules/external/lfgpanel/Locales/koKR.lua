local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["LFGPANEL_TITLE"] = "파티 찾기 입장 제한",
    ["LFGPANEL_DESC"] = "공동체 찾기가 열려 있을 때 현재 공격대 및 던전 입장 제한을 측면 패널에 표시합니다.",
    ["LFGPANEL_SHOW_PANEL"] = "입장 제한 패널 표시",
    ["LFGPANEL_SHOW_PANEL_DESC"] = "공동체 찾기가 열릴 때 입장 제한 패널을 표시합니다.",
    ["LFGPANEL_FILTER_RESULTS"] = "파티 찾기 결과 필터링",
    ["LFGPANEL_FILTER_RESULTS_DESC"] = "선택한 난이도로 파티 찾기 검색 결과를 필터링합니다.",

    ["LFGPANEL_TT_REFRESH"] = "입장 제한 새로 고침",
    ["LFGPANEL_TT_REFRESH_DESC"] = "서버에서 최신 입장 제한 데이터를 요청합니다.",
    ["LFGPANEL_TT_TOGGLE"] = "입장 제한 패널 표시",
    ["LFGPANEL_TT_TOGGLE_DESC"] = "클릭하여 입장 제한 패널을 표시합니다.",

    ["LFGPANEL_FILTER_DIFFICULTY"] = "난이도",
    ["LFGPANEL_DIFFICULTY_NORMAL"] = "일반",
    ["LFGPANEL_DIFFICULTY_HEROIC"] = "영웅",
    ["LFGPANEL_DIFFICULTY_MYTHIC"] = "신화",
    ["LFGPANEL_DIFFICULTY_MYTHICPLUS"] = "신화+",
    ["LFGPANEL_DIFFICULTY_LFR"] = "LFR",

    ["LFGPANEL_NO_LOCKOUTS"] = "활성 입장 제한이 없습니다.",
    ["LFGPANEL_NO_LOCKOUTS_FILTERED"] = "선택한 난이도에 맞는 입장 제한이 없습니다.",
    ["LFGPANEL_EXPIRED"] = "만료됨",
    ["LFGPANEL_EXTENDED"] = "연장됨",
    ["LFGPANEL_TT_EXTENDED"] = "연장된 입장 제한",
    ["LFGPANEL_TT_EXTENDED_DESC"] = "이 입장 제한은 일반 초기화를 넘어 수동으로 연장되었습니다.",

    ["LFGPANEL_TIME_DAYS"] = "%d일 %d시간",
    ["LFGPANEL_TIME_HOURS"] = "%d시간 %d분",
    ["LFGPANEL_TIME_MINUTES"] = "%d분",
    ["LFGPANEL_PROGRESS"] = "%d/%d",

    ["LFGPANEL_TT_LOCKOUT"] = "인스턴스 입장 제한",
    ["LFGPANEL_TT_LOCKOUT_PROGRESS"] = "우두머리 진행도: %d/%d",
    ["LFGPANEL_TT_LOCKOUT_TIME"] = "초기화까지: %s",
    ["LFGPANEL_TT_LOCKOUT_DIFFICULTY"] = "난이도: %s",

    ["LFGPANEL_OPT_FILTER_LFG"] = "파티 찾기 결과 필터링",
    ["LFGPANEL_TT_FILTER_LFG"] = "파티 찾기 결과 필터링",
    ["LFGPANEL_TT_FILTER_LFG_DESC"] = "활성화하면 파티 찾기 검색 결과가 선택한 난이도에 맞게 필터링됩니다.",
})
