-- OneWoW_GUI Database API
-- Stateless utility module. db handles are plain tables, not objects.
-- Design rationale: Docs/DATABASE.md
-- Comments in this file are for LLMs and humans and are to aid understanding without needing to read the full design document.
-- Do not remove comments.

local OneWoW_GUI = OneWoW_GUI

local GetOrCreateTableEntry, CopyTable = GetOrCreateTableEntry, CopyTable
local type, pairs, select, ipairs, error, tostring = type, pairs, select, ipairs, error, tostring
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

--- Canonical character key `"Name-RealmNoSpace"` (realm whitespace stripped).
--- Defaults to the current player when name/realm are omitted.
---@param name string|nil
---@param realm string|nil
---@return string|nil key nil if name or realm is missing/empty
function OneWoW_GUI:GetCharacterKey(name, realm)
    name = name or UnitName("player")
    realm = realm or GetRealmName()
    if not name or name == "" or not realm or realm == "" then return nil end
    realm = realm:gsub("%s", "")
    return name .. "-" .. realm
end

--- Canonical key for the current player. Convenience wrapper over
--- `GetCharacterKey`. Returns nil before unit/realm info is available.
---@return string|nil key
function OneWoW_GUI:BuildCharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return OneWoW_GUI:GetCharacterKey(name, realm)
end

--- Re-parses an arbitrary historical character key into the current canonical form.
--- Handles all three legacy shapes that exist in OneWoW SavedVariables:
---   "Name - Realm"           (AceDB-era, space-dash-space, realm spaces kept)
---   "Name-Realm With Space"  (early AceDB-compat layout, no padding, realm spaces kept)
---   "Name-RealmNoSpace"      (current GetCharacterKey, realm whitespace stripped)
--- Returns nil if the input cannot be parsed into a non-empty name+realm pair so
--- callers can safely skip metadata keys like "_migrated".
---@param charKey string|nil
---@return string|nil canonical
function OneWoW_GUI:CanonicalizeCharacterKey(charKey)
    if type(charKey) ~= "string" then return nil end
    local name, realm = charKey:match("^(.-)%s*-%s*(.+)$")
    if not name or not realm or name == "" or realm == "" then return nil end
    return OneWoW_GUI:GetCharacterKey(name, realm)
end

