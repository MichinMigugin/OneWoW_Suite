local _, ns = ...
local L = ns.L

local function NavigateToPlayer(fullName)
    if not OneWoW_Notes_API or not OneWoW_Notes_API.OpenPlayer then return end
    OneWoW_Notes_API.OpenPlayer(fullName)
end

local function NavigateToNPC(npcID)
    if not OneWoW_Notes_API or not OneWoW_Notes_API.OpenNPC then return end
    OneWoW_Notes_API.OpenNPC(npcID)
end

local function GetPlayMountsModule()
    if not OneWoW_QoL_API then return nil end
    return OneWoW_QoL_API.GetModule("playmounts")
end

local function IsPlayMountsEnabled()
    if not OneWoW_QoL_API then return false end
    return OneWoW_QoL_API.IsModuleEnabled("playmounts", false)
end

local function IsMatchMountEnabled()
    if not OneWoW_QoL_API then return true end
    if not OneWoW_QoL_API.IsModuleEnabled("playmounts", false) then
        return false
    end
    return OneWoW_QoL_API.GetModuleToggle("playmounts", "enableMatchMount", true)
end

local function CatalogHasVendor(npcID)
    local api = OneWoW_CatalogData_Vendors_API
    if not api or not api.GetAllVendors then return false end
    local allVendors = api.GetAllVendors()
    return allVendors and allVendors[npcID] ~= nil
end

local function HandleOpenVendorDetails(npcIDNum)
    if OneWoW_Catalog_API then
        OneWoW_Catalog_API.OpenToVendor(npcIDNum)
        return
    end
    if not OneWoW or not ns.UI then return end
    ns.UI:Show("catalog")
    C_Timer.After(0.25, function()
        if OneWoW_Catalog_API then
            OneWoW_Catalog_API.OpenToVendor(npcIDNum)
        end
    end)
end

-- =============================================
-- PLAYER HANDLERS
-- =============================================

local function HandlePlayerAdd(unit)
    if not OneWoW_Notes_API or not OneWoW_Notes_API.GetPlayer then
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

    local existing = OneWoW_Notes_API.GetPlayer(fullName)
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

    OneWoW_Notes_API.AddPlayer(fullName, playerData)
    print("|cFFFFD100OneWoW:|r " .. string.format(L["ADDED_PLAYER_S"], playerName))
end

local function HandleAddMountInfo(unit)
    if not OneWoW_Notes_API or not OneWoW_Notes_API.GetPlayer then
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
            mountText = mountText .. "\n" .. string.format(L["TYPE_S"], mountInfo.mountTypeName)
        end
        if mountInfo.sourceText and mountInfo.sourceText ~= "" then
            mountText = mountText .. "\n" .. string.format(L["UNIT_CTX_MOUNT_SOURCE"], mountInfo.sourceText)
        end
        if mountInfo.isCollected ~= nil then
            local status = mountInfo.isCollected and COLLECTED or NOT_COLLECTED
            mountText = mountText .. "\n" .. string.format(L["UNIT_CTX_MOUNT_STATUS"], status)
        end
    end

    local existing = OneWoW_Notes_API.GetPlayer(fullName)
    if existing then
        local currentNote = existing.content or ""
        if currentNote ~= "" then
            existing.content = currentNote .. "\n\n" .. mountText
        else
            existing.content = mountText
        end
        OneWoW_Notes_API.SavePlayer(fullName, existing)
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
        OneWoW_Notes_API.AddPlayer(fullName, playerData)
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

local function PlayerContextMenuHandler(_, rootDescription, contextData)
    if not contextData or not contextData.unit then return end
    if not UnitIsPlayer(contextData.unit) then return end

    if not OneWoW_Notes_API or not OneWoW_Notes_API.GetPlayer then return end

    rootDescription:CreateDivider()
    rootDescription:CreateTitle(L["UNIT_CTX_HEADER"])

    local playerName, realm = UnitName(contextData.unit)
    if playerName then
        if not realm or realm == "" then realm = GetRealmName() end
        local fullName = playerName .. "-" .. realm
        local buttonText = L["UNIT_CTX_ADD_PLAYER_NOTE"]
        if OneWoW_Notes_API.GetPlayer(fullName) then
            buttonText = L["UNIT_CTX_EDIT_NPC_NOTE"]
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
    if not OneWoW_Notes_API or not OneWoW_Notes_API.GetNPC then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NOTES_NOT_LOADED"])
        return
    end

    if not UnitExists(unit) or UnitIsPlayer(unit) then return end

    if unit ~= "target" then
        TargetUnit(unit)
        C_Timer.After(0.1, function() HandleNPCAdd("target", npcIDNum) end)
        return
    end

    local existing = OneWoW_Notes_API.GetNPC(npcIDNum)
    if existing then
        print("|cFFFFD100OneWoW:|r " .. L["NPC_NOTE_ALREADY_EXISTS"])
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

    OneWoW_Notes_API.AddNPC(npcIDNum, npcData)
    print("|cFFFFD100OneWoW:|r " .. string.format(L["ADDED_NPC_S"], npcName))
    NavigateToNPC(npcIDNum)
end

local function HandleNPCUpdateLocation(_, npcIDNum)
    if not OneWoW_Notes_API or not OneWoW_Notes_API.GetNPC then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NOTES_NOT_LOADED"])
        return
    end

    local npcData = OneWoW_Notes_API.GetNPC(npcIDNum)
    if not npcData then return end

    local mapID = C_Map.GetBestMapForUnit("player")
    local pos   = mapID and C_Map.GetPlayerMapPosition(mapID, "player")

    if mapID and pos then
        local x, y    = pos:GetXY()
        npcData.mapID  = mapID
        npcData.coords = { x = x * 100, y = y * 100 }
        local mapInfo  = C_Map.GetMapInfo(mapID)
        if mapInfo then npcData.zone = mapInfo.name end
        OneWoW_Notes_API.SaveNPC(npcIDNum, npcData)
        print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_NPC_LOC_UPDATED"],
            npcData.name or "NPC", npcData.coords.x, npcData.coords.y, npcData.zone or ""))
    else
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NPC_LOC_FAILED"])
    end
end

local function NPCContextMenuHandler(_, rootDescription, contextData)
    if not contextData or not contextData.unit then return end
    if UnitIsPlayer(contextData.unit) then return end
    if not UnitExists(contextData.unit) then return end

    local guid = UnitGUID(contextData.unit)
    if not guid or issecretvalue(guid) then return end

    local unitType, _, _, _, _, npcIDStr = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return end

    local npcIDNum = tonumber(npcIDStr)
    if not npcIDNum then return end

    local hasNotesMenu = OneWoW_Notes_API and OneWoW_Notes_API.GetNPC
    local hasVendor = CatalogHasVendor(npcIDNum)

    if not hasNotesMenu and not hasVendor then return end

    rootDescription:CreateDivider()
    rootDescription:CreateTitle(L["UNIT_CTX_HEADER"])

    if hasNotesMenu then
        local hasExisting = OneWoW_Notes_API.GetNPC(npcIDNum) ~= nil
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

    if hasVendor then
        rootDescription:CreateButton(L["UNIT_CTX_OPEN_VENDOR_DETAILS"], function()
            HandleOpenVendorDetails(npcIDNum)
        end)
    end
end

-- =============================================
-- INITIALIZATION
-- =============================================

function ns:InitializeContextMenus()
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

ns:RegisterCoreLoginHandler("ContextMenus", function()
    ns:InitializeContextMenus()
end, "early")
