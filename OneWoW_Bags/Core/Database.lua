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
}

local function ApplyDefaults(target, source)
    for key, value in pairs(source) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = CopyTable(value)
            else
                target[key] = value
            end
        elseif type(value) == "table" and type(target[key]) == "table" then
            ApplyDefaults(target[key], value)
        end
    end
end

function OneWoW_Bags:InitializeDatabase()
    if not OneWoW_Bags_DB then
        OneWoW_Bags_DB = CopyTable(defaults.global)
    end

    self.db = {
        global = OneWoW_Bags_DB,
    }

    ApplyDefaults(self.db.global, defaults.global)

    if not self.db.global.itemSortMigratedToNone then
        self.db.global.itemSort = "none"
        self.db.global.itemSortMigratedToNone = true
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
            tinsert(order, name)
        end
    end

    for _, sectionID in ipairs(g.sectionOrder) do
        local sec = g.categorySections[sectionID]
        if sec and sec.categories then
            tinsert(order, "----")
            tinsert(order, "section:" .. sectionID)
            for _, catName in ipairs(sec.categories) do
                tinsert(order, catName)
            end
            tinsert(order, "section_end")
        end
    end

    g.displayOrder = order
end
