local _, OneWoW_Bags = ...

local ipairs, pairs = ipairs, pairs
local random, time = math.random, time
local tonumber, tostring = tonumber, tostring
local tinsert, tremove, wipe = tinsert, tremove, wipe
local strtrim = strtrim
local string_lower = string.lower

OneWoW_Bags.CategoryController = {}
local CategoryController = OneWoW_Bags.CategoryController

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

local function removeCategoryNameFromOtherSections(g, categoryName, keepSectionId)
    for sid, sec in pairs(g.categorySections) do
        if sid ~= keepSectionId and sec and sec.categories then
            for i = #sec.categories, 1, -1 do
                if sec.categories[i] == categoryName then
                    tremove(sec.categories, i)
                end
            end
        end
    end
end

local function removeCategoryNameFromAllSections(g, categoryName)
    for _, sec in pairs(g.categorySections) do
        if sec and sec.categories then
            for i = #sec.categories, 1, -1 do
                if sec.categories[i] == categoryName then
                    tremove(sec.categories, i)
                end
            end
        end
    end
end

local function replaceCategoryNameInAllSections(g, oldName, newName)
    if oldName == newName then return end
    for _, sec in pairs(g.categorySections) do
        if sec and sec.categories then
            for i, nm in ipairs(sec.categories) do
                if nm == oldName then
                    sec.categories[i] = newName
                end
            end
        end
    end
end

function CategoryController:Create(addon)
    local controller = {}
    controller.addon = addon
    setmetatable(controller, { __index = self })
    return controller
end

function CategoryController:GetDB()
    return self.addon:GetDB()
end

function CategoryController:NormalizeDisplayNameKey(name)
    if not name or type(name) ~= "string" then
        return ""
    end
    return string_lower(strtrim(name))
end

function CategoryController:IsCategoryDisplayNameAvailable(name, excludeCustomId)
    local key = self:NormalizeDisplayNameKey(name)
    if key == "" then
        return false
    end
    local g = self:GetDB().global
    local SD = OneWoW_Bags.SectionDefaults
    for _, bn in ipairs(SD:GetEffectiveBuiltinNames(g)) do
        if string_lower(bn) == key then
            return false
        end
    end
    for cid, cat in pairs(g.customCategoriesV2) do
        if cid ~= excludeCustomId and cat and cat.name then
            if self:NormalizeDisplayNameKey(cat.name) == key then
                return false
            end
        end
    end
    return true
end

function CategoryController:IsSectionDisplayNameAvailable(name, excludeSectionId)
    local key = self:NormalizeDisplayNameKey(name)
    if key == "" then
        return false
    end
    local g = self:GetDB().global
    for sid, sec in pairs(g.categorySections) do
        if sid ~= excludeSectionId and sec and sec.name then
            if self:NormalizeDisplayNameKey(sec.name) == key then
                return false
            end
        end
    end
    return true
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
        self.addon:RequestLayoutRefresh("all")
    end
end

function CategoryController:CreateCategory(name)
    name = name and strtrim(name) or ""
    if name == "" then return nil end
    if not self:IsCategoryDisplayNameAvailable(name, nil) then
        return nil, "DUPLICATE_CATEGORY_NAME"
    end

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
    if not id then return false end
    name = name and strtrim(name) or ""
    if name == "" then return false end

    local db = self:GetDB()
    local g = db.global
    local category = g.customCategoriesV2[id]
    if not category then return false end

    if self:NormalizeDisplayNameKey(category.name) == self:NormalizeDisplayNameKey(name) then
        local oldName = category.name
        category.name = name
        replaceCategoryNameInAllSections(g, oldName, name)
        if oldName ~= name then
            if #db.global.displayOrder > 0 then
                wipe(db.global.displayOrder)
            end
            if g.categorySections[OneWoW_Bags.SectionDefaults.SEC_ONEWOW_BAGS] then
                OneWoW_Bags.SectionDefaults:SyncOnewowSectionCategories(g)
            end
            self:RefreshUI()
        else
            self:RefreshUI({ invalidate = false })
        end
        return true
    end
    if not self:IsCategoryDisplayNameAvailable(name, id) then
        return false, "DUPLICATE_CATEGORY_NAME"
    end

    local oldName = category.name
    category.name = name
    replaceCategoryNameInAllSections(g, oldName, name)
    if #db.global.displayOrder > 0 then
        wipe(db.global.displayOrder)
    end
    if g.categorySections[OneWoW_Bags.SectionDefaults.SEC_ONEWOW_BAGS] then
        OneWoW_Bags.SectionDefaults:SyncOnewowSectionCategories(g)
    end
    self:RefreshUI()
    return true
