local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.Categories = {}

local Categories = OneWoW_Bags.Categories

local CATEGORY_DEFINITIONS = {
    { name = "Recent Items",   priority = 1 },
    { name = "Equipment",      priority = 2 },
    { name = "Consumables",    priority = 3 },
    { name = "Reagents",       priority = 4 },
    { name = "Trade Goods",    priority = 5 },
    { name = "Tradeskill",     priority = 6 },
    { name = "Recipes",        priority = 7 },
    { name = "Gems",           priority = 8 },
    { name = "Quest Items",    priority = 9 },
    { name = "Cosmetics",      priority = 10 },
    { name = "Toys",           priority = 11 },
    { name = "Pets and Mounts", priority = 12 },
    { name = "Keys",           priority = 13 },
    { name = "Junk",           priority = 14 },
    { name = "Other",          priority = 15 },
    { name = "Empty",          priority = 99 },
}

local CATEGORY_PRIORITY = {}
for _, def in ipairs(CATEGORY_DEFINITIONS) do
    CATEGORY_PRIORITY[def.name] = def.priority
end

local recentItems = {}
local recentItemDuration = 600

local customCategoriesV2 = {}

local categoryCache = {}
local itemInfoCache = {}

local function InvalidateCache()
    wipe(categoryCache)
end

local function GetCachedItemInfo(itemID, hyperlink)
    if not itemID then return nil end

    local cached = itemInfoCache[itemID]
    if cached then
        return cached.classID, cached.subClassID, cached.quality
    end

    if not hyperlink then return nil end

    local _, _, quality, _, _, _, _, _, _, _, _, classID, subClassID = C_Item.GetItemInfo(hyperlink)

    if classID then
        itemInfoCache[itemID] = {
            classID = classID,
            subClassID = subClassID,
            quality = quality,
        }
    end

    return classID, subClassID, quality
end

function Categories:GetItemCategory(bagID, slotID, itemInfo)
    if not itemInfo then return "Other" end

    local itemID = itemInfo.itemID
    local itemGUID = itemInfo.itemGUID
    local hyperlink = itemInfo.hyperlink

    local disabled = (OneWoW_Bags.db and OneWoW_Bags.db.global and OneWoW_Bags.db.global.disabledCategories) or {}

    if itemID then
        local customName = self:GetCustomCategoryForItem(itemID)
        if customName then
            return customName
        end
    end

    if not disabled["Recent Items"] and self:IsItemRecent(bagID, slotID) then
        return "Recent Items"
    end

    if itemID then
        local cached = categoryCache[itemID]
        if cached then
            return cached
        end
    end

    if not hyperlink then
        if itemID then
            categoryCache[itemID] = "Other"
        end
        return "Other"
    end

    local classID, subClassID, quality = GetCachedItemInfo(itemID, hyperlink)

    if not classID then
        return "Other"
    end

    local category = "Other"

    if quality == Enum.ItemQuality.Poor then
        category = "Junk"
    elseif itemID and C_ToyBox and C_ToyBox.GetToyInfo then
        local toyInfo = C_ToyBox.GetToyInfo(itemID)
        if toyInfo then
            category = "Toys"
        end
    end

    if category == "Other" then
        if classID == Enum.ItemClass.Armor and subClassID == 5 then
            category = "Cosmetics"
        elseif classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor then
            category = "Equipment"
        elseif classID == Enum.ItemClass.Consumable then
            category = "Consumables"
        elseif classID == Enum.ItemClass.Reagent then
            category = "Reagents"
        elseif classID == Enum.ItemClass.Tradegoods then
            category = "Trade Goods"
        elseif classID == Enum.ItemClass.Profession then
            category = "Tradeskill"
        elseif classID == Enum.ItemClass.Recipe then
            category = "Recipes"
        elseif classID == Enum.ItemClass.Gem then
            category = "Gems"
        elseif classID == Enum.ItemClass.Questitem or classID == Enum.ItemClass.Quest then
            category = "Quest Items"
        elseif classID == Enum.ItemClass.Battlepet then
            category = "Pets and Mounts"
        elseif classID == Enum.ItemClass.Miscellaneous then
            if subClassID == Enum.ItemMiscellaneousSubclass.Mount or subClassID == Enum.ItemMiscellaneousSubclass.CompanionPet then
                category = "Pets and Mounts"
            end
        elseif classID == Enum.ItemClass.Key then
            category = "Keys"
        end
    end

    if disabled[category] then
        category = "Other"
    end

    if itemID then
        categoryCache[itemID] = category
    end

    return category
end

function Categories:GetCategoryPriority(categoryName)
    return CATEGORY_PRIORITY[categoryName] or 50
end

