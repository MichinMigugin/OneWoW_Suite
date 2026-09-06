local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["AFKPANEL_TITLE"] = "자리 비움 패널",
    ["AFKPANEL_DESC"] = "ESC 메뉴와 같은 You/Here 카드, 실시간 우편과 경매 알림, Notes가 켜져 있을 때만 보이는 일일/주간 쪽지가 있는 전체 화면 자리 비움 오버레이입니다.",
    ["AFKPANEL_CAMERA_SPIN"] = "카메라 회전",
    ["AFKPANEL_SHOW_DAILY"] = "일일 쪽지 표시",
    ["AFKPANEL_SHOW_WEEKLY"] = "주간 쪽지 표시",
    ["AFKPANEL_MODE_TITLE"] = "OneWoW QoL - 자리 비움 모드",
    ["AFKPANEL_CHARACTER_INFO"] = "캐릭터 정보",
    ["AFKPANEL_ALERTS"] = "알림",
    ["AFKPANEL_NO_ALERTS"] = "현재 알림 없음",
    ["AFKPANEL_AFK_TIME"] = "자리 비움: %s",
    ["AFKPANEL_DAILY_NOTES"] = "일일 쪽지",
    ["AFKPANEL_WEEKLY_NOTES"] = "주간 쪽지",
    ["AFKPANEL_NO_NOTES"] = "표시할 쪽지 없음",
    ["AFKPANEL_NO_GUILD"] = "길드 없음",
})
