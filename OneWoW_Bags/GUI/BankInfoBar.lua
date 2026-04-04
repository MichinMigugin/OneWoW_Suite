local _, OneWoW_Bags = ...

OneWoW_Bags.BankInfoBar = OneWoW_Bags.InfoBarFactory:Create({
    controllerKey = "BankController",
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
    cleanupCallback = function(controller)
        if controller and controller.SortBank then
            controller:SortBank()
        end
    end,
})
