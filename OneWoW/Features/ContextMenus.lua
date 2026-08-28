local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local strfind = strfind

-- ns, not the Facade global: this file loads before Core/Facade.lua.
local Location = ns.Location

local L = ns.L

local function WithUnitAsTarget(unit, fn)
    if unit ~= "target" then
        TargetUnit(unit)
        C_Timer.After(0.1, function() fn("target") end)
        return
    end
    fn(unit)
end

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
    OneWoW.UI:Show("catalog")
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
    if not OneWoW_Notes_API or not OneWoW_Notes_API.GetPlayer or not OneWoW_Notes_API.GetPlayerInfoFromUnit then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NOTES_NOT_LOADED"])
        return
    end

    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end

    WithUnitAsTarget(unit, function(targetUnit)
        local playerInfo = OneWoW_Notes_API.GetPlayerInfoFromUnit(targetUnit)
        if not playerInfo then return end

        local existing = OneWoW_Notes_API.GetPlayer(playerInfo.fullName)
        if existing then
            print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_PLAYER_EXISTS"], playerInfo.name))
            NavigateToPlayer(playerInfo.fullName)
            return
        end

        OneWoW_Notes_API.AddPlayer(playerInfo.fullName, playerInfo)
        print("|cFFFFD100OneWoW:|r " .. string.format(L["ADDED_PLAYER_S"], playerInfo.name))
    end)
end

local function HandleAddMountInfo(unit)
    if not OneWoW_Notes_API or not OneWoW_Notes_API.GetPlayer or not OneWoW_Notes_API.GetPlayerInfoFromUnit then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NOTES_NOT_LOADED"])
        return
    end

    local pmModule = GetPlayMountsModule()
    if not pmModule then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_PLAYMOUNTS_NOT_LOADED"])
        return
    end

    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end

    WithUnitAsTarget(unit, function(targetUnit)
        local mountInfo = pmModule:DetectMountOnUnit(targetUnit)
        if not mountInfo then
            local playerName = UnitName(targetUnit) or "Player"
            print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_PLAYER_NOT_MOUNTED"], playerName))
            return
        end

        local playerInfo = OneWoW_Notes_API.GetPlayerInfoFromUnit(targetUnit)
        if not playerInfo then return end

        -- Build the reference line + a dedup needle. A real mount becomes a single
        -- canonical collectible row (created once, shared across every player that
        -- rides it) plus a thin `(collectible=)` link in the player note — the
        -- mount's type/source/status now live on the collectible row (resolved live
        -- in the Collectibles tab), not duplicated into each player note. Movement
        -- forms (Travel Form, etc.) have no mount id, so they stay a plain text line.
        -- collectibleKey is nil for movement forms (Travel Form, etc.), which have
        -- no mount id and stay a plain-text line; a real mount carries a canonical
        -- key that drives both the shared collectible row and the structured
        -- per-player ref (dedup / sighting).
        local refText, dedupNeedle, collectibleKey, mountSpellID
        if mountInfo.isMovementForm then
            refText = string.format(L["UNIT_CTX_MOUNT_MOVEMENT_FORM"], mountInfo.name)
            dedupNeedle = refText
        else
            -- playmounts:DetectMountOnUnit only resolves a mount from a non-secret
            -- aura spellId (it gates on OneWoW.Restriction.IsSecret), so a returned
            -- mountID is always a plain, resolvable number even in instanced content.
            -- Still bail with a user-visible message if a canonical key can't be
            -- built rather than writing a bad reference.
            local key = OneWoW_Notes_API.BuildMountKey and OneWoW_Notes_API.BuildMountKey(mountInfo.mountID)
            if not key then
                print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_MOUNT_UNIDENTIFIED"], playerInfo.name))
                return
            end

            -- Ensure the shared collectible row exists (defaults to "General" on
            -- create); never touch an existing row so the user's own category/intent
            -- survives re-adding the mount from another player.
            if not OneWoW_Notes_API.GetCollectible(key) then
                OneWoW_Notes_API.UpsertCollectible(key)
            end

            local link = OneWoW_Notes_API.BuildCollectibleLink and OneWoW_Notes_API.BuildCollectibleLink(key)
            if not link then
                link = C_Spell.GetSpellLink(mountInfo.spellID or mountInfo.spellId) or mountInfo.name
            end
            refText = string.format(L["UNIT_CTX_MOUNT_LABEL"], link)
            collectibleKey = key
            mountSpellID = mountInfo.spellID or mountInfo.spellId
        end

        local fullName = playerInfo.fullName
        local existing = OneWoW_Notes_API.GetPlayer(fullName)
        if existing then
            -- Dedup on the structured collectible ref for real mounts (also matches
            -- legacy notes that only embedded the link); movement forms have no
            -- key, so they fall back to the plain-text needle.
            local alreadyRecorded
            if collectibleKey then
                alreadyRecorded = OneWoW_Notes_API.PlayerHasCollectibleRef(fullName, collectibleKey)
            else
                local currentNote = existing.content or ""
                alreadyRecorded = currentNote ~= "" and strfind(currentNote, dedupNeedle, 1, true) ~= nil
            end

            if alreadyRecorded then
                print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_MOUNT_INFO_ALREADY_RECORDED"], playerInfo.name))
                return
            end

            local currentNote = existing.content or ""
            if currentNote ~= "" then
                existing.content = currentNote .. "\n\n" .. refText
            else
                existing.content = refText
            end
            OneWoW_Notes_API.SavePlayer(fullName, existing)
            if collectibleKey then
                OneWoW_Notes_API.AddPlayerCollectibleRef(fullName, collectibleKey, mountSpellID)
            end
            print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_MOUNT_INFO_APPENDED"], playerInfo.name))
        else
            playerInfo.content = refText
            OneWoW_Notes_API.AddPlayer(fullName, playerInfo)
            if collectibleKey then
                OneWoW_Notes_API.AddPlayerCollectibleRef(fullName, collectibleKey, mountSpellID)
            end
            print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_MOUNT_INFO_CREATED"], playerInfo.name))
        end

        if OneWoW_Notes_API.RefreshPlayersTab then
            OneWoW_Notes_API.RefreshPlayersTab(fullName)
        end
    end)
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

    WithUnitAsTarget(unit, function(targetUnit)
        local mountInfo = pmModule:DetectMountOnUnit(targetUnit)
        if not mountInfo then
            local playerName = UnitName(targetUnit) or "Player"
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
    end)
