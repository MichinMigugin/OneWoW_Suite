local _, ns = ...
local L = ns.L

local NPCs = ns.DataModule:New(
    "npcs",
    "npcCustomCategories",
    {"Other", "Quest Givers", "Vendors", "Trainers", "Flight Masters",
     "Rare Elites", "Bosses", "Event NPCs", "Auctioneers", "Portals",
     "Repair", "Transmog", "PvP Vendors", "Profession NPCs", "Pet Trainers"}
)
ns.NPCs = NPCs

function NPCs:GetNotesDB(storageType)
    return self:GetDataDB(storageType)
end

function NPCs:GetAllNPCs()
    return self:GetAll()
end

function NPCs:GetNPC(npcID)
    if not npcID then return nil end
    npcID = tonumber(npcID)
    if not npcID then return nil end
    return self:GetAll()[npcID]
end

local function BuildCoords(npcInfo)
    if not npcInfo then return nil end
    if npcInfo.coords then
        return npcInfo.coords
    end
    if npcInfo.x and npcInfo.y then
        local x = tonumber(npcInfo.x)
        local y = tonumber(npcInfo.y)
        if x and y then
            if x <= 1 and y <= 1 then
                x = x * 100
                y = y * 100
            end
            return { x = x, y = y }
        end
    end
    return nil
end

local function GetMapName(mapID)
    if not mapID then return nil end
    local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    if mapInfo and mapInfo.name and mapInfo.name ~= "" then
        return mapInfo.name
    end
    return nil
end

local function ResolveZoneName(npcInfo, fallbackMapID)
    if not npcInfo then return "" end
    local mapName = GetMapName(npcInfo.mapID or fallbackMapID)
    if mapName then return mapName end
    return npcInfo.zone or ""
end

local npcNameResolvePending = {}
local NPC_NAME_RESOLVE_DELAYS = { 0.1, 0.35, 0.8, 1.5, 3.0 }

local function IsPlaceholderNPCName(name, npcID)
    if not name or name == "" then return true end
    npcID = tonumber(npcID)
    if not npcID then return false end
    return name == ("NPC " .. tostring(npcID))
end

local function ResolveNPCNameFromTooltip(npcID)
    npcID = tonumber(npcID)
    if not npcID or not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then
        return nil
    end

    local tooltipData = C_TooltipInfo.GetHyperlink(
        string.format("unit:Creature-0-0-0-0-%d-0000000000", npcID)
    )
    if not tooltipData or not tooltipData.lines then
        return nil
    end

    for _, line in ipairs(tooltipData.lines) do
        local name = line.leftText
        if name
            and name ~= ""
            and not name:find("Retrieving", 1, true)
            and not IsPlaceholderNPCName(name, npcID)
        then
            return name
        end
    end

    return nil
end

function NPCs:IsPlaceholderName(name, npcID)
    return IsPlaceholderNPCName(name, npcID)
end

function NPCs:ResolveNPCName(npcID)
    return ResolveNPCNameFromTooltip(npcID)
end

function NPCs:ResolveStoredNPCName(npcID, onResolved)
    npcID = tonumber(npcID)
    if not npcID or npcNameResolvePending[npcID] then
        return false
    end

    local existing = self:GetNPC(npcID)
    if not existing or not IsPlaceholderNPCName(existing.name, npcID) then
        return false
    end

    local state = { attempt = 1 }
    npcNameResolvePending[npcID] = state

    local function retry()
        local current = NPCs:GetNPC(npcID)
        if not current or not IsPlaceholderNPCName(current.name, npcID) then
            npcNameResolvePending[npcID] = nil
            return
        end

        local resolvedName = ResolveNPCNameFromTooltip(npcID)
        if resolvedName then
            current.name = resolvedName
            NPCs:SaveNPC(npcID, current)
            npcNameResolvePending[npcID] = nil
            if onResolved then onResolved(npcID, resolvedName) end
            return
        end

        state.attempt = state.attempt + 1
        local delay = NPC_NAME_RESOLVE_DELAYS[state.attempt]
        if delay and C_Timer and C_Timer.After then
            C_Timer.After(delay, retry)
        else
            npcNameResolvePending[npcID] = nil
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(NPC_NAME_RESOLVE_DELAYS[state.attempt], retry)
    else
        retry()
    end

    return true
