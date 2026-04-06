-- OneWoW Addon File
-- OneWoW_Catalog/Modules/m-itemsearch.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

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

local EXPANSION_PRIORITY = {
    "Midnight", "TheWarWithin", "Dragonflight", "Shadowlands",
    "BattleforAzeroth", "Legion", "WarlordsofDraenor", "MistsofPandaria",
    "Cataclysm", "WrathoftheLichKing", "BurningCrusade", "Classic",
}

local function GetOwnedItems()
    local owned = {}
    local sdb = _G.OneWoW_AltTracker_Storage_DB
    if not sdb then return owned end

    local function addOwned(itemID, count, charName, locLabel)
        if not owned[itemID] then
            owned[itemID] = { total = 0, locations = {} }
        end
        owned[itemID].total = owned[itemID].total + count
        table.insert(owned[itemID].locations, { charName = charName, locLabel = locLabel, count = count })
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

    local adb = _G.OneWoW_AltTracker_Auctions_DB
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
    local results = {}
    local resultMap = {}
    local count = 0
    local limitReached = false

    local doJournal = (sourceFilter == "all" or sourceFilter == "drops")
    local doVendors = (sourceFilter == "all" or sourceFilter == "vendors")
    local doCrafted = (sourceFilter == "all" or sourceFilter == "crafted")
    local doOwned   = (sourceFilter == "all" or sourceFilter == "owned")

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
        local vdb = _G.OneWoW_CatalogData_Vendors_DB
        if vdb and vdb.vendors then
            for _, vendor in pairs(vdb.vendors) do
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

    local ownedMap = GetOwnedItems()

    if doOwned and not limitReached then
        for itemID in pairs(ownedMap) do
            local itemName = C_Item.GetItemNameByID(itemID)
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

    table.sort(results, function(a, b)
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

    table.sort(results, function(a, b)
        if a.ownedCount > 0 and b.ownedCount == 0 then return true end
        if a.ownedCount == 0 and b.ownedCount > 0 then return false end
        return (a.name or "") < (b.name or "")
    end)

    return results
end

function ItemSearch:GetDetail(itemID)
    local detail = {
        drops   = {},
        vendors = {},
        crafted = {},
        owned   = {},
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
                    table.insert(detail.drops, {
                        instanceName  = instName,
                        encounterName = encName,
                        difficulties  = loc.difficulties,
                    })
                end
            end
        end
    end

    local vdb = _G.OneWoW_CatalogData_Vendors_DB
    if vdb and vdb.vendors then
        for npcID, vendor in pairs(vdb.vendors) do
            if vendor.items and vendor.items[itemID] then
                local mapID, loc
                if vendor.locations then
                    for mID, l in pairs(vendor.locations) do
                        mapID = mID
                        loc = l
                        break
                    end
                end
                table.insert(detail.vendors, {
                    name  = vendor.name,
                    npcID = npcID,
                    zone  = loc and loc.zone,
                    mapID = mapID,
                    cost  = vendor.items[itemID].cost,
                })
            end
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
                    table.insert(detail.crafted, {
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
                table.insert(detail.owned, byCharLoc[key])
            end
            byCharLoc[key].count = byCharLoc[key].count + loc.count
        end
    end

    return detail
end
