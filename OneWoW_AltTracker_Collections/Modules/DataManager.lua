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
        "UNIT_QUEST_LOG_CHANGED",
        "UPDATE_FACTION",
        "ACHIEVEMENT_EARNED",
        "QUEST_ACCEPTED",
        "QUEST_REMOVED",
        "QUEST_LOG_UPDATE",
        "CRITERIA_UPDATE",
        "NEW_MOUNT_ADDED",
        "COMPANION_LEARNED",
        "PET_JOURNAL_LIST_UPDATE",
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

    elseif event == "UNIT_QUEST_LOG_CHANGED" or event == "QUEST_ACCEPTED" or
           event == "QUEST_REMOVED" or event == "QUEST_LOG_UPDATE" then
        local unit = ...
        if not unit or unit == "player" then
            C_Timer.After(0.5, function()
                self:UpdateQuests()
            end)
        end

    elseif event == "UPDATE_FACTION" then
        C_Timer.After(0.5, function()
            self:UpdateReputations()
        end)

    elseif event == "ACHIEVEMENT_EARNED" or event == "CRITERIA_UPDATE" then
        C_Timer.After(0.5, function()
            self:UpdateAchievements()
        end)

    elseif event == "NEW_MOUNT_ADDED" or event == "COMPANION_LEARNED" or event == "PET_JOURNAL_LIST_UPDATE" then
        C_Timer.After(1, function()
            self:UpdatePetsMounts()
        end)

    end
end

function DataManager:CollectAllData()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.Quests:CollectData(charKey, charData)
    ns.Reputations:CollectData(charKey, charData)
    ns.Achievements:CollectData(charKey, charData)
    ns.PetsMounts:CollectData(charKey, charData)

    return true
end

function DataManager:UpdateQuests()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.Quests:CollectData(charKey, charData)
end

function DataManager:UpdateReputations()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.Reputations:CollectData(charKey, charData)
end

function DataManager:UpdateAchievements()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.Achievements:CollectData(charKey, charData)
end

function DataManager:UpdatePetsMounts()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.PetsMounts:CollectData(charKey, charData)
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
