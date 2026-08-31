-- ============================================================================
-- SettingsFeatureRegistry
-- ============================================================================
-- Core service with three responsibilities:
--   Catalog      — Register/GetByTab feature metadata for the settings GUI.
--   Storage path — resolves (tabName, featureId) through the settingsTab /
--                  settingsId mirror protocol (a feature registered on one tab
--                  can store its state under another, e.g.
--                  tooltips/gearupgrades -> overlays/upgrade), then delegates
--                  all reads/writes to OneWoW_GUI.DB primitives.
--   Notification — mutators fire registered listeners with storage-resolved
--                  coordinates; engines subscribe (no engine calls here).
--
-- This is the only file (besides Core/Database.lua defaults/init bridges) that
-- may touch ns.db.global.settings directly.
--
-- GetFeatureSettings returns the LIVE storage table for multi-key reads on
-- hot paths. It is READ-ONLY by contract: all writes go through SetEnabled /
-- SetSetting / SetOverlaySetting / SetIntegrationEnabled so listeners fire.
-- ============================================================================

local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

local tinsert = tinsert
local ipairs, pairs, wipe, type = ipairs, pairs, wipe, type

---@class SettingsFeatureEntry
---@field id string unique feature id within its tab
---@field title string localization key for the feature title
---@field description string|nil localization key for the feature description
---@field settingsTab string|nil mirror protocol: storage tab override
---@field settingsId string|nil mirror protocol: storage id override

---@class SettingsFeatureRegistry
ns.SettingsFeatureRegistry = {}
local reg = ns.SettingsFeatureRegistry
local featuresByTab = {}

---@type table<string, fun(storageTab: string, storageId: string|nil, key: string|nil, value: any)>
local listeners = {}

-- Nil-safe until step 8 moves Core/Database.lua to OneWoW_GUI.DB:Init; after
-- that this becomes a direct ns.db.global.settings access.
---@return table|nil
local function GetSettingsDB()
    return DB:Read(ns.db, "global", "settings")
end

-- Resolves a (tabName, featureId) through any registered settingsTab/settingsId
-- override on the feature data, so a feature registered on one tab can fully
-- mirror another tab's stored state (e.g. tooltips/gearupgrades -> overlays/upgrade).
---@param tabName string
---@param featureId string
---@return string storageTab
---@return string storageId
local function ResolveStorage(tabName, featureId)
    local list = featuresByTab[tabName]
    if list then
        for _, f in ipairs(list) do
            if f.id == featureId then
                return (f.settingsTab or tabName), (f.settingsId or f.id)
            end
        end
    end
    return tabName, featureId
end

-- Bulk events (ResetTab) pass nil storageId/key. Listener order is undefined;
-- handlers must be order-independent.
---@param storageTab string
---@param storageId string|nil
---@param key string|nil
---@param value any
local function Notify(storageTab, storageId, key, value)
    for _, fn in pairs(listeners) do
        fn(storageTab, storageId, key, value)
    end
end

--- Subscribe to settings mutations. The callback receives storage-resolved
--- coordinates (mirror writes report their storage tab, not the GUI tab).
--- Bulk changes (ResetTab) fire with nil storageId/key/value.
---@param id string unique listener id (re-registering replaces)
---@param fn fun(storageTab: string, storageId: string|nil, key: string|nil, value: any)
function reg:RegisterListener(id, fn)
    listeners[id] = fn
end

--- Add a feature to the settings catalog for a GUI tab.
---@param tabName string
---@param featureData SettingsFeatureEntry
function reg:Register(tabName, featureData)
    featuresByTab[tabName] = featuresByTab[tabName] or {}
    tinsert(featuresByTab[tabName], featureData)
    ns.SearchRegistry:RegisterFeature(tabName, featureData)
end

--- Sorted copy of a tab's catalog ("general" first). Allocates a new table;
--- not for hot paths.
---@param tabName string
---@return SettingsFeatureEntry[]
function reg:GetByTab(tabName)
    local list = featuresByTab[tabName] or {}
    local sorted = {}
    for _, f in ipairs(list) do
        if f.id == "general" then
            tinsert(sorted, 1, f)
        else
            tinsert(sorted, f)
        end
    end
    return sorted
end

