-- OneWoW Addon File
-- OneWoW/Features/ContextMenus.lua
-- Created by MichinMuggin (Ricky)
local ADDON_NAME, OneWoW = ...
local L = OneWoW.L

local function GetNotes()
    return _G.OneWoW_Notes
end

local function GetPlayMountsModule()
    local qol = _G.OneWoW_QoL
    if not qol then return nil end
    return qol.PlayMountsModule
end

local function IsPlayMountsEnabled()
    local qol = _G.OneWoW_QoL
    if not qol or not qol.db or not qol.db.global or not qol.db.global.modules then return false end
    local modData = qol.db.global.modules["playmounts"]
    if modData and modData.enabled ~= nil then
        return modData.enabled
    end
    return false
end

local function IsMatchMountEnabled()
    local qol = _G.OneWoW_QoL
    if not qol or not qol.db or not qol.db.global or not qol.db.global.modules then return true end
    local modData = qol.db.global.modules["playmounts"]
    if not modData then return true end
    if modData.enabled == false then return false end
    if modData.toggles and modData.toggles["enableMatchMount"] ~= nil then
        return modData.toggles["enableMatchMount"]
    end
    return true
end

local function NavigateToPlayer(fullName)
    local notes = GetNotes()
    if not notes then return end
    notes.pendingPlayerSelect = fullName
    if _G.OneWoW and _G.OneWoW.GUI then
        _G.OneWoW.GUI:Show("notes")
        C_Timer.After(0.25, function()
            if _G.OneWoW and _G.OneWoW.GUI then
                _G.OneWoW.GUI:SelectSubTab("notes", "players")
            end
        end)
    end
end

local function NavigateToNPC(npcID)
    local notes = GetNotes()
    if not notes then return end
    notes.pendingNPCSelect = tonumber(npcID)
    if _G.OneWoW and _G.OneWoW.GUI then
        _G.OneWoW.GUI:Show("notes")
        C_Timer.After(0.25, function()
            if _G.OneWoW and _G.OneWoW.GUI then
                _G.OneWoW.GUI:SelectSubTab("notes", "npcs")
            end
        end)
    end
end

-- =============================================
-- PLAYER HANDLERS
-- =============================================

local function HandlePlayerAdd(unit)
    local notes = GetNotes()
    if not notes or not notes.Players then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NOTES_NOT_LOADED"])
        return
    end

    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end

    if unit ~= "target" then
        TargetUnit(unit)
        C_Timer.After(0.1, function() HandlePlayerAdd("target") end)
        return
    end

    local playerName, realm = UnitName(unit)
    if not playerName then return end
    if not realm or realm == "" then realm = GetRealmName() end
    local fullName = playerName .. "-" .. realm

    local existing = notes.Players:GetPlayer(fullName)
    if existing then
        print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_PLAYER_EXISTS"], playerName))
        NavigateToPlayer(fullName)
        return
    end

    local _, classFile = UnitClass(unit)
    local _, race      = UnitRace(unit)
    local guild        = GetGuildInfo(unit) or ""

    local playerData = {
        name         = playerName,
        realm        = realm,
        fullName     = fullName,
        class        = classFile or "",
        race         = race or "",
        level        = UnitLevel(unit) or 0,
        guild        = guild,
        faction      = "",
        category     = "General",
        storage      = "account",
        content      = "",
        tooltipLines = {"", "", "", ""},
    }

    notes.Players:AddPlayer(fullName, playerData)
    print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_PLAYER_ADDED"], playerName))
end

