-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/ModuleRegistry.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.ModuleRegistry = {}
local Registry = ns.ModuleRegistry

local modules = {}
local moduleOrder = {}

local VALID_CATEGORIES = {
    AUTOMATION = true,
    INTERFACE  = true,
    SOCIAL     = true,
    COMBAT     = true,
    ECONOMY    = true,
    UTILITY    = true,
}

local CATEGORY_ORDER = { "AUTOMATION", "INTERFACE", "SOCIAL", "COMBAT", "ECONOMY", "UTILITY" }

function Registry:Register(moduleData)
    if not moduleData or not moduleData.id then return end
    if not moduleData.category or not VALID_CATEGORIES[moduleData.category] then
        moduleData.category = "UTILITY"
    end
    if modules[moduleData.id] then return end
    modules[moduleData.id] = moduleData
    table.insert(moduleOrder, moduleData.id)
end

function Registry:GetAll()
    local result = {}
    for _, id in ipairs(moduleOrder) do
        table.insert(result, modules[id])
    end
    return result
end

function Registry:GetById(moduleId)
    return modules[moduleId]
end

function Registry:GetByCategory(category)
    local result = {}
    for _, id in ipairs(moduleOrder) do
        if modules[id].category == category then
            table.insert(result, modules[id])
        end
    end
    return result
end

function Registry:GetCategories()
    return CATEGORY_ORDER
end

function Registry:HasModules()
    return #moduleOrder > 0
end

function Registry:IsEnabled(moduleId)
    local addon = _G.OneWoW_QoL
    if addon and addon.db and addon.db.global.modules then
        local modData = addon.db.global.modules[moduleId]
        if modData and modData.enabled ~= nil then
            return modData.enabled
        end
    end
    local mod = modules[moduleId]
    if mod and mod.defaultEnabled ~= nil then
        return mod.defaultEnabled
    end
    return false
end

function Registry:SetEnabled(moduleId, enabled)
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db or not addon.db.global.modules then return end
    if not addon.db.global.modules[moduleId] then
        addon.db.global.modules[moduleId] = {}
    end
    addon.db.global.modules[moduleId].enabled = enabled
    local mod = modules[moduleId]
    if mod then
        if enabled and mod.OnEnable then
            mod:OnEnable()
        elseif not enabled and mod.OnDisable then
            mod:OnDisable()
        end
    end
end

function Registry:GetToggleValue(moduleId, toggleId)
    local addon = _G.OneWoW_QoL
    if addon and addon.db and addon.db.global.modules then
        local modData = addon.db.global.modules[moduleId]
        if modData and modData.toggles and modData.toggles[toggleId] ~= nil then
            return modData.toggles[toggleId]
        end
    end
    local mod = modules[moduleId]
    if mod and mod.toggles then
        for _, t in ipairs(mod.toggles) do
            if t.id == toggleId then
                return t.default
            end
        end
    end
    return false
end

function Registry:SetToggleValue(moduleId, toggleId, value)
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db or not addon.db.global.modules then return end
    if not addon.db.global.modules[moduleId] then
        addon.db.global.modules[moduleId] = {}
    end
    if not addon.db.global.modules[moduleId].toggles then
        addon.db.global.modules[moduleId].toggles = {}
    end
    addon.db.global.modules[moduleId].toggles[toggleId] = value
    local mod = modules[moduleId]
    if mod and mod.OnToggle then
        mod:OnToggle(toggleId, value)
    end
end
