local ADDON_NAME = ...

OneWoW.Locale:Register(ADDON_NAME, "koKR", {
    ["ADDON_TITLE"] = "자동 입금",
    ["ADDON_SUBTITLE"] = "워밴드 은행 골드 자동 관리",

    ["ENABLED"] = "활성화됨",
    ["DISABLED"] = "비활성화됨",

    ["TAB_GOLD"] = "골드",

    ["DIRECT_DEPOSIT_TITLE"] = "자동 입금",
    ["DIRECT_DEPOSIT_DESCRIPTION"] = "캐릭터와 워밴드 은행 사이의 골드를 자동으로 관리합니다. 캐릭터에 유지할 목표 금액을 설정하면 시스템이 초과 골드를 입금하거나 부족할 때 인출합니다. 여러 캐릭터 간 골드 관리에 완벽합니다.",
    ["DIRECT_DEPOSIT_ENABLE"] = "자동 입금 활성화",
    ["DIRECT_DEPOSIT_ENABLE_DESC"] = "은행을 열 때 워밴드 은행에서 골드를 자동으로 입금하거나 인출하여 캐릭터의 목표 금액을 유지합니다.",

    ["ACCOUNT_SETTINGS"] = "계정 전체 설정",
    ["ACCOUNT_SETTINGS_DESC"] = "이 설정은 계정의 모든 캐릭터에 적용됩니다.",

    ["CHARACTER_SETTINGS"] = "캐릭터별 재정의",
    ["CHARACTER_SETTINGS_DESC"] = "이 특정 캐릭터에 대한 사용자 정의 설정으로 계정 전체 설정을 재정의합니다. 은행 부캐나 특별한 골드 관리가 필요한 캐릭터에 유용합니다.",

    ["USE_CHAR_SETTINGS"] = "캐릭터별 설정 사용",
    ["USE_CHAR_SETTINGS_DESC"] = "계정 전체 설정 대신 이 캐릭터에 대해 다른 설정을 사용하려면 활성화하십시오.",

    ["TARGET_GOLD"] = "캐릭터에 유지할 금액",
    ["TARGET_GOLD_DESC"] = "캐릭터에 유지할 골드 금액(골드 단위)을 입력하십시오. 비워 두면 값을 입력할 때까지 자동 골드 이동이 비활성화됩니다. 0 = 캐릭터에 골드를 남기지 않음.",
    ["GOLD"] = "골드",

    ["DEPOSIT_ENABLE"] = "워밴드 은행에 골드 입금",
    ["DEPOSIT_ENABLE_DESC"] = "목표 금액보다 많을 때 초과분을 워밴드 은행에 자동으로 입금합니다.",

    ["WITHDRAW_ENABLE"] = "워밴드 은행에서 골드 인출",
    ["WITHDRAW_ENABLE_DESC"] = "목표 금액보다 적을 때 워밴드 은행에서 자동으로 인출하여 목표에 도달합니다.",

    ["ITEM_DEPOSIT"] = "아이템 자동 입금",
    ["ITEM_DEPOSIT_ENABLE"] = "아이템 자동 입금 활성화",
    ["ITEM_DEPOSIT_ENABLE_DESC"] = "은행을 열 때 선택한 은행에 특정 아이템을 자동으로 입금합니다.",
    ["ITEM_DEPOSIT_LIST"] = "자동 입금 아이템 목록",
    ["ITEM_DEPOSIT_ADD"] = "아이템 추가",
    ["ITEM_DEPOSIT_ADD_PROMPT"] = "아이템 ID를 입력하거나 Shift+클릭하여 추가:",
    ["ITEM_DEPOSIT_WARBAND"] = "워밴드",
    ["ITEM_DEPOSIT_PERSONAL"] = "개인",

    ["CLEAR"] = "지우기",

    ["ABOUT_SECTION"] = "자동 입금 정보",
    ["ABOUT_TEXT"] = "자동 입금은 OneWoW Suite의 편의성 애드온입니다. 이 애드온은 또한 World of Warcraft 경험을 향상시키는 많은 다른 유용한 애드온을 포함하는 완전한 OneWoW Suite의 일부로 제공됩니다. 모험을 정리하고 게임 플레이를 개선하는 데 도움이 되는 더 많은 애드온을 찾아보세요!",

    ["MINIMAP_TOOLTIP_HINT"] = "클릭하여 설정 전환",
})
