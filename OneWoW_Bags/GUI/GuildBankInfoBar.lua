local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.GuildBankInfoBar = OneWoW_Bags.InfoBarFactory:Create({
    guiTargetKey = "GuildBankGUI",
    viewModeDBKey = "guildBankViewMode",
    searchName = "OneWoW_GuildBankSearch",
    viewModes = {
        { mode = "list", labelKey = "VIEW_LIST" },
        { mode = "tab",  labelKey = "VIEW_BAG" },
    },
})