--- One-shot consolidation pass for a `[charKey] = data` style SavedVariables table.
--- Walks every entry, recomputes the canonical key, and merges payloads using
--- gap-fill semantics (canonical wins on scalar conflicts; old fills only where
--- canonical is nil). Naturally idempotent — a second call after every key is
--- canonical is a no-op. Non-table values (e.g. favorites `[charKey] = true`)
--- are handled as plain renames; if both old and canonical exist, canonical
--- wins and old is discarded.
--- Safe to call during InitializeDatabase; callers should still gate behind a
--- one-time flag for the perf cost on large character tables.
---@param charactersTable table|nil
---@return number migrated count of legacy keys remapped
function DB:ConsolidateCharacterKeys(charactersTable)
    if type(charactersTable) ~= "table" then return 0 end

    -- Snapshot keys before mutating; pairs() over a table that gains keys
    -- mid-iteration is undefined behavior in Lua 5.1.
    local oldKeys = {}
    for k in pairs(charactersTable) do oldKeys[#oldKeys + 1] = k end

    local migrated = 0
    for _, oldKey in ipairs(oldKeys) do
        local canonical = OneWoW_GUI:CanonicalizeCharacterKey(oldKey)
        if canonical and canonical ~= oldKey then
            local target = charactersTable[canonical]
            local old    = charactersTable[oldKey]
            if target == nil then
                charactersTable[canonical] = old
            elseif type(target) == "table" and type(old) == "table" then
                self:MergeMissing(target, old)
            end
            -- else: target is non-nil non-table (e.g. true); keep target, drop old
            charactersTable[oldKey] = nil
            migrated = migrated + 1
        end
    end

    return migrated
end

--- Variant of ConsolidateCharacterKeys for flat arrays of records whose
--- character identity lives in a named field (e.g. accounting transactions
--- keyed by tx.character). No merging — records are independent — just a
--- per-record key rewrite.
---@param recordsArray table|nil
---@param fieldName string field on each record holding the legacy charKey
---@return number rewritten count of records whose field was canonicalized
function DB:ConsolidateRecordCharacterField(recordsArray, fieldName)
    if type(recordsArray) ~= "table" or type(fieldName) ~= "string" then return 0 end

    local rewritten = 0
    for _, record in ipairs(recordsArray) do
        if type(record) == "table" then
            local canonical = OneWoW_GUI:CanonicalizeCharacterKey(record[fieldName])
            if canonical and canonical ~= record[fieldName] then
                record[fieldName] = canonical
                rewritten = rewritten + 1
            end
        end
    end
    return rewritten
end

local function GetIdentityKeys()
    local charKey = OneWoW_GUI:BuildCharKey()
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
---@param target table mutated in place
---@param defaults table template; table values are deep-copied, never shared
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

--- Safe path walk. Returns nil if any path segment is missing or non-table.
--- Does not allocate.
---@param db table
---@param ... any path keys
---@return any value
function DB:Read(db, ...)
    local current = db
    for i = 1, select("#", ...) do
        if type(current) ~= "table" then return nil end
        current = current[select(i, ...)]
        if current == nil then return nil end
    end
    return current
end

--- Walk a path, creating intermediate tables as needed. Errors (level 2) if an
--- existing intermediate value is not a table.
---@param db table
---@param ... any path keys
---@return table leaf the table at the end of the path
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

--- Write a value at a path, creating parent tables as needed. The value is the
--- LAST vararg; all preceding varargs are path keys. Use `DB:Delete` for nil
--- writes. Errors (level 2) on fewer than one key + one value, or a non-table
--- intermediate.
---@param db table
---@param ... any path keys followed by the value to store
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

--- Remove the final key on a path. No-op if the path does not resolve.
---@param db table
---@param ... any path keys; the last key is the one removed
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

-- Two storage modes:
--   split  — separate SavedVariables globals for global and per-char data
--   single — preferred: one shared root, char data at root.chars["Name-Realm"]
-- Both return the same normalized db shape. global and char are always
-- pre-created; other scopes (realm, faction, class, spec) are lazy-initialized.
--- Build a normalized db handle from a SavedVariables config.
--- After return, `db`, `db.global`, `db.char`, and every key in
--- `config.defaults` are guaranteed to exist. Other scopes (realm, faction,
--- class, spec) are lazy-initialized on first resolved access.
---@param config table { savedVar [, savedVarChar], defaults? } — `savedVar`
---  alone selects `single` mode; `savedVar` + `savedVarChar` selects `split`.
---@return table db normalized handle
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

    if config.savedVar and config.savedVarChar then
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
        error("DB:Init requires config.savedVar", 2)
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

local function TryResolveSpec(db)
    if db._specResolved then return end
    local specIndex = GetSpecialization()
    local specID = specIndex and GetSpecializationInfo(specIndex)
    if not specID then return end

    local specKey = tostring(specID)
    db._specResolved = true

    local storage = db._scopeStorage
    if not storage then return end

    if db._mode == "split" then
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
--- Resolve a single value across scopes (then the active preset). Returns the
--- value from the most specific scope that defines it. For scalar values; use
--- `GetResolvedTable` to assemble a merged table view.
---@param db table
---@param ... any path keys
---@return any value the resolved value, or nil if undefined in all scopes
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

--- Assemble a merged read-only table view across scopes (then the active
--- preset overlays last). Narrower scopes deep-merge over broader ones; the
--- result is a fresh copy, safe to read but not a live handle for writes.
---@param db table
---@param ... any path keys
---@return any result merged table (or scalar if the path resolves to one), nil if undefined
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

--- Write a value into one specific scope (not the resolved view). Value is the
--- LAST vararg, path keys precede it. Errors (level 2) on an invalid or
--- uninitialized scope, too few args, or a non-table intermediate.
---@param db table
---@param scope string a `DB.Scope.*` constant
---@param ... any path keys followed by the value to store
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

--- Write a value into a named preset overlay (created on first write). Value is
--- the LAST vararg, path keys precede it. Errors (level 2) on a missing preset
--- name, too few args, or a non-table intermediate.
---@param db table
---@param presetName string
---@param ... any path keys followed by the value to store
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

--- Set (or clear, with nil) the active preset overlay. Persists the choice to
--- storage so it survives reload. Only one preset is active at a time.
---@param db table
---@param presetName string|nil
function DB:SetActivePreset(db, presetName)
    db._activePreset = presetName

    if db._mode == "split" then
        if db._scopeStorage then
            db._scopeStorage._activePreset = presetName
        end
    elseif db._mode == "single" then
        if db.root then
            db.root._activePreset = presetName
        end
    end
end

-- Lightweight account-wide character store, separate from the scoped `Init`
-- handle: a flat `{ characters = { [charKey] = data } }` SavedVariable used by
-- data sub-addons that aggregate every character (e.g. AltTracker stores). The
-- store's shape is ensured by its `defaults` (merged via ns:BootStore at
-- load); stores read/write the live `_G[savedVarName]` global directly, and the
-- GetCharData/GetAllChars/DeleteChar helpers below operate on it by name.

