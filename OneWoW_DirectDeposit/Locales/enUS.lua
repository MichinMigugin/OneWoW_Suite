local ADDON_NAME, OneWoW_DirectDeposit = ...

OneWoW_DirectDeposit.Locales = OneWoW_DirectDeposit.Locales or {}
OneWoW_DirectDeposit.Locales["enUS"] = {
    ["ADDON_TITLE"] = "Direct Deposit",
    ["ADDON_SUBTITLE"] = "Automatic Warband Bank Gold Management",

    ["SETTINGS"] = "Settings",
    ["STATUS"] = "Status",
    ["ENABLED"] = "Enabled",
    ["DISABLED"] = "Disabled",

    ["TAB_GOLD"] = "Gold",
    ["TAB_ITEMS"] = "Items",
    ["TAB_SETTINGS"] = "Settings",

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
    ["TARGET_GOLD_DESC"] = "Enter the amount of gold (in gold pieces) you want to maintain on your character.",
    ["GOLD"] = "gold",

    ["DEPOSIT_ENABLE"] = "Deposit Gold to Warband Bank",
    ["DEPOSIT_ENABLE_DESC"] = "When you have more than the target amount, automatically deposit the excess to your Warband Bank.",

    ["WITHDRAW_ENABLE"] = "Withdraw Gold from Warband Bank",
    ["WITHDRAW_ENABLE_DESC"] = "When you have less than the target amount, automatically withdraw from your Warband Bank to reach the target.",

    ["ITEM_DEPOSIT"] = "Item Auto-Deposit",
    ["ITEM_DEPOSIT_ENABLE"] = "Enable Item Auto-Deposit",
    ["ITEM_DEPOSIT_ENABLE_DESC"] = "Automatically deposit specific items to your chosen bank when opening the bank.",
    ["ITEM_DEPOSIT_LIST"] = "Auto-Deposit Item List",
    ["ITEM_DEPOSIT_ADD"] = "Add Item",
    ["ITEM_DEPOSIT_ADD_PROMPT"] = "Enter Item ID or shift-click an item to add:",
    ["ITEM_DEPOSIT_REMOVE"] = "Remove",
    ["ITEM_DEPOSIT_WARBAND"] = "Warband",
    ["ITEM_DEPOSIT_PERSONAL"] = "Personal",
    ["ITEM_DEPOSIT_GUILD"] = "Guild",

    ["OK"] = "OK",
    ["CLOSE"] = "Close",
    ["CLEAR"] = "Clear",
    ["CANCEL"] = "Cancel",

    ["LANGUAGE_SELECTION"] = "Language Selection",
    ["CURRENT_LANGUAGE"] = "Current Language",
    ["SELECT_LANGUAGE"] = "Select Language",
    ["LANGUAGE_DESC"] = "Choose your preferred language for the addon interface. Changes apply instantly.",
    ["ENGLISH"] = "English",
    ["SPANISH"] = "Español",
    ["KOREAN"] = "한국어",
    ["FRENCH"] = "Français",
    ["RUSSIAN"] = "Русский",
    ["GERMAN"] = "Deutsch",

    ["ABOUT_SECTION"] = "About Direct Deposit",
    ["ABOUT_TEXT"] = "Direct Deposit is a quality-of-life addon from the OneWoW Suite. This addon is also available as part of the complete OneWoW Suite, which includes many other useful addons to enhance your World of Warcraft experience. Discover more addons that can help you organize your adventures and improve your gameplay!",

    ["LINKS_SECTION"] = "Support & Community",
    ["DISCORD_LABEL"] = "Join our Discord Community",
    ["DISCORD_URL"] = "https://discord.gg/wownotes",
    ["WEBSITE_LABEL"] = "Visit our Website for Support",
    ["WEBSITE_URL"] = "https://wow2.xyz/",
    ["COPY_HINT"] = "Click to select, then Ctrl+C to copy",

    ["THEME_SECTION"] = "Color Theme",
    ["THEME_DESC"] = "Choose a color theme for the addon interface. Changes apply instantly without reloading.",
    ["THEME_CURRENT"] = "Current Theme",
    ["THEME_GREEN"] = "Forest Green",
    ["THEME_BLUE"] = "Ocean Blue",
    ["THEME_PURPLE"] = "Royal Purple",
    ["THEME_RED"] = "Crimson Red",
    ["THEME_GOLD"] = "Classic Gold",
    ["THEME_SLATE"] = "Slate Gray",
    ["THEME_ORANGE"] = "Sunset Orange",
    ["THEME_TEAL"] = "Mystic Teal",
    ["THEME_CYAN"] = "Arctic Cyan",
    ["THEME_PINK"] = "Rose Pink",
    ["THEME_DARK"] = "Midnight Dark",
    ["THEME_AMBER"] = "Amber Fire",
    ["THEME_VOID_BLACK"] = "Void Black",
    ["THEME_CHARCOAL_DEEP"] = "Charcoal Deep",
    ["THEME_FOREST_NIGHT"] = "Forest Night",
    ["THEME_OBSIDIAN_MINIMAL"] = "Obsidian Minimal",
    ["THEME_MONOCHROME_PRO"] = "Monochrome Pro",
    ["THEME_TWILIGHT_COMPACT"] = "Twilight Compact",
    ["THEME_NEON_SYNTHWAVE"] = "Neon Synthwave",
    ["THEME_GLASSMORPHIC"] = "Glassmorphic",
    ["THEME_MINIMAL_WHITE"] = "Minimal White",
    ["THEME_RETRO_CLASSIC"] = "Retro Classic",
    ["THEME_RPG_FANTASY"] = "RPG Fantasy",
    ["THEME_COVENANT_TWILIGHT"] = "Covenant Twilight",

    ["MINIMAP_SECTION"] = "Minimap Button",
    ["MINIMAP_SECTION_DESC"] = "Show or hide the minimap button.",
    ["MINIMAP_SHOW_BTN"] = "Show Minimap Button",
    ["MINIMAP_ICON_SECTION"] = "Icon Theme",
    ["MINIMAP_ICON_DESC"] = "Choose your faction icon for the minimap button and title bar.",
    ["MINIMAP_ICON_CURRENT"] = "Current Icon",
    ["MINIMAP_ICON_HORDE"] = "Horde",
    ["MINIMAP_ICON_ALLIANCE"] = "Alliance",
    ["MINIMAP_ICON_NEUTRAL"] = "Neutral",
    ["MINIMAP_TOOLTIP_HINT"] = "Click to toggle settings",

    ["ADDON_CHAT_PREFIX"] = "|cFFFFD100Direct Deposit:|r",
    ["DEPOSIT_NOW"] = "Deposit Now",
    ["PAUSE"] = "Pause",
    ["ITEM_ID_LABEL"] = "Item ID:",
    ["ITEM_DRAG_HINT"] = "Drag items here to add",
    ["ITEM_EMPTY_LIST"] = "No items in auto-deposit list.\nDrag items here to add them.",

}

OneWoW_DirectDeposit.L = {}
for k, v in pairs(OneWoW_DirectDeposit.Locales["enUS"]) do
    OneWoW_DirectDeposit.L[k] = v
end

_G["BINDING_HEADER_ONEWOW_DIRECTDEPOSIT"] = "|cFF00FF00OneWoW|r Direct Deposit"
_G["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_TOGGLE"] = "Toggle Direct Deposit Window"
_G["BINDING_NAME_ONEWOW_DIRECTDEPOSIT_DEPOSIT"] = "Deposit Items Now"
