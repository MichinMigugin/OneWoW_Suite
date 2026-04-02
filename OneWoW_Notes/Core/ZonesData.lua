-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/ZonesData.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local Zones = ns.DataModule:New("zones", "zoneCustomCategories", {
    "General", "Quest", "Farming", "Rare", "Treasure", "Dungeon", "Raid", "PvP", "Event"
})
ns.Zones = Zones

Zones.GetAllZones = Zones.GetAll

local scanningEnabled = false
local lastAlertedZone = nil
local lastAlertTime   = 0
local currentZone     = ""
local currentSubZone  = ""
local currentInstanceID = nil
local zoneEventFrame = CreateFrame("Frame")

function Zones:Initialize()
    local addon = _G.OneWoW_Notes
    self:EnsureDB()
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

    zoneEventFrame:SetScript("OnEvent", function() C_Timer.After(0.1, function() Zones:CheckZoneAlerts() end) end)
    zoneEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    zoneEventFrame:RegisterEvent("ZONE_CHANGED")
    zoneEventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    zoneEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    if not self.periodicTimer then
        self.periodicTimer = C_Timer.NewTicker(2, function()
            if not scanningEnabled then return end
            local newZone = GetZoneText()
            local newSubZone = GetSubZoneText()
            local _, _, _, _, _, _, _, newInstanceID = GetInstanceInfo()
            if newZone ~= currentZone or newSubZone ~= currentSubZone or newInstanceID ~= currentInstanceID then
                Zones:CheckZoneAlerts()
            end
        end)
    end
end

function Zones:IsScanning()
    return scanningEnabled
end

function Zones:DisableScanning()
    if not scanningEnabled then return end
    scanningEnabled = false
    local addon = _G.OneWoW_Notes
    addon.db.global.zoneAlertsEnabled = false
    zoneEventFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
    zoneEventFrame:UnregisterEvent("ZONE_CHANGED")
    zoneEventFrame:UnregisterEvent("ZONE_CHANGED_INDOORS")
    zoneEventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if self.periodicTimer then
        self.periodicTimer:Cancel()
        self.periodicTimer = nil
    end
end

function Zones:CheckZoneAlerts()
    if not scanningEnabled then return end
    local now = GetTime()
    if (now - lastAlertTime) < 5 then return end

    local zoneText    = GetZoneText()    or ""
    local subZoneText = GetSubZoneText() or ""
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()

    local previousZone       = currentZone
    local previousSubZone    = currentSubZone
    local previousInstanceID = currentInstanceID

    currentZone       = zoneText
    currentSubZone    = subZoneText
    currentInstanceID = instanceID

    local fullZone = zoneText
    if subZoneText ~= "" and subZoneText ~= zoneText then
        fullZone = zoneText .. " - " .. subZoneText
    end

    local previousFullZone = previousZone or ""
    if previousSubZone and previousSubZone ~= "" and previousSubZone ~= previousZone then
        previousFullZone = previousZone .. " - " .. previousSubZone
    end

    local mainZoneChanged = (previousZone ~= zoneText)
    local subZoneChanged  = (previousSubZone ~= subZoneText)
    local instanceChanged = (previousInstanceID ~= instanceID)

    if not mainZoneChanged and not subZoneChanged and not instanceChanged then return end

    local shouldHidePins = false
    if instanceType == "party" or instanceType == "raid" or instanceType == "scenario" then
        shouldHidePins = instanceChanged
    else
        shouldHidePins = (mainZoneChanged or subZoneChanged or fullZone ~= previousFullZone)
    end

    if shouldHidePins and ns.ZonePins then
        local addon = _G.OneWoW_Notes
        if addon.zonePins then
            local toHide = {}
            for zoneName in pairs(addon.zonePins) do
                if zoneName ~= fullZone and zoneName ~= zoneText and zoneName ~= subZoneText then
                    table.insert(toHide, zoneName)
                end
            end
            for _, zoneName in ipairs(toHide) do
                ns.ZonePins:HideZonePin(zoneName)
            end
        end
    end

    local allZones = self:GetAll()

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

    if allZones[fullZone] then
        tryZone(fullZone)
    end
    if subZoneText ~= "" and subZoneText ~= zoneText and allZones[subZoneText] then
        tryZone(subZoneText)
    end
    if allZones[zoneText] then
        tryZone(zoneText)
    end
end

function Zones:GetCurrentZoneName()
    local zoneText = GetZoneText() or ""
    local subZoneText = GetSubZoneText() or ""
    if subZoneText ~= "" and subZoneText ~= zoneText then
        return zoneText .. " - " .. subZoneText
    end
    return zoneText
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

function Zones:GetZone(zoneName)
    if not zoneName then return nil end
    return self:GetAll()[zoneName]
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
    self:InvalidateCache()
    return true
end

function Zones:SaveZone(zoneName, zoneData)
    if not zoneName or not zoneData then return end
    local addon = _G.OneWoW_Notes
    zoneData.modified = GetServerTime()
    local targetDB = (zoneData.storage == "character") and addon.db.char.zones or addon.db.global.zones
    targetDB[zoneName] = zoneData
    self:InvalidateCache()
end

function Zones:RemoveZone(zoneName)
    if not zoneName then return end
    self:Remove(zoneName)
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

function Zones:MigrateDefaultColors()
    self:MigrateColors("zoneColorsMigrated")
end

function Zones:MigrateFontFamily()
    self:MigrateFonts("zoneFontFamilyMigrated")
end
