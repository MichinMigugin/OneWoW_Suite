local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["PLAYMOUNTS_TITLE"] = "플레이어 탈것",
    ["PLAYMOUNTS_DESC"] = "다른 플레이어가 현재 사용 중인 탈것이나 이동 형상을 감지하여 표시합니다.",
    ["PLAYMOUNTS_TOGGLE_CHAT"] = "대화창에 알림",
    ["PLAYMOUNTS_TOGGLE_CHAT_DESC"] = "탈것에 탄 플레이어를 선택하면 대화창에 탈것 이름을 표시합니다.",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT"] = "탈것 맞추기",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT_DESC"] = "플레이어에 오른쪽 클릭 옵션을 추가하여 그들이 타고 있는 것과 같은 종류의 탈것을 소환합니다.",
    ["PLAYMOUNTS_COLLECTED"] = "(수집함)",
    ["PLAYMOUNTS_NOT_COLLECTED"] = "(수집 안 함)",
    ["PLAYMOUNTS_USING"] = "%s님이 %s 사용 중",
    ["PLAYMOUNTS_SOURCE"] = "출처: %s",
    ["PLAYMOUNTS_DISPLAYMODE_DESC"] = "툴팁과 대화창 출력에 표시되는 탈것 정보의 양을 조절합니다.",
    ["PLAYMOUNTS_MODE_NAME"] = "이름",
    ["PLAYMOUNTS_MODE_NAMETYPE"] = "이름 + 종류",
    ["PLAYMOUNTS_MODE_ALL"] = "전체 세부 정보",
    ["PLAYMOUNTS_TOOLTIP_HEADER"] = "툴팁 연동",
    ["PLAYMOUNTS_TOOLTIP_REQUIRES"] = "필요: OneWoW Core",
    ["PLAYMOUNTS_TOOLTIP_DETECTED"] = "상태: 감지됨",
    ["PLAYMOUNTS_TOOLTIP_NOT_DETECTED"] = "상태: 감지되지 않음",
    ["PLAYMOUNTS_TOOLTIP_NOTE"] = "탈것 툴팁 줄은 QoL → 툴팁 → 플레이어 탈것에서 켜거나 끌 수 있습니다.",
    ["PLAYMOUNTS_TOOLTIP_VIEW_BTN"] = "설정 보기",
})
