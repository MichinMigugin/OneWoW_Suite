local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["COORDS_TITLE"] = "좌표 표시",
    ["COORDS_DESC"] = "미니맵 근처의 작은 이동 가능한 프레임에 현재 지도 좌표를 표시합니다. 오른쪽 클릭하여 좌표를 복사합니다.",
    ["COORDS_TOGGLE_MAPID"] = "지도 ID 표시",
    ["COORDS_TOGGLE_MAPID_DESC"] = "좌표 옆에 숫자 지도 ID를 표시합니다.",
    ["COORDS_TOGGLE_ZONE"] = "지역 이름 표시",
    ["COORDS_TOGGLE_ZONE_DESC"] = "좌표 아래에 현재 지역 이름을 표시합니다.",
    ["COORDS_TOGGLE_SUBZONE"] = "하위 지역 표시",
    ["COORDS_TOGGLE_SUBZONE_DESC"] = "현재 하위 지역 또는 구역 이름을 표시합니다.",
    ["COORDS_TOGGLE_FACING"] = "방향 표시",
    ["COORDS_TOGGLE_FACING_DESC"] = "현재 향하는 방향을 각도와 나침반 방위로 표시합니다.",
    ["COORDS_TOGGLE_SPEED"] = "속도 표시",
    ["COORDS_TOGGLE_SPEED_DESC"] = "현재 이동 속도를 초당 야드로 표시합니다.",
    ["COORDS_TOGGLE_HIDE_INSTANCE"] = "인스턴스에서 숨기기",
    ["COORDS_TOGGLE_HIDE_INSTANCE_DESC"] = "던전, 공격대 또는 기타 인스턴스 안에 있을 때 좌표 표시를 자동으로 숨깁니다.",
    ["COORDS_MAP"] = "지도: %d",
    ["COORDS_COPIED"] = "좌표 복사됨: %s",
    ["COORDS_COPY_TITLE"] = "좌표",
})
