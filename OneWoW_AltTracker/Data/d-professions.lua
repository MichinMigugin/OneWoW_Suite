local addonName, ns = ...

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

ns.ProfessionData.ICONS = {
    ["Alchemy"] = "Interface\\Icons\\Trade_Alchemy",
    ["Blacksmithing"] = "Interface\\Icons\\Trade_BlackSmithing",
    ["Enchanting"] = "Interface\\Icons\\Trade_Engraving",
    ["Engineering"] = "Interface\\Icons\\Trade_Engineering",
    ["Herbalism"] = "Interface\\Icons\\Trade_Herbalism",
    ["Inscription"] = "Interface\\Icons\\INV_Inscription_Tradeskill01",
    ["Jewelcrafting"] = "Interface\\Icons\\INV_Misc_Gem_01",
    ["Leatherworking"] = "Interface\\Icons\\Trade_LeatherWorking",
    ["Mining"] = "Interface\\Icons\\Trade_Mining",
    ["Skinning"] = "Interface\\Icons\\Trade_Skinning",
    ["Tailoring"] = "Interface\\Icons\\Trade_Tailoring",
    ["Cooking"] = "Interface\\Icons\\INV_Misc_Food_15",
    ["Fishing"] = "Interface\\Icons\\Trade_Fishing",
    ["Archaeology"] = "Interface\\Icons\\Trade_Archaeology"
}

function ns.ProfessionData:GetIcon(professionName)
    if not professionName then return "Interface\\Icons\\INV_Misc_QuestionMark" end
    return self.ICONS[professionName] or "Interface\\Icons\\INV_Misc_QuestionMark"
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
