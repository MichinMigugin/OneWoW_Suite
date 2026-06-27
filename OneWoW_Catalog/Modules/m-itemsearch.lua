local _, ns = ...

local pairs, ipairs = pairs, ipairs
local tinsert, sort = tinsert, sort
local C_Item, C_TradeSkillUI = C_Item, C_TradeSkillUI

ns.ItemSearch = {}
local ItemSearch = ns.ItemSearch

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

local function GetRecipeKnownByFromAltTracker(itemID)
    local profsAPI = OneWoW_AltTracker_Professions_API
    if not profsAPI then return nil end
    local profChars = profsAPI.GetAllCharacters()

    local recipeItemMap = profsAPI.GetRecipeItemMap()
    local recipeSpellID
    if recipeItemMap and recipeItemMap[itemID] then
        recipeSpellID = recipeItemMap[itemID]
    end

    if not recipeSpellID then
        local _, spellID = C_Item.GetItemSpell(itemID)
        if spellID then recipeSpellID = spellID end
    end

    local knownBy = {}
    local seen = {}

    if recipeSpellID then
        for charKey, charData in pairs(profChars) do
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
            for charKey, charData in pairs(profChars) do
                if charData.recipes and not seen[charKey] then
                    for _, recipeSet in pairs(charData.recipes) do
                        for storedID in pairs(recipeSet) do
                            local info = C_TradeSkillUI.GetRecipeInfo(storedID)
                            if info and info.name == craftedName then
                                profsAPI.SetRecipeItemMapEntry(itemID, storedID)
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

-- The localized item name is embedded in every hyperlink's "[Name]" segment, so
-- it can be recovered offline without touching the live item cache.
local function NameFromLink(itemLink)
    if type(itemLink) ~= "string" then return nil end
    return itemLink:match("%[(.-)%]")
end

