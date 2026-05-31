local _, OneWoW_Bags = ...

local function BagsChromeOverride(db, key)
    local altReveal = OneWoW_Bags:IsAltShowActive()
    return (db.global[key] ~= false) or altReveal
end

OneWoW_Bags.InfoBar = OneWoW_Bags.InfoBarFactory:Create({
    controllerKey = "BagsController",
    viewModeDBKey = "viewMode",
    searchName = "OneWoW_BagsSearch",
    savedSearches = true,
    searchTransfer = {
        atlas = "Banker",
        direction = "toBank",
        tooltipKey = "SEARCH_TRANSFER_TO_BANK",
        emptyTooltipKey = "SEARCH_TRANSFER_TO_BANK_EMPTY",
        disabledTooltipKey = "SEARCH_TRANSFER_TO_BANK_DISABLED",
    },
    showHeaderFn = function(db) return BagsChromeOverride(db, "showHeaderBar") end,
    showSearchFn = function(db) return BagsChromeOverride(db, "showSearchBar") end,
    viewModes = {
        { mode = "list",     labelKey = "VIEW_LIST" },
        { mode = "category", labelKey = "VIEW_CATEGORY" },
        { mode = "bag",      labelKey = "VIEW_BAG" },
    },
    expacFilter = {
        filterKey  = "activeExpansionFilter",
        settingKey = "enableExpansionFilter",
    },
    cleanupCallback = function(controller)
        if controller and controller.SortBags then
            controller:SortBags()
        end
    end,
    categoryManagerCallback = function(controller)
        controller:ToggleCategoryManager()
    end,
})
