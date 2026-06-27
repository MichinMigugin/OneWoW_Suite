local _, ns = ...

local pairs = pairs
local GetRealmID = GetRealmID
local GetServerTime = GetServerTime

ns.AHPriceCache = ns.AHPriceCache or {}
local Cache = ns.AHPriceCache

local AHItemKeys = OneWoW.AHItemKeys

local CACHE_VERSION = 2
local AH_PRICE_MAX_AGE_DAYS = 14
local SCAN_COOLDOWN_SECONDS = 15 * 60

local function EnsureStore()
    if not OneWoW_AHPrices then
        OneWoW_AHPrices = { version = CACHE_VERSION, realms = {} }
    end
    if OneWoW_AHPrices.version ~= CACHE_VERSION then
        local hadV1 = false
        for key in pairs(OneWoW_AHPrices) do
            if type(key) == "number" then
                hadV1 = true
                break
            end
        end
        OneWoW_AHPrices = { version = CACHE_VERSION, realms = {} }
        if hadV1 then
            C_Timer.After(5, function()
                print("|cFFFFD100OneWoW:|r Previous AH price cache format was discarded. Run a full AH scan to rebuild prices.")
            end)
        end
    end
    if not OneWoW_AHPrices.realms then
        OneWoW_AHPrices.realms = {}
    end
end

function Cache:Initialize()
    EnsureStore()
    self:PurgeExpiredEntries()
end

function Cache:GetRealmID()
    return GetRealmID()
end

function Cache:GetRealmBucket(realmID)
    EnsureStore()
    realmID = realmID or GetRealmID()
    local realms = OneWoW_AHPrices.realms
    if not realms[realmID] then
        realms[realmID] = {
            meta = { lastFullScanAt = 0, lastFullScanItemCount = 0 },
            entries = {},
        }
    end
    return realms[realmID]
end

function Cache:PurgeExpiredEntries()
    EnsureStore()
    local cutoff = GetServerTime() - (AH_PRICE_MAX_AGE_DAYS * 86400)
    local purged = 0
    for realmID, bucket in pairs(OneWoW_AHPrices.realms) do
        if bucket.entries then
            for storageKey, data in pairs(bucket.entries) do
                if not data.timestamp or data.timestamp < cutoff then
                    bucket.entries[storageKey] = nil
                    purged = purged + 1
                end
            end
            if not next(bucket.entries) and (not bucket.meta or bucket.meta.lastFullScanAt == 0) then
                OneWoW_AHPrices.realms[realmID] = nil
            end
        end
    end
    if purged > 0 then
        C_Timer.After(5, function()
            print("|cFFFFD100OneWoW:|r Cleaned " .. purged .. " expired AH price entries (>" .. AH_PRICE_MAX_AGE_DAYS .. " days old).")
        end)
    end
end

function Cache:GetEntry(storageKey, realmID)
    local bucket = self:GetRealmBucket(realmID)
    return bucket.entries[storageKey]
end

function Cache:LookupPrice(itemID, itemLink, realmID)
    if not AHItemKeys then return nil end
    local keys = AHItemKeys:KeysFromItemLink(itemLink, itemID)
    if #keys == 0 and itemID then
        keys = AHItemKeys:KeysFromItemKey(C_AuctionHouse.MakeItemKey(itemID))
    end
    local bucket = self:GetRealmBucket(realmID)
    for _, storageKey in ipairs(keys) do
        local row = bucket.entries[storageKey]
        if row and row.price and row.price > 0 then
            return row, storageKey
        end
    end
    return nil, nil
end

function Cache:LookupSpeciesPrice(speciesID, realmID)
    if not AHItemKeys or not speciesID then return nil end
    local keys = AHItemKeys:KeysFromSpeciesID(speciesID)
    local bucket = self:GetRealmBucket(realmID)
    for _, storageKey in ipairs(keys) do
        local row = bucket.entries[storageKey]
        if row and row.price and row.price > 0 then
            return row, storageKey
        end
    end
    return nil, nil
end

function Cache:ReplaceRealmEntries(realmID, newEntries, itemCount)
    local bucket = self:GetRealmBucket(realmID)
    bucket.entries = newEntries or {}
    bucket.meta.lastFullScanAt = GetServerTime()
    bucket.meta.lastFullScanItemCount = itemCount or 0
end

function Cache:MergeRealmEntries(realmID, patchEntries)
    if not patchEntries then return end
    local bucket = self:GetRealmBucket(realmID)
    local serverTime = GetServerTime()
    for storageKey, price in pairs(patchEntries) do
        if type(price) == "table" then
            bucket.entries[storageKey] = price
        elseif type(price) == "number" and price > 0 then
            bucket.entries[storageKey] = { price = price, timestamp = serverTime }
        end
    end
end

function Cache:GetScanMeta(realmID)
    local bucket = self:GetRealmBucket(realmID)
    return {
        lastFullScanAt = bucket.meta.lastFullScanAt or 0,
        lastFullScanItemCount = bucket.meta.lastFullScanItemCount or 0,
        realmID = realmID or GetRealmID(),
    }
end

function Cache:CanFullScan(realmID)
    local bucket = self:GetRealmBucket(realmID)
    local lastAt = bucket.meta.lastFullScanAt or 0
    if lastAt <= 0 then
        return true, 0
    end
    local elapsed = GetServerTime() - lastAt
    if elapsed >= SCAN_COOLDOWN_SECONDS then
        return true, 0
    end
    local remaining = math.ceil((SCAN_COOLDOWN_SECONDS - elapsed) / 60)
    return false, remaining
end

function Cache:NewEntriesTable()
    return {}
end

function Cache:RecordMinPrice(entries, storageKey, unitPrice, timestamp)
    if not storageKey or not unitPrice or unitPrice <= 0 then return end
    local existing = entries[storageKey]
    if not existing or unitPrice < existing.price then
        entries[storageKey] = { price = unitPrice, timestamp = timestamp }
    end
end
