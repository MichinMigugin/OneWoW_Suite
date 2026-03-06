local addonName, ns = ...

ns.ProfessionBasics = {}
local Module = ns.ProfessionBasics

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

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

    charData.professions = professions
    charData.lastUpdate = time()

    return true
end

function Module:GetProfessionByName(charKey, charData, professionName)
    if not charData or not charData.professions then return nil end

    for slotName, profData in pairs(charData.professions) do
        if profData.name == professionName then
            return profData, slotName
        end
    end

    return nil
end
