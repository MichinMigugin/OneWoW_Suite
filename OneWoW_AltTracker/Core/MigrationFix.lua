local addonName, ns = ...

ns.MigrationFix = {}
local MigrationFix = ns.MigrationFix

function MigrationFix:FixImportedData()
    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then
        return false
    end

    local fixedCount = 0

    for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
        local dataFixed = false

        if not charData.class or charData.class == "string" then
            if charData.class and type(charData.class) == "string" then
                local normalizedClass = string.upper(charData.class)
                normalizedClass = string.gsub(normalizedClass, " ", "")
                normalizedClass = string.gsub(normalizedClass, "-", "")
                charData.class = normalizedClass
                dataFixed = true
            end
        end

        if not charData.className and charData.class then
            local classNames = {
                WARRIOR = "Warrior",
                PALADIN = "Paladin",
                HUNTER = "Hunter",
                ROGUE = "Rogue",
                PRIEST = "Priest",
                DEATHKNIGHT = "Death Knight",
                SHAMAN = "Shaman",
                MAGE = "Mage",
                WARLOCK = "Warlock",
                MONK = "Monk",
                DRUID = "Druid",
                DEMONHUNTER = "Demon Hunter",
                EVOKER = "Evoker",
            }
            charData.className = classNames[charData.class] or charData.class
            dataFixed = true
        end

        if charData.restedXP or charData.currentXP or charData.maxXP or charData.restState then
            if not charData.xp then
                charData.xp = {
                    restedXP = charData.restedXP or 0,
                    currentXP = charData.currentXP or 0,
                    maxXP = charData.maxXP or 0,
                    restState = charData.restState or 0,
                    isXPDisabled = charData.isXPDisabled or false,
                    isResting = charData.isResting or false,
                }
                charData.restedXP = nil
                charData.currentXP = nil
                charData.maxXP = nil
                charData.restState = nil
                charData.isXPDisabled = nil
                charData.isResting = nil
                dataFixed = true
            end
        end

        if charData.hearthLocation and not charData.location then
            charData.location = {
                bindLocation = charData.hearthLocation,
            }
            charData.hearthLocation = nil
            dataFixed = true
        end

        if (charData.specialization or charData.activeSpec) and not charData.stats then
            local rawSpec = charData.specialization or charData.activeSpec
            local specNameStr
            if type(rawSpec) == "table" then
                specNameStr = rawSpec.name or ""
            else
                specNameStr = tostring(rawSpec or "")
            end
            charData.stats = {
                specName = specNameStr,
            }
            charData.specialization = nil
            charData.activeSpec = nil
            dataFixed = true
        end

        if charData.stats and type(charData.stats.specName) == "table" then
            local specTable = charData.stats.specName
            charData.stats.specName = specTable.name or ""
            dataFixed = true
        end

        if charData.guild and type(charData.guild) == "string" then
            charData.guild = {
                name = charData.guild,
                rank = charData.guildRank,
                rankIndex = charData.guildRankIndex,
            }
            charData.guildRank = nil
            charData.guildRankIndex = nil
            dataFixed = true
        end

        if dataFixed then
            fixedCount = fixedCount + 1
        end
    end

    if _G.OneWoW_AltTracker_Endgame_DB and _G.OneWoW_AltTracker_Endgame_DB.characters then
        for charKey, charData in pairs(_G.OneWoW_AltTracker_Endgame_DB.characters) do
            if charData.itemLevel then
                if _G.OneWoW_AltTracker_Character_DB.characters[charKey] then
                    _G.OneWoW_AltTracker_Character_DB.characters[charKey].itemLevel = charData.itemLevel
                    _G.OneWoW_AltTracker_Character_DB.characters[charKey].itemLevelColor = charData.itemLevelColor
                end
                charData.itemLevel = nil
                charData.itemLevelColor = nil
                fixedCount = fixedCount + 1
            end
        end
    end

    return fixedCount > 0, fixedCount
end

function MigrationFix:CleanupWrongPlacedData()
    local cleanupCount = 0

    if _G.OneWoW_AltTracker_Character_DB and _G.OneWoW_AltTracker_Character_DB.characters then
        for charKey, charData in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
            if charData.restedXP then charData.restedXP = nil; cleanupCount = cleanupCount + 1 end
            if charData.currentXP then charData.currentXP = nil; cleanupCount = cleanupCount + 1 end
            if charData.maxXP then charData.maxXP = nil; cleanupCount = cleanupCount + 1 end
            if charData.restState then charData.restState = nil; cleanupCount = cleanupCount + 1 end
            if charData.isXPDisabled then charData.isXPDisabled = nil; cleanupCount = cleanupCount + 1 end
            if charData.isResting then charData.isResting = nil; cleanupCount = cleanupCount + 1 end
            if charData.hearthLocation then charData.hearthLocation = nil; cleanupCount = cleanupCount + 1 end
            if charData.specialization then charData.specialization = nil; cleanupCount = cleanupCount + 1 end
            if charData.activeSpec then charData.activeSpec = nil; cleanupCount = cleanupCount + 1 end
        end
    end

    return cleanupCount
end
