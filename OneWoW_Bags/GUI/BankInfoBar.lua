local _, OneWoW_Bags = ...

OneWoW_Bags.BankInfoBar = OneWoW_Bags.InfoBarFactory:Create({
    guiTargetKey = "BankGUI",
    viewModeDBKey = "bankViewMode",
    searchName = "OneWoW_BankSearch",
    viewModes = {
        { mode = "list",     labelKey = "VIEW_LIST" },
        { mode = "category", labelKey = "VIEW_CATEGORY" },
        { mode = "tab",      labelKey = "VIEW_BAG" },
    },
    expacFilter = {
        bagSetKey  = "BankSet",
        filterKey  = "activeBankExpansionFilter",
        settingKey = "enableBankExpansionFilter",
    },
    cleanupCallback = function()
        if not OneWoW_Bags.bankOpen then return end
        local db = OneWoW_Bags.db
        local showWarband = db.global.bankShowWarband
        if showWarband then
            C_Container.SortBank(Enum.BankType.Account)
        else
            C_Container.SortBank(Enum.BankType.Character)
        end
    end,
})
