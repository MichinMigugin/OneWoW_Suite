local _, OneWoW_Bags = ...

local ipairs, pairs = ipairs, pairs
local random, time = math.random, time
local tonumber, tostring = tonumber, tostring
local tinsert, tremove, wipe, sort = tinsert, tremove, wipe, sort

OneWoW_Bags.CategoryController = {}
local CategoryController = OneWoW_Bags.CategoryController

local BUILTIN_PRIORITY = {
    ["Recent Items"] = 1,
    ["Hearthstone"] = 2,
    ["Keystone"] = 3,
    ["Potions"] = 4,
    ["Food"] = 5,
    ["Consumables"] = 6,
    ["Quest Items"] = 7,
    ["Equipment Sets"] = 8,
    ["Weapons"] = 9,
    ["Armor"] = 10,
    ["Reagents"] = 11,
    ["Trade Goods"] = 12,
    ["Tradeskill"] = 13,
    ["Recipes"] = 14,
    ["Housing"] = 15,
    ["Gems"] = 16,
    ["Item Enhancement"] = 17,
    ["Containers"] = 18,
    ["Keys"] = 19,
    ["Miscellaneous"] = 20,
    ["Battle Pets"] = 21,
    ["Toys"] = 22,
    ["Junk"] = 90,
    ["Other"] = 98,
}

local BAGANATOR_CAT_MAP = {
    ["default_auto_recents"] = "Recent Items",
    ["default_weapon"] = "Weapons",
    ["default_armor"] = "Armor",
    ["default_auto_equipment_sets"] = "Equipment Sets",
    ["default_consumable"] = "Consumables",
    ["default_food"] = "Food",
    ["default_potion"] = "Potions",
    ["default_reagent"] = "Reagents",
    ["default_tradegoods"] = "Trade Goods",
    ["default_profession"] = "Tradeskill",
    ["default_recipe"] = "Recipes",
    ["default_gem"] = "Gems",
    ["default_questitem"] = "Quest Items",
    ["default_toy"] = "Toys",
    ["default_battlepet"] = "Battle Pets",
    ["default_miscellaneous"] = "Miscellaneous",
    ["default_key"] = "Keys",
    ["default_keystone"] = "Keystone",
    ["default_junk"] = "Junk",
    ["default_other"] = "Other",
    ["default_housing"] = "Housing",
    ["default_container"] = "Containers",
    ["default_itemenhancement"] = "Item Enhancement",
    ["default_hearthstone"] = "Hearthstone",
    ["default_special_empty"] = "Empty",
}

function CategoryController:Create(addon)
    local controller = {}
    controller.addon = addon
    setmetatable(controller, { __index = self })
    return controller
end

function CategoryController:GetDB()
    return self.addon:GetDB()
end

function CategoryController:RefreshUI(options)
    options = options or {}
    if options.invalidate ~= false then
        self.addon:InvalidateCategorization(options.scope)
    end
    if options.refreshUI ~= false and self.addon.CategoryManagerUI and self.addon.CategoryManagerUI.Refresh then
        self.addon.CategoryManagerUI:Refresh()
    end
    if options.layout ~= false then
        self.addon:RequestLayoutRefresh("bags")
    end
end

function CategoryController:CreateCategory(name)
    if not name or name == "" then return nil end

    local db = self:GetDB()
    local order = 1
    for _, category in pairs(db.global.customCategoriesV2) do
        if category.sortOrder and category.sortOrder >= order then
            order = category.sortOrder + 1
        end
    end

    local id = "custom_" .. time() .. "_" .. random(1000, 9999)
    db.global.customCategoriesV2[id] = {
        name = name,
        items = {},
        enabled = true,
        sortOrder = order,
    }

    self:RefreshUI()
    return id
end

function CategoryController:RenameCategory(id, name)
    if not id or not name or name == "" then return end

    local category = self:GetDB().global.customCategoriesV2[id]
    if not category then return end

    category.name = name
    self:RefreshUI({ invalidate = false })
end

function CategoryController:DeleteCategory(id)
    if not id then return end

    self:GetDB().global.customCategoriesV2[id] = nil
    self:RefreshUI()
end

function CategoryController:CreateSection(name)
    if not name or name == "" then return nil end

    local db = self:GetDB()
    local id = "sec_" .. time() .. "_" .. random(1000, 9999)
    db.global.categorySections[id] = {
        name = name,
        categories = {},
        collapsed = false,
        showHeader = true,
    }
    tinsert(db.global.sectionOrder, id)
    if db.global.displayOrder and #db.global.displayOrder > 0 then
        wipe(db.global.displayOrder)
    end

    self:RefreshUI()
    return id
end

function CategoryController:RenameSection(id, name)
    if not id or not name or name == "" then return end

    local section = self:GetDB().global.categorySections[id]
    if not section then return end

    section.name = name
    self:RefreshUI({ invalidate = false })
end