end

function NPCs:RefreshMissingNames(onResolved, maxQueued)
    local queued = 0
    maxQueued = maxQueued or 20

    for npcID, npcData in pairs(self:GetAllNPCs()) do
        if type(npcData) == "table" and IsPlaceholderNPCName(npcData.name, npcID) then
            if self:ResolveStoredNPCName(npcID, onResolved) then
                queued = queued + 1
                if queued >= maxQueued then
                    break
                end
            end
        end
    end

    return queued
end

function NPCs:EnsureNPC(npcID, npcInfo)
    if not npcID then return false end
    npcID = tonumber(npcID)
    if not npcID then return false end

    npcInfo = npcInfo or {}
    local existing = self:GetNPC(npcID)

    if existing then
        local changed = false
        local incomingMapID = tonumber(npcInfo.mapID)
        local mapChanged = incomingMapID and incomingMapID ~= existing.mapID

        if npcInfo.name and npcInfo.name ~= "" and (not existing.name or existing.name == "" or existing.name == ("NPC " .. npcID)) then
            existing.name = npcInfo.name
            changed = true
        end

        if incomingMapID and (not existing.mapID or mapChanged) then
            existing.mapID = incomingMapID
            changed = true
        end

        local coords = BuildCoords(npcInfo)
        if coords and (not existing.coords or mapChanged) then
            existing.coords = coords
            changed = true
        end

        local resolvedZone = ResolveZoneName(npcInfo, existing.mapID)
        if resolvedZone ~= "" and existing.zone ~= resolvedZone then
            existing.zone = resolvedZone
            changed = true
        end

        if npcInfo.category
            and npcInfo.category ~= ""
            and (
                not existing.category
                or existing.category == ""
                or existing.category == "Other"
            )
        then
            existing.category = npcInfo.category
            changed = true
        end

        if changed then
            self:SaveNPC(npcID, existing)
        end

        return false, existing
    end

    local mapID = npcInfo.mapID
    local zone = ResolveZoneName(npcInfo)

    return self:AddNPC(npcID, {
        name = npcInfo.name or ("NPC " .. npcID),
        zone = zone or "",
        mapID = mapID,
        coords = BuildCoords(npcInfo),
        category = npcInfo.category or "Quest Givers",
        storage = npcInfo.storage or "account",
        content = npcInfo.content or "",
        tooltipLines = npcInfo.tooltipLines,
    })
end

function NPCs:GetTargetNPCInfo()
    if not UnitExists("target") or UnitIsPlayer("target") then return nil end
    local guid = UnitGUID("target")
    if not guid or issecretvalue(guid) then return nil end
    local unitType, _, _, _, _, entityIDStr = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return nil end
    local entityID = tonumber(entityIDStr)
    if not entityID then return nil end

    local name = UnitName("target") or ("NPC " .. entityID)
    local mapID = C_Map.GetBestMapForUnit("player")
    local zone = GetMapName(mapID) or GetZoneText() or ""
    local coords = nil
    if mapID then
        local pos = C_Map.GetPlayerMapPosition(mapID, "target")
        if pos then
            local x, y = pos:GetXY()
            coords = { x = x * 100, y = y * 100 }
        end
    end

    return {
        id     = entityID,
        name   = name,
        zone   = zone,
        mapID  = mapID,
        coords = coords,
    }
end

