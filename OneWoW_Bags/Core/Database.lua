local ADDON_NAME, OneWoW_Bags = ...

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
        mainFramePosition = {},
        bagColumns = 15,
        bankColumns = 14,
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
        showSearchBar = true,
        showCategoryHeaders = true,
        categorySpacing = 1.0,
        bankHideScrollBar = false,
        showBankBagsBar = true,
        showBankSearchBar = true,
        showBankCategoryHeaders = true,
        bankCategorySpacing = 1.0,
        bankLocked = false,
        bankRarityColor = true,
        enableJunkCategory = true,
        enableUpgradeCategory = true,
        showHeaderBar = true,
        showBankHeaderBar = true,
        compactGap = 1,
        bankCompactGap = 1,
        bankCompactCategories = false,
        showMoneyBar = true,
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
        moveUpgradesToTop = false,
    },
    char = {}
}

function OneWoW_Bags:InitializeDatabase()
    if not OneWoW_Bags_DB then
        OneWoW_Bags_DB = CopyTable(defaults.global)
    end

    if not OneWoW_Bags_CharDB then
        OneWoW_Bags_CharDB = CopyTable(defaults.char)
    end

    self.db = {
        global = OneWoW_Bags_DB,
        char = OneWoW_Bags_CharDB
    }

    if not self.db.global.language then
        self.db.global.language = GetLocale()
    end

    if not self.db.global.theme then
        self.db.global.theme = "green"
    end

    if not self.db.global.minimap then
        self.db.global.minimap = {}
    end
    if self.db.global.minimap.hide == nil then
        self.db.global.minimap.hide = false
    end
    if self.db.global.minimap.minimapPos == nil then
        self.db.global.minimap.minimapPos = 220
    end
    if not self.db.global.minimap.theme then
        self.db.global.minimap.theme = "horde"
    end

    if not self.db.global.viewMode then
        self.db.global.viewMode = "list"
    end

    if self.db.global.columns == nil then
        self.db.global.columns = 10
    end

    if self.db.global.scale == nil then
        self.db.global.scale = 100
    end

    if self.db.global.iconSize == nil then
        self.db.global.iconSize = 3
    end

    if self.db.global.autoOpen == nil then
        self.db.global.autoOpen = true
    end

    if self.db.global.autoClose == nil then
        self.db.global.autoClose = false
    end

    if self.db.global.autoOpenWithBank == nil then
        self.db.global.autoOpenWithBank = true
    end

    if self.db.global.locked == nil then
        self.db.global.locked = false
    end

    if self.db.global.showBagsBar == nil then
        self.db.global.showBagsBar = true
    end

    if self.db.global.rarityColor == nil then
        self.db.global.rarityColor = true
    end

    if self.db.global.rarityIntensity == nil then
        self.db.global.rarityIntensity = 1.0
    end

    if self.db.global.showNewItems == nil then
        self.db.global.showNewItems = true
    end

    if self.db.global.recentItemDuration == nil then
        self.db.global.recentItemDuration = 600
    end

    if not self.db.global.customCategoriesV2 then
        self.db.global.customCategoriesV2 = {}
    end

    if not self.db.global.recentItems then
        self.db.global.recentItems = {}
    end

    if not self.db.global.pinnedCategories then
        self.db.global.pinnedCategories = {}
    end

    if not self.db.global.collapsedSections then
        self.db.global.collapsedSections = {}
    end

    if not self.db.global.collapsedBagSections then
        self.db.global.collapsedBagSections = {}
    end

    if not self.db.global.categorySort then
        self.db.global.categorySort = "priority"
    end

    if not self.db.global.categoryOrder then
        self.db.global.categoryOrder = {}
    end

    if not self.db.global.categorySections then
        self.db.global.categorySections = {}
    end

    if not self.db.global.sectionOrder then
        self.db.global.sectionOrder = {}
    end

    if not self.db.global.trackedCurrencies then
        self.db.global.trackedCurrencies = {}
    end

    if not self.db.global.disabledCategories then
        self.db.global.disabledCategories = {}
    end

    if self.db.global.showEmptySlots == nil then
        self.db.global.showEmptySlots = true
    end

    if not self.db.global.mainFramePosition then
        self.db.global.mainFramePosition = {}
    end

    if self.db.global.bagColumns == nil then
        self.db.global.bagColumns = 15
    end

    if self.db.global.bankColumns == nil then
        self.db.global.bankColumns = 14
    end

    if not self.db.global.itemSort then
        self.db.global.itemSort = "default"
    end

    if not self.db.global.itemSortMigratedToNone then
        self.db.global.itemSort = "none"
        self.db.global.itemSortMigratedToNone = true
    end

    if self.db.global.compactCategories == nil then
        self.db.global.compactCategories = false
    end

    if self.db.global.enableInventorySlots == nil then
        self.db.global.enableInventorySlots = false
    end

    if self.db.global.hideScrollBar == nil then
        self.db.global.hideScrollBar = false
    end

    if self.db.global.enableBankUI == nil then
        self.db.global.enableBankUI = true
    end

    if self.db.global.enableBankOverlays == nil then
        self.db.global.enableBankOverlays = true
    end

    if not self.db.global.bankViewMode then
        self.db.global.bankViewMode = "list"
    end

    if not self.db.global.guildBankViewMode then
        self.db.global.guildBankViewMode = "list"
    end

    if not self.db.global.bankFramePosition then
        self.db.global.bankFramePosition = {}
    end

    if not self.db.global.guildBankFramePosition then
        self.db.global.guildBankFramePosition = {}
    end

    if not self.db.global.collapsedBankSections then
        self.db.global.collapsedBankSections = {}
    end

    if not self.db.global.collapsedGuildBankSections then
        self.db.global.collapsedGuildBankSections = {}
    end

    if not self.db.global.categoriesV2Migrated then
        self:MigrateCategorySystemV2()
        self.db.global.categoriesV2Migrated = true
    end

    if not self.db.global.junkRenameMigrated then
        local g = self.db.global
        if g.disabledCategories then
            if g.disabledCategories["OneWoW Junk"] then
                g.disabledCategories["1W Junk"] = true
                g.disabledCategories["OneWoW Junk"] = nil
            end
            if g.disabledCategories["OneWoW Upgrades"] then
                g.disabledCategories["1W Upgrades"] = true
                g.disabledCategories["OneWoW Upgrades"] = nil
            end
        end
        if g.collapsedSections then
            if g.collapsedSections["OneWoW Junk"] then
                g.collapsedSections["1W Junk"] = g.collapsedSections["OneWoW Junk"]
                g.collapsedSections["OneWoW Junk"] = nil
            end
            if g.collapsedSections["OneWoW Upgrades"] then
                g.collapsedSections["1W Upgrades"] = g.collapsedSections["OneWoW Upgrades"]
                g.collapsedSections["OneWoW Upgrades"] = nil
            end
        end
        self.db.global.junkRenameMigrated = true
    end

    if not self.db.global.displayOrderMigrated then
        self:MigrateToDisplayOrder()
        self.db.global.displayOrderMigrated = true
    end

    if not self.db.global.categoriesV3Migrated then
        self:MigrateCategorySystemV3()
        self.db.global.categoriesV3Migrated = true
    end

    if self.db.global.showSearchBar == nil then
        self.db.global.showSearchBar = true
    end

    if self.db.global.showCategoryHeaders == nil then
        self.db.global.showCategoryHeaders = true
    end

    if self.db.global.categorySpacing == nil then
        self.db.global.categorySpacing = 1.0
    end

    if self.db.global.bankHideScrollBar == nil then
        self.db.global.bankHideScrollBar = false
    end

    if self.db.global.showBankBagsBar == nil then
        self.db.global.showBankBagsBar = true
    end

    if self.db.global.showBankSearchBar == nil then
        self.db.global.showBankSearchBar = true
    end

    if self.db.global.showBankCategoryHeaders == nil then
        self.db.global.showBankCategoryHeaders = true
    end

    if self.db.global.bankCategorySpacing == nil then
        self.db.global.bankCategorySpacing = 1.0
    end

    if self.db.global.bankAutoClose == nil then
        self.db.global.bankAutoClose = false
    end

    if self.db.global.bankLocked == nil then
        self.db.global.bankLocked = false
    end

    if self.db.global.bankRarityColor == nil then
        self.db.global.bankRarityColor = self.db.global.rarityColor
        if self.db.global.bankRarityColor == nil then
            self.db.global.bankRarityColor = true
        end
    end

    if self.db.global.enableJunkCategory == nil then
        self.db.global.enableJunkCategory = true
    end

    if self.db.global.enableUpgradeCategory == nil then
        self.db.global.enableUpgradeCategory = true
    end

    if self.db.global.showHeaderBar == nil then
        self.db.global.showHeaderBar = true
    end

    if self.db.global.showBankHeaderBar == nil then
        self.db.global.showBankHeaderBar = true
    end

    if self.db.global.compactGap == nil then
        self.db.global.compactGap = 1
    end

    if self.db.global.bankCompactGap == nil then
        self.db.global.bankCompactGap = 1
    end

    if self.db.global.bankCompactCategories == nil then
        self.db.global.bankCompactCategories = false
    end

    if self.db.global.showMoneyBar == nil then
        self.db.global.showMoneyBar = true
    end

    if self.db.global.showUnusableOverlay == nil then
        self.db.global.showUnusableOverlay = false
    end

    if self.db.global.dimJunkItems == nil then
        self.db.global.dimJunkItems = false
    end

    if self.db.global.stripJunkOverlays == nil then
        self.db.global.stripJunkOverlays = false
    end

    if not self.db.global.categoryModifications then
        self.db.global.categoryModifications = {}
    end

    if self.db.global.altToShow == nil then
        self.db.global.altToShow = false
    end

    if not self.db.global.displayOrder then
        self.db.global.displayOrder = {}
    end
    if self.db.global.stackItems == nil then
        self.db.global.stackItems = false
    end

    if self.db.global.enableExpansionFilter == nil then
        self.db.global.enableExpansionFilter = false
    end

    if self.db.global.enableBankExpansionFilter == nil then
        self.db.global.enableBankExpansionFilter = false
    end

    if self.db.global.moveOtherToBottom == nil then
        self.db.global.moveOtherToBottom = false
    end

    if self.db.global.moveUpgradesToTop == nil then
        self.db.global.moveUpgradesToTop = false
    end
