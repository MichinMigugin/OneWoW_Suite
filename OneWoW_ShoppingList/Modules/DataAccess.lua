local ADDON_NAME, ns = ...

ns.DataAccess = {}
local DataAccess = ns.DataAccess

local altStorage = nil
local qvCache    = {}

function DataAccess:Initialize()
    altStorage = _G.OneWoW_AltTracker_Storage
    qvCache    = {}
end

function DataAccess:HasAltData()
    return altStorage ~= nil and altStorage.db ~= nil
end

function DataAccess:GetQualityVariants(itemID)
    if qvCache[itemID] then return qvCache[itemID] end
    local variants = { itemID }
    local profAddon = _G.WoWNotesData_Professions
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

    if searchAlts and self:HasAltData() then
        local adb = altStorage.db.global

        if adb.characters then
            for charKey, charData in pairs(adb.characters) do
                if charKey ~= currentChar then
                    local charName = charKey:match("([^%-]+)") or charKey
                    local bagCount  = 0
                    local bankCount = 0

                    if charData.bagData and charData.bagData.bags then
                        for bagIdx = 0, 5 do
                            local bagInfo = charData.bagData.bags[bagIdx]
                            if bagInfo and bagInfo.items then
                                for _, item in pairs(bagInfo.items) do
                                    if item and tContains(itemIDs, item.itemID) then
                                        local c = item.count or 1
                                        bagCount = bagCount + c
                                        altOwned = altOwned + c
                                    end
                                end
                            end
                        end
                    end

                    if charData.bankData and charData.bankData.tabs then
                        for _, tabData in pairs(charData.bankData.tabs) do
                            if tabData and tabData.items then
                                for _, item in pairs(tabData.items) do
                                    if item and tContains(itemIDs, item.itemID) then
                                        local c = item.count or 1
                                        bankCount = bankCount + c
                                        altOwned = altOwned + c
                                    end
                                end
                            end
                        end
                    end

                    if bagCount > 0 then
                        table.insert(locations, string.format("%s Bags x%d", charName, bagCount))
                    end
                    if bankCount > 0 then
                        table.insert(locations, string.format("%s Bank x%d", charName, bankCount))
                    end
                else
                    if charData.bankData and charData.bankData.tabs then
                        local bankCount = 0
                        for _, tabData in pairs(charData.bankData.tabs) do
                            if tabData and tabData.items then
                                for _, item in pairs(tabData.items) do
                                    if item and tContains(itemIDs, item.itemID) then
                                        local c = item.count or 1
                                        bankCount = bankCount + c
                                        owned = owned + c
                                    end
                                end
                            end
                        end
                        if bankCount > 0 then
                            table.insert(locations, string.format("%s Bank x%d", currentName, bankCount))
                        end
                    end
                end
            end
        end

        if adb.warbandBankData and adb.warbandBankData.tabs then
            local wbCount = 0
            for _, tabData in pairs(adb.warbandBankData.tabs) do
                if tabData and tabData.items then
                    for _, item in pairs(tabData.items) do
                        if item and tContains(itemIDs, item.itemID) then
                            local c = item.count or 1
                            wbCount  = wbCount + c
                            altOwned = altOwned + c
                        end
                    end
                end
            end
            if wbCount > 0 then
                table.insert(locations, string.format("Warband Bank x%d", wbCount))
            end
        end

        if adb.guildBanks then
            for guildName, guildData in pairs(adb.guildBanks) do
                if guildData.tabs then
                    local guildCount = 0
                    for _, tabData in pairs(guildData.tabs) do
                        if tabData and tabData.items then
                            for _, item in pairs(tabData.items) do
                                if item and tContains(itemIDs, item.itemID) then
                                    local c = item.count or 1
                                    guildCount = guildCount + c
                                    altOwned   = altOwned + c
                                end
                            end
                        end
                    end
                    if guildCount > 0 then
                        table.insert(locations, string.format("Guild<%s> x%d", guildName, guildCount))
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
