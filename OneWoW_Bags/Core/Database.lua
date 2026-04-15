local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB
local pairs, ipairs, next, wipe, tinsert, tremove, sort = pairs, ipairs, next, wipe, tinsert, tremove, table.sort
local strtrim = strtrim
local string_lower = string.lower

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
    },
}

function OneWoW_Bags:InitializeDatabase()
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
        addonName = "OneWoW_Bags",
        savedVar = "OneWoW_Bags_DB",
        defaults = defaults,
    })
    self.db = db

    if db.global._migrationVersion == nil then
        local v = 0
        if db.global.categoriesV2Migrated    then v = 1 end
        if db.global.junkRenameMigrated      then v = 2 end
        if db.global.displayOrderMigrated    then v = 3 end
        if db.global.categoriesV3Migrated    then v = 4 end
        if db.global.itemSortMigratedToNone  then v = 5 end
        if v > 0 then
            db.global._migrationVersion = v
        end
    end

    DB:RunMigrations(db, {
        { version = 1, name = "category_system_v2", run = function(d) self:MigrateCategorySystemV2(d) end },
        { version = 2, name = "junk_rename",        run = function(d) self:MigrateJunkRename(d) end },
        { version = 3, name = "display_order",      run = function(d) self:MigrateToDisplayOrder(d) end },
        { version = 4, name = "category_system_v3", run = function(d) self:MigrateCategorySystemV3(d) end },
        { version = 5, name = "item_sort_to_none",  run = function(d) self:MigrateItemSortToNone(d) end },
        { version = 6, name = "cleanup_old_flags",  run = function(d)
            local g = d.global
            g.categoriesV2Migrated = nil
            g.junkRenameMigrated = nil
            g.displayOrderMigrated = nil
            g.categoriesV3Migrated = nil
            g.itemSortMigratedToNone = nil
        end },
        { version = 7, name = "split_collapsed_bank_state", run = function(d)
            self:MigrateCollapsedBankState(d)
        end },
        { version = 8, name = "columns_minimum_10", run = function(d)
            local g = d.global
            if type(g.bagColumns) == "number" and g.bagColumns < 10 then
                g.bagColumns = 10
            end
            if type(g.bankColumns) == "number" and g.bankColumns < 10 then
                g.bankColumns = 10
            end
        end },
        { version = 9, name = "bank_columns_minimum_15", run = function(d)
            local g = d.global
            if type(g.bankColumns) == "number" and g.bankColumns < 15 then
                g.bankColumns = 15
            end
        end },
        { version = 10, name = "onewow_bags_default_section", run = function(d)
            self:MigrateOnewowBagsSection(d)
        end },
        { version = 11, name = "display_name_uniqueness", run = function(d)
            self:MigrateDisplayNameUniqueness(d)
        end },
        { version = 12, name = "section_category_membership_cleanup", run = function(d)
            self:MigrateSectionCategoryMembershipCleanup(d)
        end },
        { version = 13, name = "rename_move_upgrades_to_top", run = function(d)
            local g = d.global
            if g.moveUpgradesToTop ~= nil then
                g.moveRecentToTop = g.moveUpgradesToTop
                g.moveUpgradesToTop = nil
            end
        end },
        { version = 14, name = "hide_in_to_applies_in", run = function(d)
            local catMods = d.global.categoryModifications
            for _, mod in pairs(catMods) do
                if mod.hideIn then
                    mod.appliesIn = {}
                    for _, key in ipairs({ "backpack", "character_bank", "warband_bank" }) do
                        if mod.hideIn[key] then
                            mod.appliesIn[key] = false
                        end
                    end
                    if not next(mod.appliesIn) then mod.appliesIn = nil end
                    mod.hideIn = nil
                end
            end
        end },
    })
end

function OneWoW_Bags:MigrateCategorySystemV2(db)
    local g = db.global

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

function OneWoW_Bags:MigrateJunkRename(db)
    local g = db.global

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
end

function OneWoW_Bags:MigrateToDisplayOrder(db)
    local g = db.global
    if not g.categorySections or not g.sectionOrder then return end

    local inSection = {}
    for _, sec in pairs(g.categorySections) do
        for _, catName in ipairs(sec.categories or {}) do
            inSection[catName] = true
        end
    end

    local order = {}
    local catOrder = g.categoryOrder
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