local function HandleAddMountInfo(unit)
    local notes = GetNotes()
    if not notes or not notes.Players then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NOTES_NOT_LOADED"])
        return
    end

    local pmModule = GetPlayMountsModule()
    if not pmModule then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_PLAYMOUNTS_NOT_LOADED"])
        return
    end

    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end

    if unit ~= "target" then
        TargetUnit(unit)
        C_Timer.After(0.1, function() HandleAddMountInfo("target") end)
        return
    end

    local mountInfo = pmModule:DetectMountOnUnit(unit)
    if not mountInfo then
        local playerName = UnitName(unit) or "Player"
        print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_PLAYER_NOT_MOUNTED"], playerName))
        return
    end

    local playerName, realm = UnitName(unit)
    if not realm or realm == "" then realm = GetRealmName() end
    local fullName = playerName .. "-" .. realm

    local mountText
    if mountInfo.isMovementForm then
        mountText = string.format(L["UNIT_CTX_MOUNT_MOVEMENT_FORM"], mountInfo.name)
    else
        local mountLink = C_Spell.GetSpellLink(mountInfo.spellID or mountInfo.spellId) or mountInfo.name
        mountText = string.format(L["UNIT_CTX_MOUNT_LABEL"], mountLink)
        if mountInfo.mountTypeName then
            mountText = mountText .. "\n" .. string.format(L["UNIT_CTX_MOUNT_TYPE"], mountInfo.mountTypeName)
        end
        if mountInfo.sourceText and mountInfo.sourceText ~= "" then
            mountText = mountText .. "\n" .. string.format(L["UNIT_CTX_MOUNT_SOURCE"], mountInfo.sourceText)
        end
        if mountInfo.isCollected ~= nil then
            local status = mountInfo.isCollected and L["UNIT_CTX_MOUNT_COLLECTED"] or L["UNIT_CTX_MOUNT_NOT_COLLECTED_STATUS"]
            mountText = mountText .. "\n" .. string.format(L["UNIT_CTX_MOUNT_STATUS"], status)
        end
    end

    local existing = notes.Players:GetPlayer(fullName)
    if existing then
        local currentNote = existing.content or ""
        if currentNote ~= "" then
            existing.content = currentNote .. "\n\n" .. mountText
        else
            existing.content = mountText
        end
        notes.Players:SavePlayer(fullName, existing)
        print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_MOUNT_INFO_APPENDED"], playerName))
    else
        local _, classFile = UnitClass(unit)
        local _, race      = UnitRace(unit)
        local guild        = GetGuildInfo(unit) or ""

        local playerData = {
            name         = playerName,
            realm        = realm,
            fullName     = fullName,
            class        = classFile or "",
            race         = race or "",
            level        = UnitLevel(unit) or 0,
            guild        = guild,
            faction      = "",
            category     = "General",
            storage      = "account",
            content      = mountText,
            tooltipLines = {"", "", "", ""},
        }
        notes.Players:AddPlayer(fullName, playerData)
        print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_MOUNT_INFO_CREATED"], playerName))
    end
end

local function HandleMatchMount(unit)
    local pmModule = GetPlayMountsModule()
    if not pmModule then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_PLAYMOUNTS_NOT_LOADED"])
        return
    end

    if not UnitExists(unit) or not UnitIsPlayer(unit) then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_TARGET_NOT_PLAYER"])
        return
    end

    if unit ~= "target" then
        TargetUnit(unit)
        C_Timer.After(0.1, function() HandleMatchMount("target") end)
        return
    end

    local mountInfo = pmModule:DetectMountOnUnit(unit)
    if not mountInfo then
        local playerName = UnitName(unit) or "Player"
        print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_PLAYER_NOT_MOUNTED"], playerName))
        return
    end

    if mountInfo.isMovementForm then
        print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_CANNOT_MATCH_FORM"], mountInfo.name))
        return
    end

    if not mountInfo.isCollected then
        local mountLink = C_Spell.GetSpellLink(mountInfo.spellID or mountInfo.spellId) or mountInfo.name
        print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_MOUNT_NOT_COLLECTED"], mountLink))
        return
    end

    if IsFlying() then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_CANNOT_FLYING"])
        return
    end

    local mountLink = C_Spell.GetSpellLink(mountInfo.spellID or mountInfo.spellId) or mountInfo.name
    if IsMounted() then
        Dismount()
        C_Timer.After(0.3, function()
            C_MountJournal.SummonByID(mountInfo.mountID)
            print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_MATCHING_MOUNT"], mountLink))
        end)
    else
        C_MountJournal.SummonByID(mountInfo.mountID)
        print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_MATCHING_MOUNT"], mountLink))
    end
end

local function PlayerContextMenuHandler(owner, rootDescription, contextData)
    if not contextData or not contextData.unit then return end
    if not UnitIsPlayer(contextData.unit) then return end

    local notes = GetNotes()
    if not notes then return end

    rootDescription:CreateDivider()
    rootDescription:CreateTitle(L["UNIT_CTX_HEADER"])

    local playerName, realm = UnitName(contextData.unit)
    if playerName then
        if not realm or realm == "" then realm = GetRealmName() end
        local fullName = playerName .. "-" .. realm
        local buttonText = L["UNIT_CTX_ADD_PLAYER_NOTE"]
        if notes.Players and notes.Players:GetPlayer(fullName) then
            buttonText = L["UNIT_CTX_EDIT_PLAYER_NOTE"]
        end
        rootDescription:CreateButton(buttonText, function()
            HandlePlayerAdd(contextData.unit)
        end)
    end

    local pmModule = GetPlayMountsModule()
    if pmModule and IsPlayMountsEnabled() then
        rootDescription:CreateButton(L["UNIT_CTX_ADD_MOUNT_INFO"], function()
            HandleAddMountInfo(contextData.unit)
        end)

        if IsMatchMountEnabled() then
            rootDescription:CreateButton(L["UNIT_CTX_MATCH_MOUNT"], function()
                HandleMatchMount(contextData.unit)
            end)
        end
    end
end

-- =============================================
-- NPC HANDLERS
-- =============================================

