-- OneWoW_GUI Database API
-- Stateless utility module. db handles are plain tables, not objects.
-- Design rationale: Docs/DATABASE.md
-- Comments in this file are for LLMs and humans and are to aid understanding without needing to read the full design document.
-- Do not remove comments.

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local GetOrCreateTableEntry, CopyTable = GetOrCreateTableEntry, CopyTable
local type, pairs, select, ipairs, error, tostring, pcall = type, pairs, select, ipairs, error, tostring, pcall
local UnitName, UnitClass, GetRealmName, UnitFactionGroup = UnitName, UnitClass, GetRealmName, UnitFactionGroup
local GetSpecialization, GetSpecializationInfo = C_SpecializationInfo.GetSpecialization, C_SpecializationInfo.GetSpecializationInfo

local DB = {}
OneWoW_GUI.DB = DB

DB.Scope = {
    Global  = "global",
    Realm   = "realm",
    Faction = "faction",
    Class   = "class",
    Spec    = "spec",
    Char    = "char",
}

DB.ScopePriority = {
    DB.Scope.Global,
    DB.Scope.Realm,
    DB.Scope.Faction,
    DB.Scope.Class,
    DB.Scope.Spec,
    DB.Scope.Char,
}

local VALID_SCOPES = {}
for _, v in ipairs(DB.ScopePriority) do
    VALID_SCOPES[v] = true
end


local function BuildCharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if not name or not realm or realm == "" then return nil end
    return name .. "-" .. realm
end

local function GetIdentityKeys()
    local charKey = BuildCharKey()
    local realm = GetRealmName()
    local faction = UnitFactionGroup("player")
    local _, classToken = UnitClass("player")
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    return charKey, realm, faction, classToken, specID and tostring(specID) or nil
end

-- Fill-only semantics: only nil keys receive default values. Existing user data
-- is never overwritten. This replaces every addon's custom ApplyDefaults,
-- mergeSubTable, and nil-check chains. Blizzard's MergeTable overwrites and
-- SetTablePairsToTable wipes — both are wrong for SavedVariable initialization.
function DB:MergeMissing(target, defaults)
    if type(target) ~= "table" or type(defaults) ~= "table" then return end
    for key, defaultValue in pairs(defaults) do
        local currentValue = target[key]
        if currentValue == nil then
            if type(defaultValue) == "table" then
                target[key] = CopyTable(defaultValue)
            else
                target[key] = defaultValue
            end
        elseif type(currentValue) == "table" and type(defaultValue) == "table" then
            self:MergeMissing(currentValue, defaultValue)
        end
    end
end

function DB:Read(db, ...)
    local current = db
    for i = 1, select("#", ...) do
        if type(current) ~= "table" then return nil end
        current = current[select(i, ...)]
        if current == nil then return nil end
    end
    return current
end

function DB:Ensure(db, ...)
    local current = db
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if type(current) ~= "table" then
            error("DB:Ensure hit non-table at key " .. tostring(key), 2)
        end
        current = GetOrCreateTableEntry(current, key)
    end
    return current
end

function DB:Set(db, ...)
    local n = select("#", ...)
    if n < 2 then
        error("DB:Set requires at least one key and one value", 2)
    end
    local value = select(n, ...)
    local current = db
    for i = 1, n - 2 do
        local key = select(i, ...)
        if current[key] == nil then
            current[key] = {}
        elseif type(current[key]) ~= "table" then
            error("DB:Set hit non-table at key " .. tostring(key), 2)
        end
        current = current[key]
    end
    current[select(n - 1, ...)] = value
end

function DB:Delete(db, ...)
    local n = select("#", ...)
    if n < 1 then return end
    local current = db
    for i = 1, n - 1 do
        if type(current) ~= "table" then return end
        current = current[select(i, ...)]
        if current == nil then return end
    end
    if type(current) == "table" then
        current[select(n, ...)] = nil
    end
end

