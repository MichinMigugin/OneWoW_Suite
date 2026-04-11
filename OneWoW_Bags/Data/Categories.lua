local _, OneWoW_Bags = ...

local L = OneWoW_Bags.L
local PE = OneWoW_Bags.PredicateEngine
local BagTypes = OneWoW_Bags.BagTypes
local Constants = OneWoW_Bags.Constants

local tinsert, sort, wipe = tinsert, sort, wipe
local ipairs, pairs = ipairs, pairs
local type, time, tostring = type, time, tostring
local C_Item = C_Item
local C_Container = C_Container
local C_NewItems = C_NewItems

OneWoW_Bags.Categories = {}
local Categories = OneWoW_Bags.Categories

local CATEGORY_DEFINITIONS = {
    { name = "1W Junk",          priority = 1   },
    { name = "1W Upgrades",      priority = 1   },
    { name = "Recent Items",     priority = 1   },
    { name = "Hearthstone",      priority = 2,   search = "#hearthstone",     searchOrder = 2  },
    { name = "Keystone",         priority = 3,   search = "#keystone",        searchOrder = 8  },
    { name = "Potions",          priority = 4,   search = "#potion",          searchOrder = 9  },
    { name = "Food",             priority = 5,   search = "#food",            searchOrder = 10 },
    { name = "Consumables",      priority = 6,   search = "#consumable",      searchOrder = 16 },
    { name = "Quest Items",      priority = 7,   search = "#quest",           searchOrder = 13 },
    { name = "Equipment Sets",   priority = 8,   search = "#set",             searchOrder = 3  },
    { name = "Weapons",          priority = 9,   search = "#weapon",          searchOrder = 14 },
    { name = "Armor",            priority = 10,  search = "#armor & #gear",   searchOrder = 15 },
    { name = "Reagents",         priority = 11,  search = "#reagent",         searchOrder = 11 },
    { name = "Trade Goods",      priority = 12,  search = "#tradegoods",      searchOrder = 20 },
    { name = "Tradeskill",       priority = 13,  search = "#tradeskill",      searchOrder = 22 },
    { name = "Recipes",          priority = 14,  search = "#recipe",          searchOrder = 21 },
    { name = "Housing",          priority = 15,  search = "#housing",         searchOrder = 1  },
    { name = "Gems",             priority = 16,  search = "#gem",             searchOrder = 17 },
    { name = "Item Enhancement", priority = 17,  search = "#enhancement",     searchOrder = 18 },
    { name = "Containers",       priority = 18,  search = "#container",       searchOrder = 19 },
    { name = "Keys",             priority = 19,  search = "#key",             searchOrder = 7  },
    { name = "Miscellaneous",    priority = 20,  search = "#misc & !#gear",   searchOrder = 6  },
    { name = "Battle Pets",      priority = 21,  search = "#battlepet",       searchOrder = 12 },
    { name = "Toys",             priority = 22,  search = "#toy",             searchOrder = 5  },
    { name = "Junk",             priority = 90,  search = "#poor",            searchOrder = 4  },
    { name = "Other",            priority = 98  },
    { name = "Empty",            priority = 99  },
}

local CATEGORY_PRIORITY = {}
for _, def in ipairs(CATEGORY_DEFINITIONS) do
    CATEGORY_PRIORITY[def.name] = def.priority
end

local SEARCH_CATEGORIES = {}
for _, def in ipairs(CATEGORY_DEFINITIONS) do
    if def.search and def.searchOrder then
        tinsert(SEARCH_CATEGORIES, def)
    end
end
sort(SEARCH_CATEGORIES, function(a, b) return a.searchOrder < b.searchOrder end)

local recentItems = {}
local recentItemDuration = 120
local recentExpiryTicker = nil

local customCategoriesV2 = {}

local categoryCache = {}

local function GetDB()
    return OneWoW_Bags:GetDB()
end

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

