local addonName, ns = ...

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
    local addon = _G.OneWoW_Notes
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
    local addon = _G.OneWoW_Notes
    local all = {}
    local globalDB = addon.db.global[self._dbKey]
    if globalDB then
        for key, data in pairs(globalDB) do
            all[key] = data
            if type(data) == "table" then data.storage = "account" end
        end
    end
    local charDB = addon.db.char[self._dbKey]
    if charDB then
        for key, data in pairs(charDB) do
            all[key] = data
            if type(data) == "table" then data.storage = "character" end
        end
    end
    self._cache = all
    return all
end

function DataModule:Remove(key)
    if not key then return end
    local addon = _G.OneWoW_Notes
    if addon.db.global[self._dbKey] then addon.db.global[self._dbKey][key] = nil end
    if addon.db.char[self._dbKey] then addon.db.char[self._dbKey][key] = nil end
    self._cache = nil
end

function DataModule:GetCategories()
    local addon = _G.OneWoW_Notes
    local all = {}
    for _, c in ipairs(self._builtinCategories) do tinsert(all, c) end
    if self._categoryCustomKey and addon.db.global[self._categoryCustomKey] then
        for _, c in ipairs(addon.db.global[self._categoryCustomKey]) do tinsert(all, c) end
    end
    return all
end

function DataModule:EnsureDB()
    local addon = _G.OneWoW_Notes
    if not addon.db.global[self._dbKey] then addon.db.global[self._dbKey] = {} end
    if not addon.db.char[self._dbKey] then addon.db.char[self._dbKey] = {} end
end

function DataModule:MigrateColors(flagKey)
    local addon = _G.OneWoW_Notes
    if not addon.db or not addon.db.global then return end
    if addon.db.global[flagKey] then return end

    local migratedCount = 0
    local function migrateDB(db)
        if not db then return end
        for _, data in pairs(db) do
            if data and type(data) == "table" and data.pinColor == "hunter" and data.fontColor == "match" then
                data.pinColor = "sync"
                migratedCount = migratedCount + 1
            end
        end
    end

    migrateDB(addon.db.global[self._dbKey])
    migrateDB(addon.db.char[self._dbKey])

    addon.db.global[flagKey] = true
    if migratedCount > 0 then
        print("|cFF00FF00OneWoW_Notes|r: Migrated " .. migratedCount .. " " .. self._dbKey .. " to OneWoW Sync theme")
    end
end

function DataModule:MigrateFonts(flagKey)
    local addon = _G.OneWoW_Notes
    if not addon.db or not addon.db.global then return end
    if addon.db.global[flagKey] then return end

    local GUI = LibStub("OneWoW_GUI-1.0", true)
    if not GUI or not GUI.MigrateLSMFontName then
        addon.db.global[flagKey] = true
        return
    end

    local migratedCount = 0
    local function migrateDB(db)
        if not db then return end
        for _, data in pairs(db) do
            if data and type(data) == "table" and data.fontFamily then
                local newKey = GUI:MigrateLSMFontName(data.fontFamily)
                if newKey then
                    data.fontFamily = newKey
                    migratedCount = migratedCount + 1
                end
            end
        end
    end

    migrateDB(addon.db.global[self._dbKey])
    migrateDB(addon.db.char[self._dbKey])

    addon.db.global[flagKey] = true
    if migratedCount > 0 then
        print("|cFF00FF00OneWoW_Notes|r: Migrated " .. migratedCount .. " " .. self._dbKey .. " font(s) to new font system")
    end
end
