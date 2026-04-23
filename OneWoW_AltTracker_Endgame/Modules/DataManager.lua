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
        "CHALLENGE_MODE_MAPS_UPDATE",
        "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE",
        "UPDATE_INSTANCE_INFO",
        "WEEKLY_REWARDS_UPDATE",
        "CURRENCY_DISPLAY_UPDATE",
        "PVP_RATED_STATS_UPDATE",
        "HONOR_LEVEL_UPDATE",
        "QUEST_TURNED_IN",
        "QUEST_REMOVED",
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
        C_Timer.After(2, function()
            self:CollectAllData()
        end)
        C_Timer.After(8, function()
            self:UpdateGreatVault()
            self:UpdateRaids()
        end)
        C_Timer.After(20, function()
            self:UpdateGreatVault()
        end)

    elseif event == "CHALLENGE_MODE_MAPS_UPDATE" or event == "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE" then
        C_Timer.After(0.5, function()
            self:UpdateMythicPlus()
        end)

    elseif event == "UPDATE_INSTANCE_INFO" then
        C_Timer.After(0.5, function()
            self:UpdateRaids()
        end)

    elseif event == "WEEKLY_REWARDS_UPDATE" then
        C_Timer.After(0.5, function()
            self:UpdateGreatVault()
        end)

    elseif event == "CURRENCY_DISPLAY_UPDATE" or event == "PVP_RATED_STATS_UPDATE" or event == "HONOR_LEVEL_UPDATE" then
        C_Timer.After(0.5, function()
            self:UpdatePVP()
            self:UpdateCurrencies()
        end)

    elseif event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED" then
        C_Timer.After(0.5, function()
            self:UpdateWorldBoss()
            self:UpdateWeeklyActivities()
            self:UpdateRaids()
        end)
    end
end

function DataManager:CollectAllData()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    charData.lastLogin = time()

    RequestRaidInfo()
    ns.MythicPlus:CollectData(charKey, charData)
    ns.Raids:CollectData(charKey, charData)
    ns.GreatVault:CollectData(charKey, charData)
    ns.PVP:CollectData(charKey, charData)
    ns.WorldBoss:CollectData(charKey, charData)
    ns.Currencies:CollectData(charKey, charData)
    ns.WeeklyActivities:CollectData(charKey, charData)

    return true
end

function DataManager:UpdateMythicPlus()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.MythicPlus:CollectData(charKey, charData)
end

function DataManager:UpdateRaids()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.Raids:CollectData(charKey, charData)
end

function DataManager:UpdateGreatVault()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.GreatVault:CollectData(charKey, charData)
end

function DataManager:UpdatePVP()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.PVP:CollectData(charKey, charData)
end

function DataManager:UpdateCurrencies()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.Currencies:CollectData(charKey, charData)
end

function DataManager:UpdateWorldBoss()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.WorldBoss:CollectData(charKey, charData)
end

function DataManager:UpdateWeeklyActivities()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.WeeklyActivities:CollectData(charKey, charData)
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
