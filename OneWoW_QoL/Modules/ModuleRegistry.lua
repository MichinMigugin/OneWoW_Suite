local _, ns = ...

ns.ModuleRegistry = {}
local Registry = ns.ModuleRegistry

local modules = {}
local moduleOrder = {}

-- Transient pointer to the module whose files are currently loading. Set by Define()
-- (called from each module's module.lua -- the first file in its TOC block) and read
-- once via Current() at the top of that module's other files. It is NOT exposed on
-- `ns`, so it cannot be misread at runtime: capture what you need into a file-local
-- at load time.
local loading

local VALID_CATEGORIES = {
    AUTOMATION = true,
    INTERFACE  = true,
    SOCIAL     = true,
    COMBAT     = true,
    ECONOMY    = true,
    UTILITY    = true,
}

local CATEGORY_ORDER = { "AUTOMATION", "INTERFACE", "SOCIAL", "COMBAT", "ECONOMY", "UTILITY" }

-- Empty module.lua author = team credit and copyright (LICENSE.md).
local TEAM_AUTHOR = "OneWoW Development Team"

-- Module SDK entry point. Called from <module>/module.lua (the FIRST file in the
-- module's TOC block). Derives the module's locale scope (ADDON_NAME .. "." .. id),
-- caches its read-only locale view, marks it as the currently-loading module, and
-- registers it. The module's other files retrieve it via Current().
function Registry:Define(addonName, def)
    def._scope = addonName .. "." .. def.id
    def._view  = OneWoW.Locale:GetTable(def._scope)
    loading    = def
    self:Register(def)
    return def
end

-- Returns the currently-loading module and its locale view. Call ONCE at the top of
-- each of a module's files (locale + code), after its module.lua has run, and capture
-- the results into file-locals. Do not call at runtime.
function Registry:Current()
    return loading, loading and loading._view
end

function Registry:Register(moduleData)
    if not moduleData or not moduleData.id then return end
    if not moduleData.category or not VALID_CATEGORIES[moduleData.category] then
        moduleData.category = "UTILITY"
    end
    if type(moduleData.author) ~= "string" or moduleData.author == "" then
        moduleData.author = TEAM_AUTHOR
    end
    if modules[moduleData.id] then return end
    modules[moduleData.id] = moduleData
    table.insert(moduleOrder, moduleData.id)
    OneWoW.SearchRegistry:RegisterQoLModule(moduleData)
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

--- Returns the per-module SavedVariables bucket at ns.db.global.modules[moduleId],
--- creating an empty table if missing. Registry-owned keys (enabled, toggles) and
--- module-owned keys share this bucket.
---@param moduleId string
---@return table bucket
function Registry:GetModuleBucket(moduleId)
    if not ns.db.global.modules[moduleId] then
        ns.db.global.modules[moduleId] = {}
    end
    return ns.db.global.modules[moduleId]
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
    local modData = ns.db.global.modules[moduleId]
    if modData and modData.enabled ~= nil then
        return modData.enabled
    end
    local mod = modules[moduleId]
    if mod and mod.defaultEnabled ~= nil then
        return mod.defaultEnabled
    end
    return false
end

function Registry:SetEnabled(moduleId, enabled)
    if not ns.db.global.modules[moduleId] then
        ns.db.global.modules[moduleId] = {}
    end
    ns.db.global.modules[moduleId].enabled = enabled
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
    local modData = ns.db.global.modules[moduleId]
    if modData and modData.toggles and modData.toggles[toggleId] ~= nil then
        return modData.toggles[toggleId]
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
    if not ns.db.global.modules[moduleId] then
        ns.db.global.modules[moduleId] = {}
    end
    if not ns.db.global.modules[moduleId].toggles then
        ns.db.global.modules[moduleId].toggles = {}
    end
    ns.db.global.modules[moduleId].toggles[toggleId] = value
    local mod = modules[moduleId]
    if mod and mod.OnToggle then
        mod:OnToggle(toggleId, value)
    end
end
