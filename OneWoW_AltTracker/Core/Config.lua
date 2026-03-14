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
}
