local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local tinsert, ipairs, strfind = tinsert, ipairs, strfind

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

--- Snapshot of a player unit for new note creation.
---@param unit string?
---@return table|nil playerInfo
function Players:GetPlayerInfoFromUnit(unit)
    unit = unit or "target"
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return nil end
    local name, realm = UnitName(unit)
    if not name then return nil end
    local displayRealm = (realm ~= "" and realm) or GetRealmName()
    local fullName = OneWoW_GUI:GetCharacterKey(name, realm ~= "" and realm or nil)
    if not fullName then return nil end
    local _, class = UnitClass(unit)
    local _, race  = UnitRace(unit)
    local level    = UnitLevel(unit)
    local guild    = GetGuildInfo(unit) or ""
    local _, faction = UnitFactionGroup(unit)
    return {
        fullName = fullName,
        name     = name,
        realm    = displayRealm,
        class    = class and class:upper() or "WARRIOR",
        race     = race or "",
        level    = level or 1,
        guild    = guild,
        faction  = faction or "",
    }
end

function Players:GetTargetPlayerInfo()
    return self:GetPlayerInfoFromUnit("target")
end

function Players:AddPlayer(fullName, playerInfo)
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

    if ns.mainFrame and ns.mainFrame:IsShown() then
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

-- ---------------------------------------------------------------------------
-- Collectible references (v2-C "sightings")
-- ---------------------------------------------------------------------------
-- A structured record that a player is associated with a collectible (e.g. seen
-- riding a mount). Replaces the old "search the note body for a link substring"
-- dedup with a first-class list, while still recognizing pre-v2-C notes whose
-- only trace of the sighting is the embedded collectible hyperlink. The field is
-- created lazily on first add — players without sightings carry no empty table.

--- Records a collectible reference on a player. Idempotent per canonical key.
--- The optional spellID is kept for sighting context but dropped if it is a
--- secret value (another unit's aura data in instanced content is opaque).
---@param fullName string
---@param key string canonical collectible key
---@param spellID number|nil
---@return boolean added true when a new ref was stored
function Players:AddCollectibleRef(fullName, key, spellID)
    key = OneWoW.Collectibles.CanonicalizeKey(key)
    if not key then return false end

    local player = self:GetPlayer(fullName)
    if not player then return false end

    player.collectibleRefs = player.collectibleRefs or {}
    for _, ref in ipairs(player.collectibleRefs) do
        if ref.key == key then return false end
    end

    local safeSpellID
    if spellID ~= nil and not OneWoW.Restriction.IsSecret(spellID) then
        safeSpellID = spellID
    end

    tinsert(player.collectibleRefs, {
        key = key,
        spellID = safeSpellID,
        addedAt = GetServerTime(),
    })
    self:SavePlayer(fullName, player)
    return true
end

--- True if the player already references a collectible. Structured refs are the
--- source of truth; the content fallback keeps pre-v2-C notes deduping until the
--- next add upgrades them to a structured ref.
---@param fullName string
---@param key string canonical collectible key
---@return boolean
function Players:HasCollectibleRef(fullName, key)
    key = OneWoW.Collectibles.CanonicalizeKey(key)
    if not key then return false end

    local player = self:GetPlayer(fullName)
    if not player then return false end

    if player.collectibleRefs then
        for _, ref in ipairs(player.collectibleRefs) do
            if ref.key == key then return true end
        end
    end

    -- Backward-compat: before v2-C the sighting lived only as the collectible
    -- hyperlink in the note body ("|Honewowcollectible:<key>|h...").
    if player.content and player.content ~= "" then
        if strfind(player.content, "onewowcollectible:" .. key, 1, true) then
            return true
        end
    end

    return false
end

function Players:Initialize()
    if not Players._targetFrame then
        Players._targetFrame = CreateFrame("Frame")
        Players._targetFrame:SetScript("OnEvent", function(_, event)
            if event ~= "PLAYER_TARGET_CHANGED" then return end
            if not UnitExists("target") or not UnitIsPlayer("target") or UnitIsUnit("target", "player") then return end
            C_Timer.After(0, function()
                if not UnitExists("target") or not UnitIsPlayer("target") or UnitIsUnit("target", "player") then return end
                for fullName, playerData in pairs(Players:GetAll()) do
                    if playerData.soundEnabled and UnitIsUnit("target", fullName) then
                        print("|cFFFFD100OneWoW - Players:|r " .. string.format(L["NOTES_PLAYER_ALERT_FOUND"], fullName))
                        PlaySound(SOUNDKIT.RAID_WARNING)
                        break
                    end
                end
            end)
        end)
        Players._targetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    end
end