function NPCs:AddNPC(npcID, npcInfo)
    if not npcID or not npcInfo then return false end
    npcID = tonumber(npcID)
    if not npcID then return false end

    local newData = {
        id           = npcID,
        name         = npcInfo.name or ("NPC " .. npcID),
        zone         = npcInfo.zone or "",
        mapID        = npcInfo.mapID or nil,
        coords       = npcInfo.coords or nil,
        category     = npcInfo.category or "Other",
        storage      = npcInfo.storage or "account",
        content      = npcInfo.content or "",
        tooltipLines = npcInfo.tooltipLines or {"", "", "", ""},
        alertOnFound = npcInfo.alertOnFound or false,
        ignoreIfDead = npcInfo.ignoreIfDead or false,
        favorite     = npcInfo.favorite or false,
        created      = GetServerTime(),
        modified     = GetServerTime(),
        sortOrder    = 0,
    }

    if OneWoW_Notes.mainFrame and OneWoW_Notes.mainFrame:IsShown() then
        newData.isNew = true
        newData.newTimestamp = GetServerTime()
    end

    local targetDB = self:GetDataDB(newData.storage)
    targetDB[npcID] = newData
    self:InvalidateCache()
    return true
end

function NPCs:SaveNPC(npcID, npcData)
    if not npcID or not npcData then return end
    npcID = tonumber(npcID)
    if not npcID then return end
    npcData.modified = GetServerTime()
    local targetDB = self:GetDataDB(npcData.storage or "account")
    targetDB[npcID] = npcData
    self:InvalidateCache()
end

function NPCs:RemoveNPC(npcID)
    if not npcID then return end
    npcID = tonumber(npcID)
    if not npcID then return end
    self:Remove(npcID)
end

function NPCs:CreateWaypoint(_, npcData)
    if not npcData or not npcData.mapID or not npcData.coords then return end

    if WorldMapFrame and not WorldMapFrame:IsShown() then
        ToggleWorldMap()
    end

    if WorldMapFrame and WorldMapFrame.SetMapID then
        WorldMapFrame:SetMapID(npcData.mapID)
    end

    if C_Map and C_Map.SetUserWaypoint then
        if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(npcData.mapID) then
            print("|cFFFFD100OneWoW - NPCs:|r " .. (L and L["MSG_CANNOT_SET_WAYPOINT"] or "Cannot set waypoint on this map."))
            return
        end
        local wp = UiMapPoint.CreateFromCoordinates(npcData.mapID, npcData.coords.x / 100, npcData.coords.y / 100)
        C_Map.SetUserWaypoint(wp)
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        print("|cFFFFD100OneWoW - NPCs:|r " .. string.format(L and L["MSG_WAYPOINT_SET"] or "Waypoint set for %s (%.1f, %.1f)", npcData.name or "NPC", npcData.coords.x, npcData.coords.y))
    end
end

function NPCs:Initialize()
    if not NPCs._targetFrame then
        NPCs._targetFrame = CreateFrame("Frame")
        NPCs._targetFrame:SetScript("OnEvent", function(_, event)
            if event ~= "PLAYER_TARGET_CHANGED" then return end
            if not UnitExists("target") or UnitIsPlayer("target") then return end
            local guid = UnitGUID("target")
            if not guid or issecretvalue(guid) then return end
            local unitType, _, _, _, _, entityIDStr = strsplit("-", guid)
            if unitType ~= "Creature" and unitType ~= "Vehicle" then return end
            local entityID = tonumber(entityIDStr)
            if not entityID then return end
            local existing = NPCs:GetNPC(entityID)
            if existing and existing.alertOnFound then
                if existing.ignoreIfDead and UnitIsDead("target") then return end
                print("|cFFFFD100OneWoW - NPCs:|r " .. string.format(L["NOTES_NPC_ALERT_FOUND"] or "Targeted NPC with note: %s", (existing.name or entityID)))
                PlaySound(SOUNDKIT.RAID_WARNING)
            end
        end)
        NPCs._targetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    end
end
