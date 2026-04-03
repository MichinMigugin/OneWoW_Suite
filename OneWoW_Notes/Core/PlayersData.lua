local addonName, ns = ...
local L = ns.L

local Players = ns.DataModule:New(
    "players",
    "playerCustomCategories",
    {"General", "Friend", "Guild Member", "Acquaintance", "Trader",
     "PvP", "Blacklist", "Interesting", "Officer", "Crafter", "Helper", "Other"}
)
ns.Players = Players

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
    return self:GetDataDB(storageType)
end

function Players:GetAllPlayers()
    return self:GetAll()
end

function Players:GetPlayer(fullName)
    if not fullName then return nil end
    return self:GetAll()[fullName]
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
        sortOrder    = 0,
    }

    if addon.mainFrame and addon.mainFrame:IsShown() then
        newData.isNew = true
        newData.newTimestamp = GetServerTime()
    end

    local targetDB = self:GetDataDB(newData.storage)
    targetDB[fullName] = newData
    self:InvalidateCache()
    return fullName
end

function Players:SavePlayer(fullName, playerData)
    if not fullName or not playerData then return end
    playerData.modified = GetServerTime()
    local targetDB = self:GetDataDB(playerData.storage or "account")
    targetDB[fullName] = playerData
    self:InvalidateCache()
end

function Players:RemovePlayer(fullName)
    self:Remove(fullName)
end

function Players:Initialize()
    self:EnsureDB()

    if not Players._targetFrame then
        Players._targetFrame = CreateFrame("Frame")
        Players._targetFrame:SetScript("OnEvent", function(_, event)
            if event ~= "PLAYER_TARGET_CHANGED" then return end
            if not UnitExists("target") or not UnitIsPlayer("target") or UnitIsUnit("target", "player") then return end
            C_Timer.After(0, function()
                if not UnitExists("target") or not UnitIsPlayer("target") or UnitIsUnit("target", "player") then return end
                for fullName, playerData in pairs(Players:GetAll()) do
                    if playerData.soundEnabled and UnitIsUnit("target", fullName) then
                        print("|cFFFFD100OneWoW - Players:|r " .. string.format(L["NOTES_PLAYER_ALERT_FOUND"] or "Targeted player with note: %s", fullName))
                        PlaySound(SOUNDKIT.RAID_WARNING)
                        break
                    end
                end
            end)
        end)
        Players._targetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    end
end
