-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/NPCsData.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local NPCs = {}
ns.NPCs = NPCs

local NPC_CATEGORIES = {
    "Other", "Quest Givers", "Vendors", "Trainers", "Flight Masters",
    "Rare Elites", "Bosses", "Event NPCs", "Auctioneers", "Portals",
    "Repair", "Transmog", "PvP Vendors", "Profession NPCs", "Pet Trainers"
}

function NPCs:GetNotesDB(storageType)
    local addon = _G.OneWoW_Notes
    if storageType == "character" then return addon.db.char.npcs
    else return addon.db.global.npcs end
end

function NPCs:GetAllNPCs()
    local addon = _G.OneWoW_Notes
    local all = {}
    if addon.db.global.npcs then
        for id, data in pairs(addon.db.global.npcs) do
            all[id] = data
            if type(data) == "table" then data.storage = "account" end
        end
    end
    if addon.db.char.npcs then
        for id, data in pairs(addon.db.char.npcs) do
            all[id] = data
            if type(data) == "table" then data.storage = "character" end
        end
    end
    return all
end

function NPCs:GetNPC(npcID)
    if not npcID then return nil end
    npcID = tonumber(npcID)
    if not npcID then return nil end
    return self:GetAllNPCs()[npcID]
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

    local targetDB = self:GetNotesDB(newData.storage)
    targetDB[npcID] = newData
    return true
end

function NPCs:SaveNPC(npcID, npcData)
    if not npcID or not npcData then return end
    npcID = tonumber(npcID)
    if not npcID then return end
    npcData.modified = GetServerTime()
    local targetDB = self:GetNotesDB(npcData.storage or "account")
    targetDB[npcID] = npcData
end

function NPCs:RemoveNPC(npcID)
    if not npcID then return end
    npcID = tonumber(npcID)
    if not npcID then return end
    local addon = _G.OneWoW_Notes
    if addon.db.global.npcs then addon.db.global.npcs[npcID] = nil end
    if addon.db.char.npcs   then addon.db.char.npcs[npcID]   = nil end
end

function NPCs:GetCategories()
    local addon = _G.OneWoW_Notes
    local all = {}
    for _, c in ipairs(NPC_CATEGORIES) do table.insert(all, c) end
    if addon.db.global.npcCustomCategories then
        for _, c in ipairs(addon.db.global.npcCustomCategories) do table.insert(all, c) end
    end
    return all
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

function NPCs:EnableScanning()
    local addon = _G.OneWoW_Notes
    addon.db.global.npcScanEnabled = true
    NPCs._scanningActive = true
    if NPCs._scanFrame then
        NPCs._scanFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    end
end

function NPCs:DisableScanning()
    local addon = _G.OneWoW_Notes
    addon.db.global.npcScanEnabled = false
    NPCs._scanningActive = false
    if NPCs._scanFrame then
        NPCs._scanFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
    end
end

function NPCs:IsScanning()
    return NPCs._scanningActive == true
end

function NPCs:Initialize()
    local addon = _G.OneWoW_Notes
    if not addon.db.global.npcs then addon.db.global.npcs = {} end
    if not addon.db.char.npcs   then addon.db.char.npcs   = {} end

    NPCs._scanningActive = addon.db.global.npcScanEnabled ~= false

    -- Dedicated frame so it doesn't conflict with Players registering the same event
    NPCs._scanFrame = CreateFrame("Frame")
    NPCs._scanFrame:SetScript("OnEvent", function(_, event)
        if event ~= "PLAYER_TARGET_CHANGED" then return end
        if not NPCs._scanningActive then return end
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

    if NPCs._scanningActive then
        NPCs._scanFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    end
end
