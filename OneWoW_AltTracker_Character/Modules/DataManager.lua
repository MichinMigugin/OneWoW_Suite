local addonName, ns = ...

ns.DataManager = {}
local DataManager = ns.DataManager

local eventFrame = nil
local initialized = false

function DataManager:Initialize()
    if initialized then return end
    initialized = true
end

function DataManager:RegisterEvents()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
    end

    local events = {
        "PLAYER_ALIVE",
        "PLAYER_ENTERING_WORLD",
        "PLAYER_LEVEL_UP",
        "PLAYER_SPECIALIZATION_CHANGED",
        "PLAYER_TALENT_UPDATE",
        "UNIT_NAME_UPDATE",
        "PLAYER_MONEY",
        "CURRENCY_DISPLAY_UPDATE",
        "PLAYER_XP_UPDATE",
        "PLAYER_UPDATE_RESTING",
        "ENABLE_XP_GAIN",
        "DISABLE_XP_GAIN",
        "ZONE_CHANGED",
        "ZONE_CHANGED_NEW_AREA",
        "ZONE_CHANGED_INDOORS",
        "HEARTHSTONE_BOUND",
        "PLAYER_GUILD_UPDATE",
        "UPDATE_FACTION",
        "PLAYER_EQUIPMENT_CHANGED",
        "PLAYER_AVG_ITEM_LEVEL_UPDATE",
        "UNIT_INVENTORY_CHANGED",
        "TIME_PLAYED_MSG",
        "TRAIT_CONFIG_CREATED",
        "TRAIT_CONFIG_UPDATED",
    }

    for _, event in ipairs(events) do
        eventFrame:RegisterEvent(event)
    end

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        DataManager:HandleEvent(event, ...)
    end)
end

function DataManager:HandleEvent(event, ...)
    if event == "PLAYER_ALIVE" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function()
            self:CollectAllData()
        end)

    elseif event == "PLAYER_LEVEL_UP" then
        local newLevel = ...
        self:UpdateLevel(newLevel)

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        self:UpdateStats()

    elseif event == "UNIT_NAME_UPDATE" then
        local unit = ...
        if unit == "player" then
            self:UpdateBasics()
        end

    elseif event == "PLAYER_MONEY" or event == "CURRENCY_DISPLAY_UPDATE" then
        self:UpdateEconomy()

    elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_UPDATE_RESTING" or
           event == "ENABLE_XP_GAIN" or event == "DISABLE_XP_GAIN" then
        self:UpdateXP()

    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or
           event == "ZONE_CHANGED_INDOORS" or event == "HEARTHSTONE_BOUND" then
        self:UpdateLocation()

    elseif event == "PLAYER_GUILD_UPDATE" or event == "UPDATE_FACTION" then
        self:UpdateGuild()

    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" or
           event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if not unit or unit == "player" then
            C_Timer.After(0.5, function()
                self:UpdateEquipment()
            end)
        end

    elseif event == "TIME_PLAYED_MSG" then
        local totalTime, levelTime = ...
        ns.PlayTime:OnTimePlayedMsg(totalTime, levelTime)
    end
end


function DataManager:CollectAllData()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.CharacterBasics:CollectData(charKey, charData)
    ns.CharacterStats:CollectData(charKey, charData)
    ns.XPProgression:CollectData(charKey, charData)
    ns.Location:CollectData(charKey, charData)
    ns.Guild:CollectData(charKey, charData)
    ns.Economy:CollectData(charKey, charData)
    ns.Equipment:CollectData(charKey, charData)
    ns.PlayTime:CollectData(charKey, charData)

    return true
end

function DataManager:UpdateBasics()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.CharacterBasics:CollectData(charKey, charData)
end

function DataManager:UpdateLevel(newLevel)
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.CharacterBasics:UpdateLevel(charKey, charData, newLevel)
    ns.XPProgression:CollectData(charKey, charData)
end

function DataManager:UpdateStats()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.CharacterStats:CollectData(charKey, charData)
end

function DataManager:UpdateEconomy()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.Economy:CollectData(charKey, charData)
end

function DataManager:UpdateXP()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.XPProgression:CollectData(charKey, charData)
end

function DataManager:UpdateLocation()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.Location:CollectData(charKey, charData)
end

function DataManager:UpdateGuild()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.Guild:CollectData(charKey, charData)
end

function DataManager:UpdateEquipment()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.Equipment:CollectData(charKey, charData)
end

function DataManager:CollectActionBars()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.ActionBars:CollectData(charKey, charData)

    return true
end

function DataManager:GetCharacterData(charKey)
    return ns:GetCharacterData(charKey)
end

function DataManager:GetAllCharacters()
    return ns:GetAllCharacters()
end

function DataManager:DeleteCharacter(charKey)
    return ns:DeleteCharacter(charKey)
end