function OneWoW_Bags:MigrateCategorySystemV3(db)
    local g = db.global

    if g.recentItemDuration == 600 then
        g.recentItemDuration = 120
    end

    local SD = OneWoW_Bags.SectionDefaults
    local secEquip = SD.SEC_EQUIPMENT
    local secCraft = SD.SEC_CRAFTING
    local secHouse = SD.SEC_HOUSING

    g.categorySections = {
        [secEquip] = { name = "EQUIPMENT", categories = CopyTable(SD.EQUIPMENT_CATEGORIES), collapsed = false, showHeader = true },
        [secCraft] = { name = "CRAFTING",  categories = CopyTable(SD.CRAFTING_CATEGORIES), collapsed = false, showHeader = true },
        [secHouse] = { name = "HOUSING",   categories = CopyTable(SD.HOUSING_CATEGORIES), collapsed = false, showHeader = true },
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

function OneWoW_Bags:MigrateItemSortToNone(db)
    db.global.itemSort = "none"
end

function OneWoW_Bags:MigrateOnewowBagsSection(db)
    local g = db.global
    local SD = OneWoW_Bags.SectionDefaults
    local secOw = SD.SEC_ONEWOW_BAGS
    local secEquip = SD.SEC_EQUIPMENT
    local secCraft = SD.SEC_CRAFTING
    local secHouse = SD.SEC_HOUSING
    local loc = OneWoW_Bags.Locales and OneWoW_Bags.Locales["enUS"]
    local secTitle = (loc and loc["SECTION_ONEWOW_BAGS"]) or "ONEWOW BAGS"

    if not g.categorySections[secEquip] then
        g.categorySections[secEquip] = { name = "EQUIPMENT", categories = CopyTable(SD.EQUIPMENT_CATEGORIES), collapsed = false, showHeader = true }
    end
    if not g.categorySections[secCraft] then
        g.categorySections[secCraft] = { name = "CRAFTING", categories = CopyTable(SD.CRAFTING_CATEGORIES), collapsed = false, showHeader = true }
    end
    if not g.categorySections[secHouse] then
        g.categorySections[secHouse] = { name = "HOUSING", categories = CopyTable(SD.HOUSING_CATEGORIES), collapsed = false, showHeader = true }
    end

    local order = g.sectionOrder
    local function orderContains(id)
        for _, v in ipairs(order) do
            if v == id then return true end
        end
        return false
    end
    if not orderContains(secEquip) then tinsert(order, secEquip) end
    if not orderContains(secCraft) then tinsert(order, secCraft) end
    if not orderContains(secHouse) then tinsert(order, secHouse) end

    if not g.categorySections[secOw] then
        local members = SD:BuildOnewowMembers(g)
        g.categorySections[secOw] = {
            name = secTitle,
            categories = members,
            collapsed = false,
            showHeader = false,
        }
        for _, nm in ipairs(members) do
            g.disabledCategories[nm] = nil
        end
    end

    for i = #order, 1, -1 do
        if order[i] == secOw then
            tremove(order, i)
        end
    end
    tinsert(order, 1, secOw)

    wipe(g.displayOrder)
    SD:ScrubCategoryOrderForSections(g)
end

function OneWoW_Bags:MigrateDisplayNameUniqueness(db)
    local g = db.global
    local SD = OneWoW_Bags.SectionDefaults
    local function norm(s)
        return string_lower(strtrim(s or ""))
    end

    local eff = SD:GetEffectiveBuiltinNames(g)
    local builtinNorm = {}
    for _, n in ipairs(eff) do
        builtinNorm[norm(n)] = true
    end

    local customEntries = {}
    for id in pairs(g.customCategoriesV2 or {}) do
        local cat = g.customCategoriesV2[id]
        tinsert(customEntries, { id = id, sortOrder = (cat and cat.sortOrder) or 0 })
    end
    sort(customEntries, function(a, b)
        if a.sortOrder ~= b.sortOrder then
            return a.sortOrder < b.sortOrder
        end
        return a.id < b.id
    end)

    local function categoryKeyFree(kn, usedCustomNorm)
        if builtinNorm[kn] then
            return false
        end
        if usedCustomNorm[kn] then
            return false
        end
        return true
    end

    local usedCustomNorm = {}
    for _, entry in ipairs(customEntries) do
        local cat = g.customCategoriesV2[entry.id]
        if cat and cat.name then
            local nm = strtrim(cat.name)
            if nm ~= "" then
                local kn = norm(nm)
                if not categoryKeyFree(kn, usedCustomNorm) then
                    local base = nm
                    local i = 2
                    repeat
                        nm = base .. " (" .. i .. ")"
                        kn = norm(nm)
                        i = i + 1
                    until categoryKeyFree(kn, usedCustomNorm)
                    cat.name = nm
                    kn = norm(nm)
                end
                usedCustomNorm[kn] = true
            end
        end
    end

    local seenSec = {}
    if g.sectionOrder and g.categorySections then
        for _, sid in ipairs(g.sectionOrder) do
            local sec = g.categorySections[sid]
            if sec and sec.name then
                local nm = strtrim(sec.name)
                if nm ~= "" then
                    local kn = norm(nm)
                    if seenSec[kn] then
                        local base = nm
                        local i = 2
                        repeat
                            nm = base .. " (" .. i .. ")"
                            kn = norm(nm)
                            i = i + 1
                        until not seenSec[kn]
                        sec.name = nm
                        kn = norm(nm)
                    end
                    seenSec[kn] = true
                end
            end
        end
    end

    if g.categorySections[SD.SEC_ONEWOW_BAGS] then
        SD:SyncOnewowSectionCategories(g)
    end
end

function OneWoW_Bags:MigrateSectionCategoryMembershipCleanup(db)
    local g = db.global
    local SD = OneWoW_Bags.SectionDefaults
    local eff = SD:GetEffectiveBuiltinNames(g)
    local builtinExact = {}
    for _, n in ipairs(eff) do
        builtinExact[n] = true
    end
    builtinExact["Empty"] = true

    local function normName(s)
        return string_lower(strtrim(s or ""))
    end

    local function isLiveCustomName(nm)
        local kn = normName(nm)
        if kn == "" then
            return false
        end
        for _, cd in pairs(g.customCategoriesV2 or {}) do
            if cd and cd.name and normName(cd.name) == kn then
                return true
            end
        end
        return false
    end

    for _, sec in pairs(g.categorySections or {}) do
        if sec and sec.categories then
            for i = #sec.categories, 1, -1 do
                local nm = sec.categories[i]
                if not builtinExact[nm] and not isLiveCustomName(nm) then
                    tremove(sec.categories, i)
                end
            end
        end
    end

    local seen = {}
    if g.sectionOrder and g.categorySections then
        for _, sid in ipairs(g.sectionOrder) do
            local sec = g.categorySections[sid]
            if sec and sec.categories then
                local newList = {}
                local seenLocal = {}
                for _, nm in ipairs(sec.categories) do
                    if not seen[nm] and not seenLocal[nm] then
                        seen[nm] = true
                        seenLocal[nm] = true
                        tinsert(newList, nm)
                    end
                end
                sec.categories = newList
            end
        end
    end

    if g.categorySections[SD.SEC_ONEWOW_BAGS] then
        SD:SyncOnewowSectionCategories(g)
    end
end

function OneWoW_Bags:MigrateCollapsedBankState(db)
    local g = db.global

    g.collapsedBankCategorySections = g.collapsedBankCategorySections or {}
    g.collapsedBankTabSections = g.collapsedBankTabSections or {}
    g.collapsedGuildBankTabSections = g.collapsedGuildBankTabSections or {}

    if g.collapsedBankSections then
        for key, value in pairs(g.collapsedBankSections) do
            if type(key) == "number" then
                g.collapsedBankTabSections[key] = value
            else
                local numericKey = tonumber(key)
                if numericKey then
                    g.collapsedBankTabSections[numericKey] = value
                else
                    g.collapsedBankCategorySections[key] = value
                end
            end
        end
    end

    if g.collapsedGuildBankSections then
        for key, value in pairs(g.collapsedGuildBankSections) do
            if type(key) == "number" then
                g.collapsedGuildBankTabSections[key] = value
            else
                local numericKey = tonumber(key)
                if numericKey then
                    g.collapsedGuildBankTabSections[numericKey] = value
                end
            end
        end
    end
end
