local addonName, ns = ...

ns.ItemIndex = {}
local ItemIndex = ns.ItemIndex

local index = {}
local rebuildPending = false

local function GetCharMeta(charKey)
    local charDB = _G.OneWoW_AltTracker_Character_DB
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

local function BuildIndex()
    wipe(index)

    local storageDB = _G.OneWoW_AltTracker_Storage_DB
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

    local charDB = _G.OneWoW_AltTracker_Character_DB
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

    local auctionsDB = _G.OneWoW_AltTracker_Auctions_DB
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