function CategoryController:DeleteSection(id)
    if not id then return end

    local db = self:GetDB()
    db.global.categorySections[id] = nil

    for i, sectionID in ipairs(db.global.sectionOrder) do
        if sectionID == id then
            tremove(db.global.sectionOrder, i)
            break
        end
    end

    if #db.global.displayOrder > 0 then
        wipe(db.global.displayOrder)
    end

    self:RefreshUI()
end

function CategoryController:SetSectionCollapsed(id, collapsed)
    local section = self:GetDB().global.categorySections[id]
    if not section then return end

    section.collapsed = collapsed
    if self.addon.CategoryManagerUI and self.addon.CategoryManagerUI.Refresh then
        self.addon.CategoryManagerUI:Refresh()
    end
end

function CategoryController:SetSectionShowHeader(id, showHeader)
    local section = self:GetDB().global.categorySections[id]
    if not section then return end

    section.showHeader = showHeader and true or false
    self:RefreshUI({ invalidate = false })
end

function CategoryController:SetSectionMembership(id, categoryName, isMember)
    local db = self:GetDB()
    local section = db.global.categorySections[id]
    if not section then return end

    if isMember then
        for _, existing in ipairs(section.categories) do
            if existing == categoryName then
                return
            end
        end
        tinsert(section.categories, categoryName)
    else
        for i, existing in ipairs(section.categories) do
            if existing == categoryName then
                tremove(section.categories, i)
                break
            end
        end
    end

    if #db.global.displayOrder > 0 then
        wipe(db.global.displayOrder)
    end

    self:RefreshUI()
end

function CategoryController:EnsureRootCategoryOrder(rootCats)
    local db = self:GetDB()
    if #db.global.categoryOrder > 0 then
        return db.global.categoryOrder
    end

    local seeded = {}
    for i, entry in ipairs(rootCats) do
        seeded[i] = entry.name
    end
    db.global.categoryOrder = seeded
    return db.global.categoryOrder
end

function CategoryController:MoveRootCategory(rootCats, index, direction)
    local order = self:EnsureRootCategoryOrder(rootCats)
    local otherIndex = index + direction
    if otherIndex < 1 or otherIndex > #order then return end

    order[index], order[otherIndex] = order[otherIndex], order[index]
    self:RefreshUI({ invalidate = false })
end

function CategoryController:MoveSection(sectionID, direction)
    local sectionOrder = self:GetDB().global.sectionOrder
    for i, id in ipairs(sectionOrder) do
        if id == sectionID then
            local otherIndex = i + direction
            if otherIndex < 1 or otherIndex > #sectionOrder then
                return
            end
            sectionOrder[i], sectionOrder[otherIndex] = sectionOrder[otherIndex], sectionOrder[i]
            self:RefreshUI({ invalidate = false })
            return
        end
    end
end

function CategoryController:MoveSectionCategory(sectionID, index, direction)
    local section = self:GetDB().global.categorySections[sectionID]
    if not section then return end

    local otherIndex = index + direction
    if otherIndex < 1 or otherIndex > #section.categories then return end

    section.categories[index], section.categories[otherIndex] = section.categories[otherIndex], section.categories[index]
    self:RefreshUI({ invalidate = false })
end

function CategoryController:SetBuiltinCategoryEnabled(categoryName, enabled)
    local disabledCategories = self:GetDB().global.disabledCategories
    if enabled then
        disabledCategories[categoryName] = nil
    else
        disabledCategories[categoryName] = true
    end
    self:RefreshUI()
end

function CategoryController:GetCategoryModification(categoryName)
    return self.addon:EnsureCategoryModification(categoryName)
end

function CategoryController:SetCategorySortMode(categoryName, value)
    self:GetCategoryModification(categoryName).sortMode = value
    self:RefreshUI({ invalidate = false })
end

function CategoryController:SetCategoryGroupBy(categoryName, value)
    self:GetCategoryModification(categoryName).groupBy = value
    self:RefreshUI({ invalidate = false })
end

function CategoryController:SetCategoryPriority(categoryName, value)
    self:GetCategoryModification(categoryName).priority = value
    self:RefreshUI()
end

function CategoryController:SetCategoryColor(categoryName, hex)
    self:GetCategoryModification(categoryName).color = hex
    self:RefreshUI({ invalidate = false })
end

function CategoryController:ClearCategoryColor(categoryName)
    self:GetCategoryModification(categoryName).color = nil
    self:RefreshUI({ invalidate = false })
end

function CategoryController:SetCategoryHiddenIn(categoryName, key, hidden)
    local hideIn = self:GetCategoryModification(categoryName).hideIn
    if not hideIn then
        hideIn = {}
        self:GetCategoryModification(categoryName).hideIn = hideIn
    end

    if hidden then
        hideIn[key] = true
    else
        hideIn[key] = nil
    end
    self:RefreshUI({ invalidate = false })
end

