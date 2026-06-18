local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR, pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["MAPWORLD_TITLE"] = "지도(전체) 도구",
    ["MAPWORLD_DESC"] = "전체 지도: 클라이언트 데이터로 미탐험 지형 표시, 선택적 색조, 전장 지도 조정, 좌표, 그리고 작은 편의/정리 옵션.",

    ["MAPWORLD_GROUP_EXPLORE"] = "탐험 (지도 그림)",
    ["MAPWORLD_GROUP_FOGOVERLAY"] = "안개 오버레이 (어두운 층)",
    ["MAPWORLD_GROUP_FRAME"] = "지도 창",
    ["MAPWORLD_GROUP_COMFORT"] = "편의",
    ["MAPWORLD_GROUP_CLEANUP"] = "정리",
    ["MAPWORLD_GROUP_COORDS"] = "좌표",
    ["MAPWORLD_GROUP_POI"] = "관심 지점",
    ["MAPWORLD_GROUP_BATTLE"] = "전장 지도",
    ["MAPWORLD_GROUP_POLISH"] = "마무리",
    ["MAPWORLD_GROUP_CANVAS"] = "전체 지도 오버레이",
    ["MAPWORLD_GROUP_MAP"] = "전체 지도 창",

    ["MAPWORLD_REVEAL_MAP"] = "미탐험 지역 표시",
    ["MAPWORLD_REVEAL_MAP_DESC"] = "포함된 지도 그림 데이터를 사용하여 누락된 탐험 타일을 그립니다(종이 지도를 펼치는 것과 같은 개념). 전체 지도와 전장 지도에서 작동합니다.",

    ["MAPWORLD_TINT_UNEXPLORED"] = "미탐험 지역에 색조 적용",
    ["MAPWORLD_TINT_UNEXPLORED_DESC"] = "위 옵션으로 드러난 타일에 색조를 적용합니다(지역 지도만).",

    ["MAPWORLD_UNEX_R"] = "미탐험 빨강",
    ["MAPWORLD_UNEX_G"] = "미탐험 초록",
    ["MAPWORLD_UNEX_B"] = "미탐험 파랑",
    ["MAPWORLD_UNEX_A"] = "미탐험 불투명도",

    ["MAPWORLD_REMOVE_FOG"] = "어두운 안개 층 숨기기",
    ["MAPWORLD_REMOVE_FOG_DESC"] = "지도 위에 있는 블리자드의 전장의 안개 프레임을 숨깁니다(누락된 탐험 그림을 그리는 것과는 별개).",

    ["MAPWORLD_FOG_TINT"] = "안개 층에 색조 적용 (전장의 안개)",
    ["MAPWORLD_FOG_TINT_DESC"] = "어두운 안개 층이 보일 때 그 색을 곱합니다.",

    ["MAPWORLD_CLEAR_BLACKOUT"] = "지도 뒤 세계 클릭 통과",
    ["MAPWORLD_CLEAR_BLACKOUT_DESC"] = "지도 뒤의 어두운 “암전”을 투명하게 만들고 클릭을 막지 않게 하여 세계가 또렷하게 보이도록 합니다.",

    ["MAPWORLD_NO_MAP_FADE"] = "이동 중 지도 흐려짐 비활성화",
    ["MAPWORLD_NO_MAP_FADE_DESC"] = "mapFade를 설정하여 캐릭터가 이동할 때 지도가 반투명해지지 않도록 합니다.",

    ["MAPWORLD_NO_MAP_EMOTE"] = "읽기 감정표현 비활성화",
    ["MAPWORLD_NO_MAP_EMOTE_DESC"] = "지도를 열 때 읽기 감정표현을 취소합니다.",

    ["MAPWORLD_HIDE_FILTER_RESET"] = "필터 초기화 UI 숨기기",
    ["MAPWORLD_HIDE_FILTER_RESET_DESC"] = "전체 지도 필터 초기화 컨트롤과 관련 카운터 배너를 숨깁니다.",

    ["MAPWORLD_HIDE_MAP_TUTORIAL"] = "지도 튜토리얼 숨기기",
    ["MAPWORLD_HIDE_MAP_TUTORIAL_DESC"] = "전체 지도 튜토리얼 프레임을 숨기고 정보 프레임에서 닫힘으로 표시합니다.",

    ["MAPWORLD_SHOW_COORDS"] = "좌표 표시",
    ["MAPWORLD_SHOW_COORDS_DESC"] = "지도 창에 커서와 플레이어 위치를 표시합니다.",

    ["MAPWORLD_COORDS_LARGE"] = "큰 좌표 글꼴",
    ["MAPWORLD_COORDS_LARGE_DESC"] = "좌표 표시에 더 큰 글꼴을 사용합니다.",

    ["MAPWORLD_COORDS_BG"] = "좌표 막대 배경",
    ["MAPWORLD_COORDS_BG_DESC"] = "좌표 글자 뒤에 어두운 띠를 표시합니다.",

    ["MAPWORLD_HIDE_CONTINENT_POI"] = "대륙에서 마을/도시 관심 지점 숨기기",
    ["MAPWORLD_HIDE_CONTINENT_POI_DESC"] = "대륙 및 전체 지도 보기에서 특정 고향, 진영, 도시 표식을 숨깁니다.",

    ["MAPWORLD_ENHANCE_BATTLE_MAP"] = "전장 지도 향상",
    ["MAPWORLD_ENHANCE_BATTLE_MAP_DESC"] = "전장 지도에 파티를 표시하고 아래 옵션을 활성화합니다.",

    ["MAPWORLD_UNLOCK_BATTLEFIELD"] = "끌어서 전장 지도 이동",
    ["MAPWORLD_UNLOCK_BATTLEFIELD_DESC"] = "전장 지도를 안쪽 영역으로 끌어서 이동합니다.",

    ["MAPWORLD_BATTLE_CENTER"] = "전장 지도를 플레이어 중심으로 유지",
    ["MAPWORLD_BATTLE_CENTER_DESC"] = "전장 지도를 당신의 위치에 다시 중앙 정렬합니다. 끄는 동안 Shift를 누르면 일시 중지됩니다.",

    ["MAPWORLD_BATTLE_OPACITY"] = "전장 지도 가시성",
    ["MAPWORLD_BATTLE_GROUP"] = "파티 아이콘 크기",
    ["MAPWORLD_BATTLE_PLAYER"] = "플레이어 화살표 크기",

    ["MAPWORLD_TINT_MENU"] = "전체 지도 메뉴 색조 전환",
    ["MAPWORLD_TINT_MENU_DESC"] = "지도 추적 메뉴에 “미탐험 색조” 확인란을 추가합니다(메뉴 API가 바뀌면 로드되지 않을 수 있음).",

    ["MAPWORLD_CANVAS_TINT"] = "전체 지도 색상 오버레이",
    ["MAPWORLD_CANVAS_TINT_DESC"] = "지도 전체 화면을 반투명 색으로 칠합니다(탐험 색조와는 별개).",

    ["MAPWORLD_MAP_ALPHA"] = "전체 지도 불투명도",
    ["MAPWORLD_MAP_ALPHA_DESC"] = "전체 지도 창 전체의 불투명도를 낮춥니다(프레임 알파).",

    ["MAPWORLD_MAP_ALPHA_SLIDER"] = "지도 창 불투명도",
    ["MAPWORLD_RED"] = "빨강",
    ["MAPWORLD_GREEN"] = "초록",
    ["MAPWORLD_BLUE"] = "파랑",

    ["MAPWORLD_CURSOR"] = "커서",
})