function Categories:GetItemCategory(bagID, slotID, itemInfo)
    if not itemInfo then return "Other" end

    local db = GetDB()
    local itemID = itemInfo.itemID
    local hyperlink = itemInfo.hyperlink
    local disabled = db.global.disabledCategories

    local junkCatEnabled = db.global.enableJunkCategory and not disabled["1W Junk"]
    if junkCatEnabled and itemID then
        if PE:BuildProps(itemID, bagID, slotID, itemInfo).isJunk then
            return "1W Junk"
        end
    end

    if itemID and hyperlink then
        if db.global.enableUpgradeCategory and not disabled["1W Upgrades"] then
            if PE:BuildProps(itemID, bagID, slotID, itemInfo).isUpgrade then
                return "1W Upgrades"
            end
        end
    end

    if itemID then
        local customName = self:GetCustomCategoryForItem(itemID, bagID, slotID, itemInfo)
        if customName then
            return customName
        end
    end

    if itemID then
        local catMods = db.global.categoryModifications
        for catName, mod in pairs(catMods) do
            if mod.addedItems and mod.addedItems[tostring(itemID)] then
                return catName
            end
        end
    end

    if not disabled["Recent Items"] and itemID and self:SlotMatchesRecent(itemID, bagID, slotID, itemInfo) then
        return "Recent Items"
    end

    if not hyperlink then
        return "Other"
    end

    local cacheKey = PE:GetItemCacheKey(itemID, bagID, slotID, itemInfo.hyperlink)
    if cacheKey then
        local cached = categoryCache[cacheKey]
        if cached then
            return cached
        end
    end

    local props = PE:BuildProps(itemID, bagID, slotID, itemInfo)

    local category = "Other"
    for _, def in ipairs(SEARCH_CATEGORIES) do
        if not disabled[def.name] then
            if PE:CheckItem(def.search, itemID, bagID, slotID, itemInfo) then
                category = def.name
                break
            end
        end
    end

    if db.global.enableInventorySlots then
        if category == "Weapons" or category == "Armor" then
            local equipLoc = props.equipLoc
            if equipLoc and equipLoc ~= "" then
                local slotName = GetSlotCategoryName(equipLoc)
                if slotName then
                    category = slotName
                end
            end
        end
    end

    if disabled[category] then
        category = "Other"
    end

    if cacheKey and hyperlink and props.classID ~= nil then
        categoryCache[cacheKey] = category
    end

    return category
end

function Categories:GetCategoryPriority(categoryName)
    return CATEGORY_PRIORITY[categoryName] or 50
end

