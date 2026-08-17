local _, ns = ...

local E = ns.TrackerEvaluators
local tonumber = tonumber

E.Register("level", function(op)
    local req = tonumber(op.level) or 1
    local current = UnitLevel("player") or 1
    return current, req
end)

E.Register("ilvl", function(op)
    local req = tonumber(op.ilvl) or 1
    local current = select(2, GetAverageItemLevel()) or 0
    return math.floor(current), req
end)

E.Register("achievement", function(op)
    local achID = tonumber(op.achievementID)
    if achID then
        local _, _, _, completed = GetAchievementInfo(achID)
        return completed and 1 or 0, 1
    end
end)

E.Register("reputation", function(op)
    local factionID = tonumber(op.factionID)
    local reqStanding = tonumber(op.standing) or 6
    if factionID then
        local data = C_Reputation.GetFactionDataByID(factionID)
        if data then
            return data.currentStanding or 0, reqStanding
        end
    end
end)

E.Register("renown", function(op)
    local factionID = tonumber(op.factionID)
    local reqLevel = tonumber(op.level) or 1
    if factionID then
        local data = C_MajorFactions.GetMajorFactionData(factionID)
        if data then
            return data.renownLevel or 0, reqLevel
        end
    end
end)

E.Register("spell_known", function(op)
    local spellID = tonumber(op.spellID)
    if not spellID then return end
    if C_SpellBook.IsSpellKnown(spellID) then return 1, 1 end
    if C_SpellBook.IsSpellInSpellBook(spellID) then return 1, 1 end
    if op.itemID then
        local result = OneWoW.RecipeKnownUtil:IsRecipeKnown(tonumber(op.itemID))
        if result then return 1, 1 end
    end
    return 0, 1
end)
