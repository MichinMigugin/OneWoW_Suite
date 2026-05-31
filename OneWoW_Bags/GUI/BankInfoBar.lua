local _, OneWoW_Bags = ...

OneWoW_Bags.BankInfoBar = OneWoW_Bags.InfoBarFactory:Create({
    controllerKey = "BankController",
    guiTargetKey = "BankGUI",
    hideScrollBarFn = function() return OneWoW_Bags.BankController:Get("hideScrollBar") end,
    viewModeDBKey = "bankViewMode",
    showHeaderFn = function() return OneWoW_Bags.BankController:Get("showHeaderBar") ~= false end,
    showSearchFn = function() return OneWoW_Bags.BankController:Get("showSearchBar") ~= false end,
    searchName = "OneWoW_BankSearch",
    savedSearches = true,
    searchTransfer = {
        atlas = "hud-backpack",
        direction = "fromBank",
        tooltipKey = "SEARCH_TRANSFER_FROM_BANK",
        emptyTooltipKey = "SEARCH_TRANSFER_FROM_BANK_EMPTY",
    },
    viewModes = {
        { mode = "list",     labelKey = "VIEW_LIST" },
        { mode = "category", labelKey = "VIEW_CATEGORY" },
        { mode = "tab",      labelKey = "VIEW_BAG" },
    },
    expacFilter = {
        filterKey  = "activeBankExpansionFilter",
        settingFn  = function() return OneWoW_Bags.BankController:Get("expansionFilter") == true end,
    },
    cleanupCallback = function(controller)
        if controller and controller.SortBank then
            controller:SortBank()
        end
    end,
    categoryManagerCallback = function(controller)
        controller:ToggleCategoryManager()
    end,
})