function CategoryController:SetCustomCategoryValue(categoryID, key, value, options)
    local category = self:GetDB().global.customCategoriesV2[categoryID]
    if not category then return end

    category[key] = value
    self:RefreshUI(options)
end

function CategoryController:AddItemToCategory(categoryKey, itemID)
    local db = self:GetDB()
    local numericID = tonumber(itemID)
    if not categoryKey or not numericID then return end

    if categoryKey:sub(1, 8) == "builtin:" then
        self.addon.Categories:AddItemToBuiltinCategory(categoryKey:sub(9), numericID)
    else
        for id, category in pairs(db.global.customCategoriesV2) do
            if id ~= categoryKey and category.items then
                category.items[tostring(numericID)] = nil
            end
        end

        local target = db.global.customCategoriesV2[categoryKey]
        if target then
            target.items = target.items or {}
            target.items[tostring(numericID)] = true
        end
    end

    self:RefreshUI()
end

function CategoryController:AddItemsToCategory(categoryKey, itemIDs)
    for _, itemID in ipairs(itemIDs) do
        self:AddItemToCategory(categoryKey, itemID)
    end
end

function CategoryController:RemoveItemFromCategory(categoryKey, itemID)
    local db = self:GetDB()
    local numericID = tonumber(itemID)
    if not categoryKey or not numericID then return end

    if categoryKey:sub(1, 8) == "builtin:" then
        self.addon.Categories:RemoveItemFromBuiltinCategory(categoryKey:sub(9), numericID)
    else
        local target = db.global.customCategoriesV2[categoryKey]
        if target and target.items then
            target.items[tostring(numericID)] = nil
        end
    end

    self:RefreshUI()
end

function CategoryController:ImportBaganator()
    local db = self:GetDB()
    if not _G.BAGANATOR_CONFIG or not _G.BAGANATOR_CONFIG.Profiles then
        return 0, 0
    end

    local importedCategories = 0
    local importedSections = 0
    local profile
    for _, candidate in pairs(_G.BAGANATOR_CONFIG.Profiles) do
        profile = candidate
        break
    end
    if not profile then
        return 0, 0
    end

    if profile.custom_categories then
        for _, categoryData in pairs(profile.custom_categories) do
            local name = categoryData.name
            if name and name ~= "" then
                local exists = false
                for _, existing in pairs(db.global.customCategoriesV2) do
                    if existing.name == name then
                        exists = true
                        break
                    end
                end
                if not exists then
                    local id = self:CreateCategory(name)
                    local target = db.global.customCategoriesV2[id]
                    target.items = {}

                    if categoryData.items then
                        if categoryData.items[1] ~= nil then
                            for _, rawID in ipairs(categoryData.items) do
                                if tonumber(rawID) then
                                    target.items[tostring(rawID)] = true
                                end
                            end
                        else
                            for rawID in pairs(categoryData.items) do
                                if tonumber(rawID) then
                                    target.items[tostring(rawID)] = true
                                end
                            end
                        end
                    end

                    if categoryData.rules then
                        for _, rule in ipairs(categoryData.rules) do
                            if rule.type == "item" and rule.itemID then
                                target.items[tostring(rule.itemID)] = true
                            end
                        end
                    end

                    importedCategories = importedCategories + 1
                end
            end
        end
    end

    local sectionIDMap = {}
    if profile.category_sections and profile.category_display_order then
        for bagIndex, sectionData in pairs(profile.category_sections) do
            local name = sectionData.name
            if name and name ~= "" then
                local exists = false
                for _, existing in pairs(db.global.categorySections) do
                    if existing.name == name then
                        exists = true
                        break
                    end
                end
                if not exists then
                    local sectionID = self:CreateSection(name)
                    sectionIDMap[bagIndex] = sectionID
                    importedSections = importedSections + 1
                end
            end
        end

        local currentSectionID
        local addedToSection = {}
        for _, entry in ipairs(profile.category_display_order) do
            if entry:sub(1, 1) == "_" and entry ~= "----" then
                if entry == "__end" then
                    currentSectionID = nil
                    wipe(addedToSection)
                else
                    currentSectionID = sectionIDMap[entry:sub(2)]
                end
            elseif entry ~= "----" and currentSectionID then
                local categoryName = BAGANATOR_CAT_MAP[entry]
                if categoryName and not addedToSection[categoryName] then
                    local section = db.global.categorySections[currentSectionID]
                    if section then
                        tinsert(section.categories, categoryName)
                        addedToSection[categoryName] = true
                    end
                end
            end
        end
    end

    self:RefreshUI()
    return importedCategories, importedSections
end

function CategoryController:ImportTSM()
    local tsm = self.addon.TSMIntegration
    if not tsm or not tsm.IsAvailable or not tsm:IsAvailable() then
        return 0
    end

    local count = tsm:Import()
    if count > 0 then
        self:RefreshUI()
    end
    return count
end
