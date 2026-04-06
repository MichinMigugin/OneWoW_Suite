local ADDON_NAME, ns = ...

ns.DataAccess = {}
local DataAccess = ns.DataAccess

local altStorage = nil
local altStorageDB = nil
local storageAPI = nil
local qvCache    = {}

function DataAccess:Initialize()
    altStorage = _G.OneWoW_AltTracker_Storage
    altStorageDB = _G.OneWoW_AltTracker_Storage_DB
    storageAPI = _G.StorageAPI
    qvCache    = {}
end

function DataAccess:HasAltData()
    if storageAPI then return true end
    if altStorageDB and (altStorageDB.characters or altStorageDB.warbandBank or altStorageDB.guildBanks) then
        return true
    end
    return altStorage ~= nil and altStorage.db ~= nil
end

local function GetStorageDBGlobal()
    -- Support both legacy shape (ns.db.global) and current storage addon shape (SavedVariable root).
    if altStorage and altStorage.db and altStorage.db.global then
        return altStorage.db.global
    end
    if altStorageDB then
        return altStorageDB
    end
    return nil
end

local function IterateBagsForCharacter(charData, itemIDs, onCount)
    if not charData then return end

    -- Current OneWoW_AltTracker_Storage shape: charData.bags[bagID].slots[slotID].stackCount
    if charData.bags then
        for _, bagData in pairs(charData.bags) do
            if bagData and bagData.slots then
                for _, slotData in pairs(bagData.slots) do
                    if slotData and slotData.itemID and tContains(itemIDs, slotData.itemID) then
                        onCount(slotData.stackCount or 1)
                    end
                end
            end
        end
        return
    end

    -- Older shape used by ShoppingList previously: charData.bagData.bags[bagIdx].items[*].count
    if charData.bagData and charData.bagData.bags then
        for _, bagInfo in pairs(charData.bagData.bags) do
            if bagInfo and bagInfo.items then
                for _, item in pairs(bagInfo.items) do
                    if item and tContains(itemIDs, item.itemID) then
                        onCount(item.count or 1)
                    end
                end
            end
        end
    end
end

local function IteratePersonalBankForCharacter(charData, itemIDs, onCount)
    if not charData then return end

    -- Current storage shape: charData.personalBank.tabs[tabIndex].items[slotID].stackCount
    if charData.personalBank and charData.personalBank.tabs then
        for _, tabData in pairs(charData.personalBank.tabs) do
            if tabData and tabData.items then
                for _, slotData in pairs(tabData.items) do
                    if slotData and slotData.itemID and tContains(itemIDs, slotData.itemID) then
                        onCount(slotData.stackCount or 1)
                    end
                end
            end
        end
        return
    end

    -- Older shape: charData.bankData.tabs[*].items[*].count
    if charData.bankData and charData.bankData.tabs then
        for _, tabData in pairs(charData.bankData.tabs) do
            if tabData and tabData.items then
                for _, item in pairs(tabData.items) do
                    if item and tContains(itemIDs, item.itemID) then
                        onCount(item.count or 1)
                    end
                end
            end
        end
    end
end

local function IterateWarbandBank(storageDB, itemIDs, onCount)
    if not storageDB then return end

    -- Current storage shape: storageDB.warbandBank.tabs[tabIndex].items[slotID].stackCount
    if storageDB.warbandBank and storageDB.warbandBank.tabs then
        for _, tabData in pairs(storageDB.warbandBank.tabs) do
            if tabData and tabData.items then
                for _, slotData in pairs(tabData.items) do
                    if slotData and slotData.itemID and tContains(itemIDs, slotData.itemID) then
                        onCount(slotData.stackCount or 1)
                    end
                end
            end
        end
        return
    end

    -- Older ShoppingList expectation: storageDB.warbandBankData.tabs[*].items[*].count
    if storageDB.warbandBankData and storageDB.warbandBankData.tabs then
        for _, tabData in pairs(storageDB.warbandBankData.tabs) do
            if tabData and tabData.items then
                for _, item in pairs(tabData.items) do
                    if item and tContains(itemIDs, item.itemID) then
                        onCount(item.count or 1)
                    end
                end
            end
        end
    end
end

