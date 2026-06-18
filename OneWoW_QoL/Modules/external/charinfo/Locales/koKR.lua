local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["CHARINFO_TITLE"] = "캐릭터 정보 시트",
    ["CHARINFO_DESC"] = "캐릭터 시트에서 착용한 각 아이템 옆에 깔끔한 정보 패널을 표시하여 아이템 레벨(품질별 색상), 마법부여 상태, 보석 상태, 내구도 백분율을 보여줍니다.",
    ["CHARINFO_ENCHANTED"] = "마법부여됨",
    ["CHARINFO_MISSING_ENCHANT"] = "마법부여 없음",
    ["CHARINFO_NO_ENCHANT_NEEDED"] = "마법부여 불필요",
    ["CHARINFO_ALL_SOCKETS_EMPTY"] = "모든 홈 비어 있음",
    ["CHARINFO_SOME_SOCKETS_EMPTY"] = "일부 홈 비어 있음",
    ["CHARINFO_ALL_SOCKETS_FILLED"] = "모든 홈 채워짐",
    ["CHARINFO_NO_SOCKETS"] = "홈 없음",
    ["CHARINFO_TOGGLE_DURABILITY"] = "내구도 표시",
    ["CHARINFO_TOGGLE_DURABILITY_DESC"] = "아이템 버튼에 내구도 백분율을 표시합니다",
    ["CHARINFO_TOGGLE_SOCKETS"] = "홈 없음 아이콘 표시",
    ["CHARINFO_TOGGLE_SOCKETS_DESC"] = "아이템에 홈이 없을 때 아이콘을 표시합니다",
    ["CHARINFO_ENCHANT_SLOTS_HEADER"] = "마법부여 슬롯 추적",
    ["CHARINFO_ENCHANT_SLOTS_DESC"] = "마법부여를 추적할 장비 슬롯을 선택하세요. 비활성화된 슬롯은 마법부여 상태 아이콘을 표시하지 않습니다.",
    ["CHARINFO_SLOT_HEAD"] = "머리",
    ["CHARINFO_SLOT_NECK"] = "목",
    ["CHARINFO_SLOT_SHOULDER"] = "어깨",
    ["CHARINFO_SLOT_CHEST"] = "가슴",
    ["CHARINFO_SLOT_WAIST"] = "허리",
    ["CHARINFO_SLOT_LEGS"] = "다리",
    ["CHARINFO_SLOT_FEET"] = "발",
    ["CHARINFO_SLOT_WRIST"] = "손목",
    ["CHARINFO_SLOT_HANDS"] = "손",
    ["CHARINFO_SLOT_RING1"] = "반지 1",
    ["CHARINFO_SLOT_RING2"] = "반지 2",
    ["CHARINFO_SLOT_BACK"] = "등",
    ["CHARINFO_SLOT_MAINHAND"] = "주장비",
    ["CHARINFO_SLOT_OFFHAND"] = "보조장비",
    ["FEATURES_ON"] = "켜짐",
    ["FEATURES_OFF"] = "꺼짐",
})
