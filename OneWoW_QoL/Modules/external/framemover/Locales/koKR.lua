local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted (Phase 4) — koKR (was English; now translated), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["FRAMEMOVER_TITLE"] = "프레임 이동기",
    ["FRAMEMOVER_DESC"] = "블리자드 UI 프레임을 끌어 위치를 바꿉니다. Ctrl+스크롤로 크기를 조절하세요. 위치와 크기는 세션 간에 유지될 수 있습니다.",

    ["FRAMEMOVER_TOGGLE_REQUIRE_SHIFT"] = "끌려면 Shift 필요",
    ["FRAMEMOVER_TOGGLE_ENABLE_SCALING"] = "Ctrl+스크롤 크기 조절",
    ["FRAMEMOVER_TOGGLE_SAVE_POSITIONS"] = "위치 기억",
    ["FRAMEMOVER_TOGGLE_SAVE_SCALES"] = "크기 기억",
    ["FRAMEMOVER_TOGGLE_CLAMP_SCREEN"] = "화면 안으로 제한",

    ["FRAMEMOVER_GROUP_BEHAVIOR"] = "동작",
    ["FRAMEMOVER_GROUP_SAVING"] = "유지",

    ["FRAMEMOVER_CAT_CORE"] = "핵심 UI",
    ["FRAMEMOVER_CAT_COLLECTIONS"] = "수집 및 일지",
    ["FRAMEMOVER_CAT_PROFESSIONS"] = "전문기술 및 경제",
    ["FRAMEMOVER_CAT_GROUP"] = "그룹 콘텐츠",
    ["FRAMEMOVER_CAT_CHARACTER"] = "캐릭터 및 특성",
    ["FRAMEMOVER_CAT_SOCIAL"] = "친목 및 길드",
    ["FRAMEMOVER_CAT_MISC"] = "기타",
    ["FRAMEMOVER_CAT_HOUSING"] = "주택",

    ["FRAMEMOVER_FRAMES_HEADER"] = "이동 가능한 프레임",
    ["FRAMEMOVER_RESET_POSITIONS"] = "모든 위치 초기화",
    ["FRAMEMOVER_RESET_SCALES"] = "모든 크기 초기화",
    ["FRAMEMOVER_RESET_POS_DONE"] = "위치를 초기화했습니다. 프레임을 다시 열어 기본값을 확인하세요.",
    ["FRAMEMOVER_RESET_SCALE_DONE"] = "크기를 초기화했습니다. 프레임을 다시 열어 기본값을 확인하세요.",
    ["FRAMEMOVER_ENABLED_TOOLTIP"] = "왼쪽 클릭하여 전환. 프레임 위에서 Ctrl+스크롤로 크기를 조절합니다.",
    ["FEATURES_ON"] = "켜짐",
    ["FEATURES_OFF"] = "꺼짐",
})
