local addonName, ns = ...

ns.ItemIndex = {}
local ItemIndex = ns.ItemIndex

-- index[itemID] = { locations = { ... }, totalCount = N }
local index = {}

-- nameIndex[ lowercased C_Item.GetItemNameByID(itemID) ] = { [itemID] = true, ... }
-- Used to group sibling itemIDs that are different craft ranks of the same item
-- (e.g. Algari Mana Oil R1/R2/R3 each have their own itemID but share a name).
local nameIndex = {}

local rebuildPending = false

local function GetCharMeta(charKey)
    local charDB = OneWoW_AltTracker_Character_DB
    if charDB and charDB.characters and charDB.characters[charKey] then
        local cd = charDB.characters[charKey]
        return cd.name, cd.realm, cd.class, cd.className
    end
    local name, realm = charKey:match("^(.+)-(.+)$")
    return name or charKey, realm or "", nil, nil
end

local function AddToIndex(itemID, locationData)
    if not itemID or itemID == 0 then return end
    if not index[itemID] then
        index[itemID] = { locations = {}, totalCount = 0 }
    end
    table.insert(index[itemID].locations, locationData)
    index[itemID].totalCount = index[itemID].totalCount + (locationData.count or 0)
end

local function BuildNameIndex()
    wipe(nameIndex)
    for itemID in pairs(index) do
        local name = C_Item.GetItemNameByID(itemID)
        if name and name ~= "" then
            local key = name:lower()
            local bucket = nameIndex[key]
            if not bucket then
                bucket = {}
                nameIndex[key] = bucket
            end
            bucket[itemID] = true
        end
    end
end

