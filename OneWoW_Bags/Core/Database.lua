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
        recentItemDuration = 600,
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
            "Miscellaneous", "Pets and Mounts", "Toys", "Cosmetics", "Other", "Junk",
        }, collapsed = false },
        [secEquip] = { name = "EQUIPMENT", categories = { "Equipment Sets", "Weapons", "Armor" }, collapsed = false },
        [secCraft] = { name = "CRAFTING",  categories = { "Reagents", "Trade Goods", "Tradeskill", "Recipes" }, collapsed = false },
        [secHouse] = { name = "HOUSING",   categories = { "Housing" }, collapsed = false },
    }
    g.sectionOrder = { secDefault, secEquip, secCraft, secHouse }
end