end

local function HandleSelfWayPin()
    OneWoW:BringUp("OneWoW_Notes")
    local mapID, x, y = Location.GetPlayerLocation()
    if not mapID or not x then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NPC_LOC_FAILED"])
        return
    end
    if OneWoW_Notes_API and OneWoW_Notes_API.OpenWayPinEditor then
        OneWoW_Notes_API.OpenWayPinEditor({
            title  = UnitName("player"),
            mapID  = mapID,
            x      = x,
            y      = y,
            source = "self",
        })
        return
    end
    if not OneWoW_Notes_API or not OneWoW_Notes_API.AddWayPin then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NOTES_NOT_LOADED"])
        return
    end
    OneWoW_Notes_API.AddWayPin({
        title  = UnitName("player"),
        mapID  = mapID,
        x      = x,
        y      = y,
        source = "self",
    })
end

local function PlayerContextMenuHandler(_, rootDescription, contextData)
    if not contextData or not contextData.unit then return end
    if not UnitIsPlayer(contextData.unit) then return end

    local isSelf = UnitIsUnit(contextData.unit, "player")
    local hasNotesPlayer = OneWoW_Notes_API and OneWoW_Notes_API.GetPlayer
    if not isSelf and not hasNotesPlayer then return end

    rootDescription:CreateDivider()
    rootDescription:CreateTitle(L["UNIT_CTX_HEADER"])

    if isSelf then
        rootDescription:CreateButton(L["UNIT_CTX_ADD_WAYPIN_HERE"], function()
            HandleSelfWayPin()
        end)
    end

    if hasNotesPlayer then
        local playerName, realm = UnitName(contextData.unit)
        if playerName then
            local fullName = OneWoW_GUI:GetCharacterKey(playerName, realm ~= "" and realm or nil)
            if fullName then
                local buttonText = L["UNIT_CTX_ADD_PLAYER_NOTE"]
                if OneWoW_Notes_API.GetPlayer(fullName) then
                    buttonText = L["UNIT_CTX_EDIT_NPC_NOTE"]
                end
                rootDescription:CreateButton(buttonText, function()
                    HandlePlayerAdd(contextData.unit)
                end)
            end
        end
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

    WithUnitAsTarget(unit, function(targetUnit)
        local existing = OneWoW_Notes_API.GetNPC(npcIDNum)
        if existing then
            print("|cFFFFD100OneWoW:|r " .. L["NPC_NOTE_ALREADY_EXISTS"])
            NavigateToNPC(npcIDNum)
            return
        end

        local npcName = UnitName(targetUnit) or ("NPC " .. npcIDNum)
        local mapID, x, y = Location.GetPlayerLocation()
        local coords = x and { x = x, y = y } or nil
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
    end)
