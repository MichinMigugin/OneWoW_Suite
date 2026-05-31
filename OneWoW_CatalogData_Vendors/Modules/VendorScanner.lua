local _, ns = ...

ns.VendorScanner = {}
local VendorScanner = ns.VendorScanner

local tinsert = tinsert
local pcall, time = pcall, time
local floor, tonumber = math.floor, tonumber
local UnitGUID, UnitName, UnitCreatureType, UnitClassification, UnitLevel  = UnitGUID, UnitName, UnitCreatureType, UnitClassification, UnitLevel
local GetMerchantNumItems, GetMerchantItemLink = GetMerchantNumItems, GetMerchantItemLink
local GetMerchantItemCostInfo, GetMerchantItemCostItem = GetMerchantItemCostInfo, GetMerchantItemCostItem
local C_Timer = C_Timer
local C_Map, GetSubZoneText = C_Map, GetSubZoneText
local C_MerchantFrame = C_MerchantFrame
local C_CurrencyInfo = C_CurrencyInfo
local C_Item = C_Item

local scanInProgress = false

function VendorScanner:ExtractNPCID(guid)
    if not guid then return 0 end
    local ok, result = pcall(string.match, guid, "-(%d+)-%x+$")
    if ok and result then return tonumber(result) or 0 end
    return 0
end

function VendorScanner:GetCurrentLocation()
    local location = {}
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end

    location.mapID = mapID

    local mapInfo = C_Map.GetMapInfo(mapID)
    location.zone = mapInfo and mapInfo.name or GetZoneText() or ""
    location.subzone = GetSubZoneText() or ""

    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if position then
        location.x = floor(position.x * 10000) / 100
        location.y = floor(position.y * 10000) / 100
    else
        location.x = 0
        location.y = 0
    end

    return location
end

function VendorScanner:ScanVendor()
    if scanInProgress then return end

    local settings = ns:GetSettings()
    if settings and settings.enabled == false then return end

    scanInProgress = true

    local guid = UnitGUID("npc")
    local npcID = self:ExtractNPCID(guid)

    if npcID == 0 then
        guid = UnitGUID("target")
        npcID = self:ExtractNPCID(guid)
    end

    if npcID == 0 then
        scanInProgress = false
        return
    end

    local name = UnitName("npc") or ""
    local creatureType = UnitCreatureType("npc") or ""
    local classification = UnitClassification("npc") or "normal"
    local level = UnitLevel("npc") or 0

    local location = self:GetCurrentLocation()

    local numItems = GetMerchantNumItems()
    local items = {}

    for i = 1, numItems do
        local itemLink = GetMerchantItemLink(i)
        if itemLink then
            local itemID = tonumber(itemLink:match("item:(%d+)"))
            if itemID then
                local merchantInfo = C_MerchantFrame.GetItemInfo(i)
                local itemEntry = {
                    cost = merchantInfo and merchantInfo.price or 0,
                    limited = merchantInfo and merchantInfo.numAvailable and merchantInfo.numAvailable > 0 or false,
                    maxStack = merchantInfo and merchantInfo.stackCount or 1,
                    lastSeen = time(),
                    currencies = {},
                }

                if merchantInfo and merchantInfo.hasExtendedCost then
                    local costCount = GetMerchantItemCostInfo(i)
                    for c = 1, costCount do
                        local texture, value, costLink, currName = GetMerchantItemCostItem(i, c)
                        local costEntry = { amount = value, texture = texture }

                        if costLink then
                            local currID = tonumber(costLink:match("currency:(%d+)"))
                            if currID then
                                costEntry.currencyID = currID
                                local currInfo = C_CurrencyInfo.GetCurrencyInfo(currID)
                                costEntry.name = currInfo and currInfo.name or currName or ""
                            else
                                local itemCostID = tonumber(costLink:match("item:(%d+)"))
                                if itemCostID then
                                    costEntry.itemID = itemCostID
                                    local costItemName = C_Item.GetItemNameByID(itemCostID)
                                    if not costItemName then
                                        C_Item.RequestLoadItemDataByID(itemCostID)
                                    end
                                    costEntry.name = costItemName or currName or ""
                                end
                            end
                        elseif currName then
                            costEntry.name = currName
                        end

                        if costEntry.amount and costEntry.amount > 0 then
                            tinsert(itemEntry.currencies, costEntry)
                        end
                    end
                end

                items[itemID] = itemEntry
            end
        end
    end

    local db = ns:GetDB()
    if not db.vendors then db.vendors = {} end

    local existing = db.vendors[npcID]
    local now = time()

    if existing then
        if name ~= "" then existing.name = name end
        existing.creatureType = creatureType
        existing.classification = classification
        existing.level = level
        existing.lastScanned = now
        existing.scanCount = (existing.scanCount or 0) + 1

        if location and location.mapID then
            if not existing.locations then existing.locations = {} end
            existing.locations[location.mapID] = {
                zone = location.zone,
                subzone = location.subzone,
                x = location.x,
                y = location.y,
            }
        end

        if not existing.items then existing.items = {} end
        for itemID, itemData in pairs(items) do
            existing.items[itemID] = itemData
        end
    else
        local locations = {}
        if location and location.mapID then
            locations[location.mapID] = {
                zone = location.zone,
                subzone = location.subzone,
                x = location.x,
                y = location.y,
            }
        end

        db.vendors[npcID] = {
            name = name,
            npcID = npcID,
            locations = locations,
            creatureType = creatureType,
            classification = classification,
            level = level,
            items = items,
            firstSeen = now,
            lastScanned = now,
            scanCount = 1,
        }
    end

    if name ~= "" then
        if not db.nameCache then db.nameCache = {} end
        db.nameCache[npcID] = name
    end

    scanInProgress = false
    ns:FireScanCallbacks(db.vendors[npcID])
end

function VendorScanner:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("MERCHANT_SHOW")
    frame:RegisterEvent("MERCHANT_CLOSED")
    frame:RegisterEvent("MERCHANT_UPDATE")

    frame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            C_Timer.After(0.5, function()
                VendorScanner:ScanVendor()
            end)
        elseif event == "MERCHANT_CLOSED" then
            scanInProgress = false
        elseif event == "MERCHANT_UPDATE" then
            if not scanInProgress then
                VendorScanner:ScanVendor()
            end
        end
    end)
end
