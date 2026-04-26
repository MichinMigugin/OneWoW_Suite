local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.CharacterStats = {}
local Module = ns.CharacterStats

local HeroSpecs = {
    -- Priest
    [18] = "Voidweaver",
    [19] = "Archon",
    [20] = "Oracle",
    -- Druid
    [21] = "Druid of the Claw",
    [22] = "Wildstalker",
    [23] = "Keeper of the Grove",
    [24] = "Elune's Chosen",
    -- Death Knight
    [31] = "San'layn",
    [32] = "Rider of the Apocalypse",
    [33] = "Deathbringer",
    -- Demon Hunter
    [34] = "Fel-Scarred",
    [35] = "Aldrachi Reaver",
    -- Evoker
    [36] = "Scalecommander",
    [37] = "Flameshaper",
    [38] = "Chronowarden",
    -- Mage
    [39] = "Sunfury",
    [40] = "Spellslinger",
    [41] = "Frostfire",
    -- Hunter
    [42] = "Sentinel",
    [43] = "Pack Leader",
    [44] = "Dark Ranger",
    -- Paladin
    [48] = "Templar",
    [49] = "Lightsmith",
    [50] = "Herald of the Sun",
    -- Rogue
    [51] = "Trickster",
    [52] = "Fatebound",
    [53] = "Deathstalker",
    -- Shaman
    [54] = "Totemic",
    [55] = "Stormbringer",
    [56] = "Farseer",
    -- Warlock
    [57] = "Soul Harvester",
    [58] = "Hellcaller",
    [59] = "Diabolist",
    -- Warrior
    [60] = "Slayer",
    [61] = "Mountain Thane",
    [62] = "Colossus",
    -- Monk
    [64] = "Conduit of the Celestials",
    [65] = "Shado-pan",
    [66] = "Master of Harmony",
}

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end
    if OneWoW_GUI:IsAddonRestricted() then return end

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
    stats.heroSpecName = HeroSpecs[heroSpecID] or nil

    charData.stats = stats

    return true
end
