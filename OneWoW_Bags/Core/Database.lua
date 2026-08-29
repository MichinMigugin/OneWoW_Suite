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
        iconSize = 3,
        autoOpen = true,
        autoClose = false,
        autoOpenWithBank = true,
        locked = false,
        showBagsBar = true,
        hideBlizzardBagsBar = false,
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
        bagScale = 100,
        bankColumns = 15,
        bankScale = 100,
        compactCategories = false,
        enableInventorySlots = false,
        itemSort = "none",
        hideScrollBar = false,
        enableBagsUI = true,
        enableBankUI = true,
        enableGuildBankUI = true,
        enableBankOverlays = true,
        bankShowWarband = false,
        bankViewMode = "list",
        guildBankViewMode = "list",
        bankFramePosition = {},
        guildBankFramePosition = {},
        guildBankScale = 100,
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
        warbandBankViewMode = "list",
        warbandBankColumns = 15,
        warbandBankScale = 100,
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
    ns:MigrateRarityToQualityBorder()
    ns:MigrateGuildBankUIEnable()
end

--- One-time: Bags rarityColor / bank / warband toggles → Overlay Quality Border.
--- Missing legacy keys count as the old default (true). Sticky flag prevents re-runs.
function ns:MigrateRarityToQualityBorder()
    local g = ns.db.global
    if g._migratedRarityToQualityBorder then return end

    -- Legacy SV keys may still be present; nil means old default (on).
    local anyOn = (g.rarityColor ~= false)
        or (g.bankRarityColor ~= false)
        or (g.warbandBankRarityColor ~= false)

    OneWoW.SettingsFeatureRegistry:SetEnabled("overlays", "qualityborder", anyOn)
    g._migratedRarityToQualityBorder = true
end

--- One-time: Enable Bank UI used to gate guild bank too. Players who already
--- turned it off keep Blizzard guild bank until they opt in separately.
function ns:MigrateGuildBankUIEnable()
    local g = ns.db.global
    if g._migratedGuildBankUIEnable then return end
    if g.enableBankUI == false then
        g.enableGuildBankUI = false
    end
    g._migratedGuildBankUIEnable = true
end

--- Return the addon database handle after initialization.
---@return table db
function ns:GetDB()
    return ns.db
end