local function IterateGuildBanks(storageDB, itemIDs, onCount)
    if not storageDB or not storageDB.guildBanks then return end

    -- Current storage shape: guildBanks[guildName].tabs[tabID].slots[slotID].stackCount
    for guildName, guildData in pairs(storageDB.guildBanks) do
        if guildData and guildData.tabs then
            for _, tabData in pairs(guildData.tabs) do
                if tabData and (tabData.slots or tabData.items) then
                    local slots = tabData.slots or tabData.items
                    for _, slotData in pairs(slots) do
                        if slotData and slotData.itemID and tContains(itemIDs, slotData.itemID) then
                            onCount(slotData.stackCount or slotData.count or 1, guildName)
                        end
                    end
                end
            end
        end
    end
end

function DataAccess:GetQualityVariants(itemID)
    if qvCache[itemID] then return qvCache[itemID] end
    local variants = { itemID }
    local profAddon = _G.OneWoW_CatalogData_Tradeskills
    if profAddon and profAddon.db and profAddon.db.global.recipeIndex then
        for _, recipeData in pairs(profAddon.db.global.recipeIndex) do
            if recipeData.reagentSlots then
                for _, slot in ipairs(recipeData.reagentSlots) do
                    if slot.options then
                        local found = false
                        for _, opt in ipairs(slot.options) do
                            if opt.itemID == itemID then found = true; break end
                        end
                        if found then
                            for _, opt in ipairs(slot.options) do
                                if not tContains(variants, opt.itemID) then
                                    table.insert(variants, opt.itemID)
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    end
    qvCache[itemID] = variants
    return variants
end

function DataAccess:GetItemInventoryData(itemID, list)
    local itemIDs   = self:GetQualityVariants(itemID)
    local searchAlts = list and list.searchAlts or false

    local owned     = 0
    local altOwned  = 0
    local locations = {}

    local currentChar = UnitName("player") .. "-" .. GetRealmName()
    local currentName = UnitName("player")

    for bagID = 0, 5 do
        local numSlots = C_Container.GetContainerNumSlots(bagID)
        if numSlots then
            for slotID = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bagID, slotID)
                if info and tContains(itemIDs, info.itemID) then
                    local count = info.stackCount or 1
                    owned = owned + count
                end
            end
        end
    end

    if owned > 0 then
        table.insert(locations, string.format("%s Bags x%d", currentName, owned))
    end

    -- Warband Bank is account-wide, so include it even when not searching alts.
    if self:HasAltData() then
        local adb = GetStorageDBGlobal()
        if adb then
            local wbCount = 0
            IterateWarbandBank(adb, itemIDs, function(c)
                wbCount = wbCount + c
                owned = owned + c
            end)
            if wbCount > 0 then
                table.insert(locations, string.format("Warband Bank x%d", wbCount))
            end
        end
    end

    if searchAlts and self:HasAltData() then
        local adb = GetStorageDBGlobal()

        if adb and adb.characters then
            for charKey, charData in pairs(adb.characters) do
                local charName = charKey:match("([^%-]+)") or charKey

                if charKey ~= currentChar then
                    local bagCount = 0
                    local bankCount = 0
                    IterateBagsForCharacter(charData, itemIDs, function(c)
                        bagCount = bagCount + c
                        altOwned = altOwned + c
                    end)
                    IteratePersonalBankForCharacter(charData, itemIDs, function(c)
                        bankCount = bankCount + c
                        altOwned = altOwned + c
                    end)

                    if bagCount > 0 then
                        table.insert(locations, string.format("%s Bags x%d", charName, bagCount))
                    end
                    if bankCount > 0 then
                        table.insert(locations, string.format("%s Bank x%d", charName, bankCount))
                    end
                else
                    local bankCount = 0
                    IteratePersonalBankForCharacter(charData, itemIDs, function(c)
                        bankCount = bankCount + c
                        owned = owned + c
                    end)
                    if bankCount > 0 then
                        table.insert(locations, string.format("%s Bank x%d", currentName, bankCount))
                    end
                end
            end
        end

        if adb then
            local guildCounts = {}
            IterateGuildBanks(adb, itemIDs, function(c, guildName)
                local g = guildName or "Guild"
                guildCounts[g] = (guildCounts[g] or 0) + c
                altOwned = altOwned + c
            end)
            for guildName, cnt in pairs(guildCounts) do
                if cnt > 0 then
                    if guildName == "Guild" then
                        table.insert(locations, string.format("Guild x%d", cnt))
                    else
                        table.insert(locations, string.format("Guild<%s> x%d", guildName, cnt))
                    end
                end
            end
        end
    end

    return {
        owned     = owned,
        altOwned  = altOwned,
        locations = locations,
    }
end
