local addonName, ns = ...

_G.OneWoW_AltTracker_Character = ns

if OneWoW_AltTracker_Character_API then
    OneWoW_AltTracker_Character_API = nil
end

OneWoW_AltTracker_Character_API = {
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

    CollectActionBars = function()
        return ns.DataManager:CollectActionBars()
    end,

    ForceDataCollection = function()
        return ns.DataManager:CollectAllData()
    end,
}
