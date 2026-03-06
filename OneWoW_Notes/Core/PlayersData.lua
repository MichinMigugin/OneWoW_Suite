-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/PlayersData.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local Players = {}
ns.Players = Players

local PLAYER_CATEGORIES = {
    "General", "Friend", "Guild Member", "Acquaintance", "Trader",
    "PvP", "Blacklist", "Interesting", "Officer", "Crafter", "Helper", "Other"
}

local CLASS_TO_PIN = {
    WARRIOR = "warrior", PALADIN = "paladin", HUNTER = "hunter", ROGUE = "rogue",
    PRIEST = "priest", DEATHKNIGHT = "deathknight", SHAMAN = "shaman", MAGE = "mage",
    WARLOCK = "warlock", MONK = "monk", DRUID = "druid", DEMONHUNTER = "demonhunter",
    EVOKER = "evoker"
}

function Players:GetPinColorKey(class)
    if not class then return "hunter" end
    return CLASS_TO_PIN[class:upper()] or "hunter"
end

function Players:GetNotesDB(storageType)
    local addon = _G.OneWoW_Notes
    if storageType == "character" then return addon.db.char.players
    else return addon.db.global.players end
end

function Players:GetAllPlayers()
    local addon = _G.OneWoW_Notes
    local all = {}
    if addon.db.global.players then
        for name, data in pairs(addon.db.global.players) do
            all[name] = data
            if type(data) == "table" then data.storage = "account" end
        end
    end
    if addon.db.char.players then
        for name, data in pairs(addon.db.char.players) do
            all[name] = data
            if type(data) == "table" then data.storage = "character" end
        end
    end
    return all
end

function Players:GetPlayer(fullName)
    if not fullName then return nil end
    return self:GetAllPlayers()[fullName]
end

function Players:GetTargetPlayerInfo()
    if not UnitExists("target") or not UnitIsPlayer("target") then return nil end
    local name, realm = UnitName("target")
    if not name then return nil end
    if not realm or realm == "" then realm = GetRealmName() or "Unknown" end
    local fullName = name .. "-" .. realm
    local _, class = UnitClass("target")
    local _, race  = UnitRace("target")
    local level    = UnitLevel("target")
    local guild    = GetGuildInfo("target") or ""
    local _, faction = UnitFactionGroup("target")
    return {
        fullName = fullName,
        name     = name,
        realm    = realm,
        class    = class and class:upper() or "WARRIOR",
        race     = race or "",
        level    = level or 1,
        guild    = guild,
        faction  = faction or "",
    }
end

function Players:AddPlayer(fullName, playerInfo)
    local addon = _G.OneWoW_Notes
    if not fullName or not playerInfo then return end

    local newData = {
        fullName     = fullName,
        name         = playerInfo.name or fullName,
        realm        = playerInfo.realm or "",
        class        = playerInfo.class or "",
        race         = playerInfo.race or "",
        level        = playerInfo.level or 0,
        guild        = playerInfo.guild or "",
        faction      = playerInfo.faction or "",
        category     = playerInfo.category or "General",
        storage      = playerInfo.storage or "account",
        content      = playerInfo.content or "",
        tooltipLines = playerInfo.tooltipLines or {"", "", "", ""},
        soundEnabled = playerInfo.soundEnabled or false,
        favorite     = playerInfo.favorite or false,
        created      = GetServerTime(),
        modified     = GetServerTime(),
    }

    if addon.mainFrame and addon.mainFrame:IsShown() then
        newData.isNew = true
        newData.newTimestamp = GetServerTime()
    end

    local targetDB = self:GetNotesDB(newData.storage)
    targetDB[fullName] = newData
    return fullName
end

function Players:SavePlayer(fullName, playerData)
    if not fullName or not playerData then return end
    playerData.modified = GetServerTime()
    local targetDB = self:GetNotesDB(playerData.storage or "account")
    targetDB[fullName] = playerData
end

function Players:RemovePlayer(fullName)
    if not fullName then return end
    local addon = _G.OneWoW_Notes
    if addon.db.global.players then addon.db.global.players[fullName] = nil end
    if addon.db.char.players   then addon.db.char.players[fullName]   = nil end
end

function Players:GetCategories()
    local addon = _G.OneWoW_Notes
    local all = {}
    for _, c in ipairs(PLAYER_CATEGORIES) do table.insert(all, c) end
    if addon.db.global.playerCustomCategories then
        for _, c in ipairs(addon.db.global.playerCustomCategories) do table.insert(all, c) end
    end
    return all
end

function Players:EnableScanning()
    local addon = _G.OneWoW_Notes
    addon.db.global.playerScanEnabled = true
    Players._scanningActive = true
    if Players._scanFrame then
        Players._scanFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    end
end

function Players:DisableScanning()
    local addon = _G.OneWoW_Notes
    addon.db.global.playerScanEnabled = false
    Players._scanningActive = false
    if Players._scanFrame then
        Players._scanFrame:UnregisterEvent("PLAYER_TARGET_CHANGED")
    end
end

function Players:IsScanning()
    return Players._scanningActive == true
end

function Players:Initialize()
    local addon = _G.OneWoW_Notes
    if not addon.db.global.players then addon.db.global.players = {} end
    if not addon.db.char.players   then addon.db.char.players   = {} end

    Players._scanningActive = addon.db.global.playerScanEnabled ~= false

    -- Dedicated frame so it doesn't conflict with NPCs registering the same event
    Players._scanFrame = CreateFrame("Frame")
    Players._scanFrame:SetScript("OnEvent", function(_, event)
        if event ~= "PLAYER_TARGET_CHANGED" then return end
        if not Players._scanningActive then return end
        if not UnitExists("target") or not UnitIsPlayer("target") then return end
        local name, realm = UnitName("target")
        if not name or name == UnitName("player") then return end
        if not realm or realm == "" then realm = GetRealmName() or "Unknown" end
        local fullName = name .. "-" .. realm
        local existing = Players:GetPlayer(fullName)
        if existing and existing.soundEnabled then
            print("|cFFFFD100OneWoW - Players:|r " .. string.format(L["NOTES_PLAYER_ALERT_FOUND"] or "Targeted player with note: %s", fullName))
            PlaySound(SOUNDKIT.RAID_WARNING)
        end
    end)

    if Players._scanningActive then
        Players._scanFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    end
end
