local _, ns = ...
local L = ns.L

ns.UI = ns.UI or {}

function ns.UI.CreateCollectiblesTab(parent)
    local session = ns.UI.CreateCollectibleBrowser(parent, {
        listName = "CatalogCollectiblesList",
        searchKey = "COLLECTIBLES_SEARCH",
        emptyKey = "COLLECTIBLES_EMPTY",
        selectKey = "COLLECTIBLES_SELECT",
        noResultsKey = "ITEMSEARCH_NO_RESULTS",
        defaultFilter = "all",
        navKind = "collectible",
        filters = {
            { key = "all", label = L["JOURNAL_FILTER_SHOW_ALL"], descKey = "COLLECTIBLES_FILTER_ALL_DESC" },
            { key = "appearance", label = L["JOURNAL_FILTER_TMOG"], descKey = "COLLECTIBLES_FILTER_TMOG_DESC" },
            { key = "mount", label = MOUNTS, descKey = "COLLECTIBLES_FILTER_MOUNT_DESC" },
            { key = "pet", label = PETS, descKey = "COLLECTIBLES_FILTER_PET_DESC" },
            { key = "toy", label = L["JOURNAL_FILTER_TOY"], descKey = "COLLECTIBLES_FILTER_TOY_DESC" },
        },
        startQuery = function(filterKey, search, outResults, callbacks)
            ns.CollectibleBrowse.StartCollectiblesQuery(filterKey, search, outResults, callbacks)
        end,
    })
    ns.UI.RefreshCollectiblesList = session.Refresh
end