local function BuildIndex()
    wipe(index)
    wipe(nameIndex)

    local storageDB = OneWoW_AltTracker_Storage_DB
    if not storageDB then return end

    if storageDB.characters then
        for charKey, charData in pairs(storageDB.characters) do
            local name, realm, class, className = GetCharMeta(charKey)

            if charData.bags then
                for _, bagData in pairs(charData.bags) do
                    if bagData.slots then
                        for _, slotData in pairs(bagData.slots) do
                            if slotData.itemID and slotData.itemID ~= 0 then
                                AddToIndex(slotData.itemID, {
                                    locationType = "bags",
                                    charKey      = charKey,
                                    name         = name,
                                    realm        = realm,
                                    class        = class,
                                    className    = className,
                                    count        = slotData.stackCount or 1,
                                    itemLink     = slotData.itemLink,
                                    quality      = slotData.quality,
                                })
                            end
                        end
                    end
                end
            end

            if charData.personalBank and charData.personalBank.tabs then
                for _, tabData in pairs(charData.personalBank.tabs) do
                    if tabData.items then
                        for _, slotData in pairs(tabData.items) do
                            if slotData.itemID and slotData.itemID ~= 0 then
                                AddToIndex(slotData.itemID, {
                                    locationType = "bank",
                                    charKey      = charKey,
                                    name         = name,
                                    realm        = realm,
                                    class        = class,
                                    className    = className,
                                    count        = slotData.stackCount or 1,
                                    itemLink     = slotData.itemLink,
                                    quality      = slotData.quality,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    if storageDB.warbandBank and storageDB.warbandBank.tabs then
        for _, tabData in pairs(storageDB.warbandBank.tabs) do
            if tabData.items then
                for _, slotData in pairs(tabData.items) do
                    if slotData.itemID and slotData.itemID ~= 0 then
                        AddToIndex(slotData.itemID, {
                            locationType = "warband",
                            count        = slotData.stackCount or 1,
                            itemLink     = slotData.itemLink,
                            quality      = slotData.quality,
                        })
                    end
                end
            end
        end
    end

    if storageDB.guildBanks then
        for guildName, guildData in pairs(storageDB.guildBanks) do
            if guildData.tabs then
                for _, tabData in pairs(guildData.tabs) do
                    if tabData.slots then
                        for _, slotData in pairs(tabData.slots) do
                            if slotData.itemID and slotData.itemID ~= 0 then
                                AddToIndex(slotData.itemID, {
                                    locationType = "guild",
                                    guildName    = guildName,
                                    count        = slotData.stackCount or 1,
                                    itemLink     = slotData.itemLink,
                                    quality      = slotData.quality,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    local charDB = OneWoW_AltTracker_Character_DB
    if charDB and charDB.characters then
        for charKey, charData in pairs(charDB.characters) do
            if charData.equipment then
                local name, realm, class, className = GetCharMeta(charKey)
                for _, slotData in pairs(charData.equipment) do
                    if slotData.itemID and slotData.itemID ~= 0 then
                        AddToIndex(slotData.itemID, {
                            locationType = "equipped",
                            charKey      = charKey,
                            name         = name,
                            realm        = realm,
                            class        = class,
                            className    = className,
                            count        = 1,
                            itemLink     = slotData.itemLink,
                            quality      = slotData.quality,
                        })
                    end
                end
            end
        end
    end

    local auctionsDB = OneWoW_AltTracker_Auctions_DB
    if auctionsDB and auctionsDB.characters then
        for charKey, charData in pairs(auctionsDB.characters) do
            if charData.activeAuctions then
                local name, realm, class, className = GetCharMeta(charKey)
                for _, auction in pairs(charData.activeAuctions) do
                    if auction.itemID and auction.itemID ~= 0 then
                        AddToIndex(auction.itemID, {
                            locationType     = "auction",
                            charKey          = charKey,
                            name             = name,
                            realm            = realm,
                            class            = class,
                            className        = className,
                            count            = auction.quantity or 1,
                            itemLink         = auction.itemLink,
                            quality          = auction.itemRarity,
                            buyoutAmount     = auction.buyoutAmount,
                            timeLeftSeconds  = auction.timeLeftSeconds,
                        })
                    end
                end
            end
        end
    end

    BuildNameIndex()
end

local function ScheduleRebuild()
    if rebuildPending then return end
    rebuildPending = true
    C_Timer.After(0.8, function()
        rebuildPending = false
        BuildIndex()
    end)
end

function ItemIndex:GetTooltipData(itemID)
    if not itemID then return nil end
    local data = index[itemID]
    if not data or #data.locations == 0 then return nil end
    return {
        locations  = data.locations,
        totalCount = data.totalCount,
    }
end

--- Decode a craft rank (1-3 reagent / 1-5 crafted) from an itemID or itemLink.
--- Returns nil for items that don't carry a profession-quality marker.
---@param itemIDOrLink number|string|nil
---@return number|nil rank
function ItemIndex:DecodeRank(itemIDOrLink)
    if not itemIDOrLink then return nil end
    local r = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemIDOrLink)
    if r then return r end
    return C_TradeSkillUI.GetItemCraftedQualityByItemInfo(itemIDOrLink)
end

--- Return itemIDs that share a name with the given itemID (other craft ranks
--- of the same item), filtered to itemIDs that share the same Enum.ItemClass
--- so unrelated items that coincidentally share a name don't collapse together.
--- The returned list excludes itemID itself. Returns nil when no siblings exist.
---@param itemID number|nil
---@return number[]|nil
function ItemIndex:GetSiblingItemIDs(itemID)
    if not itemID then return nil end
    local name = C_Item.GetItemNameByID(itemID)
    if not name or name == "" then return nil end
    local bucket = nameIndex[name:lower()]
    if not bucket then return nil end

    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)

    local result = {}
    for sid in pairs(bucket) do
        if sid ~= itemID then
            local _, _, _, _, _, sClassID = C_Item.GetItemInfoInstant(sid)
            if sClassID == classID then
                table.insert(result, sid)
            end
        end
    end
    if #result == 0 then return nil end
    return result
end

--- Return a flat list of location entries for the "item family" of itemID:
--- the hovered itemID's own locations plus every craft-rank sibling's locations.
--- Each entry is a shallow copy of the stored location with two extras:
---   .itemID  -- the family-member itemID this location belongs to
---   .rank    -- decoded craft rank (per itemLink when available, else per itemID),
---              may be nil for non-ranked items
--- Returns nil when nothing in the family is owned anywhere.
---@param itemID number|nil
---@return table[]|nil
function ItemIndex:GetFamilyLocations(itemID)
    if not itemID then return nil end

    local results = {}

    local function harvest(sid)
        local data = index[sid]
        if not data then return end
        local idRank = self:DecodeRank(sid)
        for _, loc in ipairs(data.locations) do
            local copy = {}
            for k, v in pairs(loc) do copy[k] = v end
            copy.itemID = sid
            copy.rank   = (loc.itemLink and self:DecodeRank(loc.itemLink)) or idRank
            table.insert(results, copy)
        end
    end

    harvest(itemID)
    local siblings = self:GetSiblingItemIDs(itemID)
    if siblings then
        for _, sid in ipairs(siblings) do harvest(sid) end
    end

    if #results == 0 then return nil end
    return results
end

function ItemIndex:Initialize()
    C_Timer.After(1.5, function()
        BuildIndex()
    end)

    local f = CreateFrame("Frame")
    f:RegisterEvent("BAG_UPDATE_DELAYED")
    f:RegisterEvent("BANKFRAME_CLOSED")
    f:RegisterEvent("GUILDBANKFRAME_CLOSED")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:RegisterEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED")
    f:SetScript("OnEvent", function(_, event)
        ScheduleRebuild()
    end)
end
