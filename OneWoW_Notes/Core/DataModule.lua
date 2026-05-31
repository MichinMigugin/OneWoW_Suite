local _, ns = ...

local DataModule = {}
ns.DataModule = DataModule

local pairs, ipairs, type, tinsert = pairs, ipairs, type, table.insert

function DataModule:New(dbKey, categoryCustomKey, builtinCategories)
    local obj = setmetatable({}, { __index = self })
    obj._dbKey = dbKey
    obj._categoryCustomKey = categoryCustomKey
    obj._builtinCategories = builtinCategories or {}
    obj._cache = nil
    return obj
end

function DataModule:GetDataDB(storageType)
    local addon = OneWoW_Notes
    if storageType == "character" then
        return addon.db.char[self._dbKey]
    else
        return addon.db.global[self._dbKey]
    end
end

function DataModule:InvalidateCache()
    self._cache = nil
end

function DataModule:GetAll()
    if self._cache then return self._cache end
    local addon = OneWoW_Notes
    local all = {}
    for key, data in pairs(addon.db.global[self._dbKey]) do
        all[key] = data
        if type(data) == "table" then data.storage = "account" end
    end
    for key, data in pairs(addon.db.char[self._dbKey]) do
        all[key] = data
        if type(data) == "table" then data.storage = "character" end
    end
    self._cache = all
    return all
end

function DataModule:Remove(key)
    if not key then return end
    local addon = OneWoW_Notes
    addon.db.global[self._dbKey][key] = nil
    addon.db.char[self._dbKey][key] = nil
    self._cache = nil
end

function DataModule:GetCategories()
    local addon = OneWoW_Notes
    local all = {}
    for _, c in ipairs(self._builtinCategories) do tinsert(all, c) end
    if self._categoryCustomKey then
        for _, c in ipairs(addon.db.global[self._categoryCustomKey]) do tinsert(all, c) end
    end
    return all
end