local function EnsureScopeTable(storage, storageKey, identityKey)
    if not storageKey or not identityKey then return nil end
    if not storage[storageKey] then
        storage[storageKey] = {}
    end
    if not storage[storageKey][identityKey] then
        storage[storageKey][identityKey] = {}
    end
    return storage[storageKey][identityKey]
end

-- Three storage modes for compatibility during incremental migration:
--   acedb  — wraps an existing AceDB handle (global/char come from AceDB)
--   split  — separate SavedVariables globals for global and per-char data
--   single — preferred: one shared root, char data at root.chars["Name-Realm"]
-- All three return the same normalized db shape. global and char are always
-- pre-created; other scopes (realm, faction, class, spec) are lazy-initialized.
function DB:Init(config)
    if type(config) ~= "table" then
        error("DB:Init requires a config table", 2)
    end

    local charKey, realm, faction, classToken, specKey = GetIdentityKeys()
    local db = {
        global         = nil,
        char           = nil,
        root           = nil,
        currentCharKey = charKey,
        _addonName     = config.addonName,
        _scopes        = {},
        _presets        = nil,
        _activePreset  = nil,
        _specResolved  = specKey ~= nil,
        _mode          = nil,
        _savedVarName  = nil,
    }

    if config.aceDB then
        db._mode = "acedb"
        local acedb = config.aceDB
        db.global = acedb.global or {}
        db.char   = acedb.char or {}

        if not db.global._scopes then db.global._scopes = {} end
        local scopeStore = db.global._scopes

        db._scopes[DB.Scope.Global] = db.global
        db._scopes[DB.Scope.Char]   = db.char

        if realm then
            db._scopes[DB.Scope.Realm] = EnsureScopeTable(scopeStore, "realms", realm)
        end
        if faction then
            db._scopes[DB.Scope.Faction] = EnsureScopeTable(scopeStore, "factions", faction)
        end
        if classToken then
            db._scopes[DB.Scope.Class] = EnsureScopeTable(scopeStore, "classes", classToken)
        end
        if specKey then
            db._scopes[DB.Scope.Spec] = EnsureScopeTable(scopeStore, "specs", specKey)
        end

        if not db.global._presets then db.global._presets = {} end
        db._presets = db.global._presets
        db._activePreset = db.global._activePreset

        db._scopeStorage = scopeStore

    elseif config.savedVar and config.savedVarChar then
        db._mode = "split"
        db._savedVarName = config.savedVar

        if not _G[config.savedVar] then _G[config.savedVar] = {} end
        local globalRoot = _G[config.savedVar]
        db.root   = globalRoot
        db.global = globalRoot

        if not _G[config.savedVarChar] then _G[config.savedVarChar] = {} end
        db.char = _G[config.savedVarChar]

        db._scopes[DB.Scope.Global] = db.global
        db._scopes[DB.Scope.Char]   = db.char

        if realm then
            db._scopes[DB.Scope.Realm] = EnsureScopeTable(globalRoot, "_realms", realm)
        end
        if faction then
            db._scopes[DB.Scope.Faction] = EnsureScopeTable(globalRoot, "_factions", faction)
        end
        if classToken then
            db._scopes[DB.Scope.Class] = EnsureScopeTable(globalRoot, "_classes", classToken)
        end
        if specKey then
            db._scopes[DB.Scope.Spec] = EnsureScopeTable(globalRoot, "_specs", specKey)
        end

        if not globalRoot._presets then globalRoot._presets = {} end
        db._presets = globalRoot._presets
        db._activePreset = globalRoot._activePreset

        db._scopeStorage = globalRoot

    elseif config.savedVar then
        db._mode = "single"
        db._savedVarName = config.savedVar

        if not _G[config.savedVar] then _G[config.savedVar] = {} end
        local root = _G[config.savedVar]
        db.root = root

        if not root.global then root.global = {} end
        db.global = root.global

        if not root.chars then root.chars = {} end
        if charKey then
            if not root.chars[charKey] then root.chars[charKey] = {} end
            db.char = root.chars[charKey]
        else
            db.char = {}
        end

        db._scopes[DB.Scope.Global] = db.global
        db._scopes[DB.Scope.Char]   = db.char

        if realm then
            db._scopes[DB.Scope.Realm] = EnsureScopeTable(root, "realms", realm)
        end
        if faction then
            db._scopes[DB.Scope.Faction] = EnsureScopeTable(root, "factions", faction)
        end
        if classToken then
            db._scopes[DB.Scope.Class] = EnsureScopeTable(root, "classes", classToken)
        end
        if specKey then
            db._scopes[DB.Scope.Spec] = EnsureScopeTable(root, "specs", specKey)
        end

        if not root.presets then root.presets = {} end
        db._presets = root.presets
        db._activePreset = root._activePreset

        db._scopeStorage = root

    else
        error("DB:Init requires config.savedVar or config.aceDB", 2)
    end

    local defaults = config.defaults
    if defaults then
        if defaults.global then
            self:MergeMissing(db.global, defaults.global)
        end
        if defaults.char then
            self:MergeMissing(db.char, defaults.char)
        end
    end

    return db
