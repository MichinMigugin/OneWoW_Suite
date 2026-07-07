local _, ns = ...

local CreateTextureMarkup = CreateTextureMarkup
local C_TradeSkillUI = C_TradeSkillUI

ns.ProfessionData = {}

local PRIMARY_PROFESSIONS = {
    ["Alchemy"] = true,
    ["Blacksmithing"] = true,
    ["Enchanting"] = true,
    ["Engineering"] = true,
    ["Herbalism"] = true,
    ["Inscription"] = true,
    ["Jewelcrafting"] = true,
    ["Leatherworking"] = true,
    ["Mining"] = true,
    ["Skinning"] = true,
    ["Tailoring"] = true,
}

ns.ProfessionData.PRIMARY_PROFESSIONS = {
    "Alchemy", "Blacksmithing", "Enchanting", "Engineering",
    "Herbalism", "Inscription", "Jewelcrafting", "Leatherworking",
    "Mining", "Skinning", "Tailoring"
}

function ns.ProfessionData:IsPrimaryProfession(professionName)
    return PRIMARY_PROFESSIONS[professionName] == true
end

local QUESTION_MARK_ICON = 134400

-- Base profession skill line -> icon file ID (locale-independent).
local SKILL_LINE_ICONS = {
    [171] = 136240,  -- Alchemy
    [164] = 136241,  -- Blacksmithing
    [333] = 136244,  -- Enchanting
    [202] = 136243,  -- Engineering
    [182] = 136246,  -- Herbalism
    [773] = 237171,  -- Inscription
    [755] = 134071,  -- Jewelcrafting
    [165] = 133611,  -- Leatherworking
    [186] = 134708,  -- Mining
    [393] = 134366,  -- Skinning
    [197] = 136249,  -- Tailoring
    [185] = 133971,  -- Cooking
    [356] = 136245,  -- Fishing
    [794] = 441139,  -- Archaeology
}

-- English-name fallback for callers that only have a legacy string key.
ns.ProfessionData.ICONS = {
    ["Alchemy"] = SKILL_LINE_ICONS[171],
    ["Blacksmithing"] = SKILL_LINE_ICONS[164],
    ["Enchanting"] = SKILL_LINE_ICONS[333],
    ["Engineering"] = SKILL_LINE_ICONS[202],
    ["Herbalism"] = SKILL_LINE_ICONS[182],
    ["Inscription"] = SKILL_LINE_ICONS[773],
    ["Jewelcrafting"] = SKILL_LINE_ICONS[755],
    ["Leatherworking"] = SKILL_LINE_ICONS[165],
    ["Mining"] = SKILL_LINE_ICONS[186],
    ["Skinning"] = SKILL_LINE_ICONS[393],
    ["Tailoring"] = SKILL_LINE_ICONS[197],
    ["Cooking"] = SKILL_LINE_ICONS[185],
    ["Fishing"] = SKILL_LINE_ICONS[356],
    ["Archaeology"] = SKILL_LINE_ICONS[794],
}

local function GetIconBySkillLine(skillLine)
    local icon = SKILL_LINE_ICONS[skillLine]
    if icon then return icon end

    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLine)
    local parentID = info and info.parentProfessionID
    if parentID then
        return SKILL_LINE_ICONS[parentID]
    end

    return nil
end

function ns.ProfessionData:GetIcon(professionName, iconFileID, skillLine)
    if iconFileID and iconFileID > 0 then
        return iconFileID
    end
    if skillLine then
        local icon = GetIconBySkillLine(skillLine)
        if icon then return icon end
    end
    if professionName and self.ICONS[professionName] then
        return self.ICONS[professionName]
    end
    return QUESTION_MARK_ICON
end

function ns.ProfessionData:GetIconFromProf(profData)
    if not profData then return QUESTION_MARK_ICON end
    return self:GetIcon(profData.name, profData.icon, profData.skillLine)
end

function ns.ProfessionData:GetProfIconMarkup(profData, width, height)
    local icon = self:GetIconFromProf(profData)
    return CreateTextureMarkup(icon, 64, 64, width, height, 0, 1, 0, 1)
end

function ns.ProfessionData:GetAbbreviation(professionName)
    local abbrevs = {
        ["Alchemy"] = "Alch",
        ["Blacksmithing"] = "BS",
        ["Enchanting"] = "Ench",
        ["Engineering"] = "Eng",
        ["Herbalism"] = "Herb",
        ["Inscription"] = "Inscr",
        ["Jewelcrafting"] = "JC",
        ["Leatherworking"] = "LW",
        ["Mining"] = "Mine",
        ["Skinning"] = "Skin",
        ["Tailoring"] = "Tail",
    }
    return abbrevs[professionName] or professionName
end