end

function OneWoW_Bags:MigrateCategorySystemV2()
    local g = self.db.global

    local OLD_TO_NEW = {
        ["Equipment"] = { "Weapons", "Armor" },
        ["Consumables"] = { "Potions", "Food", "Consumables" },
    }

    if g.disabledCategories then
        for oldName, newNames in pairs(OLD_TO_NEW) do
            if g.disabledCategories[oldName] then
                for _, newName in ipairs(newNames) do
                    g.disabledCategories[newName] = true
                end
                g.disabledCategories[oldName] = nil
            end
        end
    end

    if g.collapsedSections then
        for oldName, newNames in pairs(OLD_TO_NEW) do
            if g.collapsedSections[oldName] then
                for _, newName in ipairs(newNames) do
                    g.collapsedSections[newName] = true
                end
                g.collapsedSections[oldName] = nil
            end
        end
    end

    g.categoryOrder = { "Recent Items" }

    local secDefault = "sec_default_general"
    local secEquip   = "sec_default_equipment"
    local secCraft   = "sec_default_crafting"
    local secHouse   = "sec_default_housing"

    g.categorySections = {
        [secDefault] = { name = "DEFAULT", categories = {
            "Hearthstone", "Keystone", "Potions", "Food", "Consumables", "Quest Items",
            "Gems", "Item Enhancement", "Containers", "Keys",
            "Miscellaneous", "Battle Pets", "Toys", "Other", "Junk",
        }, collapsed = false },
        [secEquip] = { name = "EQUIPMENT", categories = { "Equipment Sets", "Weapons", "Armor" }, collapsed = false },
        [secCraft] = { name = "CRAFTING",  categories = { "Reagents", "Trade Goods", "Tradeskill", "Recipes" }, collapsed = false },
        [secHouse] = { name = "HOUSING",   categories = { "Housing" }, collapsed = false },
    }
    g.sectionOrder = { secDefault, secEquip, secCraft, secHouse }
