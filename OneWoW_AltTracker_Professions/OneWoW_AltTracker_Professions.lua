local addonName, ns = ...

_G.OneWoW_AltTracker_Professions = ns

if OneWoW_AltTracker_Professions_API then
    OneWoW_AltTracker_Professions_API = nil
end

OneWoW_AltTracker_Professions_API = {
    GetCharacterData = function(charKey)
        return ns.DataManager:GetCharacterData(charKey)
    end,

    GetAllCharacters = function()
        return ns.DataManager:GetAllCharacters()
    end,

    GetCurrentCharacterKey = function()
        return ns:GetCharacterKey()
    end,

    DeleteCharacter = function(charKey)
        return ns.DataManager:DeleteCharacter(charKey)
    end,

    ForceFullScan = function()
        return ns.DataManager:ForceFullScan()
    end,

    CollectBasicData = function()
        return ns.DataManager:CollectAllBasicData()
    end,

    GetProfessionEquipment = function(charKey, professionName)
        local charData = ns.DataManager:GetCharacterData(charKey)
        if not charData then return nil end
        return ns.ProfessionEquipment:GetEquipmentForProfession(charKey, charData, professionName)
    end,

    GetActiveCooldowns = function(charKey, professionName)
        local charData = ns.DataManager:GetCharacterData(charKey)
        if not charData then return {} end
        return ns.ProfessionCooldowns:GetActiveCooldowns(charKey, charData, professionName)
    end,

    GetRecentTrainers = function(charKey, count)
        local charData = ns.DataManager:GetCharacterData(charKey)
        if not charData then return {} end
        return ns.ProfessionTrainers:GetRecentTrainers(charKey, charData, count)
    end,

    GetConcentration = function(charKey, slotName)
        local charData = ns.DataManager:GetCharacterData(charKey)
        if not charData then return nil end
        return ns.ProfessionConcentration:GetConcentration(charData, slotName)
    end,

    GetRecipeCount = function(charKey, professionName)
        local charData = ns.DataManager:GetCharacterData(charKey)
        if not charData then return 0 end
        return ns.ProfessionAdvanced:GetRecipeCount(charKey, charData, professionName)
    end,
}
