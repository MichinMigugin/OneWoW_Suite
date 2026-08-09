local ADDON_NAME = ...

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(ADDON_NAME, "zhCN", {

    ["CTX_OPEN_DD"] = "打开直接存款",
    ["ADDON_TITLE"] = "直接存款",
    ["ADDON_SUBTITLE"] = "战团银行金币自动管理",


    ["TAB_GOLD"] = "金币",

    ["DIRECT_DEPOSIT_TITLE"] = "直接存款",
    ["DIRECT_DEPOSIT_DESCRIPTION"] = "在你的角色与战团银行之间自动管理金币。设置一个想要保留在角色身上的目标金额，系统会在金币过多时存入多余部分，或在不足时取出。非常适合管理多个角色的金币。",
    ["DIRECT_DEPOSIT_ENABLE"] = "启用直接存款",
    ["DIRECT_DEPOSIT_ENABLE_DESC"] = "在你打开银行时，自动从战团银行存入或取出金币，以使角色保持目标金额。",

    ["ACCOUNT_SETTINGS"] = "全账号设置",
    ["ACCOUNT_SETTINGS_DESC"] = "这些设置适用于你账号上的所有角色。",

    ["CHARACTER_SETTINGS"] = "角色专属覆盖",
    ["CHARACTER_SETTINGS_DESC"] = "用此角色的自定义设置覆盖全账号设置。适用于银行小号或有特殊金币管理需求的角色。",

    ["USE_CHAR_SETTINGS"] = "使用角色专属设置",
    ["USE_CHAR_SETTINGS_DESC"] = "启用此项可为此角色使用不同于全账号设置的设置。",

    ["TARGET_GOLD"] = "角色保留金额",
    ["TARGET_GOLD_DESC"] = "输入你想在角色身上保持的金币数量（以金为单位）。留空则在设置前不进行任何自动金币转移。输入 0 表示角色不保留金币。",
    ["GOLD"] = "金",

    ["DEPOSIT_ENABLE"] = "向战团银行存入金币",
    ["DEPOSIT_ENABLE_DESC"] = "当你的金币多于目标金额时，自动将多余部分存入战团银行。",

    ["WITHDRAW_ENABLE"] = "从战团银行取出金币",
    ["WITHDRAW_ENABLE_DESC"] = "当你的金币少于目标金额时，自动从战团银行取出以达到目标。",

    ["ITEM_DEPOSIT"] = "物品自动存入",
    ["ITEM_DEPOSIT_ENABLE"] = "启用物品自动存入",
    ["ITEM_DEPOSIT_ENABLE_DESC"] = "在打开银行时，自动将特定物品存入你选择的银行。",
    ["ITEM_DEPOSIT_LIST"] = "自动存入物品列表",
    ["ITEM_DEPOSIT_ADD_PROMPT"] = "输入物品 ID 或按住 Shift 点击物品以添加：",
    ["ITEM_DEPOSIT_WARBAND"] = "战团",
    ["ITEM_DEPOSIT_PERSONAL"] = "个人",

    ["CLEAR"] = "清除",


    ["MINIMAP_TOOLTIP_HINT"] = "点击以切换设置",

    ["ADDON_CHAT_PREFIX"] = "|cFFFFD100Direct Deposit:|r",
    ["DEPOSIT_NOW"] = "立即存入",

    ["TAB_KEYBINDS"] = "快捷键",

    ["KEYBIND_SECTION"] = "快速添加快捷键",
    ["KEYBIND_DESC"] = "将鼠标悬停在任意物品上并按下快捷键，即可立即将其添加到存入列表。在 游戏菜单 > 按键设置 > OneWoW Direct Deposit 中分配按键。",
    ["KEYBIND_ADD_PERSONAL"] = "添加悬停物品 - 个人银行",
    ["KEYBIND_ADD_WARBAND"] = "添加悬停物品 - 战团银行",
    ["KEYBIND_ADD_GUILD"] = "添加悬停物品 - 公会银行",
    ["KEYBIND_NO_ITEM"] = "未找到物品 - 请先将鼠标悬停在物品上。",

    ["WARBOUND_SECTION"] = "战团自动存入",
    ["WARBOUND_ENABLE"] = "自动存入所有战团绑定物品",
    ["WARBOUND_ENABLE_DESC"] = "在打开任意银行时，自动将你包裹中所有战团绑定（账号绑定）物品存入战团银行。已在上方存入列表中的物品将被排除。",

    ["WARBOUND_EXCLUDE_KEYWORD_LABEL"] = "按关键词保留",
    ["WARBOUND_EXCLUDE_KEYWORD_DESC"] = "与此关键词表达式匹配的物品将保留在你的包裹中，永不自动存入。使用诸如 #potion、#flask、#elixir、#consumable 之类的关键词，用 | 分隔表示“或”。示例：#potion | #flask",
    ["WARBOUND_EXCLUDE_KEYWORD_PLACEHOLDER"] = "例如 #potion | #flask",
    ["WARBOUND_EXCLUDE_ITEMS_LABEL"] = "保留特定物品",
    ["WARBOUND_EXCLUDE_ITEMS_DESC"] = "这些物品将始终保留在你的包裹中，即使是战团绑定物品。将物品拖到此处或输入其物品 ID。",

    ["TOOLTIP_SECTION"] = "工具提示叠加",
    ["TOOLTIP_ENABLE"] = "在工具提示中显示存入状态",
    ["TOOLTIP_ENABLE_DESC"] = "排队等待存入的物品将在其工具提示底部显示目标银行。",
    ["TOOLTIP_LABEL"] = "直接存入：",
    ["TOOLTIP_PERSONAL"] = "个人",
    ["TOOLTIP_WARBAND"] = "战团",

    ["BINDING_HEADER_ONEWOW_DIRECTDEPOSIT"] = "|cFF00FF00OneWoW|r Direct Deposit",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_TOGGLE"] = "切换 Direct Deposit 窗口",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_DEPOSIT"] = "立即存入物品",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_PERSONAL"] = "快速添加：个人银行",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_WARBAND"] = "快速添加：战团银行",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_GUILD"] = "快速添加：公会银行",
})
