local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR, pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["INSPECTMOG_TITLE"] = "장비 살펴보기",
    ["INSPECTMOG_DESC"] = "살펴보기 창에 측면 패널을 추가하여 살펴보는 플레이어가 착용한 장비를 나열합니다. 전체 목록을 OneWoW Notes 플레이어 쪽지에 저장하거나, 아이템을 Shift-클릭하여 아이템 쪽지에 추가하세요.",

    ["INSPECTMOG_ADD_NOTE"] = "플레이어 쪽지에 추가",
    ["INSPECTMOG_ADD_ALL"] = "모두 추가",
    ["INSPECTMOG_EMPTY"] = "아직 살펴볼 장비가 없습니다.",
    ["INSPECTMOG_PANEL_TITLE"] = "형상변환 살펴보기 도구",
    ["INSPECTMOG_NO_DATA"] = "사용할 수 있는 살펴보기 데이터가 없습니다.",
    ["INSPECTMOG_UNKNOWN_PLAYER"] = "살펴본 플레이어",
    ["INSPECTMOG_NATIVE_APPEARANCE"] = "기본 외형",
    ["INSPECTMOG_SOURCE_FORMAT"] = "원본 #%d",
    ["INSPECTMOG_APPEARANCE_SOURCE_FORMAT"] = "외형 원본: %d",

    ["INSPECTMOG_TT_PREVIEW"] = "Ctrl-클릭하여 착장 시험실에서 미리 보기",
    ["INSPECTMOG_TT_NOTES"] = "Shift-클릭하여 Notes > 아이템에 추가",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED"] = "Shift-클릭하여 착용한 아이템을 Notes > 아이템에 추가",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED_COLL"] = "Shift-클릭하여 이 아이템의 외형을 Notes > 수집품에 추가",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE"] = "Shift-클릭하여 형상변환 외형을 Notes > 아이템에 추가",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE_COLL"] = "Shift-클릭하여 형상변환 외형을 Notes > 수집품에 추가",
    ["INSPECTMOG_ROUTE_COLLECTIBLES"] = "외형을 수집품에 추가",
    ["INSPECTMOG_TT_PREVIEW_EQUIPPED"] = "Ctrl-클릭하여 착용한 아이템 미리 보기",
    ["INSPECTMOG_TT_PREVIEW_APPEARANCE"] = "Ctrl-클릭하여 형상변환 외형 미리 보기",
    ["INSPECTMOG_TT_HIDDEN_APPEARANCE"] = "숨겨진 외형은 아이템 쪽지에 추가되지 않습니다",
    ["INSPECTMOG_TT_ADD_ALL_TITLE"] = "모든 형상변환 추가",
    ["INSPECTMOG_TT_ADD_ALL_DESC"] = "보이는 모든 형상변환 외형 아이템을 Notes > 아이템에 추가합니다.",

    ["INSPECTMOG_TT_ADD_NOTE_TITLE"] = "장비를 플레이어 쪽지에 저장",
    ["INSPECTMOG_TT_ADD_NOTE_DESC"] = "나열된 모든 부위와 아이템을 OneWoW Notes의 이 플레이어 쪽지에 기록합니다. 다시 저장하면 장비 블록이 갱신되고 쪽지의 나머지 부분은 유지됩니다.",

    ["INSPECTMOG_NOTE_HEADER"] = "[OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_FOOTER"] = "[/OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_UPDATED"] = "살펴봄: %s",
    ["INSPECTMOG_NOTE_LINE"] = "%s - %s",

    ["INSPECTMOG_ITEM_STAMP"] = "TMOG 살펴봄 %s - %s",

    ["INSPECTMOG_STATUS_NOTE_SAVED"] = "%s님의 쪽지에 장비를 저장했습니다.",
    ["INSPECTMOG_STATUS_NOTE_UPDATED"] = "%s님의 쪽지에서 장비를 갱신했습니다.",
    ["INSPECTMOG_STATUS_ITEM_ADDED"] = "%s을(를) 아이템 쪽지에 추가했습니다.",
    ["INSPECTMOG_STATUS_NOTES_MISSING"] = "OneWoW Notes가 설치되어 있지 않습니다.",
    ["INSPECTMOG_STATUS_NO_DATA"] = "아직 사용할 수 있는 장비 데이터가 없습니다.",
})
