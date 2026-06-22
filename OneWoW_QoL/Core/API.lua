local _, ns = ...

local pairs = pairs

-- Public, cross-addon read surface for the QoL hub. ns stays private.
OneWoW_QoL_API = {}

--- Returns a registered external module table by id.
---@param moduleId string
---@return table|nil module
function OneWoW_QoL_API.GetModule(moduleId)
    if not ns.ModuleRegistry then return nil end
    return ns.ModuleRegistry:GetById(moduleId)
end

--- Whether a QoL module is enabled (saved override or module default).
---@param moduleId string
---@param defaultEnabled boolean|nil
---@return boolean
function OneWoW_QoL_API.IsModuleEnabled(moduleId, defaultEnabled)
    if not ns.db or not ns.ModuleRegistry then
        return defaultEnabled == true
    end
    local modData = ns.db.global.modules[moduleId]
    if modData and modData.enabled ~= nil then
        return modData.enabled
    end
    if defaultEnabled ~= nil then
        return defaultEnabled
    end
    return ns.ModuleRegistry:IsEnabled(moduleId)
end

--- Returns a module toggle value (saved override or toggle default).
---@param moduleId string
---@param toggleId string
---@param defaultValue boolean|nil
---@return boolean
function OneWoW_QoL_API.GetModuleToggle(moduleId, toggleId, defaultValue)
    if not ns.db or not ns.ModuleRegistry then
        return defaultValue ~= false
    end
    local modData = ns.db.global.modules[moduleId]
    if modData and modData.toggles and modData.toggles[toggleId] ~= nil then
        return modData.toggles[toggleId]
    end
    if defaultValue ~= nil then
        return defaultValue
    end
    return ns.ModuleRegistry:GetToggleValue(moduleId, toggleId)
end

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = type(v) == "table" and DeepCopy(v) or v
    end
    return dst
end

local function DeepMerge(dst, src)
    if type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            DeepMerge(dst[k], v)
        else
            dst[k] = v
        end
    end
end

--- Snapshot QoL global settings for profile export.
---@return table|nil snapshot
function OneWoW_QoL_API.CaptureProfileSettings()
    if not ns.db or not ns.db.global then return nil end
    local q = ns.db.global
    local snapshot = {
        language = q.language,
        theme    = q.theme,
        minimap  = DeepCopy(q.minimap),
        modules  = {},
    }
    if q.modules then
        for id, modData in pairs(q.modules) do
            snapshot.modules[id] = DeepCopy(modData)
        end
    end
    return snapshot
end

--- Apply a QoL profile snapshot produced by CaptureProfileSettings.
---@param snapshot table|nil
function OneWoW_QoL_API.ApplyProfileSettings(snapshot)
    if not snapshot or not ns.db or not ns.db.global then return end
    local q = ns.db.global
    if snapshot.language then q.language = snapshot.language end
    if snapshot.theme    then q.theme    = snapshot.theme    end
    if snapshot.minimap  then DeepMerge(q.minimap, snapshot.minimap) end
    if snapshot.modules then
        for id, modData in pairs(snapshot.modules) do
            if q.modules and q.modules[id] then
                DeepMerge(q.modules[id], modData)
            end
        end
    end
end

--- CVar entries from the QoL Toggles tab (for profile capture).
---@return table|nil list
function OneWoW_QoL_API.GetCVarList()
    if ns.GetCVarList then
        return ns.GetCVarList()
    end
    return nil
end
