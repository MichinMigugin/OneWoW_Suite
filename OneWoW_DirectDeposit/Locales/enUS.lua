local ADDON_NAME, ns = ...

OneWoW.Locale:Register(ADDON_NAME, "enUS", {

    ["CTX_OPEN_DD"] = "Open Direct Deposit",
    ["ADDON_TITLE"] = "Direct Deposit",
    ["ADDON_SUBTITLE"] = "Automatic Warband Bank Gold Management",


    ["TAB_GOLD"] = "Gold",

    ["DIRECT_DEPOSIT_TITLE"] = "Direct Deposit",
    ["DIRECT_DEPOSIT_DESCRIPTION"] = "Automatically manage gold between your character and Warband Bank. Set a target amount to keep on your character, and the system will deposit excess gold or withdraw when you're short. Perfect for managing gold across multiple characters.",
    ["DIRECT_DEPOSIT_ENABLE"] = "Enable Direct Deposit",
    ["DIRECT_DEPOSIT_ENABLE_DESC"] = "Automatically deposit or withdraw gold from your Warband Bank to maintain a target amount on your character when you open the bank.",

    ["ACCOUNT_SETTINGS"] = "Account-Wide Settings",
    ["ACCOUNT_SETTINGS_DESC"] = "These settings apply to all characters on your account.",

    ["CHARACTER_SETTINGS"] = "Character-Specific Override",
    ["CHARACTER_SETTINGS_DESC"] = "Override account-wide settings with custom settings for this specific character. Useful for bank alts or characters with special gold management needs.",

    ["USE_CHAR_SETTINGS"] = "Use Character-Specific Settings",
    ["USE_CHAR_SETTINGS_DESC"] = "Enable this to use different settings for this character instead of the account-wide settings.",

    ["TARGET_GOLD"] = "Amount to Keep on Character",
    ["TARGET_GOLD_DESC"] = "Enter the amount of gold (in gold pieces) you want to maintain on your character. Leave blank for no automatic gold moves until set. Enter 0 to keep no gold on the character.",
    ["GOLD"] = "gold",

    ["DEPOSIT_ENABLE"] = "Deposit Gold to Warband Bank",
    ["DEPOSIT_ENABLE_DESC"] = "When you have more than the target amount, automatically deposit the excess to your Warband Bank.",

    ["WITHDRAW_ENABLE"] = "Withdraw Gold from Warband Bank",
    ["WITHDRAW_ENABLE_DESC"] = "When you have less than the target amount, automatically withdraw from your Warband Bank to reach the target.",

    ["ITEM_DEPOSIT"] = "Item Auto-Deposit",
    ["ITEM_DEPOSIT_ENABLE"] = "Enable Item Auto-Deposit",
    ["ITEM_DEPOSIT_ENABLE_DESC"] = "Automatically deposit specific items to your chosen bank when opening the bank.",
    ["ITEM_DEPOSIT_LIST"] = "Auto-Deposit Item List",
    ["ITEM_DEPOSIT_ADD_PROMPT"] = "Enter Item ID or shift-click an item to add:",
    ["ITEM_DEPOSIT_WARBAND"] = "Warband",
    ["ITEM_DEPOSIT_PERSONAL"] = "Personal",

    ["CLEAR"] = "Clear",


    ["MINIMAP_TOOLTIP_HINT"] = "Click to toggle settings",

    ["ADDON_CHAT_PREFIX"] = "|cFFFFD100Direct Deposit:|r",
    ["DEPOSIT_NOW"] = "Deposit Now",

    ["TAB_KEYBINDS"] = "Keybinds",

    ["KEYBIND_SECTION"] = "Quick Add Keybinds",
    ["KEYBIND_DESC"] = "Hover over any item and press a keybind to instantly add it to the deposit list. Assign keys in Game Menu > Key Bindings > OneWoW Direct Deposit.",
    ["KEYBIND_ADD_PERSONAL"] = "Add Hovered Item - Personal Bank",
    ["KEYBIND_ADD_WARBAND"] = "Add Hovered Item - Warband Bank",
    ["KEYBIND_ADD_GUILD"] = "Add Hovered Item - Guild Bank",
    ["KEYBIND_NO_ITEM"] = "No item found - hover over an item first.",

    ["WARBOUND_SECTION"] = "Warband Auto-Deposit",
    ["WARBOUND_ENABLE"] = "Auto-Deposit All Warbound Items",
    ["WARBOUND_ENABLE_DESC"] = "When opening any bank, automatically deposit all warbound (account-bound) items from your bags into the Warband Bank. Items already in your deposit list above are excluded.",

    ["WARBOUND_EXCLUDE_KEYWORD_LABEL"] = "Keep by Keyword",
    ["WARBOUND_EXCLUDE_KEYWORD_DESC"] = "Items matching this keyword expression are kept in your bags and never auto-deposited. Use keywords like #potion, #flask, #elixir, #consumable, separated by | for \"or\". Example: #potion | #flask",
    ["WARBOUND_EXCLUDE_KEYWORD_PLACEHOLDER"] = "e.g. #potion | #flask",
    ["WARBOUND_EXCLUDE_ITEMS_LABEL"] = "Keep Specific Items",
    ["WARBOUND_EXCLUDE_ITEMS_DESC"] = "These items are always kept in your bags, even when warbound. Drag an item here or enter its Item ID.",

    ["TOOLTIP_SECTION"] = "Tooltip Overlay",
    ["TOOLTIP_ENABLE"] = "Show Deposit Status in Tooltips",
    ["TOOLTIP_ENABLE_DESC"] = "Items queued for deposit will show their destination bank at the bottom of their tooltip.",
    ["TOOLTIP_LABEL"] = "DirectDepositing:",
    ["TOOLTIP_PERSONAL"] = "Personal",
    ["TOOLTIP_WARBAND"] = "Warband",

    ["BINDING_HEADER_ONEWOW_DIRECTDEPOSIT"] = "|cFF00FF00OneWoW|r Direct Deposit",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_TOGGLE"] = "Toggle Direct Deposit Window",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_DEPOSIT"] = "Deposit Items Now",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_PERSONAL"] = "Quick Add: Personal Bank",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_WARBAND"] = "Quick Add: Warband Bank",
    ["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_ADD_GUILD"] = "Quick Add: Guild Bank",
})

ns.L = OneWoW.Locale:GetTable(ADDON_NAME)
