local addonName, ns = ...

ns.CharacterBasics = {}
local Module = ns.CharacterBasics

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local name, realm = UnitName("player"), GetRealmName()
    local level = UnitLevel("player")
    local className, classFile = UnitClass("player")
    local raceName, raceFile = UnitRace("player")
    local gender = UnitSex("player")
    local faction = UnitFactionGroup("player")
    local guid = UnitGUID("player")

    local titleID = GetCurrentTitle()
    local titleName = nil
    if titleID and titleID > 0 then
        titleName = GetTitleName(titleID)
    end

    charData.name = name
    charData.level = level
    charData.class = classFile
    charData.className = className
    charData.race = raceFile
    charData.raceName = raceName
    charData.sex = gender
    charData.faction = faction
    charData.realm = realm
    charData.guid = guid
    charData.title = titleName
    charData.lastLogin = time()

    return true
end

function Module:UpdateLevel(charKey, charData, newLevel)
    if not charKey or not charData then return false end

    charData.level = newLevel
    charData.lastLogin = time()

    return true
end