function Categories:SortCategories(categoryList, sortMode)
    if sortMode == "alphabetical" then
        sort(categoryList, function(a, b)
            local aName = type(a) == "table" and a.name or a
            local bName = type(b) == "table" and b.name or b

            if aName == "Empty" then return false end
            if bName == "Empty" then return true end

            if aName == "Other" then return false end
            if bName == "Other" then return true end

            if aName == "Junk" then return false end
            if bName == "Junk" then return true end

            if aName == "Recent Items" then return true end
            if bName == "Recent Items" then return false end

            return aName < bName
        end)
    else
        local db = GetDB()
        local customOrderMap = {}
        for _, catData in pairs(customCategoriesV2) do
            if catData.name and catData.sortOrder then
                customOrderMap[catData.name] = catData.sortOrder
            end
        end
        local catMods = db.global.categoryModifications
        sort(categoryList, function(a, b)
            local aName = type(a) == "table" and a.name or a
            local bName = type(b) == "table" and b.name or b

            local aPriority = self:GetCategoryPriority(aName)
            local bPriority = self:GetCategoryPriority(bName)

            local aMod = catMods[aName]
            local bMod = catMods[bName]
            if aMod and aMod.priority then aPriority = aPriority + aMod.priority end
            if bMod and bMod.priority then bPriority = bPriority + bMod.priority end

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

function Categories:SlotMatchesRecent(itemID, bagID, slotID, itemInfo)
    if not itemID or not bagID or not slotID then return false end
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
    local removed = false
    for guid, timestamp in pairs(recentItems) do
        if currentTime - timestamp >= recentItemDuration then
            recentItems[guid] = nil
            removed = true
        end
    end
    return removed
end

function Categories:BeginRecentExpiryTicker()
    if recentExpiryTicker then
        recentExpiryTicker:Cancel()
        recentExpiryTicker = nil
    end
    local interval = Constants.GUI.RECENT_EXPIRY_TICK_INTERVAL or 2
    recentExpiryTicker = C_Timer.NewTicker(interval, function()
        local gui = OneWoW_Bags.GUI
        if not gui or not gui:IsShown() then
            Categories:EndRecentExpiryTicker()
            return
        end
        if Categories:CleanExpiredRecent() then
            OneWoW_Bags:RequestLayoutRefresh("bags")
        end
    end)
end

function Categories:EndRecentExpiryTicker()
    if recentExpiryTicker then
        recentExpiryTicker:Cancel()
        recentExpiryTicker = nil
    end
    self:CleanExpiredRecent()
end

function Categories:SetRecentItemDuration(duration)
    recentItemDuration = duration or 120
end

function Categories:SetRecentItems(saved)
    if saved then
        recentItems = saved
    end
end

function Categories:OnPlayerBagDirtySnapshot(dirtyBags)
    if not dirtyBags then return end
    self:CleanExpiredRecent()
    for bagID in pairs(dirtyBags) do
        if BagTypes:IsPlayerBag(bagID) then
            local numSlots = C_Container.GetContainerNumSlots(bagID) or 0
            for slotID = 1, numSlots do
                if C_NewItems.IsNewItem(bagID, slotID) then
                    local loc = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
                    if loc and loc:IsValid() and C_Item.DoesItemExist(loc) then
                        local guid = C_Item.GetItemGUID(loc)
                        if guid then
                            self:AddRecentItem(guid)
                        end
                    end
                end
            end
        end
    end
end

function Categories:GetCustomCategoryForItem(itemID, bagID, slotID, itemInfo)
    if not itemID then return nil end

    for categoryId, categoryData in pairs(customCategoriesV2) do
        if categoryData.enabled ~= false then
            if categoryData.items and categoryData.items[tostring(itemID)] then
                return categoryData.name, categoryId
            end
            local fm = categoryData.filterMode
            if (fm == "search" or (not fm and categoryData.searchExpression and categoryData.searchExpression ~= "")) then
                if categoryData.searchExpression and categoryData.searchExpression ~= "" then
                    if PE:CheckItem(categoryData.searchExpression, itemID, bagID, slotID, itemInfo or {}) then
                        return categoryData.name, categoryId
                    end
                end
            end
            local hasType = categoryData.itemType and categoryData.itemType ~= ""
            local hasSubType = categoryData.itemSubType and categoryData.itemSubType ~= ""
            if (fm == "type" or not fm) and (hasType or hasSubType) then
                local props = PE:BuildProps(itemID, bagID, slotID, itemInfo)
                local classID = props.classID
                local subClassID = props.subClassID
                local typeMatch = not hasType
                local subTypeMatch = not hasSubType
                if hasType and classID ~= nil then
                    local className = C_Item.GetItemClassInfo(classID)
                    typeMatch = className ~= nil and className:lower() == categoryData.itemType:lower()
                end
                if hasSubType and classID ~= nil and subClassID ~= nil then
                    local subClassName = C_Item.GetItemSubClassInfo(classID, subClassID)
                    subTypeMatch = subClassName ~= nil and subClassName:lower() == categoryData.itemSubType:lower()
                end
                local matched
                if hasType and hasSubType then
                    if categoryData.typeMatchMode == "or" then
                        matched = typeMatch or subTypeMatch
                    else
                        matched = typeMatch and subTypeMatch
                    end
                elseif hasType then
                    matched = typeMatch
                else
                    matched = subTypeMatch
                end
                if matched then
                    return categoryData.name, categoryId
                end
            end
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

    InvalidateCache()

    return true
end

function Categories:RemoveItemFromCustomCategory(categoryID, itemID)
    if not categoryID or not customCategoriesV2[categoryID] or not itemID then
        return false
    end

    customCategoriesV2[categoryID].items[itemID] = nil

    InvalidateCache()

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
        tinsert(names, def.name)
    end
    return names
end

function Categories:GetCategoryDefinitions()
    return CATEGORY_DEFINITIONS
end

function Categories:GetSearchCategories()
    return SEARCH_CATEGORIES
end

function Categories:GetSubCategory(categoryName, bagID, slotID, itemInfo)
    if not bagID or not slotID then return nil end

    if categoryName == "Containers" then
        local tt = PE:GetTooltipText(bagID, slotID)
        if tt then
            if tt:find(LOCKED) then
                return "Locked"
            else
                return "Unlocked"
            end
        end
    end

    if categoryName == "Consumables" or categoryName == "Potions" or categoryName == "Food" then
        local tt = PE:GetTooltipText(bagID, slotID)
        if tt then
            local charges = tt:match("(%d+) Charges?")
            if charges then
                return charges .. " Charges"
            end
        end
    end

    return nil
end

function Categories:AddItemToBuiltinCategory(categoryName, itemID)
    if not categoryName or not itemID then return false end

    local addedItems = OneWoW_Bags:EnsureBuiltinCategoryAddedItems(categoryName)
    if not addedItems then return false end
    addedItems[tostring(itemID)] = true
    InvalidateCache()
    return true
end

function Categories:RemoveItemFromBuiltinCategory(categoryName, itemID)
    if not categoryName or not itemID then return false end

    local db = GetDB()
    if not db.global.categoryModifications then return false end
    local mod = db.global.categoryModifications[categoryName]
    if not mod or not mod.addedItems then return false end
    mod.addedItems[tostring(itemID)] = nil
    InvalidateCache()
    return true
end

function Categories:GetCategoryDescription(categoryName)
    local descKeys = {
        ["1W Junk"] = "CAT_DESC_1W_JUNK",
        ["1W Upgrades"] = "CAT_DESC_1W_UPGRADES",
        ["Recent Items"] = "CAT_DESC_RECENT_ITEMS",
        ["Hearthstone"] = "CAT_DESC_HEARTHSTONE",
        ["Keystone"] = "CAT_DESC_KEYSTONE",
        ["Potions"] = "CAT_DESC_POTIONS",
        ["Food"] = "CAT_DESC_FOOD",
        ["Consumables"] = "CAT_DESC_CONSUMABLES",
        ["Quest Items"] = "CAT_DESC_QUEST_ITEMS",
        ["Equipment Sets"] = "CAT_DESC_EQUIPMENT_SETS",
        ["Weapons"] = "CAT_DESC_WEAPONS",
        ["Armor"] = "CAT_DESC_ARMOR",
        ["Reagents"] = "CAT_DESC_REAGENTS",
        ["Trade Goods"] = "CAT_DESC_TRADE_GOODS",
        ["Tradeskill"] = "CAT_DESC_TRADESKILL",
        ["Recipes"] = "CAT_DESC_RECIPES",
        ["Housing"] = "CAT_DESC_HOUSING",
        ["Gems"] = "CAT_DESC_GEMS",
        ["Item Enhancement"] = "CAT_DESC_ITEM_ENHANCEMENT",
        ["Containers"] = "CAT_DESC_CONTAINERS",
        ["Keys"] = "CAT_DESC_KEYS",
        ["Miscellaneous"] = "CAT_DESC_MISCELLANEOUS",
        ["Battle Pets"] = "CAT_DESC_BATTLE_PETS",
        ["Toys"] = "CAT_DESC_TOYS",
        ["Other"] = "CAT_DESC_OTHER",
        ["Junk"] = "CAT_DESC_JUNK",
    }
    local key = descKeys[categoryName]
    return key and L[key] or nil
end

PE:RegisterKeyword("recent", function(p)
    if not p.id then return false end
    local itemInfo = {
        hyperlink = p.hyperlink,
        quality = p.quality,
        count = p.count,
    }
    return Categories:SlotMatchesRecent(p.id, p._bagID, p._slotID, itemInfo)
end)