end

function CategoryController:DeleteCategory(id)
    if not id then return end

    local db = self:GetDB()
    local g = db.global
    local cat = g.customCategoriesV2[id]
    local catName = cat and cat.name and strtrim(cat.name) or nil
    g.customCategoriesV2[id] = nil
    if catName and catName ~= "" then
        removeCategoryNameFromAllSections(g, catName)
    end
    if #db.global.displayOrder > 0 then
        wipe(db.global.displayOrder)
    end
    if g.categorySections[OneWoW_Bags.SectionDefaults.SEC_ONEWOW_BAGS] then
        OneWoW_Bags.SectionDefaults:SyncOnewowSectionCategories(g)
    end
    self:RefreshUI()
end

function CategoryController:CreateSection(name)
    name = name and strtrim(name) or ""
    if name == "" then return nil end
    if not self:IsSectionDisplayNameAvailable(name, nil) then
        return nil, "DUPLICATE_SECTION_NAME"
    end

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
    if not id then return false end
    name = name and strtrim(name) or ""
    if name == "" then return false end

    local section = self:GetDB().global.categorySections[id]
    if not section then return false end

    if self:NormalizeDisplayNameKey(section.name) == self:NormalizeDisplayNameKey(name) then
        section.name = name
        self:RefreshUI({ invalidate = false })
        return true
    end
    if not self:IsSectionDisplayNameAvailable(name, id) then
        return false, "DUPLICATE_SECTION_NAME"
    end

    section.name = name
    self:RefreshUI({ invalidate = false })
    return true
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

    if id ~= OneWoW_Bags.SectionDefaults.SEC_ONEWOW_BAGS then
        OneWoW_Bags.SectionDefaults:SyncOnewowSectionCategories(db.global)
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

    if section.showHeaderBank == nil then
        section.showHeaderBank = section.showHeader or false
    end
    section.showHeader = showHeader and true or false
    self:RefreshUI({ invalidate = false })
end

function CategoryController:SetSectionShowHeaderBank(id, showHeader)
    local section = self:GetDB().global.categorySections[id]
    if not section then return end

    section.showHeaderBank = showHeader and true or false
    self:RefreshUI({ invalidate = false })
end

function CategoryController:SetSectionMembership(id, categoryName, isMember)
    local db = self:GetDB()
    local section = db.global.categorySections[id]
    if not section then return end

    if isMember then
        removeCategoryNameFromOtherSections(db.global, categoryName, id)
        local already = false
        for _, existing in ipairs(section.categories) do
            if existing == categoryName then
                already = true
                break
            end
        end
        if not already then
            tinsert(section.categories, categoryName)
        end
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

    if id ~= OneWoW_Bags.SectionDefaults.SEC_ONEWOW_BAGS then
        OneWoW_Bags.SectionDefaults:SyncOnewowSectionCategories(db.global)
    end

    self:RefreshUI()
end

function CategoryController:MoveSectionOrder(fromIndex, toIndex)
    local sectionOrder = self:GetDB().global.sectionOrder
    local n = #sectionOrder
    if fromIndex < 1 or fromIndex > n or toIndex < 1 or toIndex > n or fromIndex == toIndex then
        return
    end
    local id = tremove(sectionOrder, fromIndex)
    tinsert(sectionOrder, toIndex, id)
    self:RefreshUI()
end

