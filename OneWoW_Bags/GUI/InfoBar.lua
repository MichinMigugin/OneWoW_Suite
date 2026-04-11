local _, OneWoW_Bags = ...

local function BagsChromeOverride(db, key)
    local altReveal = OneWoW_Bags:IsAltShowActive()
    return (db.global[key] ~= false) or altReveal
end

OneWoW_Bags.InfoBar = OneWoW_Bags.InfoBarFactory:Create({
    controllerKey = "BagsController",
    viewModeDBKey = "viewMode",
    searchName = "OneWoW_BagsSearch",
    showHeaderFn = function(db) return BagsChromeOverride(db, "showHeaderBar") end,
    showSearchFn = function(db) return BagsChromeOverride(db, "showSearchBar") end,
    viewModes = {
        { mode = "list",     labelKey = "VIEW_LIST" },
        { mode = "category", labelKey = "VIEW_CATEGORY" },
        { mode = "bag",      labelKey = "VIEW_BAG" },
    },
    expacFilter = {
        bagSetKey  = "BagSet",
        filterKey  = "activeExpansionFilter",
        settingKey = "enableExpansionFilter",
    },
})
