local _, ns = ...

local pairs, ipairs = pairs, ipairs
local tinsert, sort = tinsert, sort
local C_Item, C_TradeSkillUI = C_Item, C_TradeSkillUI

ns.ItemSearch = {}
local ItemSearch = ns.ItemSearch
if _G.OneWoW_Catalog then
    _G.OneWoW_Catalog.ItemSearch = ItemSearch
end

local EXPANSION_NAMES = {
    "Classic", "BurningCrusade", "WrathoftheLichKing", "Cataclysm",
    "MistsofPandaria", "WarlordsofDraenor", "Legion", "BattleforAzeroth",
    "Shadowlands", "Dragonflight", "TheWarWithin", "Midnight",
}

local TRADESKILL_PROFS = {
    "Alchemy", "Blacksmithing", "Cooking", "Enchanting", "Engineering",
    "Fishing", "Herbalism", "HousingDyes", "Inscription", "Jewelcrafting",
    "Leatherworking", "Mining", "Skinning", "Tailoring",
}

local MAX_RESULTS = 200
local DEFAULT_LIMIT = 50
local questRewardIndex = nil

local function GetVendorDataAddon()
    return ns.Catalog and ns.Catalog:GetDataAddon("vendors")
end

local function GetVendorData()
    local vendorAddon = GetVendorDataAddon()
    return vendorAddon and vendorAddon.VendorData
end

local function GetAllVendors()
    local vendorData = GetVendorData()
    if vendorData and vendorData.GetAllVendors then
        return vendorData:GetAllVendors()
    end

    local vdb = OneWoW_CatalogData_Vendors_DB
    return vdb and vdb.vendors or nil
end

local function GetVendorsByItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then return {} end

    local vendorData = GetVendorData()
    if vendorData and vendorData.GetVendorsByItem then
        return vendorData:GetVendorsByItem(itemID)
    end

    local results = {}
    local vendors = GetAllVendors()
    if not vendors then return results end

    for _, vendor in pairs(vendors) do
        if vendor.items and vendor.items[itemID] then
            tinsert(results, vendor)
        end
    end

    return results
end

