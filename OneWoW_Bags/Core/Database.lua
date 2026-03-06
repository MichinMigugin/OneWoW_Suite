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
        trackedCurrencies = {},
        selectedBag = nil,
        disabledCategories = {},
        windowHeight = nil,
        showEmptySlots = true,
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

    if not self.db.global.trackedCurrencies then
        self.db.global.trackedCurrencies = {}
    end

    if not self.db.global.disabledCategories then
        self.db.global.disabledCategories = {}
    end

    if self.db.global.showEmptySlots == nil then
        self.db.global.showEmptySlots = true
    end
end
