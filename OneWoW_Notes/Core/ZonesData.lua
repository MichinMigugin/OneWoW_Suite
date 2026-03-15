-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/ZonesData.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local Zones = {}
ns.Zones = Zones

local BUILT_IN_ZONE_CATEGORIES = {
    "General", "Quest", "Farming", "Rare", "Treasure", "Dungeon", "Raid", "PvP", "Event"
}

local scanningEnabled = false
local lastAlertedZone = nil
local lastAlertTime   = 0
local currentZone     = ""
local currentSubZone  = ""

function Zones:Initialize()
    local addon = _G.OneWoW_Notes
    if not addon.db.global.zones     then addon.db.global.zones     = {} end
    if not addon.db.char.zones       then addon.db.char.zones       = {} end
    if addon.db.global.zoneAlertsEnabled == nil then
        addon.db.global.zoneAlertsEnabled = true
    end

    if addon.db.global.zoneAlertsEnabled then
        self:EnableScanning()
        C_Timer.After(1, function() Zones:CheckZoneAlerts() end)
    end
end

function Zones:EnableScanning()
    if scanningEnabled then return end
    scanningEnabled = true
    local addon = _G.OneWoW_Notes
    addon.db.global.zoneAlertsEnabled = true

    local function onZone() C_Timer.After(0.1, function() Zones:CheckZoneAlerts() end) end
    addon:RegisterEvent("ZONE_CHANGED_NEW_AREA", onZone)
    addon:RegisterEvent("ZONE_CHANGED",          onZone)
    addon:RegisterEvent("ZONE_CHANGED_INDOORS",  onZone)
    addon:RegisterEvent("PLAYER_ENTERING_WORLD", onZone)
end

function Zones:IsScanning()
    return scanningEnabled
end

function Zones:DisableScanning()
    if not scanningEnabled then return end
    scanningEnabled = false
    local addon = _G.OneWoW_Notes
    addon.db.global.zoneAlertsEnabled = false
    pcall(function() addon:UnregisterEvent("ZONE_CHANGED_NEW_AREA") end)
    pcall(function() addon:UnregisterEvent("ZONE_CHANGED") end)
    pcall(function() addon:UnregisterEvent("ZONE_CHANGED_INDOORS") end)
    pcall(function() addon:UnregisterEvent("PLAYER_ENTERING_WORLD") end)
end

function Zones:CheckZoneAlerts()
    if not scanningEnabled then return end
    local now = GetTime()

    local zoneText    = GetZoneText()    or ""
    local subZoneText = GetSubZoneText() or ""

    local mainZoneChanged = (zoneText    ~= currentZone)
    local subZoneChanged  = (subZoneText ~= currentSubZone)

    if not mainZoneChanged and not subZoneChanged then return end

    currentZone    = zoneText
    currentSubZone = subZoneText

    -- Hide zone pins that no longer match where the player is
    if ns.ZonePins then
        local addon = _G.OneWoW_Notes
        if addon.zonePins then
            local toHide = {}
            for zoneName in pairs(addon.zonePins) do
                if zoneName ~= zoneText and zoneName ~= subZoneText then
                    table.insert(toHide, zoneName)
                end
            end
            for _, zoneName in ipairs(toHide) do
                ns.ZonePins:HideZonePin(zoneName)
            end
        end
    end

    local allZones = self:GetAllZones()

    local function tryZone(key)
        local zoneData = allZones[key]
        if not zoneData or type(zoneData) ~= "table" then return end

        if zoneData.pinEnabled then
            local dismissed = zoneData.dismissedUntil and GetTime() < zoneData.dismissedUntil
            if not dismissed and ns.ZonePins then
                ns.ZonePins:ShowZonePin(key, zoneData)
            end
        end

        if zoneData.alertEnabled ~= false then
            local dismissed = zoneData.dismissedUntil and GetTime() < zoneData.dismissedUntil
            if not dismissed then
                if not (lastAlertedZone == key and (now - lastAlertTime) < 30) then
                    if (now - lastAlertTime) >= 5 then
                        lastAlertTime   = now
                        lastAlertedZone = key
                        print("|cFFFFD100OneWoW - Zones:|r " .. (L["NOTES_ZONE_ALERT_ARRIVED"] or "Zone:") .. " " .. key)
                        PlaySound(SOUNDKIT.RAID_WARNING)
                        if _G.OneWoW and _G.OneWoW.Toasts and _G.OneWoW.Toasts.FireZoneAlert then
                            local preview = (zoneData.content and zoneData.content ~= "") and zoneData.content:sub(1, 60) or nil
                            _G.OneWoW.Toasts.FireZoneAlert(key, preview)
                        end
                    end
                end
            end
        end
    end

    if mainZoneChanged and zoneText ~= "" and allZones[zoneText] then
        tryZone(zoneText)
    end
    if subZoneChanged and subZoneText ~= "" and subZoneText ~= zoneText and allZones[subZoneText] then
        tryZone(subZoneText)
    end
