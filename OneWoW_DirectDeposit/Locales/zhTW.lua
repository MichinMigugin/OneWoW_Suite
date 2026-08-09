local ADDON_NAME = ...

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(ADDON_NAME, "zhTW", {

    ["CTX_OPEN_DD"] = "開啟直接存款",
    ["ADDON_TITLE"] = "直接存款",
    ["ADDON_SUBTITLE"] = "戰隊銀行金幣自動管理",


    ["TAB_GOLD"] = "金幣",

    ["DIRECT_DEPOSIT_TITLE"] = "直接存款",
    ["DIRECT_DEPOSIT_DESCRIPTION"] = "在你的角色與戰隊銀行之間自動管理金幣。設定一個想要保留在角色身上的目標金額，系統會在金幣過多時存入多餘部分，或在不足時提領。非常適合管理多個角色的金幣。",
    ["DIRECT_DEPOSIT_ENABLE"] = "啟用直接存款",
    ["DIRECT_DEPOSIT_ENABLE_DESC"] = "在你開啟銀行時，自動從戰隊銀行存入或提領金幣，以使角色保持目標金額。",

    ["ACCOUNT_SETTINGS"] = "全帳號設定",
    ["ACCOUNT_SETTINGS_DESC"] = "這些設定適用於你帳號上的所有角色。",

    ["CHARACTER_SETTINGS"] = "角色專屬覆寫",
    ["CHARACTER_SETTINGS_DESC"] = "以此角色的自訂設定覆寫全帳號設定。適用於銀行分身或有特殊金幣管理需求的角色。",

    ["USE_CHAR_SETTINGS"] = "使用角色專屬設定",
    ["USE_CHAR_SETTINGS_DESC"] = "啟用此項可為此角色使用不同於全帳號設定的設定。",

    ["TARGET_GOLD"] = "角色保留金額",
    ["TARGET_GOLD_DESC"] = "輸入你想在角色身上保持的金幣數量（以金為單位）。留空則在設定前不進行任何自動金幣轉移。輸入 0 表示角色不保留金幣。",
    ["GOLD"] = "金",

    ["DEPOSIT_ENABLE"] = "將金幣存入戰隊銀行",
    ["DEPOSIT_ENABLE_DESC"] = "當你的金幣多於目標金額時，自動將多餘部分存入戰隊銀行。",

    ["WITHDRAW_ENABLE"] = "從戰隊銀行提領金幣",
    ["WITHDRAW_ENABLE_DESC"] = "當你的金幣少於目標金額時，自動從戰隊銀行提領以達到目標。",

    ["ITEM_DEPOSIT"] = "物品自動存入",
    ["ITEM_DEPOSIT_ENABLE"] = "啟用物品自動存入",
    ["ITEM_DEPOSIT_ENABLE_DESC"] = "在開啟銀行時，自動將特定物品存入你選擇的銀行。",
    ["ITEM_DEPOSIT_LIST"] = "自動存入物品清單",
    ["ITEM_DEPOSIT_ADD_PROMPT"] = "輸入物品 ID 或按住 Shift 點擊物品以新增：",
    ["ITEM_DEPOSIT_WARBAND"] = "戰隊",
    ["ITEM_DEPOSIT_PERSONAL"] = "個人",

    ["CLEAR"] = "清除",


    ["MINIMAP_TOOLTIP_HINT"] = "點擊以切換設定",

    ["ADDON_CHAT_PREFIX"] = "|cFFFFD100Direct Deposit:|r",
    ["DEPOSIT_NOW"] = "立即存入",

    ["TAB_KEYBINDS"] = "快捷鍵",

    ["KEYBIND_SECTION"] = "快速新增快捷鍵",
    ["KEYBIND_DESC"] = "將滑鼠游標停在任意物品上並按下快捷鍵，即可立即將其新增至存入清單。在 遊戲選單 > 按鍵設定 > OneWoW Direct Deposit 中指派按鍵。",
    ["KEYBIND_ADD_PERSONAL"] = "新增游標所指物品 - 個人銀行",
    ["KEYBIND_ADD_WARBAND"] = "新增游標所指物品 - 戰隊銀行",
    ["KEYBIND_ADD_GUILD"] = "新增游標所指物品 - 公會銀行",
    ["KEYBIND_NO_ITEM"] = "找不到物品 - 請先將游標停在物品上。",

    ["WARBOUND_SECTION"] = "戰隊自動存入",
    ["WARBOUND_ENABLE"] = "自動存入所有戰隊綁定物品",
    ["WARBOUND_ENABLE_DESC"] = "在開啟任意銀行時，自動將你背包中所有戰隊綁定（帳號綁定）物品存入戰隊銀行。已在上方存入清單中的物品將被排除。",

    ["WARBOUND_EXCLUDE_KEYWORD_LABEL"] = "依關鍵字保留",
    ["WARBOUND_EXCLUDE_KEYWORD_DESC"] = "與此關鍵字運算式相符的物品將保留在你的背包中，永不自動存入。使用諸如 #potion、#flask、#elixir、#consumable 之類的關鍵字，以 | 分隔表示「或」。範例：#potion | #flask",
    ["WARBOUND_EXCLUDE_KEYWORD_PLACEHOLDER"] = "例如 #potion | #flask",
    ["WARBOUND_EXCLUDE_ITEMS_LABEL"] = "保留特定物品",
    ["WARBOUND_EXCLUDE_ITEMS_DESC"] = "這些物品將始終保留在你的背包中，即使是戰隊綁定物品。將物品拖曳至此處或輸入其物品 ID。",

    ["TOOLTIP_SECTION"] = "提示資訊疊加",
    ["TOOLTIP_ENABLE"] = "在提示資訊中顯示存入狀態",
    ["TOOLTIP_ENABLE_DESC"] = "排隊等待存入的物品將在其提示資訊底部顯示目標銀行。",
    ["TOOLTIP_LABEL"] = "直接存入：",
    ["TOOLTIP_PERSONAL"] = "個人",
    ["TOOLTIP_WARBAND"] = "戰隊",

    ["BINDING_HEADER_ONEWOW_DIRECTDEPOSIT"] = "|cFF00FF00OneWoW|r Direct Deposit",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_TOGGLE"] = "切換 Direct Deposit 視窗",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_DEPOSIT"] = "立即存入物品",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_PERSONAL"] = "快速新增：個人銀行",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_WARBAND"] = "快速新增：戰隊銀行",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_GUILD"] = "快速新增：公會銀行",
})