end

function DB:RunMigrations(db, migrations)
    local g = db.global
    local currentVersion = g._migrationVersion or 0
    for _, step in ipairs(migrations) do
        if step.version > currentVersion then
            local ok, err = pcall(step.run, db)
            if not ok then
                error("DB:RunMigrations failed at version " .. step.version
                      .. " (" .. (step.name or "unnamed") .. "): " .. tostring(err), 2)
            end
            g._migrationVersion = step.version
            currentVersion = step.version
        end
    end
end

local function TryResolveSpec(db)
    if db._specResolved then return end
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    if not specID then return end

    local specKey = tostring(specID)
    db._specResolved = true

    local storage = db._scopeStorage
    if not storage then return end

    if db._mode == "acedb" then
        db._scopes[DB.Scope.Spec] = EnsureScopeTable(storage, "specs", specKey)
    elseif db._mode == "split" then
        db._scopes[DB.Scope.Spec] = EnsureScopeTable(storage, "_specs", specKey)
    elseif db._mode == "single" then
        db._scopes[DB.Scope.Spec] = EnsureScopeTable(storage, "specs", specKey)
    end
end

local function WalkPath(root, ...)
    local current = root
    for i = 1, select("#", ...) do
        if type(current) ~= "table" then return nil end
        current = current[select(i, ...)]
        if current == nil then return nil end
    end
    return current
end

-- Scope resolution: Global -> Realm -> Faction -> Class -> Spec -> Char.
-- Later scopes override earlier ones, so Char is the most specific identity
-- override. Presets overlay last because they represent mode (gathering, travel)
-- not identity. Resolved values are read-only snapshots; writes go through
-- SetScopeValue or SetPresetValue.
function DB:GetResolvedValue(db, ...)
    TryResolveSpec(db)

    local resolved = nil
    for _, scope in ipairs(DB.ScopePriority) do
        local scopeTable = db._scopes[scope]
        if scopeTable then
            local val = WalkPath(scopeTable, ...)
            if val ~= nil then
                resolved = val
            end
        end
    end

    local presetName = db._activePreset
    if presetName and db._presets and db._presets[presetName] then
        local presetVal = WalkPath(db._presets[presetName], ...)
        if presetVal ~= nil then
            resolved = presetVal
        end
    end

    return resolved
end

