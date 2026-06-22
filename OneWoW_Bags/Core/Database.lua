local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB
local pairs, wipe = pairs, wipe

local defaults = {
    global = {
        language = GetLocale(),
        theme = "green",
        minimap = {
            hide = false,
            minimapPos = 220,
            theme = "horde",
        },
        viewMode = "list",
        columns = 10,
        scale = 100,
        iconSize = 3,
        autoOpen = true,
        autoClose = false,
        autoOpenWithBank = true,
        locked = false,
        showBagsBar = true,
        hideBlizzardBagsBar = false,
        rarityColor = true,
        rarityIntensity = 1.0,
        showNewItems = true,
        recentItemDuration = 120,
        customCategoriesV2 = {},
        recentItems = {},
        pinnedCategories = {},
        collapsedSections = {},
        collapsedBagSections = {},
        categorySort = "priority",
        categoryOrder = {},
        categorySections = {},
        sectionOrder = {},
        trackedCurrencies = {},
        selectedBag = nil,
        disabledCategories = {},
        showEmptySlots = true,
        bankShowEmptySlots = true,
        warbandBankShowEmptySlots = true,
        guildBankShowEmptySlots = true,
        mainFramePosition = {},
        bagColumns = 15,
        bankColumns = 15,
        compactCategories = false,
        enableInventorySlots = false,
        itemSort = "none",
        hideScrollBar = false,
        enableBankUI = true,
        enableBankOverlays = true,
        bankShowWarband = false,
        bankViewMode = "list",
        guildBankViewMode = "list",
        bankFramePosition = {},
        guildBankFramePosition = {},
        bankSelectedTab = nil,
        guildBankSelectedTab = nil,
        collapsedBankSections = {},
        collapsedGuildBankSections = {},
        collapsedBankCategorySections = {},
        collapsedBankTabSections = {},
        collapsedGuildBankTabSections = {},
        showSearchBar = true,
        searchHistoryLimit = 10,
        searchHistory = {},
        savedSearches = {},
        showCategoryHeaders = true,
        categorySpacing = 1.0,
        bankHideScrollBar = false,
        showBankBagsBar = true,
        showBankSearchBar = true,
        showBankCategoryHeaders = true,
        bankCategorySpacing = 1.0,
        bankLocked = false,
        bankRarityColor = true,
        warbandBankViewMode = "list",
        warbandBankColumns = 15,
        warbandBankRarityColor = true,
        enableWarbandBankOverlays = true,
        warbandBankHideScrollBar = false,
        showWarbandBankBagsBar = true,
        showWarbandBankHeaderBar = true,
        showWarbandBankSearchBar = true,
        showWarbandBankCategoryHeaders = true,
        warbandBankCategorySpacing = 1.0,
        warbandBankCompactCategories = false,
        warbandBankCompactGap = 1,
        enableWarbandBankExpansionFilter = false,
        warbandBankSelectedTab = nil,
        collapsedWarbandBankTabSections = {},
        enableJunkCategory = true,
        enableUpgradeCategory = true,
        showHeaderBar = true,
        showBankHeaderBar = true,
        compactGap = 1,
        bankCompactGap = 1,
        bankCompactCategories = false,
        showMoneyBar = true,
        showCurrencyTrackerCapHighlight = true,
        showUnusableOverlay = false,
        dimJunkItems = false,
        stripJunkOverlays = false,
        categoryModifications = {},
        altToShow = false,
        displayOrder = {},
        stackItems = false,
        enableExpansionFilter = false,
        enableBankExpansionFilter = false,
        moveOtherToBottom = false,
        moveRecentToTop = false,
        pinnedCategoryShowsWhenDisabled = true,
        showKeywordsInTooltips = true,
        useMasque = true,
    },
}

function ns:InitializeDatabase()
    local sv = OneWoW_Bags_DB
    if sv and not sv.global and next(sv) ~= nil then
        local oldData = {}
        for k, v in pairs(sv) do
            oldData[k] = v
        end
        wipe(sv)
        sv.global = oldData
    end

    local db = DB:Init({
        addonName = ADDON_NAME,
        savedVar = "OneWoW_Bags_DB",
        defaults = defaults,
    })
    ns.db = db
end

--- Return the addon database handle after initialization.
---@return table db
function ns:GetDB()
    return ns.db
end
