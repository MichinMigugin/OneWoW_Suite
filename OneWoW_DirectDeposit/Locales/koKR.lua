local ADDON_NAME = ...

OneWoW.Locale:Register(ADDON_NAME, "koKR", {

    ["CTX_OPEN_DD"] = "Direct Deposit 열기",
    ["ADDON_TITLE"] = "자동 입금",
    ["ADDON_SUBTITLE"] = "전투부대 은행 골드 자동 관리",


    ["TAB_GOLD"] = "골드",

    ["DIRECT_DEPOSIT_TITLE"] = "자동 입금",
    ["DIRECT_DEPOSIT_DESCRIPTION"] = "캐릭터와 전투부대 은행 사이의 골드를 자동으로 관리합니다. 캐릭터에 유지할 목표 금액을 설정하면 시스템이 초과 골드를 입금하거나 부족할 때 인출합니다. 여러 캐릭터 간 골드 관리에 완벽합니다.",
    ["DIRECT_DEPOSIT_ENABLE"] = "자동 입금 활성화",
    ["DIRECT_DEPOSIT_ENABLE_DESC"] = "은행을 열 때 전투부대 은행에서 골드를 자동으로 입금하거나 인출하여 캐릭터의 목표 금액을 유지합니다.",

    ["ACCOUNT_SETTINGS"] = "계정 전체 설정",
    ["ACCOUNT_SETTINGS_DESC"] = "이 설정은 계정의 모든 캐릭터에 적용됩니다.",

    ["CHARACTER_SETTINGS"] = "캐릭터별 재정의",
    ["CHARACTER_SETTINGS_DESC"] = "이 특정 캐릭터에 대한 사용자 정의 설정으로 계정 전체 설정을 재정의합니다. 은행 부캐나 특별한 골드 관리가 필요한 캐릭터에 유용합니다.",

    ["USE_CHAR_SETTINGS"] = "캐릭터별 설정 사용",
    ["USE_CHAR_SETTINGS_DESC"] = "계정 전체 설정 대신 이 캐릭터에 대해 다른 설정을 사용하려면 활성화하십시오.",

    ["TARGET_GOLD"] = "캐릭터에 유지할 금액",
    ["TARGET_GOLD_DESC"] = "캐릭터에 유지할 골드 금액(골드 단위)을 입력하십시오. 비워 두면 값을 입력할 때까지 자동 골드 이동이 비활성화됩니다. 0 = 캐릭터에 골드를 남기지 않음.",
    ["GOLD"] = "골드",

    ["DEPOSIT_ENABLE"] = "전투부대 은행에 골드 입금",
    ["DEPOSIT_ENABLE_DESC"] = "목표 금액보다 많을 때 초과분을 전투부대 은행에 자동으로 입금합니다.",

    ["WITHDRAW_ENABLE"] = "전투부대 은행에서 골드 인출",
    ["WITHDRAW_ENABLE_DESC"] = "목표 금액보다 적을 때 전투부대 은행에서 자동으로 인출하여 목표에 도달합니다.",

    ["ITEM_DEPOSIT"] = "아이템 자동 입금",
    ["ITEM_DEPOSIT_ENABLE"] = "아이템 자동 입금 활성화",
    ["ITEM_DEPOSIT_ENABLE_DESC"] = "은행을 열 때 선택한 은행에 특정 아이템을 자동으로 입금합니다.",
    ["ITEM_DEPOSIT_LIST"] = "자동 입금 아이템 목록",
    ["ITEM_DEPOSIT_ADD_PROMPT"] = "아이템 ID를 입력하거나 Shift+클릭하여 추가:",
    ["ITEM_DEPOSIT_WARBAND"] = "전투부대",
    ["ITEM_DEPOSIT_PERSONAL"] = "개인",

    ["CLEAR"] = "지우기",


    ["MINIMAP_TOOLTIP_HINT"] = "클릭하여 설정 전환",

    ["ADDON_CHAT_PREFIX"] = "|cFFFFD100Direct Deposit:|r",
    ["DEPOSIT_NOW"] = "지금 입금",

    ["TAB_KEYBINDS"] = "단축키",

    ["KEYBIND_SECTION"] = "빠른 추가 단축키",
    ["KEYBIND_DESC"] = "아무 아이템 위에 마우스를 올리고 단축키를 누르면 즉시 입금 목록에 추가됩니다. 게임 메뉴 > 키 설정 > OneWoW Direct Deposit에서 키를 지정하세요.",
    ["KEYBIND_ADD_PERSONAL"] = "지정한 아이템 추가 - 개인 은행",
    ["KEYBIND_ADD_WARBAND"] = "지정한 아이템 추가 - 전투부대 은행",
    ["KEYBIND_ADD_GUILD"] = "지정한 아이템 추가 - 길드 은행",
    ["KEYBIND_NO_ITEM"] = "아이템을 찾을 수 없습니다 - 먼저 아이템 위에 마우스를 올리세요.",

    ["WARBOUND_SECTION"] = "전투부대 자동 입금",
    ["WARBOUND_ENABLE"] = "모든 전투부대 귀속 아이템 자동 입금",
    ["WARBOUND_ENABLE_DESC"] = "은행을 열 때 가방에 있는 모든 전투부대 귀속(계정 귀속) 아이템을 전투부대 은행에 자동으로 입금합니다. 위의 입금 목록에 이미 있는 아이템은 제외됩니다.",

    ["WARBOUND_EXCLUDE_KEYWORD_LABEL"] = "키워드로 보관",
    ["WARBOUND_EXCLUDE_KEYWORD_DESC"] = "이 키워드 식과 일치하는 아이템은 가방에 보관되며 자동으로 입금되지 않습니다. #potion, #flask, #elixir, #consumable 같은 키워드를 \"또는\"을 뜻하는 |로 구분해 사용하세요. 예: #potion | #flask",
    ["WARBOUND_EXCLUDE_KEYWORD_PLACEHOLDER"] = "예: #potion | #flask",
    ["WARBOUND_EXCLUDE_ITEMS_LABEL"] = "특정 아이템 보관",
    ["WARBOUND_EXCLUDE_ITEMS_DESC"] = "이 아이템은 전투부대 귀속이더라도 항상 가방에 보관됩니다. 아이템을 여기로 끌어오거나 아이템 ID를 입력하세요.",

    ["TOOLTIP_SECTION"] = "툴팁 오버레이",
    ["TOOLTIP_ENABLE"] = "툴팁에 입금 상태 표시",
    ["TOOLTIP_ENABLE_DESC"] = "입금 대기 중인 아이템은 툴팁 하단에 대상 은행을 표시합니다.",
    ["TOOLTIP_LABEL"] = "입금 예정:",
    ["TOOLTIP_PERSONAL"] = "개인",
    ["TOOLTIP_WARBAND"] = "전투부대",

    ["BINDING_HEADER_ONEWOW_DIRECTDEPOSIT"] = "|cFF00FF00OneWoW|r Direct Deposit",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_TOGGLE"] = "Direct Deposit 창 켜기/끄기",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_DEPOSIT"] = "지금 아이템 입금",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_PERSONAL"] = "빠른 추가: 개인 은행",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_WARBAND"] = "빠른 추가: 전투부대 은행",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_GUILD"] = "빠른 추가: 길드 은행",
})
