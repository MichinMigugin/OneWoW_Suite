local ADDON_NAME, OneWoW = ...

OneWoW.ModuleRegistry = {}
local Registry = OneWoW.ModuleRegistry

local registeredModules = {}
local registeredSettingsPanels = {}

function OneWoW:RegisterModule(moduleInfo)
    if not moduleInfo or not moduleInfo.name then return end
    if registeredModules[moduleInfo.name] then return end

    registeredModules[moduleInfo.name] = {
        name = moduleInfo.name,
        displayName = moduleInfo.displayName or moduleInfo.name,
        addonName = moduleInfo.addonName or "",
        order = moduleInfo.order or 99,
        tabs = moduleInfo.tabs or {},
    }
end

function Registry:GetModules()
    local sorted = {}
    for _, mod in pairs(registeredModules) do
        table.insert(sorted, mod)
    end
    table.sort(sorted, function(a, b) return a.order < b.order end)
    return sorted
end

function Registry:GetModule(name)
    return registeredModules[name]
end

function Registry:IsRegistered(name)
    return registeredModules[name] ~= nil
end

function Registry:GetModuleCount()
    local count = 0
    for _ in pairs(registeredModules) do
        count = count + 1
    end
    return count
end

function OneWoW:RegisterSettingsPanel(panelInfo)
    if not panelInfo or not panelInfo.name then return end
    if registeredSettingsPanels[panelInfo.name] then return end

    registeredSettingsPanels[panelInfo.name] = {
        name = panelInfo.name,
        displayName = panelInfo.displayName or panelInfo.name,
        order = panelInfo.order or 99,
        create = panelInfo.create,
    }
end

function Registry:GetSettingsPanels()
    local sorted = {}
    for _, panel in pairs(registeredSettingsPanels) do
        table.insert(sorted, panel)
    end
    table.sort(sorted, function(a, b) return a.order < b.order end)
    return sorted
end
