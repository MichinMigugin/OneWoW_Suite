local _, ns = ...
local L = ns.L

ns.UI = ns.UI or {}

function ns.UI.CreateHousingTab(parent)
    local session = ns.UI.CreateCollectibleBrowser(parent, {
        listName = "CatalogHousingList",
        searchKey = "HOUSING_SEARCH",
        emptyKey = "HOUSING_EMPTY",
        selectKey = "HOUSING_SELECT",
        noResultsKey = "ITEMSEARCH_NO_RESULTS",
        defaultFilter = "all",
        navKind = "housing",
        filters = {
            { key = "all", label = L["JOURNAL_FILTER_SHOW_ALL"], descKey = "HOUSING_FILTER_ALL_DESC" },
            { key = "decor", label = L["DECOR"], descKey = "HOUSING_FILTER_DECOR_DESC" },
        },
        startQuery = function(filterKey, search, outResults, callbacks)
            ns.CollectibleBrowse.StartHousingQuery(filterKey, search, outResults, callbacks)
        end,
    })
    ns.UI.RefreshHousingList = session.Refresh
end