--- Whether a feature's enable toggle is on. Missing entries read as disabled.
---@param tabName string
---@param featureId string
---@return boolean
function reg:IsEnabled(tabName, featureId)
    local settings = GetSettingsDB()
    if not settings then return false end
    local storageTab, storageId = ResolveStorage(tabName, featureId)
    return DB:Read(settings, storageTab, storageId, "enabled") == true
end

--- Set a feature's enable toggle. No-op (no write, no notification) when the
--- enabled state would not change.
---@param tabName string
---@param featureId string
---@param value boolean
function reg:SetEnabled(tabName, featureId, value)
    local settings = GetSettingsDB()
    if not settings then return end
    if self:IsEnabled(tabName, featureId) == (value == true) then return end
    local storageTab, storageId = ResolveStorage(tabName, featureId)
    DB:Set(settings, storageTab, storageId, "enabled", value)
    Notify(storageTab, storageId, "enabled", value)
end

--- Read a single setting key for a feature.
---@param tabName string
---@param featureId string
---@param key string
---@return any
function reg:GetSetting(tabName, featureId, key)
    local settings = GetSettingsDB()
    if not settings then return nil end
    local storageTab, storageId = ResolveStorage(tabName, featureId)
    return DB:Read(settings, storageTab, storageId, key)
end

--- Write a single setting key for a feature and notify listeners.
--- Scalar writes early-return when the value is unchanged. Table values are
--- always written and notified: pass a NEW table, not a mutated table obtained
--- from GetFeatureSettings (identity comparison cannot detect in-place edits).
---@param tabName string
---@param featureId string
---@param key string
---@param value any
function reg:SetSetting(tabName, featureId, key, value)
    local settings = GetSettingsDB()
    if not settings then return end
    local storageTab, storageId = ResolveStorage(tabName, featureId)
    if type(value) ~= "table" and DB:Read(settings, storageTab, storageId, key) == value then return end
    DB:Set(settings, storageTab, storageId, key, value)
    Notify(storageTab, storageId, key, value)
end

--- Live storage table for a feature, for multi-key reads on hot paths
--- (tooltip providers, overlay paint). READ-ONLY by contract — all writes go
--- through the Set* mutators so listeners fire.
--- Pre-DB-init fallback returns an empty table (removed at step 8).
---@param tabName string
---@param featureId string
---@return table
function reg:GetFeatureSettings(tabName, featureId)
    local settings = GetSettingsDB()
    if not settings then return {} end
    local storageTab, storageId = ResolveStorage(tabName, featureId)
    return DB:Ensure(settings, storageTab, storageId)
end

--- Whether a bag-addon overlay integration is enabled. Entries are guaranteed
--- by the defaults table (Core/Database.lua settings.overlays.integrations).
---@param integrationKey string e.g. "onewow_bags", "bagnon", "elvui"
---@return boolean
function reg:IsIntegrationEnabled(integrationKey)
    local settings = GetSettingsDB()
    if not settings then return false end
    return DB:Read(settings, "overlays", "integrations", integrationKey, "enabled") == true
end

--- Set a bag-addon overlay integration's enabled state and notify listeners.
---@param integrationKey string
---@param value boolean
function reg:SetIntegrationEnabled(integrationKey, value)
    local settings = GetSettingsDB()
    if not settings then return end
    if (DB:Read(settings, "overlays", "integrations", integrationKey, "enabled") == true) == (value == true) then return end
    DB:Set(settings, "overlays", "integrations", integrationKey, "enabled", value)
    Notify("overlays", "integrations", integrationKey, value)
end

--- Read one key of an overlay feature (thin wrapper over GetSetting).
---@param featureId string
---@param key string
---@return any
function reg:GetOverlaySetting(featureId, key)
    return self:GetSetting("overlays", featureId, key)
end

--- Write one key of an overlay feature (thin wrapper over SetSetting).
---@param featureId string
---@param key string
---@param value any
function reg:SetOverlaySetting(featureId, key, value)
    self:SetSetting("overlays", featureId, key, value)
end

--- Reset a whole settings tab to its shipped defaults, then fire a bulk
--- notification (nil storageId/key). Callers wanting to preserve specific
--- values re-apply them via Set* afterward.
---@param tabName string
function reg:ResetTab(tabName)
    local settings = GetSettingsDB()
    if not settings then return end
    local tab = DB:Ensure(settings, tabName)
    wipe(tab)
    DB:MergeMissing(tab, ns:GetSettingsDefaults(tabName))
    Notify(tabName, nil, nil, nil)
end