local function HandleNPCAdd(unit, npcIDNum)
    local notes = GetNotes()
    if not notes or not notes.NPCs then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NOTES_NOT_LOADED"])
        return
    end

    if not UnitExists(unit) or UnitIsPlayer(unit) then return end

    if unit ~= "target" then
        TargetUnit(unit)
        C_Timer.After(0.1, function() HandleNPCAdd("target", npcIDNum) end)
        return
    end

    local existing = notes.NPCs:GetNPC(npcIDNum)
    if existing then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NPC_EXISTS"])
        NavigateToNPC(npcIDNum)
        return
    end

    local npcName = UnitName(unit) or ("NPC " .. npcIDNum)
    local mapID   = C_Map.GetBestMapForUnit("player")
    local coords  = nil
    if mapID then
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then
            local x, y = pos:GetXY()
            coords = { x = x * 100, y = y * 100 }
        end
    end
    local mapInfo  = mapID and C_Map.GetMapInfo(mapID)
    local zoneName = (mapInfo and mapInfo.name) or GetZoneText() or ""

    local npcData = {
        id           = npcIDNum,
        name         = npcName,
        mapID        = mapID,
        zone         = zoneName,
        coords       = coords,
        category     = "Other",
        storage      = "account",
        content      = "",
        tooltipLines = {"", "", "", ""},
        alertOnFound = false,
    }

    notes.NPCs:AddNPC(npcIDNum, npcData)
    print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_NPC_ADDED"], npcName))
    NavigateToNPC(npcIDNum)
end

local function HandleNPCUpdateLocation(unit, npcIDNum)
    local notes = GetNotes()
    if not notes or not notes.NPCs then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NOTES_NOT_LOADED"])
        return
    end

    local npcData = notes.NPCs:GetNPC(npcIDNum)
    if not npcData then return end

    local mapID = C_Map.GetBestMapForUnit("player")
    local pos   = mapID and C_Map.GetPlayerMapPosition(mapID, "player")

    if mapID and pos then
        local x, y    = pos:GetXY()
        npcData.mapID  = mapID
        npcData.coords = { x = x * 100, y = y * 100 }
        local mapInfo  = C_Map.GetMapInfo(mapID)
        if mapInfo then npcData.zone = mapInfo.name end
        notes.NPCs:SaveNPC(npcIDNum, npcData)
        print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_NPC_LOC_UPDATED"],
            npcData.name or "NPC", npcData.coords.x, npcData.coords.y, npcData.zone or ""))
    else
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NPC_LOC_FAILED"])
    end
end

local function NPCContextMenuHandler(owner, rootDescription, contextData)
    if not contextData or not contextData.unit then return end
    if UnitIsPlayer(contextData.unit) then return end
    if not UnitExists(contextData.unit) then return end

    local guid = UnitGUID(contextData.unit)
    if not guid or issecretvalue(guid) then return end

    local unitType, _, _, _, _, npcIDStr = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return end

    local npcIDNum = tonumber(npcIDStr)
    if not npcIDNum then return end

    local notes = GetNotes()
    if not notes then return end

    rootDescription:CreateDivider()
    rootDescription:CreateTitle(L["UNIT_CTX_HEADER"])

    local hasExisting = notes.NPCs and (notes.NPCs:GetNPC(npcIDNum) ~= nil)
    local buttonText  = hasExisting and L["UNIT_CTX_EDIT_NPC_NOTE"] or L["UNIT_CTX_ADD_NPC_NOTE"]

    rootDescription:CreateButton(buttonText, function()
        HandleNPCAdd(contextData.unit, npcIDNum)
    end)

    if hasExisting then
        rootDescription:CreateButton(L["UNIT_CTX_UPDATE_LOCATION"], function()
            HandleNPCUpdateLocation(contextData.unit, npcIDNum)
        end)
    end
end

-- =============================================
-- INITIALIZATION
-- =============================================

function OneWoW:InitializeContextMenus()
    if not Menu or not Menu.ModifyMenu then return end

    Menu.ModifyMenu("MENU_UNIT_PLAYER",                   PlayerContextMenuHandler)
    Menu.ModifyMenu("MENU_UNIT_ENEMY_PLAYER",             PlayerContextMenuHandler)
    Menu.ModifyMenu("MENU_UNIT_FRIEND",                   PlayerContextMenuHandler)
    Menu.ModifyMenu("MENU_UNIT_COMMUNITIES_GUILD_MEMBER", PlayerContextMenuHandler)
    Menu.ModifyMenu("MENU_UNIT_PARTY",                    PlayerContextMenuHandler)
    Menu.ModifyMenu("MENU_UNIT_RAID",                     PlayerContextMenuHandler)

    Menu.ModifyMenu("MENU_UNIT_ENEMY",  NPCContextMenuHandler)
    Menu.ModifyMenu("MENU_UNIT_TARGET", NPCContextMenuHandler)
end