--- Fetch (creating if absent) the per-character record in a sub-module store.
--- Omitting charKey defaults to the current character; an explicit charKey is
--- canonicalized (and validated) so a bad key — e.g. a numeric array index from
--- iterating GetAllCharacters incorrectly — resolves to nil and returns nil
--- instead of auto-vivifying a junk record. Returns nil if no character key
--- resolves or the store is uninitialized.
---@param savedVarName string
---@param charKey string|nil
---@return table|nil charData
function DB:GetCharData(savedVarName, charKey)
    if charKey == nil then
        charKey = OneWoW_GUI:GetCharacterKey()
    else
        charKey = OneWoW_GUI:CanonicalizeCharacterKey(charKey)
    end
    if not charKey then return nil end
    local sv = _G[savedVarName]
    if not sv or not sv.characters then return nil end
    if not sv.characters[charKey] then sv.characters[charKey] = {} end
    return sv.characters[charKey]
end

--- All characters in a sub-module store as `{ key, data }` entries, sorted
--- descending by `sortField` (default `lastUpdate`). Returns an empty table if
--- the store is uninitialized.
---@param savedVarName string
---@param sortField string|nil numeric field on each record to sort by
---@return { key: string, data: table }[] chars
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

--- Remove a character's record from a sub-module store. The charKey is
--- canonicalized (and validated) before lookup, so a missing or malformed key
--- returns false rather than touching the wrong record.
---@param savedVarName string
---@param charKey string
---@return boolean removed false if no key given or the store is uninitialized
function DB:DeleteChar(savedVarName, charKey)
    charKey = OneWoW_GUI:CanonicalizeCharacterKey(charKey)
    if not charKey then return false end
    local sv = _G[savedVarName]
    if not sv or not sv.characters then return false end
    sv.characters[charKey] = nil
    return true
end

-- Simple slash command registration without AceConsole.
-- Multiple commands can be registered by calling this multiple times.
---@param commandName string base name without the slash (e.g. "1wcat" → /1wcat)
---@param handler fun(msg: string) receives the argument string after the command
function DB:RegisterSlashCommand(commandName, handler)
    local upper = commandName:upper()
    local key = "ONEWOW_" .. upper
    _G["SLASH_" .. key .. "1"] = "/" .. commandName
    SlashCmdList[key] = handler
end