function Categories:SortCategories(categoryList, sortMode)
    if sortMode == "alphabetical" then
        table.sort(categoryList, function(a, b)
            local aName = type(a) == "table" and a.name or a
            local bName = type(b) == "table" and b.name or b

            if aName == "Empty" then return false end
            if bName == "Empty" then return true end

            if aName == "Recent Items" then return true end
            if bName == "Recent Items" then return false end

            return aName < bName
        end)
    else
        local customOrderMap = {}
        for _, catData in pairs(customCategoriesV2) do
            if catData.name and catData.sortOrder then
                customOrderMap[catData.name] = catData.sortOrder
            end
        end
        table.sort(categoryList, function(a, b)
            local aName = type(a) == "table" and a.name or a
            local bName = type(b) == "table" and b.name or b

            local aPriority = self:GetCategoryPriority(aName)
            local bPriority = self:GetCategoryPriority(bName)

            if aPriority ~= bPriority then
                return aPriority < bPriority
            end

            if aPriority == 50 then
                local aOrder = customOrderMap[aName] or 999
                local bOrder = customOrderMap[bName] or 999
                if aOrder ~= bOrder then
                    return aOrder < bOrder
                end
            end

            return aName < bName
        end)
    end
end

function Categories:IsItemRecent(bagID, slotID)
    if C_NewItems and C_NewItems.IsNewItem and bagID and slotID then
        if C_NewItems.IsNewItem(bagID, slotID) then
            return true
        end
    end

    local key = bagID .. ":" .. slotID
    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if itemLocation and itemLocation:IsValid() and C_Item.DoesItemExist(itemLocation) then
        local guid = C_Item.GetItemGUID(itemLocation)
        if guid and recentItems[guid] then
            local currentTime = time()
            if currentTime - recentItems[guid] < recentItemDuration then
                return true
            else
                recentItems[guid] = nil
            end
        end
    end

    return false
end

function Categories:AddRecentItem(itemGUID)
    if not itemGUID then return end
    recentItems[itemGUID] = time()
end

function Categories:CleanExpiredRecent()
    local currentTime = time()
    for guid, timestamp in pairs(recentItems) do
        if currentTime - timestamp >= recentItemDuration then
            recentItems[guid] = nil
        end
    end
end

function Categories:SetRecentItemDuration(duration)
    recentItemDuration = duration or 600
end

function Categories:GetRecentItems()
    return recentItems
end

function Categories:SetRecentItems(saved)
    if saved then
        recentItems = saved
    end
end

function Categories:ClearRecentItems()
    wipe(recentItems)
    if C_NewItems and C_NewItems.ClearAll then
        C_NewItems.ClearAll()
    end
end

function Categories:GetCustomCategoryForItem(itemID)
    if not itemID then return nil end

    for categoryId, categoryData in pairs(customCategoriesV2) do
        if categoryData.items and categoryData.items[tostring(itemID)] and categoryData.enabled ~= false then
            return categoryData.name, categoryId
        end
    end

    return nil, nil
end

function Categories:CreateCustomCategory(name)
    if not name or name == "" then
        return nil
    end

    local categoryId = "custom_" .. time() .. "_" .. math.random(1000, 9999)

    customCategoriesV2[categoryId] = {
        name = name,
        items = {},
        created = time(),
        enabled = true,
    }

    InvalidateCache()

    return categoryId
end

function Categories:AddItemToCustomCategory(categoryID, itemID)
    if not categoryID or not customCategoriesV2[categoryID] or not itemID then
        return false
    end

    customCategoriesV2[categoryID].items[itemID] = true

    if categoryCache[itemID] then
        categoryCache[itemID] = nil
    end

    return true
end

function Categories:RemoveItemFromCustomCategory(categoryID, itemID)
    if not categoryID or not customCategoriesV2[categoryID] or not itemID then
        return false
    end

    customCategoriesV2[categoryID].items[itemID] = nil

    if categoryCache[itemID] then
        categoryCache[itemID] = nil
    end

    return true
end

function Categories:DeleteCustomCategory(categoryID)
    if not categoryID or not customCategoriesV2[categoryID] then
        return false
    end

    customCategoriesV2[categoryID] = nil

    InvalidateCache()

    return true
end

function Categories:GetAllCustomCategories()
    return customCategoriesV2
end

function Categories:SetCustomCategories(saved)
    if saved then
        customCategoriesV2 = saved
    end
end

function Categories:GetCustomCategoriesForSave()
    return customCategoriesV2
end

function Categories:InvalidateCache()
    InvalidateCache()
end

function Categories:GetAllCategoryNames()
    local names = {}
    for _, def in ipairs(CATEGORY_DEFINITIONS) do
        table.insert(names, def.name)
    end
    return names
end