end

function OneWoW_Bags:MigrateCategorySystemV3()
    local g = self.db.global

    if g.recentItemDuration == 600 then
        g.recentItemDuration = 120
    end

    local secEquip = "sec_equipment"
    local secCraft = "sec_crafting"
    local secHouse = "sec_housing"

    g.categorySections = {
        [secEquip] = { name = "EQUIPMENT", categories = { "Equipment Sets", "Weapons", "Armor" }, collapsed = false, showHeader = true },
        [secCraft] = { name = "CRAFTING",  categories = { "Reagents", "Trade Goods", "Tradeskill", "Recipes" }, collapsed = false, showHeader = true },
        [secHouse] = { name = "HOUSING",   categories = { "Housing" }, collapsed = false, showHeader = true },
    }
    g.sectionOrder = { secEquip, secCraft, secHouse }

    g.displayOrder = {
        "1W Junk",
        "1W Upgrades",
        "Recent Items",
        "----",
        "Hearthstone",
        "Keystone",
        "Potions",
        "Food",
        "Consumables",
        "Quest Items",
        "section:" .. secEquip,
        "Equipment Sets",
        "Weapons",
        "Armor",
        "section_end",
        "section:" .. secCraft,
        "Reagents",
        "Trade Goods",
        "Tradeskill",
        "Recipes",
        "section_end",
        "section:" .. secHouse,
        "Housing",
        "section_end",
        "Gems",
        "Item Enhancement",
        "Containers",
        "Keys",
        "Miscellaneous",
        "Battle Pets",
        "Toys",
        "Other",
        "----",
        "Junk",
        "Empty",
    }

    if g.collapsedSections then
        if g.collapsedSections["Pets and Mounts"] ~= nil then
            g.collapsedSections["Battle Pets"] = g.collapsedSections["Pets and Mounts"]
            g.collapsedSections["Pets and Mounts"] = nil
        end
        g.collapsedSections["Cosmetics"] = nil
    end
    if g.collapsedBankSections then
        if g.collapsedBankSections["Pets and Mounts"] ~= nil then
            g.collapsedBankSections["Battle Pets"] = g.collapsedBankSections["Pets and Mounts"]
            g.collapsedBankSections["Pets and Mounts"] = nil
        end
        g.collapsedBankSections["Cosmetics"] = nil
    end

    if g.categoryModifications then
        if g.categoryModifications["Pets and Mounts"] then
            g.categoryModifications["Battle Pets"] = g.categoryModifications["Pets and Mounts"]
            g.categoryModifications["Pets and Mounts"] = nil
        end
        g.categoryModifications["Cosmetics"] = nil
    end

    if g.disabledCategories then
        if g.disabledCategories["Pets and Mounts"] then
            g.disabledCategories["Battle Pets"] = true
            g.disabledCategories["Pets and Mounts"] = nil
        end
        g.disabledCategories["Cosmetics"] = nil
    end

    g.categoryOrder = {}
end

function OneWoW_Bags:MigrateToDisplayOrder()
    local g = self.db.global
    if not g.categorySections or not g.sectionOrder then return end

    local inSection = {}
    for _, sec in pairs(g.categorySections) do
        for _, catName in ipairs(sec.categories or {}) do
            inSection[catName] = true
        end
    end

    local order = {}
    local catOrder = g.categoryOrder or {}
    for _, name in ipairs(catOrder) do
        if not inSection[name] then
            table.insert(order, name)
        end
    end

    for _, sectionID in ipairs(g.sectionOrder) do
        local sec = g.categorySections[sectionID]
        if sec and sec.categories then
            table.insert(order, "----")
            table.insert(order, "section:" .. sectionID)
            for _, catName in ipairs(sec.categories) do
                table.insert(order, catName)
            end
            table.insert(order, "section_end")
        end
    end

    g.displayOrder = order
end
