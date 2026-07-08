local _, ns = ...
local L = ns.L

local Zones = ns.DataModule:New("zones", "zoneCustomCategories", {
    "General", "Quest", "Farming", "Rare", "Treasure", "Dungeon", "Raid", "PvP", "Event"
})
ns.Zones = Zones

Zones.GetAllZones = Zones.GetAll

local lastAlertedZone = nil
local lastAlertTime   = 0
local currentZone     = ""
local currentSubZone  = ""
local currentInstanceID = nil
local zoneEventFrame  = CreateFrame("Frame")
local zoneWatchStarted = false

function Zones:Initialize()
    -- Always watch zone changes so pinned zone notes trigger even when the zone
    -- alert messages are turned off. Alerts themselves stay gated by the setting.
    self:StartZoneWatch()
    C_Timer.After(1, function() Zones:CheckZones() end)
end

-- Register the zone-change events / poll once. Independent of zone alerts so
-- pins keep working regardless of the alert toggle.
function Zones:StartZoneWatch()
    if zoneWatchStarted then return end
    zoneWatchStarted = true

    zoneEventFrame:SetScript("OnEvent", function() C_Timer.After(0.1, function() Zones:CheckZones() end) end)
    zoneEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    zoneEventFrame:RegisterEvent("ZONE_CHANGED")
    zoneEventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")

    OneWoW_Notes:RegisterEnteringWorldHandler("zones", function()
        C_Timer.After(0.1, function() Zones:CheckZones() end)
    end)

    if not self.periodicTimer then
        self.periodicTimer = C_Timer.NewTicker(2, function()
            local newZone = GetZoneText()
            local newSubZone = GetSubZoneText()
            local _, _, _, _, _, _, _, newInstanceID = GetInstanceInfo()
            if newZone ~= currentZone or newSubZone ~= currentSubZone or newInstanceID ~= currentInstanceID then
                Zones:CheckZones()
            end
        end)
    end
end

-- "Scanning" in the settings UI refers to the zone alert messages, not pin
-- triggering (pins are always watched once StartZoneWatch has run).
function Zones:IsScanning()
    return ns.db.global.zoneAlertsEnabled and true or false
end

function Zones:EnableScanning()
    ns.db.global.zoneAlertsEnabled = true
    self:StartZoneWatch()
    Zones:CheckZones()
end

function Zones:DisableScanning()
    -- Only turn off the alert messages; the zone watcher keeps running so pinned
    -- zone notes still appear on zone change.
    ns.db.global.zoneAlertsEnabled = false
end

-- Runs on every zone change: shows/hides pinned zone notes (always) and fires
-- zone alert messages (only when zone alerts are enabled).
function Zones:CheckZones()
    local now = GetTime()
    local alertsOn = ns.db.global.zoneAlertsEnabled and true or false

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
        if ns.zonePins then
            local toHide = {}
            for zoneName in pairs(ns.zonePins) do
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

        local dismissed = zoneData.dismissedUntil and GetTime() < zoneData.dismissedUntil

        -- Pins always trigger, regardless of the alert setting.
        if zoneData.pinEnabled and not dismissed and ns.ZonePins then
            ns.ZonePins:ShowZonePin(key, zoneData)
        end

        -- Alert message / sound / toast only when zone alerts are enabled.
        if alertsOn and zoneData.alertEnabled ~= false and not dismissed then
            if not (lastAlertedZone == key and (now - lastAlertTime) < 30) then
                lastAlertTime   = now
                lastAlertedZone = key
                print("|cFFFFD100OneWoW - Zones:|r " .. (L["NPC_LABEL_ZONE"]) .. " " .. key)
                PlaySound(SOUNDKIT.RAID_WARNING)
                local preview = (zoneData.content and zoneData.content ~= "") and zoneData.content:sub(1, 60) or nil
                OneWoW.Toasts.FireZoneAlert(key, preview)
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

    if ns.mainFrame and ns.mainFrame:IsShown() then
        zoneData.isNew          = true
        zoneData.newTimestamp   = GetServerTime()
    end

    local targetDB = (zoneData.storage == "character") and ns.db.char.zones or ns.db.global.zones
    targetDB[zoneName] = zoneData
    self:InvalidateCache()
    return true
end

function Zones:SaveZone(zoneName, zoneData)
    if not zoneName or not zoneData then return end
    zoneData.modified = GetServerTime()
    local targetDB = (zoneData.storage == "character") and ns.db.char.zones or ns.db.global.zones
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
