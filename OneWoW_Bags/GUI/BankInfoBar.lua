local _, ns = ...

ns.BankInfoBar = ns.InfoBarFactory:Create({
    controllerKey = "BankController",
    guiTargetKey = "BankGUI",
    hideScrollBarFn = function() return ns.BankController:Get("hideScrollBar") end,
    viewModeDBKey = "bankViewMode",
    showHeaderFn = function() return ns.BankController:Get("showHeaderBar") ~= false end,
    showSearchFn = function() return ns.BankController:Get("showSearchBar") ~= false end,
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
        settingFn  = function() return ns.BankController:Get("expansionFilter") == true end,
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