local function MergeOver(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" and type(target[k]) == "table" then
            MergeOver(target[k], v)
        else
            if type(v) == "table" then
                target[k] = CopyTable(v)
            else
                target[k] = v
            end
        end
    end
end

function DB:GetResolvedTable(db, ...)
    TryResolveSpec(db)

    local result = nil
    for _, scope in ipairs(DB.ScopePriority) do
        local scopeTable = db._scopes[scope]
        if scopeTable then
            local val = WalkPath(scopeTable, ...)
            if val ~= nil then
                if type(val) == "table" then
                    if not result then
                        result = CopyTable(val)
                    else
                        MergeOver(result, val)
                    end
                else
                    result = val
                end
            end
        end
    end

    local presetName = db._activePreset
    if presetName and db._presets and db._presets[presetName] then
        local presetVal = WalkPath(db._presets[presetName], ...)
        if presetVal ~= nil then
            if type(presetVal) == "table" then
                if not result then
                    result = CopyTable(presetVal)
                elseif type(result) == "table" then
                    MergeOver(result, presetVal)
                else
                    result = CopyTable(presetVal)
                end
            else
                result = presetVal
            end
        end
    end

    return result
end

function DB:SetScopeValue(db, scope, ...)
    local n = select("#", ...)
    if n < 2 then
        error("DB:SetScopeValue requires at least one key and one value", 2)
    end
    if not VALID_SCOPES[scope] then
        error("DB:SetScopeValue invalid scope: " .. tostring(scope), 2)
    end

    local scopeTable = db._scopes[scope]
    if not scopeTable then
        error("DB:SetScopeValue scope not initialized: " .. tostring(scope), 2)
    end

    local value = select(n, ...)
    local current = scopeTable
    for i = 1, n - 2 do
        local key = select(i, ...)
        if current[key] == nil then
            current[key] = {}
        elseif type(current[key]) ~= "table" then
            error("DB:SetScopeValue hit non-table at key " .. tostring(key), 2)
        end
        current = current[key]
    end
    current[select(n - 1, ...)] = value
end

function DB:SetPresetValue(db, presetName, ...)
    local n = select("#", ...)
    if n < 2 then
        error("DB:SetPresetValue requires at least one key and one value", 2)
    end
    if not presetName then
        error("DB:SetPresetValue requires a preset name", 2)
    end

    if not db._presets[presetName] then
        db._presets[presetName] = {}
    end
    local current = db._presets[presetName]
    local value = select(n, ...)

    for i = 1, n - 2 do
        local key = select(i, ...)
        if current[key] == nil then
            current[key] = {}
        elseif type(current[key]) ~= "table" then
            error("DB:SetPresetValue hit non-table at key " .. tostring(key), 2)
        end
        current = current[key]
    end
    current[select(n - 1, ...)] = value
end

function DB:SetActivePreset(db, presetName)
    db._activePreset = presetName

    if db._mode == "acedb" then
        db.global._activePreset = presetName
    elseif db._mode == "split" then
        if db._scopeStorage then
            db._scopeStorage._activePreset = presetName
        end
    elseif db._mode == "single" then
        if db.root then
            db.root._activePreset = presetName
        end
    end
end

function DB:InitSubModule(savedVarName)
    if not _G[savedVarName] then _G[savedVarName] = {} end
    local sv = _G[savedVarName]
    if not sv.characters then sv.characters = {} end
    if not sv.version then sv.version = 1 end
    return sv
end

function DB:GetCharData(savedVarName, charKey)
    charKey = charKey or OneWoW_GUI:GetCharacterKey()
    if not charKey then return nil end
    local sv = _G[savedVarName]
    if not sv or not sv.characters then return nil end
    if not sv.characters[charKey] then sv.characters[charKey] = {} end
    return sv.characters[charKey]
end

function DB:GetAllChars(savedVarName, sortField)
    local sv = _G[savedVarName]
    if not sv or not sv.characters then return {} end
    local chars = {}
    for charKey, data in pairs(sv.characters) do
        chars[#chars + 1] = { key = charKey, data = data }
    end
    sortField = sortField or "lastUpdate"
    table.sort(chars, function(a, b)
        return (a.data[sortField] or 0) > (b.data[sortField] or 0)
    end)
    return chars
end

function DB:DeleteChar(savedVarName, charKey)
    if not charKey then return false end
    local sv = _G[savedVarName]
    if not sv or not sv.characters then return false end
    sv.characters[charKey] = nil
    return true
end

function DB:BootSubModule(ns, config)
    local addonName = config.addonName
    local savedVar = config.savedVar
    local onLogin = config.onLogin
    local defaults = config.defaults
    local initDB = config.initDB

    ns.AddonInitialized = false

    if config.withScanCallbacks then
        local scanCallbacks = {}
        ns.RegisterScanCallback = function(self, fn)
            scanCallbacks[#scanCallbacks + 1] = fn
        end
        ns.FireScanCallbacks = function(self, data)
            for _, fn in ipairs(scanCallbacks) do
                pcall(fn, data)
            end
        end
    end

    ns.GetCharacterKey = function(self)
        return OneWoW_GUI:GetCharacterKey()
    end
    ns.GetCharacterData = function(self, charKey)
        return DB:GetCharData(savedVar, charKey)
    end
    ns.GetAllCharacters = function(self)
        return DB:GetAllChars(savedVar, config.sortField)
    end
    ns.DeleteCharacter = function(self, charKey)
        return DB:DeleteChar(savedVar, charKey)
    end

    ns.GetDB = function(self)
        return _G[savedVar]
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("ADDON_LOADED")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "ADDON_LOADED" then
            local loaded = ...
            if loaded == addonName then
                if savedVar then
                    if not _G[savedVar] then _G[savedVar] = {} end
                    if defaults then
                        DB:MergeMissing(_G[savedVar], defaults)
                    end
                end
                if initDB then
                    initDB()
                elseif ns.InitializeDatabase then
                    ns:InitializeDatabase()
                end
            end
        elseif event == "PLAYER_LOGIN" then
            ns.AddonInitialized = true
            if onLogin then onLogin() end
        end
    end)
end

-- Simple slash command registration without AceConsole.
-- commandName is the base name (e.g., "owcat"), handler receives the msg string.
-- Multiple commands can be registered by calling this multiple times.
function DB:RegisterSlashCommand(commandName, handler)
    local upper = commandName:upper()
    local key = "ONEWOW_" .. upper
    _G["SLASH_" .. key .. "1"] = "/" .. commandName
    SlashCmdList[key] = handler
end

-- Factory for item data loading with async callback queue.
-- Eliminates per-addon DataLoader duplication. Pass the addon's DB table
-- (the one with an itemCache sub-table). Returns a loader object.
function OneWoW_GUI:CreateItemDataLoader(dbTable)
    if not dbTable then error("CreateItemDataLoader requires a dbTable", 2) end

    local loader = { _db = dbTable, _pending = {} }

    function loader:GetCachedItem(itemID)
        if self._db.itemCache and self._db.itemCache[itemID] then
            return self._db.itemCache[itemID]
        end
        return nil
    end

    function loader:CacheItem(itemID, name, quality, icon, link)
        if not self._db.itemCache then self._db.itemCache = {} end
        self._db.itemCache[itemID] = {
            name    = name,
            quality = quality or 1,
            icon    = icon or 134400,
            link    = link,
        }
    end

    function loader:LoadItemData(itemID, callback)
        local cached = self:GetCachedItem(itemID)
        if cached and cached.name then
            if callback then callback(itemID, cached) end
            return cached
        end

        local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)
        if name then
            self:CacheItem(itemID, name, quality, icon, link)
            local result = self:GetCachedItem(itemID)
            if callback then callback(itemID, result) end
            return result
        end

        C_Item.RequestLoadItemDataByID(itemID)
        if not self._pending[itemID] then
            self._pending[itemID] = {}
        end
        if callback then
            self._pending[itemID][#self._pending[itemID] + 1] = callback
        end
        return nil
    end

    function loader:Initialize()
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
        frame:SetScript("OnEvent", function(_, _, loadedItemID, success)
            if not success then return end
            local callbacks = self._pending[loadedItemID]
            if not callbacks then return end
            local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(loadedItemID)
            if name then
                self:CacheItem(loadedItemID, name, quality, icon, link)
                local result = self:GetCachedItem(loadedItemID)
                for _, cb in ipairs(callbacks) do
                    pcall(cb, loadedItemID, result)
                end
            end
            self._pending[loadedItemID] = nil
        end)
    end

    return loader
end
