local addonName, ns = ...
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

function NPCs:GetTargetNPCInfo()
    if not UnitExists("target") or UnitIsPlayer("target") then return nil end
    local guid = UnitGUID("target")
    if not guid or issecretvalue(guid) then return nil end
    local unitType, _, _, _, _, entityIDStr = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return nil end
    local entityID = tonumber(entityIDStr)
    if not entityID then return nil end

    local name = UnitName("target") or ("NPC " .. entityID)
    local zone = GetZoneText() or ""
    local mapID = C_Map.GetBestMapForUnit("player")
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
    local addon = _G.OneWoW_Notes
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

    if addon.mainFrame and addon.mainFrame:IsShown() then
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

function NPCs:CreateWaypoint(npcID, npcData)
    if not npcData or not npcData.mapID or not npcData.coords then return end
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
    self:EnsureDB()

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
