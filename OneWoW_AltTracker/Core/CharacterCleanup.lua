local _, ns = ...

-- Cross-database character scan + purge. Relocated from UI/t-settings.lua so the
-- core Roles & Alts tab can drive it through OneWoW_AltTracker_API without the
-- logic living in a UI file. Sees every AltTracker sub-store plus optional
-- Catalog data stores; all lookups are guarded so absent modules are skipped.

local ns_CharacterCleanup = {}
ns.CharacterCleanup = ns_CharacterCleanup

local pairs, ipairs, type = pairs, ipairs, type
local tinsert, sort = tinsert, sort

--- Every character key known to any OneWoW database, with the stores each was
--- found in. Sorted by last login (most recent first), then name.
---@return table[] characters { key, name, realm, class, className, level, lastLogin, sources }
function ns_CharacterCleanup:CollectAll()
    local charMap = {}

    if OneWoW_AltTracker_Character_API then
        for charKey, data in pairs(OneWoW_AltTracker_Character_API.GetAllCharacters()) do
            if type(charKey) == "string" then
                if not charMap[charKey] then
                    charMap[charKey] = {
                        key = charKey,
                        name = data.name or charKey:match("^(.+)-"),
                        realm = data.realm or charKey:match("-(.+)$"),
                        class = data.class,
                        className = data.className,
                        level = data.level,
                        lastLogin = data.lastLogin,
                        sources = {},
                    }
                end
                charMap[charKey].sources["Character"] = true
            end
        end
    end

    local simpleDBs = {
        { global = "OneWoW_AltTracker_Professions_DB", label = "Professions" },
        { global = "OneWoW_AltTracker_Endgame_DB",     label = "Endgame" },
        { global = "OneWoW_AltTracker_Storage_DB",      label = "Storage" },
        { global = "OneWoW_AltTracker_Auctions_DB",     label = "Auctions" },
        { global = "OneWoW_AltTracker_Collections_DB",  label = "Collections" },
    }

    for _, dbInfo in ipairs(simpleDBs) do
        local db = _G[dbInfo.global]
        if db and db.characters then
            for charKey, _ in pairs(db.characters) do
                if type(charKey) == "string" then
                    if not charMap[charKey] then
                        charMap[charKey] = {
                            key = charKey,
                            name = charKey:match("^(.+)-"),
                            realm = charKey:match("-(.+)$"),
                            sources = {},
                        }
                    end
                    charMap[charKey].sources[dbInfo.label] = true
                end
            end
        end
    end

    local accountingTx = OneWoW_AltTracker_Accounting_API and OneWoW_AltTracker_Accounting_API.GetTransactions()
    if accountingTx then
        local seen = {}
        for _, tx in ipairs(accountingTx) do
            if tx.character and not seen[tx.character] then
                seen[tx.character] = true
                if not charMap[tx.character] then
                    charMap[tx.character] = {
                        key = tx.character,
                        name = tx.character:match("^(.+)-"),
                        realm = tx.character:match("-(.+)$"),
                        sources = {},
                    }
                end
                charMap[tx.character].sources["Accounting"] = true
            end
        end
    end

    local favorites = ns.db.global.favorites
    if favorites then
        for charKey, _ in pairs(favorites) do
            if type(charKey) == "string" then
                if not charMap[charKey] then
                    charMap[charKey] = {
                        key = charKey,
                        name = charKey:match("^(.+)-"),
                        realm = charKey:match("-(.+)$"),
                        sources = {},
                    }
                end
                charMap[charKey].sources["Favorites"] = true
            end
        end
    end

    local questsAPI = OneWoW:GetCatalogPackAPI("quests")
    if questsAPI then
        for _, charKey in ipairs(questsAPI.GetTrackedCharacterKeys()) do
            if type(charKey) == "string" then
                if not charMap[charKey] then
                    charMap[charKey] = {
                        key = charKey,
                        name = charKey:match("^(.+)-"),
                        realm = charKey:match("-(.+)$"),
                        sources = {},
                    }
                end
                charMap[charKey].sources["Quest Completion"] = true
            end
        end
    end

    local tsAPI = OneWoW:GetCatalogPackAPI("tradeskills")
    if tsAPI then
        for _, charKey in ipairs(tsAPI.GetAllCharacters()) do
            local name, realm = strsplit("-", charKey)
            if name and realm then
                if not charMap[charKey] then
                    charMap[charKey] = {
                        key = charKey,
                        name = name,
                        realm = realm,
                        sources = {},
                    }
                end
                charMap[charKey].sources["Tradeskill Scans"] = true
            end
        end
    end

    local sorted = {}
    for _, info in pairs(charMap) do
        tinsert(sorted, info)
    end
    sort(sorted, function(a, b)
        if (a.lastLogin or 0) ~= (b.lastLogin or 0) then
            return (a.lastLogin or 0) > (b.lastLogin or 0)
        end
        return (a.name or "") < (b.name or "")
    end)

    return sorted
end

--- Permanently remove a character from every OneWoW database.
---@param charKey string
---@return string[] purgedFrom labels of stores the character was removed from
function ns_CharacterCleanup:Purge(charKey)
    local purgedFrom = {}

    local simpleDBs = {
        { global = "OneWoW_AltTracker_Character_DB",    label = "Character" },
        { global = "OneWoW_AltTracker_Professions_DB",  label = "Professions" },
        { global = "OneWoW_AltTracker_Endgame_DB",      label = "Endgame" },
        { global = "OneWoW_AltTracker_Storage_DB",       label = "Storage" },
        { global = "OneWoW_AltTracker_Auctions_DB",      label = "Auctions" },
        { global = "OneWoW_AltTracker_Collections_DB",   label = "Collections" },
    }

    for _, dbInfo in ipairs(simpleDBs) do
        local db = _G[dbInfo.global]
        if db and db.characters and db.characters[charKey] then
            db.characters[charKey] = nil
            tinsert(purgedFrom, dbInfo.label)
        end
    end

    if OneWoW_AltTracker_Accounting_API then
        local removed = OneWoW_AltTracker_Accounting_API.PurgeCharacter(charKey)
        if removed > 0 then
            tinsert(purgedFrom, "Accounting (" .. removed .. " transactions)")
        end
    end

    local favorites = ns.db.global.favorites
    if favorites and favorites[charKey] then
        favorites[charKey] = nil
        tinsert(purgedFrom, "Favorites")
    end

    local questsAPI = OneWoW:GetCatalogPackAPI("quests")
    if questsAPI and questsAPI.PurgeCharacter(charKey) then
        tinsert(purgedFrom, "Quest Completion")
    end

    local tsAPI = OneWoW:GetCatalogPackAPI("tradeskills")
    if tsAPI and tsAPI.PurgeCharacter(charKey) then
        tinsert(purgedFrom, "Tradeskill Scans")
    end

    OneWoW.AltScope:RemoveCharFromAllRoles(charKey)

    return purgedFrom
end
