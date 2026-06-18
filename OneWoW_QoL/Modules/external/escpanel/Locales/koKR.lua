local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["ESCPANEL_TITLE"] = "ESC 메뉴 패널",
    ["ESCPANEL_DESC"] = "ESC 메뉴 옆에 캐릭터 정보, 알림, 지역 쪽지, 차원문 띠를 표시합니다. 아래에서 각 항목이 사용할 쪽을 선택하세요.",
    ["ESCPANEL_TOGGLE_SHOW_CHARACTER"] = "캐릭터 정보 표시",
    ["ESCPANEL_TOGGLE_ALERTS"] = "알림 표시",
    ["ESCPANEL_TOGGLE_ZONE_NOTES"] = "지역 쪽지 표시",
    ["ESCPANEL_TOGGLE_HIDE_ZONE_EMPTY"] = "비어 있으면 지역 쪽지 숨기기",
    ["ESCPANEL_TOGGLE_SHOW_PORTALS"] = "차원문 표시",
    ["ESCPANEL_LAYOUT_HEADER"] = "배치",
    ["ESCPANEL_PANELS_SIDE_LABEL"] = "정보 패널 쪽",
    ["ESCPANEL_PORTALS_SIDE_LABEL"] = "차원문 쪽",
    ["ESCPANEL_SIDE_LEFT"] = "메뉴 왼쪽",
    ["ESCPANEL_SIDE_RIGHT"] = "메뉴 오른쪽",
    ["ESCPANEL_LAYOUT_DESC"] = "둘 다 같은 쪽에 있으면 차원문이 바깥쪽(메뉴에서 더 멀리)에 놓이고 패널은 메뉴 옆에 놓입니다.",
    ["ESCPANEL_ICON_SIZE_LABEL"] = "차원문 아이콘 크기",
})
