local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "koKR", {

    ["BAGBAR_TITLE"] = "가방 바",
    ["BAGBAR_DESC"] = "사용 가능한 가방 아이템을 이동할 수 있는 바에 표시합니다. 아이템은 PredicateEngine 표현식으로 선택되며(가방 검색과 같은 표현 어휘), 착용 가능한 장비는 항상 바에서 제외됩니다(자동으로 적용되며 편집기에는 나타나지 않음).",
    ["BAGBAR_LOCK_POSITION"] = "위치 고정",
    ["BAGBAR_MAX_BUTTONS"] = "최대 버튼 수",
    ["BAGBAR_SHIFT_RIGHT_CLICK_TO_SKIP"] = "Shift+오른쪽 클릭: 이번 접속 동안 건너뛰기",
    ["BAGBAR_ALT_RIGHT_CLICK_TO_BLACKLIST"] = "Alt+오른쪽 클릭: 영구 차단 목록에 추가",
    ["BAGBAR_MANUAL_ITEMS_HEADER"] = "수동 아이템",
    ["BAGBAR_MANUAL_DESC"] = "특정 아이템을 고정하면 바에서 우선 표시됩니다. 여전히 표현식 필터와 바 사용 규칙을 만족해야 합니다.",
    ["BAGBAR_MACROS_HEADER"] = "수동 매크로",
    ["BAGBAR_MACROS_DESC"] = "매크로를 사용자 지정 버튼으로 바에 추가합니다. 매크로 창에서 매크로를 끌어 놓기 영역으로 가져오거나, 매크로 이름을 입력하고 추가를 클릭하세요. 매크로는 가방 아이템보다 먼저 표시됩니다.",
    ["BAGBAR_MACRO_NAME_LABEL"] = "매크로 이름:",
    ["BAGBAR_DRAG_MACRO_HERE"] = "여기로 매크로 끌어오기",
    ["BAGBAR_MACRO_LEFT_CLICK_TO_RUN"] = "왼쪽 클릭하여 매크로 실행",
    ["BAGBAR_MACRO_MISSING"] = "(없음)",
    ["BAGBAR_BLACKLIST_DESC"] = "바 위 아이템을 Shift+오른쪽 클릭하면 이번 접속 동안 건너뛰고, Alt+오른쪽 클릭하면 영구 차단합니다.",
    ["BAGBAR_COLUMNS"] = "열",
    ["BAGBAR_CONTEXT_LOCK"] = "위치 고정",
    ["BAGBAR_GROW_RIGHT"] = "오른쪽",
    ["BAGBAR_GROW_LEFT"] = "왼쪽",
    ["BAGBAR_EXPRESSION_FILTER_HEADER"] = "표현식 필터",
    ["BAGBAR_EXPRESSION_FILTER_DESC"] = "가방에 어떤 아이템이 나타날 수 있는지 정하는 PredicateEngine 표현식입니다(가방 검색과 동일한 키워드). ?를 눌러 도움말을 보세요. 착용 가능한 장비는 이 표현식과 별도로 항상 제외됩니다.",
    ["BAGBAR_EXPRESSION_FILTER_PLACEHOLDER"] = "예: #usable & #mount",
})