function CategoryController:MoveCategoryToSection(fromSectionID, fromIdx, toSectionID, toIdx)
    local sections = self:GetDB().global.categorySections
    local src, dst = sections[fromSectionID], sections[toSectionID]
    if not src or not dst or not src.categories or not src.categories[fromIdx] then return end

    local name = tremove(src.categories, fromIdx)
    if src == dst and toIdx > fromIdx then toIdx = toIdx - 1 end
    local dstLen = dst.categories and #dst.categories or 0
    if not dst.categories then dst.categories = {} end
    if toIdx < 1 then toIdx = 1 end
    if toIdx > dstLen + 1 then toIdx = dstLen + 1 end
    tinsert(dst.categories, toIdx, name)
    self:RefreshUI()
end

function CategoryController:SetCategoryEnabled(categoryName, enabled)
    local disabledCategories = self:GetDB().global.disabledCategories
    if enabled then
        disabledCategories[categoryName] = nil
    else
        disabledCategories[categoryName] = true
    end
    self:RefreshUI()
end

CategoryController.SetBuiltinCategoryEnabled = CategoryController.SetCategoryEnabled

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

function CategoryController:SetCategoryAppliesIn(categoryName, key, applies)
    local mod = self:GetCategoryModification(categoryName)
    if applies then
        if mod.appliesIn then
            mod.appliesIn[key] = nil
            if not next(mod.appliesIn) then mod.appliesIn = nil end
        end
    else
        if not mod.appliesIn then mod.appliesIn = {} end
        mod.appliesIn[key] = false
    end
    self:RefreshUI({ invalidate = true })
end

function CategoryController:SetCustomCategoryValue(categoryID, key, value, options)
    local category = self:GetDB().global.customCategoriesV2[categoryID]
    if not category then return end

    category[key] = value
    self:RefreshUI(options)
end

function CategoryController:AddItemToCategory(categoryKey, itemID, options)
    options = options or {}
    local db = self:GetDB()
    local numericID = tonumber(itemID)
    if not categoryKey or not numericID then return false end

    local Categories = self.addon.Categories

    if categoryKey:sub(1, 8) == "builtin:" then
        local catName = categoryKey:sub(9)
        local ok, ownerName = Categories:AddItemToBuiltinCategory(catName, numericID)
        if not ok then
            return false, ownerName
        end
    else
        local pin = Categories:FindManualPinForItem(numericID)
        if pin then
            if pin.kind == "custom" and pin.categoryId == categoryKey then
                if not options.skipRefresh then
                    self:RefreshUI()
                end
                return true
            end
            return false, pin.displayName
        end

        local target = db.global.customCategoriesV2[categoryKey]
        if target then
            target.items = target.items or {}
            target.items[tostring(numericID)] = true
        end
    end

    if not options.skipRefresh then
        self:RefreshUI()
    end
    return true
end

function CategoryController:AddItemsToCategory(categoryKey, itemIDs)
    for _, itemID in ipairs(itemIDs) do
        local ok, ownerName = self:AddItemToCategory(categoryKey, itemID, { skipRefresh = true })
        if not ok then
            self:RefreshUI()
            return false, ownerName
        end
    end
    self:RefreshUI()
    return true
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
    if not BAGANATOR_CONFIG or not BAGANATOR_CONFIG.Profiles then
        return 0, 0
    end

    local importedCategories = 0
    local importedSections = 0
    local profile
    for _, candidate in pairs(BAGANATOR_CONFIG.Profiles) do
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
                local id = self:CreateCategory(name)
                if id then
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
                local sectionID = self:CreateSection(name)
                if sectionID then
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
                        removeCategoryNameFromOtherSections(db.global, categoryName, currentSectionID)
                        local already = false
                        for _, e in ipairs(section.categories) do
                            if e == categoryName then
                                already = true
                                break
                            end
                        end
                        if not already then
                            tinsert(section.categories, categoryName)
                        end
                        addedToSection[categoryName] = true
                    end
                end
            end
        end
    end

    OneWoW_Bags.SectionDefaults:SyncOnewowSectionCategories(db.global)

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
