local _, ns = ...

ns.ModuleRegistry = {}
local Registry = ns.ModuleRegistry

local registeredModules = {}
local registeredSettingsPanels = {}

function ns:RegisterModule(moduleInfo)
    if not moduleInfo or not moduleInfo.name then return end
    if registeredModules[moduleInfo.name] then return end

    registeredModules[moduleInfo.name] = {
        name = moduleInfo.name,
        displayName = moduleInfo.displayName or moduleInfo.name,
        addonName = moduleInfo.addonName or "",
        order = moduleInfo.order or 99,
        loadPhase = moduleInfo.loadPhase or "login",
        tabs = moduleInfo.tabs or {},
    }

    ns.SearchRegistry:RegisterHubModule(registeredModules[moduleInfo.name])

    -- MainWindow builds row-1 tabs once at first open; mid-session loads (e.g. a
    -- soft-disabled unit re-enabled via Load Addon) register here after init.
    EventRegistry:TriggerEvent("ns.ModuleRegistered", moduleInfo.name)
end

function Registry:GetModules()
    local sorted = {}
    for _, mod in pairs(registeredModules) do
        table.insert(sorted, mod)
    end
    table.sort(sorted, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.name < b.name
    end)
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

function ns:RegisterSettingsPanel(panelInfo)
    if not panelInfo or not panelInfo.name then return end
    if registeredSettingsPanels[panelInfo.name] then return end

    registeredSettingsPanels[panelInfo.name] = {
        name = panelInfo.name,
        displayName = panelInfo.displayName or panelInfo.name,
        order = panelInfo.order or 99,
        create = panelInfo.create,
    }

    ns.SearchRegistry:RegisterSettingsPanelEntry(registeredSettingsPanels[panelInfo.name])
end

function Registry:GetSettingsPanels()
    local sorted = {}
    for _, panel in pairs(registeredSettingsPanels) do
        table.insert(sorted, panel)
    end
    table.sort(sorted, function(a, b) return a.order < b.order end)
    return sorted
end
