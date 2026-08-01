local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

local tinsert, ipairs, strfind = tinsert, ipairs, strfind
local pairs, tonumber, tconcat = pairs, tonumber, table.concat
local C_MountJournal = C_MountJournal

local Players = ns.DataModule:New(
    "players",
    "playerCustomCategories",
    {"General", "Friend", "Guild Member", "Acquaintance", "Trader",
     "PvP", "Blacklist", "Interesting", "Officer", "Crafter", "Helper"}
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
-- Collectible references ("sightings")
-- ---------------------------------------------------------------------------
-- A structured record that a player is associated with a collectible (e.g. seen
-- riding a mount). Replaces the old "search the note body for a link substring"
-- dedup with a first-class list, while still recognizing legacy notes whose only
-- trace of the sighting is the embedded collectible hyperlink. The field is
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
--- source of truth; the content fallback keeps legacy notes deduping until the
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

    -- Backward-compat: legacy notes stored the sighting only as the collectible
    -- hyperlink in the note body ("|Honewowcollectible:<key>|h...").
    if player.content and player.content ~= "" then
        if strfind(player.content, "onewowcollectible:" .. key, 1, true) then
            return true
        end
    end

    return false
end

-- ---------------------------------------------------------------------------
-- Legacy mount-blob migration
-- ---------------------------------------------------------------------------
-- The original "Add Mount Info" wrote a multi-line blob into the player note:
--   Mount: <spell hyperlink>\nType: …\nSource: …\nStatus: …
-- That was replaced with a single thin `Mount: <collectible link>` line plus a
-- shared collectible row and a structured ref. This one-time pass upgrades any
-- surviving legacy blob: the embedded `|Hspell:<id>|h` resolves to a mount, so
-- each such note gets its collectible row + ref and its blob block rewritten to
-- the thin link. Notes already in the thin-link format carry `onewowcollectible:`
-- (not a spell link), so they never match. Gated by a global flag so the scan
-- runs once per account.

-- Split a note body into its `\n\n`-delimited blocks (the granularity the old
-- writer appended each mount blob at).
local function SplitBlocks(s)
    local blocks, pos = {}, 1
    while true do
        local a, b = strfind(s, "\n\n", pos, true)
        if not a then
            blocks[#blocks + 1] = s:sub(pos)
            break
        end
        blocks[#blocks + 1] = s:sub(pos, a - 1)
        pos = b + 1
    end
    return blocks
end

-- Thin replacement line for a migrated mount blob. Uses the Blizzard MOUNT global
-- (locale-safe, no cross-scope core-locale dependency) + the clickable collectible
-- link, matching what new sightings write visually.
local function BuildMountRefLine(key)
    local link
    if ns.NotesHyperlinks and ns.NotesHyperlinks.BuildCollectibleLink then
        link = ns.NotesHyperlinks:BuildCollectibleLink(key)
    end
    if not link then
        local display = OneWoW.Collectibles.ResolveDisplay(key)
        link = display and display.name
    end
    if not link then return nil end
    return MOUNT .. ": " .. link
end

-- Rewrite one note's legacy mount blob(s) in place. Returns true if it changed.
function Players:MigrateMountBlobForNote(fullName, record)
    local content = record.content
    if type(content) ~= "string" or content == "" then return false end
    if not strfind(content, "Hspell:", 1, true) then return false end

    local blocks = SplitBlocks(content)
    local changed = false

    for i, block in ipairs(blocks) do
        local mountID, spellID
        for s in block:gmatch("Hspell:(%d+)") do
            local sid = tonumber(s)
            local mid = sid and C_MountJournal.GetMountFromSpell(sid)
            if mid then
                mountID, spellID = mid, sid
                break
            end
        end

        if mountID then
            local key = OneWoW.Collectibles.BuildKey("mount", mountID)
            local line = key and BuildMountRefLine(key)
            if key and line then
                -- Create the shared collectible row once (never clobber an existing
                -- one), mirroring the ContextMenus upsert.
                if ns.Collectibles and not ns.Collectibles:GetCollectible(key) then
                    ns.Collectibles:UpsertCollectible(key)
                end
                blocks[i] = line
                changed = true
                self:AddCollectibleRef(fullName, key, spellID)
            end
        end
    end

    if changed then
        record.content = tconcat(blocks, "\n\n")
    end
    return changed
end

--- One-time account-wide pass that upgrades legacy mount blobs to the thin
--- ref + shared collectible row. Idempotent (gated by a global flag; re-running
--- is a no-op). Safe to call at login after the Players module is initialized.
function Players:MigrateLegacyMountBlobs()
    if ns.db.global.collectibleMountMigrated then return end

    -- Snapshot first: SavePlayer/AddCollectibleRef invalidate the merged cache, so
    -- mutating while iterating self:GetAll() would be undefined.
    local snapshot = {}
    for fullName, record in pairs(self:GetAll()) do
        if type(record) == "table" then
            snapshot[#snapshot + 1] = { fullName = fullName, record = record }
        end
    end

    for _, entry in ipairs(snapshot) do
        if self:MigrateMountBlobForNote(entry.fullName, entry.record) then
            entry.record._collectibleMountMigrated = true
            self:SavePlayer(entry.fullName, entry.record)
        end
    end

    ns.db.global.collectibleMountMigrated = true
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
