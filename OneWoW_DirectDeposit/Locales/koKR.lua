local ADDON_NAME, OneWoW_DirectDeposit = ...

OneWoW_DirectDeposit.Locales = OneWoW_DirectDeposit.Locales or {}
OneWoW_DirectDeposit.Locales["koKR"] = {
    ["ADDON_TITLE"] = "자동 입금",
    ["ADDON_SUBTITLE"] = "워밴드 은행 골드 자동 관리",

    ["WOWNOTES_DETECTED_TITLE"] = "WoWNotes 감지됨",
    ["WOWNOTES_DETECTED_MESSAGE"] = "이 애드온은 WoWNotes의 일부입니다. 이 애드온의 독립 실행형 버전을 설치할 필요가 없습니다. WoWNotes가 활성화되어 있는 동안 비활성화되므로 OneWoW_DirectDeposit를 제거하십시오.",
    ["WOWNOTES_DETECTED_DISABLED"] = "WoWNotes가 설치되어 있어 이 애드온이 비활성화되었습니다.",

    ["SETTINGS"] = "설정",
    ["STATUS"] = "상태",
    ["ENABLED"] = "활성화됨",
    ["DISABLED"] = "비활성화됨",

    ["TAB_GOLD"] = "골드",
    ["TAB_ITEMS"] = "아이템",
    ["TAB_SETTINGS"] = "설정",

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
    ["TARGET_GOLD_DESC"] = "캐릭터에 유지할 골드 금액(골드 단위)을 입력하십시오.",
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
    ["ITEM_DEPOSIT_REMOVE"] = "제거",
    ["ITEM_DEPOSIT_WARBAND"] = "워밴드",
    ["ITEM_DEPOSIT_PERSONAL"] = "개인",
    ["ITEM_DEPOSIT_GUILD"] = "길드",

    ["OK"] = "확인",
    ["CLOSE"] = "닫기",
    ["CLEAR"] = "지우기",
    ["CANCEL"] = "취소",

    ["LANGUAGE_SELECTION"] = "언어 선택",
    ["CURRENT_LANGUAGE"] = "현재 언어",
    ["SELECT_LANGUAGE"] = "언어 선택",
    ["LANGUAGE_DESC"] = "애드온 인터페이스에 선호하는 언어를 선택하세요. 변경 사항은 즉시 적용됩니다.",
    ["ENGLISH"] = "English",
    ["SPANISH"] = "Español",
    ["KOREAN"] = "한국어",
    ["FRENCH"] = "Français",
    ["RUSSIAN"] = "Русский",
    ["GERMAN"] = "Deutsch",

    ["ABOUT_SECTION"] = "자동 입금 정보",
    ["ABOUT_TEXT"] = "자동 입금은 WoWNotes Suite의 편의성 애드온입니다. 이 애드온은 또한 World of Warcraft 경험을 향상시키는 많은 다른 유용한 애드온을 포함하는 완전한 WoWNotes Suite의 일부로 제공됩니다. 모험을 정리하고 게임 플레이를 개선하는 데 도움이 되는 더 많은 애드온을 찾아보세요!",

    ["LINKS_SECTION"] = "지원 및 커뮤니티",
    ["DISCORD_LABEL"] = "Discord 커뮤니티에 가입하세요",
    ["DISCORD_URL"] = "https://discord.gg/wownotes",
    ["WEBSITE_LABEL"] = "지원을 위해 웹사이트를 방문하세요",
    ["WEBSITE_URL"] = "https://wow2.xyz/",
    ["COPY_HINT"] = "클릭하여 선택한 다음 Ctrl+C를 눌러 복사",

    ["THEME_SECTION"] = "색상 테마",
    ["THEME_DESC"] = "애드온 인터페이스의 색상 테마를 선택하세요. 변경 사항은 재로드 없이 즉시 적용됩니다.",
    ["THEME_CURRENT"] = "현재 테마",
    ["THEME_GREEN"] = "숲 녹색",
    ["THEME_BLUE"] = "바다 파랑",
    ["THEME_PURPLE"] = "로얄 퍼플",
    ["THEME_GOLD"] = "클래식 골드",
    ["THEME_SLATE"] = "슬레이트 회색",
    ["THEME_ORANGE"] = "석양 오렌지",
    ["THEME_TEAL"] = "신비로운 청록",
    ["THEME_CYAN"] = "북극 사이안",
    ["THEME_PINK"] = "장미 핑크",
    ["THEME_DARK"] = "미드나잇 다크",
    ["THEME_AMBER"] = "호박 불꽃",

    ["MINIMAP_SECTION"] = "미니맵 버튼",
    ["MINIMAP_SECTION_DESC"] = "미니맵 버튼을 표시하거나 숨깁니다.",
    ["MINIMAP_SHOW_BTN"] = "미니맵 버튼 표시",
    ["MINIMAP_ICON_SECTION"] = "아이콘 테마",
    ["MINIMAP_ICON_DESC"] = "미니맵 버튼과 제목 표시줄의 진영 아이콘을 선택하세요.",
    ["MINIMAP_ICON_CURRENT"] = "현재 아이콘",
    ["MINIMAP_ICON_HORDE"] = "호드",
    ["MINIMAP_ICON_ALLIANCE"] = "얼라이언스",
    ["MINIMAP_ICON_NEUTRAL"] = "중립",
    ["MINIMAP_TOOLTIP_HINT"] = "클릭하여 설정 전환",

    ["IMPORT_SECTION"] = "WoWNotes에서 가져오기",
    ["IMPORT_DESC"] = "WoWNotes에서 자동 입금 아이템 목록 및 설정을 가져옵니다. 가져온 아이템은 기존 목록에 추가되며 현재 아이템을 바꾸지 않습니다.",
    ["IMPORT_BUTTON"] = "WoWNotes에서 가져오기",
    ["IMPORT_SUCCESS"] = "가져오기 성공! WoWNotes에서 {count}개의 아이템을 가져왔습니다",
    ["IMPORT_NO_DATA"] = "WoWNotes에서 자동 입금 데이터를 찾을 수 없습니다",
    ["IMPORT_NOT_INSTALLED"] = "WoWNotes가 설치되지 않았습니다",
}
