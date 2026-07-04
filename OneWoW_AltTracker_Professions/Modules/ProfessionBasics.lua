local _, ns = ...

ns.ProfessionBasics = {}
local Module = ns.ProfessionBasics

-- Newest-first ordering for the per-expansion skill bands, matching the order
-- Blizzard's profession side panel uses. Category names are localized by the
-- API, so we match on English keywords and fall back to API order for the rest.
local EXPANSION_ORDER = {
    { pattern = "Midnight",        order = 12 },
    { pattern = "Khaz Algar",      order = 11 },
    { pattern = "War Within",      order = 11 },
    { pattern = "Dragon",          order = 10 },
    { pattern = "Shadowlands",     order = 9 },
    { pattern = "Kul Tiran",       order = 8 },
    { pattern = "Zandalari",       order = 8 },
    { pattern = "Battle",          order = 8 },
    { pattern = "Legion",          order = 7 },
    { pattern = "Broken Isles",    order = 7 },
    { pattern = "Draenor",         order = 6 },
    { pattern = "Pandaria",        order = 5 },
    { pattern = "Pandaren",        order = 5 },
    { pattern = "Cataclysm",       order = 4 },
    { pattern = "Northrend",       order = 3 },
    { pattern = "Lich King",       order = 3 },
    { pattern = "Cold North",      order = 3 },
    { pattern = "Outland",         order = 2 },
    { pattern = "Burning Crusade", order = 2 },
    { pattern = "Classic",         order = 1 },
    { pattern = "Old World",       order = 1 },
}

local function GetExpansionOrder(name)
    if not name then return 0 end
    for _, entry in ipairs(EXPANSION_ORDER) do
        if name:find(entry.pattern) then
            return entry.order
        end
    end
    return 0
end

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local previousProfessions = charData.professions
    local professions = {}

    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()

    if prof1 then
        local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine, skillModifier = GetProfessionInfo(prof1)
        if name then
            professions.Primary1 = {
                name = name,
                icon = icon,
                currentSkill = skillLevel,
                maxSkill = maxSkillLevel,
                skillLine = skillLine,
                skillModifier = skillModifier,
                numAbilities = numAbilities,
                spellOffset = spelloffset,
                index = prof1,
            }
        end
    end

    if prof2 then
        local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine, skillModifier = GetProfessionInfo(prof2)
        if name then
            professions.Primary2 = {
                name = name,
                icon = icon,
                currentSkill = skillLevel,
                maxSkill = maxSkillLevel,
                skillLine = skillLine,
                skillModifier = skillModifier,
                numAbilities = numAbilities,
                spellOffset = spelloffset,
                index = prof2,
            }
        end
    end

    if cooking then
        local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine, skillModifier = GetProfessionInfo(cooking)
        if name then
            professions.Cooking = {
                name = name,
                icon = icon,
                currentSkill = skillLevel,
                maxSkill = maxSkillLevel,
                skillLine = skillLine,
                skillModifier = skillModifier,
                numAbilities = numAbilities,
                spellOffset = spelloffset,
                index = cooking,
            }
        end
    end

    if fishing then
        local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine, skillModifier = GetProfessionInfo(fishing)
        if name then
            professions.Fishing = {
                name = name,
                icon = icon,
                currentSkill = skillLevel,
                maxSkill = maxSkillLevel,
                skillLine = skillLine,
                skillModifier = skillModifier,
                numAbilities = numAbilities,
                spellOffset = spelloffset,
                index = fishing,
            }
        end
    end

    if archaeology then
        local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine, skillModifier = GetProfessionInfo(archaeology)
        if name then
            professions.Archaeology = {
                name = name,
                icon = icon,
                currentSkill = skillLevel,
                maxSkill = maxSkillLevel,
                skillLine = skillLine,
                skillModifier = skillModifier,
                numAbilities = numAbilities,
                spellOffset = spelloffset,
                index = archaeology,
            }
        end
    end

    -- Carry forward per-expansion skill bands; the category API only works while
    -- a profession window is open, so a plain rebuild must not drop earlier scans.
    if previousProfessions then
        for _, newProf in pairs(professions) do
            for _, oldProf in pairs(previousProfessions) do
                if oldProf.name == newProf.name and oldProf.expansions then
                    newProf.expansions = oldProf.expansions
                    break
                end
            end
        end
    end

    charData.professions = professions
    charData.lastUpdate = time()

    -- If a profession window is open right now, refresh its bands into the
    -- freshly built table so the data lands where the UI reads it.
    if C_TradeSkillUI.IsTradeSkillReady() then
        self:CollectExpansionSkills(charKey, charData)
    end

    return true
end

-- Maps a child profession (per-expansion skill line) back to its base
-- profession slot. Prefer the explicit parent name, fall back to a substring
-- match the way the concentration module does.
local function MatchSlot(childInfo, professions)
    for slotName, profData in pairs(professions) do
        if profData and profData.name then
            if childInfo.parentProfessionName == profData.name then
                return slotName
            end
        end
    end
    for slotName, profData in pairs(professions) do
        if profData and profData.name and childInfo.professionName and childInfo.professionName:find(profData.name, 1, true) then
            return slotName
        end
    end
    return nil
end

-- Scans the per-expansion skill bands and stores them on the matching
-- profession slot as profData.expansions. Each child profession info is one
-- expansion band (expansionName / skillLevel / maxSkillLevel) attributed to its
-- own parent profession, so opening one profession never overwrites another.
-- The API only returns data while a trade-skill window is open, so this runs
-- from the TRADE_SKILL_SHOW flow.
function Module:CollectExpansionSkills(_, charData)
    if not charData or not charData.professions then return false end
    if not C_TradeSkillUI.IsTradeSkillReady() then return false end

    local childInfos = C_TradeSkillUI.GetChildProfessionInfos()
    if not childInfos or #childInfos == 0 then return false end

    local bandsBySlot = {}
    for _, info in ipairs(childInfos) do
        if (info.maxSkillLevel or 0) > 0 then
            local slotName = MatchSlot(info, charData.professions)
            if slotName then
                local list = bandsBySlot[slotName]
                if not list then
                    list = {}
                    bandsBySlot[slotName] = list
                end
                local bandName = info.expansionName or info.professionName
                list[#list + 1] = {
                    name = bandName,
                    currentSkill = info.skillLevel or 0,
                    maxSkill = info.maxSkillLevel or 0,
                    sortOrder = GetExpansionOrder(bandName),
                    professionID = info.professionID or 0,
                }
            end
        end
    end

    local found = false
    for slotName, bands in pairs(bandsBySlot) do
        table.sort(bands, function(a, b)
            if a.sortOrder ~= b.sortOrder then return a.sortOrder > b.sortOrder end
            return (a.professionID or 0) > (b.professionID or 0)
        end)
        charData.professions[slotName].expansions = bands
        found = true
    end

    if found then
        charData.lastUpdate = time()
    end

    return found
end

function Module:GetProfessionByName(_, charData, professionName)
    if not charData or not charData.professions then return nil end

    for slotName, profData in pairs(charData.professions) do
        if profData.name == professionName then
            return profData, slotName
        end
    end

    return nil
end