end

function Zones:GetCurrentZoneName()
    return GetZoneText() or ""
end

function Zones:GetParentZoneName()
    local mapInfo = self:GetCurrentMapInfo()
    if mapInfo and mapInfo.parentMapID and mapInfo.parentMapID > 0 then
        local parentInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
        if parentInfo then return parentInfo.name end
    end
    return GetZoneText() or ""
end

function Zones:GetCurrentMapInfo()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local info = C_Map.GetMapInfo(mapID)
    if not info then return nil end
    return {
        mapID       = mapID,
        name        = info.name,
        parentMapID = info.parentMapID or 0,
    }
end

function Zones:GetAllZones()
    local addon = _G.OneWoW_Notes
    local all = {}

    if addon.db.global.zones then
        for name, data in pairs(addon.db.global.zones) do
            all[name] = data
            if type(data) == "table" then data.storage = "account" end
        end
    end

    if addon.db.char.zones then
        for name, data in pairs(addon.db.char.zones) do
            all[name] = data
            if type(data) == "table" then data.storage = "character" end
        end
    end

    return all
end

function Zones:GetZone(zoneName)
    if not zoneName then return nil end
    return self:GetAllZones()[zoneName]
end

function Zones:AddZone(zoneName, zoneData)
    if not zoneName or not zoneData then return false end
    local addon = _G.OneWoW_Notes

    zoneData.content       = zoneData.content or zoneData.text or ""
    zoneData.text          = nil
    zoneData.todos         = zoneData.todos or {}
    zoneData.alertEnabled  = zoneData.alertEnabled  == nil and true  or zoneData.alertEnabled
    zoneData.pinEnabled    = zoneData.pinEnabled     == nil and false or zoneData.pinEnabled
    zoneData.pinColor      = zoneData.pinColor  or "sync"
    zoneData.fontColor     = zoneData.fontColor or "match"
    zoneData.fontFamily    = zoneData.fontFamily or nil
    zoneData.fontSize      = zoneData.fontSize  or 12
    zoneData.opacity       = zoneData.opacity   or 0.9
    zoneData.tasksOnTop    = zoneData.tasksOnTop == nil and false or zoneData.tasksOnTop
    zoneData.storage       = zoneData.storage   or "account"
    zoneData.category      = zoneData.category  or "General"
    zoneData.created       = zoneData.created   or GetServerTime()
    zoneData.modified      = GetServerTime()
    zoneData.sortOrder     = zoneData.sortOrder or 0

    if addon.mainFrame and addon.mainFrame:IsShown() then
        zoneData.isNew          = true
        zoneData.newTimestamp   = GetServerTime()
    end

    local targetDB = (zoneData.storage == "character") and addon.db.char.zones or addon.db.global.zones
    targetDB[zoneName] = zoneData
    return true
end

function Zones:SaveZone(zoneName, zoneData)
    if not zoneName or not zoneData then return end
    local addon = _G.OneWoW_Notes
    zoneData.modified = GetServerTime()
    local targetDB = (zoneData.storage == "character") and addon.db.char.zones or addon.db.global.zones
    targetDB[zoneName] = zoneData
end

function Zones:RemoveZone(zoneName)
    if not zoneName then return end
    local addon = _G.OneWoW_Notes
    if addon.db.global.zones then addon.db.global.zones[zoneName] = nil end
    if addon.db.char.zones   then addon.db.char.zones[zoneName]   = nil end
