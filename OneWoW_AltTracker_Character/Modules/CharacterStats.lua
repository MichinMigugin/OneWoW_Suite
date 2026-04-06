local addonName, ns = ...

ns.CharacterStats = {}
local Module = ns.CharacterStats

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local stats = {}

    stats.strength = UnitStat("player", 1)
    stats.agility = UnitStat("player", 2)
    stats.stamina = UnitStat("player", 3)
    stats.intellect = UnitStat("player", 4)

    local baseArmor, effectiveArmor = UnitArmor("player")
    stats.armor = effectiveArmor or baseArmor

    local attackPower = UnitAttackPower("player")
    stats.attackPower = attackPower

    stats.critChance = GetCritChance()
    stats.haste = GetHaste()
    stats.mastery = GetMastery()
    stats.versatility = GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE)

    local specID = GetSpecialization()
    if specID then
        local id, name, description, icon, background, role = GetSpecializationInfo(specID)
        stats.specID = id
        stats.specName = name
        stats.specRole = role
        stats.specBackground = background
        stats.specIcon = icon
    end

    local heroSpecID = C_ClassTalents.GetActiveHeroTalentSpec()
    if heroSpecID and heroSpecID > 0 then
        local configID = C_ClassTalents.GetActiveConfigID()
        stats.heroSpecID = heroSpecID
        stats.activeConfigID = configID

        local heroConfig = C_Traits.GetConfigInfo(configID)
        if heroConfig and heroConfig.treeIDs then
            for _, treeID in ipairs(heroConfig.treeIDs) do
                local treeInfo = C_Traits.GetTreeInfo(configID, treeID)
                if treeInfo and treeInfo.ID == heroSpecID then
                    stats.heroSpecName = treeInfo.name
                    break
                end
            end
        end

        if not stats.heroSpecName then
            local nodeInfo = C_Traits.GetNodeInfo(configID, heroSpecID)
            if nodeInfo then
                stats.heroSpecName = nodeInfo.name
            end
        end
    end

    charData.stats = stats

    return true
end
