local ADDON_NAME, OneWoW = ...

OneWoW.SettingsFeatureRegistry = {}
local reg = OneWoW.SettingsFeatureRegistry
local featuresByTab = {}

function reg:Register(tabName, featureData)
    featuresByTab[tabName] = featuresByTab[tabName] or {}
    table.insert(featuresByTab[tabName], featureData)
end

function reg:GetByTab(tabName)
    local list = featuresByTab[tabName] or {}
    local sorted = {}
    for _, f in ipairs(list) do
        if f.id == "general" then
            table.insert(sorted, 1, f)
        else
            table.insert(sorted, f)
        end
    end
    return sorted
end

function reg:IsEnabled(tabName, featureId)
    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    if not db or not db[tabName] then
        return false
    end
    local entry = db[tabName][featureId]
    if entry == nil then
        return false
    end
    return entry.enabled == true
end

function reg:SetEnabled(tabName, featureId, value)
    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    if not db then
        return
    end
    db[tabName] = db[tabName] or {}
    db[tabName][featureId] = db[tabName][featureId] or {}
    db[tabName][featureId].enabled = value

    if tabName == "overlays" and OneWoW.OverlayEngine then
        C_Timer.After(0.05, function()
            OneWoW.OverlayEngine:Refresh()
        end)
    end
end

function reg:SetOverlaySetting(featureId, key, value)
    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    if not db then return end
    db.overlays = db.overlays or {}
    db.overlays[featureId] = db.overlays[featureId] or {}
    db.overlays[featureId][key] = value

    if OneWoW.OverlayEngine then
        C_Timer.After(0.05, function()
            OneWoW.OverlayEngine:Refresh()
        end)
    end
end

function reg:GetOverlaySetting(featureId, key)
    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    if not db or not db.overlays or not db.overlays[featureId] then return nil end
    return db.overlays[featureId][key]
end