end

function Zones:AddTodo(zoneName, todoText)
    local zoneData = self:GetZone(zoneName)
    if not zoneData then return end
    if not zoneData.todos then zoneData.todos = {} end

    local todo = {
        id        = math.random(100000, 999999),
        text      = todoText,
        completed = false,
        created   = GetServerTime(),
    }
    table.insert(zoneData.todos, todo)
    zoneData.modified = GetServerTime()
    self:SaveZone(zoneName, zoneData)
    return todo
end

function Zones:UpdateTodo(zoneName, todoId, newText, completed)
    local zoneData = self:GetZone(zoneName)
    if not zoneData or not zoneData.todos then return end
    for _, todo in ipairs(zoneData.todos) do
        if todo.id == todoId then
            if newText    ~= nil then todo.text      = newText    end
            if completed  ~= nil then todo.completed = completed  end
            zoneData.modified = GetServerTime()
            self:SaveZone(zoneName, zoneData)
            return true
        end
    end
    return false
end

function Zones:RemoveTodo(zoneName, todoId)
    local zoneData = self:GetZone(zoneName)
    if not zoneData or not zoneData.todos then return end
    for i, todo in ipairs(zoneData.todos) do
        if todo.id == todoId then
            table.remove(zoneData.todos, i)
            zoneData.modified = GetServerTime()
            self:SaveZone(zoneName, zoneData)
            return true
        end
    end
    return false
end

function Zones:GetCategories()
    local addon = _G.OneWoW_Notes
    local all = {}
    for _, c in ipairs(BUILT_IN_ZONE_CATEGORIES) do table.insert(all, c) end
    if addon.db.global.zoneCustomCategories then
        for _, c in ipairs(addon.db.global.zoneCustomCategories) do table.insert(all, c) end
    end
    return all
end

function Zones:MigrateDefaultColors()
    local addon = _G.OneWoW_Notes
    if not addon.db or not addon.db.global then return end

    if addon.db.global.zoneColorsMigrated then return end

    local migratedCount = 0
    if addon.db.global.zones then
        for zoneName, zoneData in pairs(addon.db.global.zones) do
            if zoneData and type(zoneData) == "table" then
                if zoneData.pinColor == "hunter" and zoneData.fontColor == "match" then
                    zoneData.pinColor = "sync"
                    migratedCount = migratedCount + 1
                end
            end
        end
    end

    addon.db.global.zoneColorsMigrated = true
    if migratedCount > 0 then
        print("|cFF00FF00OneWoW_Notes|r: Migrated " .. migratedCount .. " zone(s) to OneWoW Sync theme")
    end
end

function Zones:MigrateFontFamily()
    local addon = _G.OneWoW_Notes
    if not addon.db or not addon.db.global then return end
    if addon.db.global.zoneFontFamilyMigrated then return end

    local GUI = LibStub("OneWoW_GUI-1.0", true)
    if not GUI or not GUI.MigrateLSMFontName then
        addon.db.global.zoneFontFamilyMigrated = true
        return
    end

    local migratedCount = 0
    if addon.db.global.zones then
        for _, zoneData in pairs(addon.db.global.zones) do
            if zoneData and type(zoneData) == "table" and zoneData.fontFamily then
                local newKey = GUI:MigrateLSMFontName(zoneData.fontFamily)
                if newKey then
                    zoneData.fontFamily = newKey
                    migratedCount = migratedCount + 1
                end
            end
        end
    end

    if addon.db.char and addon.db.char.zones then
        for _, zoneData in pairs(addon.db.char.zones) do
            if zoneData and type(zoneData) == "table" and zoneData.fontFamily then
                local newKey = GUI:MigrateLSMFontName(zoneData.fontFamily)
                if newKey then
                    zoneData.fontFamily = newKey
                    migratedCount = migratedCount + 1
                end
            end
        end
    end

    addon.db.global.zoneFontFamilyMigrated = true
    if migratedCount > 0 then
        print("|cFF00FF00OneWoW_Notes|r: Migrated " .. migratedCount .. " zone font(s) to new font system")
    end
end
