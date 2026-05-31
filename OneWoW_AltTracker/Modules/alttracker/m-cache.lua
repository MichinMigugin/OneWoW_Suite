local addonName, ns = ...

ns.AltTrackerCache = ns.AltTrackerCache or {}
local Cache = ns.AltTrackerCache

local cacheStore = {}
local sessionCache = {}
local MAX_CACHE_SIZE = 50

function Cache:Initialize()
    self.initialized = true
    wipe(cacheStore)
    wipe(sessionCache)
end

function Cache:EvictOldest()
    local oldestKey = nil
    local oldestTime = math.huge

    for key, data in pairs(cacheStore) do
        if data.timestamp and data.timestamp < oldestTime then
            oldestTime = data.timestamp
            oldestKey = key
        end
    end

    if oldestKey then
        cacheStore[oldestKey] = nil
    end
end

function Cache:GetCacheSize()
    local count = 0
    for _ in pairs(cacheStore) do
        count = count + 1
    end
    return count
end

function Cache:GetCachedData(cacheKey, fetchFunc, timeout)
    timeout = timeout or 30

    local now = GetTime()
    local cached = cacheStore[cacheKey]

    if cached and cached.data and cached.timestamp then
        local age = now - cached.timestamp
        if age < timeout then
            return cached.data, true
        end
    end

    if fetchFunc then
        local data = fetchFunc()
        cacheStore[cacheKey] = {
            data = data,
            timestamp = now
        }
        return data, false
    end

    return nil, false
end

function Cache:SetCache(cacheKey, data)
    if self:GetCacheSize() >= MAX_CACHE_SIZE then
        self:EvictOldest()
    end

    cacheStore[cacheKey] = {
        data = data,
        timestamp = GetTime()
    }
end

function Cache:InvalidateCache(cacheKey)
    if cacheKey then
        cacheStore[cacheKey] = nil
    end
end

function Cache:ClearAllCaches()
    wipe(cacheStore)
end

function Cache:GetSessionCache(key)
    return sessionCache[key]
end

function Cache:SetSessionCache(key, data)
    sessionCache[key] = data
end

function Cache:HasSessionCache(key)
    return sessionCache[key] ~= nil
end

function Cache:BuildSessionCache()
    if self:HasSessionCache("collections") then
        return
    end

    local collections = {
        mounts = {collected = 0, total = 0},
        pets = {collected = 0, total = 0},
        achievements = 0
    }

    local mountIDs = C_MountJournal.GetMountIDs()
    if mountIDs then
        collections.mounts.total = #mountIDs
        for _, mountID in ipairs(mountIDs) do
            local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
            if isCollected then
                collections.mounts.collected = collections.mounts.collected + 1
            end
        end
    end

    local numPets, numOwned = C_PetJournal.GetNumPets()
    collections.pets.total = numPets or 0
    collections.pets.collected = numOwned or 0

    collections.achievements = GetTotalAchievementPoints() or 0

    self:SetSessionCache("collections", collections)
end

function Cache:GetCollectionsData()
    local cached = self:GetSessionCache("collections")
    if cached then
        return cached
    end

    return {
        mounts = {collected = 0, total = 0},
        pets = {collected = 0, total = 0},
        achievements = 0
    }
end