local function GetItemNameFromCatalogCache(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end

    local itemCache =
        OneWoW_Catalog_DB
        and OneWoW_Catalog_DB.global
        and OneWoW_Catalog_DB.global.itemCache

    local entry = itemCache and itemCache[itemID]
    if type(entry) == "table" then
        return entry.name
    elseif type(entry) == "string" then
        return entry
    end

    return nil
end

local function GetKnownItemName(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end

    local itemName = C_Item.GetItemNameByID(itemID)
    if itemName then return itemName end

    itemName = GetItemNameFromCatalogCache(itemID)
    if itemName then return itemName end

    local questAddon = ns.Catalog and ns.Catalog:GetDataAddon("quests")
    if questAddon and questAddon.QuestData and questAddon.QuestData.GetCachedItemName then
        return questAddon.QuestData:GetCachedItemName(itemID)
    end

    return nil
end

local function AddQuestRewardIndexEntry(index, itemID, quest, sourceType)
    itemID = tonumber(itemID)
    if not itemID or not quest or not quest.id then
        return
    end

    index[itemID] = index[itemID] or {
        itemID = itemID,
        quests = {},
        seen = {},
    }

    local bucket = index[itemID]
    if bucket.seen[quest.id] then
        return
    end

    bucket.seen[quest.id] = true
    tinsert(bucket.quests, {
        questID = quest.id,
        name = quest.name,
        expansion = quest.expansion,
        sourceType = sourceType,
    })
end

local function IndexRewardItemList(index, quest, rewards, sourceType)
    if type(rewards) ~= "table" then
        return
    end

    for _, reward in ipairs(rewards) do
        local itemID = reward
        if type(reward) == "table" then
            itemID = reward.itemID or reward.id
        end

        AddQuestRewardIndexEntry(index, itemID, quest, sourceType)
    end
end

local function GetQuestRewardIndex()
    if questRewardIndex then
        return questRewardIndex
    end

    local index = {}
    local questAddon = ns.Catalog and ns.Catalog:GetDataAddon("quests")
    local questData = questAddon and questAddon.QuestData
    local quests = questData and questData.GetAllQuests and questData:GetAllQuests()

    if quests then
        for _, quest in pairs(quests) do
            IndexRewardItemList(index, quest, quest.rewardItems, "reward")
            IndexRewardItemList(index, quest, quest.rewardChoices, "choice")
        end
    end

    for _, bucket in pairs(index) do
        bucket.seen = nil
        sort(bucket.quests, function(a, b)
            return (a.name or "") < (b.name or "")
        end)
    end

    questRewardIndex = index
    return questRewardIndex
end

local function GetRecipeKnownByFromAltTracker(itemID)
    local profsDB = OneWoW_AltTracker_Professions_DB
    if not profsDB or not profsDB.characters then return nil end

    local recipeSpellID
    if profsDB.recipeItemMap and profsDB.recipeItemMap[itemID] then
        recipeSpellID = profsDB.recipeItemMap[itemID]
    end

    if not recipeSpellID then
        local _, spellID = C_Item.GetItemSpell(itemID)
        if spellID then recipeSpellID = spellID end
    end

    local knownBy = {}
    local seen = {}

    if recipeSpellID then
        for charKey, charData in pairs(profsDB.characters) do
            if charData.recipes then
                for _, recipeSet in pairs(charData.recipes) do
                    if recipeSet[recipeSpellID] and not seen[charKey] then
                        seen[charKey] = true
                        tinsert(knownBy, charKey)
                    end
                end
            end
        end
    end

    if #knownBy == 0 then
        local itemName = C_Item.GetItemNameByID(itemID)
        if itemName then
            local craftedName = itemName:match("^%S+:%s*(.+)$") or itemName
            for charKey, charData in pairs(profsDB.characters) do
                if charData.recipes and not seen[charKey] then
                    for _, recipeSet in pairs(charData.recipes) do
                        for storedID in pairs(recipeSet) do
                            local info = C_TradeSkillUI.GetRecipeInfo(storedID)
                            if info and info.name == craftedName then
                                if profsDB.recipeItemMap then
                                    profsDB.recipeItemMap[itemID] = storedID
                                end
                                if not seen[charKey] then
                                    seen[charKey] = true
                                    tinsert(knownBy, charKey)
                                end
                                break
                            end
                        end
                        if seen[charKey] then break end
                    end
                end
            end
        end
    end

    sort(knownBy)
    return knownBy
end

local EXPANSION_PRIORITY = {
    "Midnight", "TheWarWithin", "Dragonflight", "Shadowlands",
    "BattleforAzeroth", "Legion", "WarlordsofDraenor", "MistsofPandaria",
    "Cataclysm", "WrathoftheLichKing", "BurningCrusade", "Classic",
}

local function GetOwnedItems()
    local owned = {}
    local sdb = OneWoW_AltTracker_Storage_DB
    if not sdb then return owned end

    local function addOwned(itemID, count, charName, locLabel)
        if not owned[itemID] then
            owned[itemID] = { total = 0, locations = {} }
        end
        owned[itemID].total = owned[itemID].total + count
        tinsert(owned[itemID].locations, { charName = charName, locLabel = locLabel, count = count })
    end

    if sdb.characters then
        for charKey, charData in pairs(sdb.characters) do
            local charName = charKey:match("^([^%-]+)") or charKey

            if charData.bags then
                for _, bagInfo in pairs(charData.bags) do
                    if bagInfo.slots then
                        for _, slot in pairs(bagInfo.slots) do
                            if slot and slot.itemID then
                                addOwned(slot.itemID, slot.stackCount or 1, charName, "bags")
                            end
                        end
                    end
                end
            end

            if charData.personalBank and charData.personalBank.tabs then
                for _, tabInfo in pairs(charData.personalBank.tabs) do
                    if tabInfo.items then
                        for _, slot in pairs(tabInfo.items) do
                            if slot and slot.itemID then
                                addOwned(slot.itemID, slot.stackCount or 1, charName, "bank")
                            end
                        end
                    end
                end
            end

            if charData.mail and charData.mail.mails then
                for _, mailData in pairs(charData.mail.mails) do
                    if mailData.items then
                        for _, slot in pairs(mailData.items) do
                            if slot and slot.itemID then
                                addOwned(slot.itemID, slot.count or 1, charName, "mail")
                            end
                        end
                    end
                end
            end
        end
    end

    if sdb.warbandBank and sdb.warbandBank.tabs then
        for _, tabInfo in pairs(sdb.warbandBank.tabs) do
            if tabInfo.items then
                for _, slot in pairs(tabInfo.items) do
                    if slot and slot.itemID then
                        addOwned(slot.itemID, slot.count or 1, "Warband", "warband")
                    end
                end
            end
        end
    end

    if sdb.guildBanks then
        for guildName, guildBank in pairs(sdb.guildBanks) do
            if guildBank.tabs then
                for _, tabInfo in pairs(guildBank.tabs) do
                    if tabInfo.slots then
                        for _, slot in pairs(tabInfo.slots) do
                            if slot and slot.itemID then
                                addOwned(slot.itemID, slot.stackCount or 1, guildName, "guild")
                            end
                        end
                    end
                end
            end
        end
    end

    local adb = OneWoW_AltTracker_Auctions_DB
    if adb and adb.characters then
        for charKey, charData in pairs(adb.characters) do
            local charName = charKey:match("^([^%-]+)") or charKey
            if charData.activeAuctions then
                for _, auc in ipairs(charData.activeAuctions) do
                    if auc.itemID then
                        addOwned(auc.itemID, auc.quantity or 1, charName, "ah")
                    end
                end
            end
        end
    end

    return owned
end

function ItemSearch:Query(searchTerm, sourceFilter)
    if not searchTerm or #searchTerm < 2 then return {}, false end

    local term = searchTerm:lower()
    local itemIDSearch = tonumber(searchTerm)
    local results = {}
    local resultMap = {}
    local count = 0
    local limitReached = false

    local doJournal = (sourceFilter == "all" or sourceFilter == "drops")
    local doVendors = (sourceFilter == "all" or sourceFilter == "vendors")
    local doCrafted = (sourceFilter == "all" or sourceFilter == "crafted")
    local doOwned   = (sourceFilter == "all" or sourceFilter == "owned")
    local doQuests  = (sourceFilter == "all" or sourceFilter == "quests")

    local function addOrAnnotate(itemID, name, icon, quality, sourceKey)
        if resultMap[itemID] then
            results[resultMap[itemID]][sourceKey] = true
            return
        end
        if count >= MAX_RESULTS then
            limitReached = true
            return
        end
        count = count + 1
        local entry = {
            itemID    = itemID,
            name      = name,
            icon      = icon,
            quality   = quality or 1,
            ownedCount = 0,
            isJournal = false,
            isVendor  = false,
            isCrafted = false,
            isOwned   = false,
            isQuest   = false,
        }
        entry[sourceKey] = true
        results[count] = entry
        resultMap[itemID] = count
    end

    if doJournal then
        for _, expName in ipairs(EXPANSION_NAMES) do
            local items = _G["OneWoWItems_" .. expName]
            if items then
                for itemID, idata in pairs(items) do
                    if idata.name and idata.name:lower():find(term, 1, true) then
                        addOrAnnotate(itemID, idata.name, idata.icon, idata.quality, "isJournal")
                        if limitReached then break end
                    end
                end
            end
            if limitReached then break end
        end
    end

    if doVendors and not limitReached then
        local vendors = GetAllVendors()
        if vendors then
            for _, vendor in pairs(vendors) do
                if vendor.items then
                    for itemID in pairs(vendor.items) do
                        local itemName = C_Item.GetItemNameByID(itemID)
                        local matchesName =
                            itemName
                            and itemName:lower():find(term, 1, true)

                        if matchesName or itemID == itemIDSearch then
                            addOrAnnotate(itemID, itemName or ("Item #" .. tostring(itemID)), nil, nil, "isVendor")
                            if limitReached then break end
                        end
                    end
                end
                if limitReached then break end
            end
        end
    end

    if doCrafted and not limitReached then
        for _, profName in ipairs(TRADESKILL_PROFS) do
            local data = _G["OneWoWTradeskills_" .. profName]
            if data and data.r then
                for _, recipe in pairs(data.r) do
                    if recipe.item and recipe.item > 0 then
                        local itemName = C_Item.GetItemNameByID(recipe.item)
                        local matchesName =
                            itemName
                            and itemName:lower():find(term, 1, true)

                        if matchesName or recipe.item == itemIDSearch then
                            addOrAnnotate(recipe.item, itemName or ("Item #" .. tostring(recipe.item)), nil, nil, "isCrafted")
                            if limitReached then break end
                        end
                    end
                end
            end
            if limitReached then break end
        end
    end

    local ownedMap = GetOwnedItems()

    if doOwned and not limitReached then
        for itemID in pairs(ownedMap) do
            local itemName = GetKnownItemName(itemID)
            local matchesName =
                itemName
                and itemName:lower():find(term, 1, true)

            if matchesName or itemID == itemIDSearch then
                addOrAnnotate(itemID, itemName or ("Item #" .. tostring(itemID)), nil, nil, "isOwned")
                if limitReached then break end
            end
        end
    end

    if doQuests and not limitReached then
        for itemID in pairs(GetQuestRewardIndex()) do
            local itemName = GetKnownItemName(itemID)
            local matchesName =
                itemName
                and itemName:lower():find(term, 1, true)

            if matchesName or itemID == itemIDSearch then
                addOrAnnotate(itemID, itemName or ("Item #" .. tostring(itemID)), nil, nil, "isQuest")
                if limitReached then break end
            end
        end
    end

    for _, entry in ipairs(results) do
        local od = ownedMap[entry.itemID]
        if od then
            entry.ownedCount = od.total
            entry.isOwned = true
        end
    end

    sort(results, function(a, b)
        if a.ownedCount > 0 and b.ownedCount == 0 then return true end
        if a.ownedCount == 0 and b.ownedCount > 0 then return false end
        return (a.name or "") < (b.name or "")
    end)

    return results, limitReached
end

function ItemSearch:GetDefaultItems(limit)
    limit = limit or DEFAULT_LIMIT
    local results = {}
    local resultMap = {}
    local count = 0

    local ownedMap = GetOwnedItems()

    for _, expName in ipairs(EXPANSION_PRIORITY) do
        local items = _G["OneWoWItems_" .. expName]
        if items then
            for itemID, idata in pairs(items) do
                if idata.name and not resultMap[itemID] then
                    count = count + 1
                    local od = ownedMap[itemID]
                    results[count] = {
                        itemID     = itemID,
                        name       = idata.name,
                        icon       = idata.icon,
                        quality    = idata.quality or 1,
                        ownedCount = od and od.total or 0,
                        isJournal  = true,
                        isVendor   = false,
                        isCrafted  = false,
                        isOwned    = od and true or false,
                        isQuest    = false,
                    }
                    resultMap[itemID] = count
                    if count >= limit then break end
                end
            end
        end
        if count >= limit then break end
    end

    sort(results, function(a, b)
        if a.ownedCount > 0 and b.ownedCount == 0 then return true end
        if a.ownedCount == 0 and b.ownedCount > 0 then return false end
        return (a.name or "") < (b.name or "")
    end)

    return results
end

function ItemSearch:GetDetail(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end

    local isRecipe = false
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    if classID == Enum.ItemClass.Recipe then
        isRecipe = true
    end

    local detail = {
        drops        = {},
        vendors      = {},
        crafted      = {},
        owned        = {},
        quests       = {},
        isRecipe     = isRecipe,
        recipeKnownBy = isRecipe and GetRecipeKnownByFromAltTracker(itemID) or nil,
    }

    for _, expName in ipairs(EXPANSION_NAMES) do
        local items      = _G["OneWoWItems_"      .. expName]
        local instances  = _G["OneWoWInstances_"  .. expName]
        local encounters = _G["OneWoWEncounters_" .. expName]

        if items and items[itemID] and instances and encounters then
            local idata = items[itemID]
            if idata.locations then
                for _, loc in ipairs(idata.locations) do
                    local instInfo = loc.instanceID and instances[loc.instanceID]
                    local instName = instInfo and instInfo.name or ""
                    local encName
                    if loc.encounterID and loc.encounterID ~= 0 then
                        local encInfo = encounters[loc.encounterID]
                        encName = encInfo and encInfo.name
                    end
                    tinsert(detail.drops, {
                        instanceName  = instName,
                        instanceID    = loc.instanceID,
                        mapID         = instInfo and instInfo.mapID,
                        encounterName = encName,
                        difficulties  = loc.difficulties,
                    })
                end
            end
        end
    end

    local vendors = GetVendorsByItem(itemID)
    for _, vendor in ipairs(vendors) do
        local npcID = vendor.npcID
        local mapID, loc
        if vendor.locations then
            for mID, l in pairs(vendor.locations) do
                mapID = mID
                loc = l
                break
            end
        end

        tinsert(detail.vendors, {
            name  = vendor.name,
            npcID = npcID,
            zone  = loc and loc.zone,
            mapID = mapID,
            cost  = vendor.items and vendor.items[itemID] and vendor.items[itemID].cost,
        })
    end

    for _, profName in ipairs(TRADESKILL_PROFS) do
        local data = _G["OneWoWTradeskills_" .. profName]
        if data and data.r then
            for recipeID, recipe in pairs(data.r) do
                if recipe.item == itemID then
                    local knownBy
                    local tsAddon = ns.Catalog and ns.Catalog:GetDataAddon("tradeskills")
                    if tsAddon and tsAddon.TradeskillScanner then
                        knownBy = tsAddon.TradeskillScanner:GetRecipeKnownBy(recipeID)
                    end
                    tinsert(detail.crafted, {
                        recipeID  = recipeID,
                        profName  = recipe.prof or profName,
                        expansion = recipe.exp,
                        knownBy   = knownBy,
                    })
                end
            end
        end
    end

    local ownedMap = GetOwnedItems()
    local od = ownedMap[itemID]
    if od then
        local byCharLoc = {}
        for _, loc in ipairs(od.locations) do
            local key = loc.charName .. "|" .. loc.locLabel
            if not byCharLoc[key] then
                byCharLoc[key] = { charName = loc.charName, locLabel = loc.locLabel, count = 0 }
                tinsert(detail.owned, byCharLoc[key])
            end
            byCharLoc[key].count = byCharLoc[key].count + loc.count
        end
    end

    local questBucket = GetQuestRewardIndex()[itemID]
    if questBucket and questBucket.quests then
        for _, quest in ipairs(questBucket.quests) do
            tinsert(detail.quests, quest)
        end
    end

    return detail
end

function ItemSearch:GetItemEntry(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end

    local itemName = GetKnownItemName(itemID)
    local _, _, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
    local ownedMap = GetOwnedItems()
    local od = ownedMap[itemID]
    local questBucket = GetQuestRewardIndex()[itemID]
    local vendors = GetVendorsByItem(itemID)

    return {
        itemID = itemID,
        name = itemName or ("Item #" .. tostring(itemID)),
        icon = icon,
        quality = quality or 1,
        ownedCount = od and od.total or 0,
        isJournal = false,
        isVendor = vendors and #vendors > 0,
        isCrafted = false,
        isOwned = od and true or false,
        isQuest = questBucket and true or false,
    }
end

function ItemSearch:InvalidateQuestRewardIndex()
    questRewardIndex = nil
end
