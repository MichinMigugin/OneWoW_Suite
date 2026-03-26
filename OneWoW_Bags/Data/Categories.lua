local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.Categories = {}

local Categories = OneWoW_Bags.Categories

local CATEGORY_DEFINITIONS = {
    { name = "OneWoW Junk",       priority = 0 },
    { name = "OneWoW Upgrades",   priority = 0.5 },
    { name = "Recent Items",      priority = 1 },
    { name = "Hearthstone",       priority = 2 },
    { name = "Keystone",          priority = 3 },
    { name = "Potions",           priority = 4 },
    { name = "Food",              priority = 5 },
    { name = "Consumables",       priority = 6 },
    { name = "Quest Items",       priority = 7 },
    { name = "Equipment Sets",    priority = 8 },
    { name = "Weapons",           priority = 9 },
    { name = "Armor",             priority = 10 },
    { name = "Reagents",          priority = 11 },
    { name = "Trade Goods",       priority = 12 },
    { name = "Tradeskill",        priority = 13 },
    { name = "Recipes",           priority = 14 },
    { name = "Housing",           priority = 15 },
    { name = "Gems",              priority = 16 },
    { name = "Item Enhancement",  priority = 17 },
    { name = "Containers",        priority = 18 },
    { name = "Keys",              priority = 19 },
    { name = "Miscellaneous",     priority = 20 },
    { name = "Pets and Mounts",   priority = 21 },
    { name = "Toys",              priority = 22 },
    { name = "Cosmetics",         priority = 23 },
    { name = "Other",             priority = 24 },
    { name = "Junk",              priority = 25 },
    { name = "Empty",             priority = 99 },
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
local equipSetCache = nil
local equipSetCacheTime = 0

local HEARTHSTONE_IDS = {
    [6948] = true,
    [64488] = true,
    [54452] = true,
    [93672] = true,
    [110560] = true,
    [140192] = true,
    [141605] = true,
    [162973] = true,
    [163045] = true,
    [165669] = true,
    [165670] = true,
    [165802] = true,
    [166746] = true,
    [166747] = true,
    [168907] = true,
    [172179] = true,
    [180290] = true,
    [182773] = true,
    [183716] = true,
    [184353] = true,
    [188952] = true,
    [190196] = true,
    [193588] = true,
    [200630] = true,
    [206195] = true,
    [208704] = true,
    [209035] = true,
    [210455] = true,
    [212337] = true,
    [228940] = true,
}

local INVTYPE_TO_EQUIP_SLOT = {
    [Enum.InventoryType.IndexHeadType]          = 1,
    [Enum.InventoryType.IndexNeckType]          = 2,
    [Enum.InventoryType.IndexShoulderType]      = 3,
    [Enum.InventoryType.IndexBodyType]          = 4,
    [Enum.InventoryType.IndexChestType]         = 5,
    [Enum.InventoryType.IndexWaistType]         = 6,
    [Enum.InventoryType.IndexLegsType]          = 7,
    [Enum.InventoryType.IndexFeetType]          = 8,
    [Enum.InventoryType.IndexWristType]         = 9,
    [Enum.InventoryType.IndexHandType]          = 10,
    [Enum.InventoryType.IndexFingerType]        = 11,
    [Enum.InventoryType.IndexTrinketType]       = 13,
    [Enum.InventoryType.IndexWeaponType]        = 16,
    [Enum.InventoryType.IndexShieldType]        = 17,
    [Enum.InventoryType.IndexCloakType]         = 15,
    [Enum.InventoryType.Index2HweaponType]      = 16,
    [Enum.InventoryType.IndexRobeType]          = 5,
    [Enum.InventoryType.IndexWeaponmainhandType] = 16,
    [Enum.InventoryType.IndexWeaponoffhandType] = 17,
    [Enum.InventoryType.IndexHoldableType]      = 17,
}

local SLOT_NORMALIZE = {
    ["INVTYPE_ROBE"] = "INVTYPE_CHEST",
    ["INVTYPE_RANGEDRIGHT"] = "INVTYPE_RANGED",
}

local function GetSlotCategoryName(equipLoc)
    if not equipLoc or equipLoc == "" then return nil end
    local normalized = SLOT_NORMALIZE[equipLoc] or equipLoc
    local displayName = _G[normalized]
    if displayName and displayName ~= "" then
        return displayName
    end
    return nil
end

local function InvalidateCache()
    wipe(categoryCache)
end

local function GetCachedItemInfo(itemID, hyperlink)
    if not itemID then return nil end

    local cached = itemInfoCache[itemID]
    if cached then
        return cached.classID, cached.subClassID, cached.quality, cached.invType
    end

    if not hyperlink then return nil end

    local _, _, quality, _, _, _, _, _, equipLoc, _, _, classID, subClassID = C_Item.GetItemInfo(hyperlink)

    if classID then
        itemInfoCache[itemID] = {
            classID = classID,
            subClassID = subClassID,
            quality = quality,
            invType = equipLoc,
        }
    end

    return classID, subClassID, quality, equipLoc
end

local function BuildEquipSetCache()
    local now = GetTime()
    if equipSetCache and (now - equipSetCacheTime) < 5 then return end
    equipSetCache = {}
    equipSetCacheTime = now
    if not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetIDs then return end
    local setIDs = C_EquipmentSet.GetEquipmentSetIDs()
    if not setIDs then return end
    for _, setID in ipairs(setIDs) do
        local itemIDs = C_EquipmentSet.GetItemIDs(setID)
        if itemIDs then
            for _, id in pairs(itemIDs) do
                if id and id > 0 then
                    equipSetCache[id] = true
                end
            end
        end
    end
end

local function IsInEquipmentSet(itemID)
    if not itemID then return false end
    BuildEquipSetCache()
    return equipSetCache and equipSetCache[itemID] or false
end

local function IsItemUpgrade(bagID, slotID, itemID, hyperlink)
    if not itemID or not bagID or not slotID then return false end
    if not C_Item or not C_Item.GetItemInventoryTypeByID then return false end

    local invType = C_Item.GetItemInventoryTypeByID(itemID)
    if not invType then return false end

    local equipSlot = INVTYPE_TO_EQUIP_SLOT[invType]
    if not equipSlot or equipSlot <= 0 then return false end

    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if not itemLocation or not itemLocation:IsValid() then return false end
    if not C_Item.DoesItemExist(itemLocation) then return false end

    local ilvl = C_Item.GetCurrentItemLevel(itemLocation)
    if not ilvl or ilvl <= 0 then return false end

    local equippedLink = GetInventoryItemLink("player", equipSlot)
    if equippedLink then
        local equippedIlvl = C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(equippedLink)
        if equippedIlvl and ilvl > equippedIlvl then
            return true
        end
    else
        return true
    end

    if equipSlot == 11 then
        local equippedLink2 = GetInventoryItemLink("player", 12)
        if equippedLink2 then
            local equippedIlvl2 = C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(equippedLink2)
            if equippedIlvl2 and ilvl > equippedIlvl2 then return true end
        else
            return true
        end
    elseif equipSlot == 13 then
        local equippedLink2 = GetInventoryItemLink("player", 14)
        if equippedLink2 then
            local equippedIlvl2 = C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(equippedLink2)
            if equippedIlvl2 and ilvl > equippedIlvl2 then return true end
        else
            return true
        end
    end

    return false
end

local function IsHearthstone(itemID)
    if not itemID then return false end
    if HEARTHSTONE_IDS[itemID] then return true end
    if C_ToyBox and C_ToyBox.GetToyInfo then
        local toyInfo = C_ToyBox.GetToyInfo(itemID)
        if toyInfo then
            local itemName = C_Item.GetItemNameByID(itemID)
            if itemName and itemName:lower():find("hearthstone") then
                return true
            end
        end
    end
    return false
end

function Categories:GetItemCategory(bagID, slotID, itemInfo)
    if not itemInfo then return "Other" end

    local itemID = itemInfo.itemID
    local hyperlink = itemInfo.hyperlink

    local db = OneWoW_Bags.db
    local disabled = (db and db.global and db.global.disabledCategories) or {}

    if itemID and _G.OneWoW and _G.OneWoW.ItemStatus then
        if db and db.global and db.global.enableJunkCategory and not disabled["OneWoW Junk"] then
            if _G.OneWoW.ItemStatus:IsItemJunk(itemID) then
                return "OneWoW Junk"
            end
        end
    end

    if itemID and hyperlink and _G.OneWoW then
        if db and db.global and db.global.enableUpgradeCategory and not disabled["OneWoW Upgrades"] then
            if IsItemUpgrade(bagID, slotID, itemID, hyperlink) then
                return "OneWoW Upgrades"
            end
        end
    end

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

    local classID, subClassID, quality, equipLoc = GetCachedItemInfo(itemID, hyperlink)

    if not classID then
        return "Other"
    end

    local category = "Other"

    if not disabled["Hearthstone"] and IsHearthstone(itemID) then
        category = "Hearthstone"
    elseif quality == Enum.ItemQuality.Poor then
        category = "Junk"
    elseif itemID and C_ToyBox and C_ToyBox.GetToyInfo then
        local toyInfo = C_ToyBox.GetToyInfo(itemID)
        if toyInfo then
            category = "Toys"
        end
    end

    if category == "Other" then
        if not disabled["Equipment Sets"] and IsInEquipmentSet(itemID) then
            category = "Equipment Sets"
        elseif classID == Enum.ItemClass.Armor and subClassID == 5 then
            category = "Cosmetics"
        elseif classID == Enum.ItemClass.Weapon then
            if db and db.global.enableInventorySlots then
                local slotName = GetSlotCategoryName(equipLoc)
                if slotName then
                    category = slotName
                else
                    category = "Weapons"
                end
            else
                category = "Weapons"
            end
        elseif classID == Enum.ItemClass.Armor then
            if db and db.global.enableInventorySlots then
                local slotName = GetSlotCategoryName(equipLoc)
                if slotName then
                    category = slotName
                else
                    category = "Armor"
                end
            else
                category = "Armor"
            end
        elseif classID == Enum.ItemClass.Consumable then
            if subClassID == 1 or subClassID == 2 or subClassID == 3 then
                category = "Potions"
            elseif subClassID == 5 then
                category = "Food"
            else
                category = "Consumables"
            end
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
        elseif classID == Enum.ItemClass.ItemEnhancement then
            category = "Item Enhancement"
        elseif classID == Enum.ItemClass.Container then
            category = "Containers"
        elseif classID == Enum.ItemClass.Questitem or classID == Enum.ItemClass.Quest then
            category = "Quest Items"
        elseif classID == Enum.ItemClass.Battlepet then
            category = "Pets and Mounts"
        elseif classID == Enum.ItemClass.Miscellaneous then
            if subClassID == Enum.ItemMiscellaneousSubclass.Mount or subClassID == Enum.ItemMiscellaneousSubclass.CompanionPet then
                category = "Pets and Mounts"
            else
                category = "Miscellaneous"
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

function Categories:InvalidateEquipSetCache()
    equipSetCache = nil
    equipSetCacheTime = 0
    InvalidateCache()
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

function Categories:GetCategoryDefinitions()
    return CATEGORY_DEFINITIONS
end
