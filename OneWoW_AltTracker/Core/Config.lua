local addonName, ns = ...

ns.Config = {
    ADDON_NAME = "WoWNotes Alt Tracker",
    ADDON_SHORT_NAME = "Alt Tracker",
    ADDON_VERSION = "B2602.1421",

    DISCORD_URL = "https://discord.gg/wownotes",
    WEBSITE_URL = "https://wow2.xyz/",

    DEBUG_MODE = false,

    SLASH_COMMANDS = {
        "/alttracker",
        "/at"
    },

    DEFAULT_THEME = "green",
    DEFAULT_LANGUAGE = "enUS",

    SUPPORTED_LANGUAGES = {
        "enUS",
        "koKR"
    },

    MAX_CHARACTERS = 60,

    DATA_COLLECTION_EVENTS = {
        "PLAYER_ENTERING_WORLD",
        "PLAYER_LEVEL_UP",
        "PLAYER_MONEY",
        "PLAYER_EQUIPMENT_CHANGED",
        "MAIL_SHOW",
        "MAIL_INBOX_UPDATE",
        "MAIL_CLOSED",
        "UPDATE_PENDING_MAIL",
        "BANKFRAME_OPENED",
        "GUILDBANKFRAME_OPENED",
        "GUILDBANK_UPDATE_TABS",
        "GUILDBANK_UPDATE_MONEY",
        "GUILDBANKBAGSLOTS_CHANGED",
        "AUCTION_HOUSE_SHOW",
        "TRADE_SKILL_SHOW",
        "TIME_PLAYED_MSG",
        "PLAYER_SPECIALIZATION_CHANGED",
        "UPDATE_INSTANCE_INFO"
    }
}