end

local function HandleNPCUpdateLocation(_, npcIDNum)
    if not OneWoW_Notes_API or not OneWoW_Notes_API.GetNPC then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NOTES_NOT_LOADED"])
        return
    end

    local npcData = OneWoW_Notes_API.GetNPC(npcIDNum)
    if not npcData then return end

    local mapID, x, y = Location.GetPlayerLocation()

    if mapID and x then
        npcData.mapID  = mapID
        npcData.coords = { x = x, y = y }
        local mapInfo  = C_Map.GetMapInfo(mapID)
        if mapInfo then npcData.zone = mapInfo.name end
        OneWoW_Notes_API.SaveNPC(npcIDNum, npcData)
        print("|cFFFFD100OneWoW:|r " .. string.format(L["UNIT_CTX_NPC_LOC_UPDATED"],
            npcData.name or "NPC", npcData.coords.x, npcData.coords.y, npcData.zone or ""))
    else
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NPC_LOC_FAILED"])
    end
end

local function HandleNPCWayPin(unit, npcIDNum)
    OneWoW:BringUp("OneWoW_Notes")
    if not OneWoW_Notes_API or not OneWoW_Notes_API.AddWayPin then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NOTES_NOT_LOADED"])
        return
    end

    local name = UnitName(unit)
    local mapID, x, y
    local existing = OneWoW_Notes_API.GetNPC and OneWoW_Notes_API.GetNPC(npcIDNum)
    if existing and existing.mapID and existing.coords then
        mapID, x, y = existing.mapID, existing.coords.x, existing.coords.y
    else
        mapID, x, y = Location.GetPlayerLocation()
    end
    if not mapID or not x then
        print("|cFFFFD100OneWoW:|r " .. L["UNIT_CTX_NPC_LOC_FAILED"])
        return
    end

    OneWoW_Notes_API.AddWayPin({
        title     = name or ("NPC " .. tostring(npcIDNum)),
        mapID     = mapID,
        x         = x,
        y         = y,
        source    = "npc",
        sourceKey = npcIDNum,
    })
end

local function NPCContextMenuHandler(_, rootDescription, contextData)
    if not contextData or not contextData.unit then return end
    if UnitIsPlayer(contextData.unit) then return end
    if not UnitExists(contextData.unit) then return end

    local guid = UnitGUID(contextData.unit)
    if not guid or ns.Restriction.IsSecret(guid) then return end

    local unitType, _, _, _, _, npcIDStr = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return end

    local npcIDNum = tonumber(npcIDStr)
    if not npcIDNum then return end

    local hasNotesMenu = OneWoW_Notes_API and OneWoW_Notes_API.GetNPC
    local hasVendor = CatalogHasVendor(npcIDNum)

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

    rootDescription:CreateButton(L["UNIT_CTX_ADD_WAYPIN"], function()
        HandleNPCWayPin(contextData.unit, npcIDNum)
    end)

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
    Menu.ModifyMenu("MENU_UNIT_SELF",                     PlayerContextMenuHandler)
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