local function GetOwnedItems()
    local owned = {}
    local storageAPI = OneWoW_AltTracker_Storage_API
    if not storageAPI then return owned end
    local characters = storageAPI.GetCharacters()
    local warbandBank = storageAPI.GetWarbandBank()
    local guildBanks = storageAPI.GetGuildBanks()

    -- name is captured from the slot's persisted itemName / itemLink so owned-item
    -- search works offline (the live cache may not have the item yet).
    local function addOwned(itemID, count, charName, locLabel, name)
        local rec = owned[itemID]
        if not rec then
            rec = { total = 0, locations = {} }
            owned[itemID] = rec
        end
        rec.total = rec.total + count
        if not rec.name and name and name ~= "" then
            rec.name = name
        end
        tinsert(rec.locations, { charName = charName, locLabel = locLabel, count = count })
    end

    if characters then
        for charKey, charData in pairs(characters) do
            local charName = charKey:match("^([^%-]+)") or charKey

            if charData.bags then
                for _, bagInfo in pairs(charData.bags) do
                    if bagInfo.slots then
                        for _, slot in pairs(bagInfo.slots) do
                            if slot and slot.itemID then
                                addOwned(slot.itemID, slot.stackCount or 1, charName, "bags",
                                    slot.itemName or NameFromLink(slot.itemLink))
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
                                addOwned(slot.itemID, slot.stackCount or 1, charName, "bank",
                                    slot.itemName or NameFromLink(slot.itemLink))
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
                                addOwned(slot.itemID, slot.count or 1, charName, "mail",
                                    slot.itemName or NameFromLink(slot.itemLink))
                            end
                        end
                    end
                end
            end
        end
    end

    if warbandBank and warbandBank.tabs then
        for _, tabInfo in pairs(warbandBank.tabs) do
            if tabInfo.items then
                for _, slot in pairs(tabInfo.items) do
                    if slot and slot.itemID then
                        -- Warband tabs use ContainerScan, whose canonical slot field
                        -- is stackCount (not count).
                        addOwned(slot.itemID, slot.stackCount or 1, "Warband", "warband",
                            slot.itemName or NameFromLink(slot.itemLink))
                    end
                end
            end
        end
    end

    if guildBanks then
        for guildName, guildBank in pairs(guildBanks) do
            if guildBank.tabs then
                for _, tabInfo in pairs(guildBank.tabs) do
                    if tabInfo.slots then
                        for _, slot in pairs(tabInfo.slots) do
                            if slot and slot.itemID then
                                addOwned(slot.itemID, slot.stackCount or 1, guildName, "guild",
                                    slot.itemName or NameFromLink(slot.itemLink))
                            end
                        end
                    end
                end
            end
        end
    end

    local auctionChars = OneWoW_AltTracker_Auctions_API and OneWoW_AltTracker_Auctions_API.GetCharacters()
    if auctionChars then
        for charKey, charData in pairs(auctionChars) do
            local charName = charKey:match("^([^%-]+)") or charKey
            if charData.activeAuctions then
                for _, auc in ipairs(charData.activeAuctions) do
                    if auc.itemID then
                        addOwned(auc.itemID, auc.quantity or 1, charName, "ah",
                            auc.itemName or NameFromLink(auc.itemLink))
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
    local exactItemID = tonumber(searchTerm)
    local results = {}
    local resultMap = {}
    local count = 0
    local limitReached = false

    local doJournal = (sourceFilter == "all" or sourceFilter == "drops")
    local doVendors = (sourceFilter == "all" or sourceFilter == "vendors")
    local doCrafted = (sourceFilter == "all" or sourceFilter == "crafted")
    local doOwned   = (sourceFilter == "all" or sourceFilter == "owned")
    local doQuest   = (sourceFilter == "all" or sourceFilter == "quests")

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
            isQuestReward = false,
            isExactMatch  = false,
        }
        entry[sourceKey] = true
        results[count] = entry
        resultMap[itemID] = count
    end

    if exactItemID then
        local sourceKey = "isQuestReward"
        if sourceFilter == "drops" then
            sourceKey = "isJournal"
        elseif sourceFilter == "vendors" then
            sourceKey = "isVendor"
        elseif sourceFilter == "crafted" then
            sourceKey = "isCrafted"
        elseif sourceFilter == "owned" then
            sourceKey = "isOwned"
        end

        local exactName = C_Item.GetItemNameByID(exactItemID)
        local _, _, _, _, exactIcon = C_Item.GetItemInfoInstant(exactItemID)
        addOrAnnotate(exactItemID, exactName, exactIcon, nil, sourceKey)
        if resultMap[exactItemID] then
            results[resultMap[exactItemID]].isExactMatch = true
        end
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
        local vendorsAPI = OneWoW_CatalogData_Vendors_API
        local vendors = vendorsAPI and vendorsAPI.GetAllVendors()
        if vendors then
            for _, vendor in pairs(vendors) do
                if vendor.items then
                    for itemID in pairs(vendor.items) do
                        local itemName = C_Item.GetItemNameByID(itemID)
                        if itemName and itemName:lower():find(term, 1, true) then
                            addOrAnnotate(itemID, itemName, nil, nil, "isVendor")
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
                        if itemName and itemName:lower():find(term, 1, true) then
                            addOrAnnotate(recipe.item, itemName, nil, nil, "isCrafted")
                            if limitReached then break end
                        end
                    end
                end
            end
            if limitReached then break end
        end
    end

    if doQuest and not limitReached then
        local questAddon = ns.Catalog and ns.Catalog:GetDataAddon("quests")
        if questAddon then
            for _, itemID in ipairs(questAddon.GetRewardItemIDs()) do
                local itemName = C_Item.GetItemNameByID(itemID)
                if itemName and itemName:lower():find(term, 1, true) then
                    addOrAnnotate(itemID, itemName, nil, nil, "isQuestReward")
                    if limitReached then break end
                end
            end
        end
    end

    local ownedMap = GetOwnedItems()

    if doOwned and not limitReached then
        for itemID, od in pairs(ownedMap) do
            -- Prefer the name persisted at scan time so owned items match offline;
            -- fall back to the live cache only when no stored name exists.
            local itemName = od.name or C_Item.GetItemNameByID(itemID)
            if itemName and itemName:lower():find(term, 1, true) then
                addOrAnnotate(itemID, itemName, nil, nil, "isOwned")
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
        questRewards = {},
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
                        encounterName = encName,
                        difficulties  = loc.difficulties,
                    })
                end
            end
        end
    end

    local vendorsAPI = OneWoW_CatalogData_Vendors_API
    local sellingVendors = vendorsAPI and vendorsAPI.GetVendorsByItem(itemID)
    if sellingVendors then
        for _, vendor in ipairs(sellingVendors) do
            local mapID, loc
            if vendor.locations then
                for mID, l in pairs(vendor.locations) do
                    mapID = mID
                    loc = l
                    break
                end
            end
            local itemEntry = vendor.items and vendor.items[itemID]
            tinsert(detail.vendors, {
                name  = vendor.name,
                npcID = vendor.npcID,
                zone  = loc and loc.zone,
                mapID = mapID,
                cost  = itemEntry and itemEntry.cost,
            })
        end
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

    local questAddon = ns.Catalog and ns.Catalog:GetDataAddon("quests")
    if questAddon then
        local questIDs = questAddon.GetQuestsRewardingItem(itemID)
        if questIDs then
            for _, questID in ipairs(questIDs) do
                local q = questAddon.GetQuest(questID)
                tinsert(detail.questRewards, { questID = questID, questName = q and q.name })
            end
        end
    end

    return detail
end
