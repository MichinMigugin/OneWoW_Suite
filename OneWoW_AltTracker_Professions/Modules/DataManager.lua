local addonName, ns = ...

ns.DataManager = {}
local DataManager = ns.DataManager

local eventFrame = nil
local initialized = false
local currentOpenProfession = nil

function DataManager:Initialize()
    if initialized then return end
    initialized = true
end

function DataManager:RegisterEvents()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
    end

    local events = {
        "TRADE_SKILL_SHOW",
        "TRADE_SKILL_LIST_UPDATE",
        "TRADE_SKILL_CLOSE",
        "TRAINER_SHOW",
        "TRAINER_CLOSED",
        "PLAYER_EQUIPMENT_CHANGED",
    }

    for _, event in ipairs(events) do
        eventFrame:RegisterEvent(event)
    end

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        DataManager:HandleEvent(event, ...)
    end)
end

function DataManager:HandleEvent(event, ...)
    if event == "TRADE_SKILL_SHOW" then
        C_Timer.After(0.5, function()
            self:OnTradeSkillShow()
        end)

    elseif event == "TRADE_SKILL_LIST_UPDATE" then
        if currentOpenProfession then
            C_Timer.After(0.3, function()
                self:UpdateCurrentProfession()
            end)
        end

    elseif event == "TRADE_SKILL_CLOSE" then
        currentOpenProfession = nil

    elseif event == "TRAINER_SHOW" then
        C_Timer.After(0.5, function()
            self:OnTrainerShow()
        end)

    elseif event == "TRAINER_CLOSED" then

    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slotID = ...
        if slotID >= 20 and slotID <= 30 then
            C_Timer.After(0.5, function()
                self:UpdateEquipment()
            end)
        end
    end
end

function DataManager:OnTradeSkillShow()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.ProfessionBasics:CollectData(charKey, charData)
    ns.ProfessionEquipment:CollectData(charKey, charData)

    local professionInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    if professionInfo and professionInfo.professionName then
        currentOpenProfession = professionInfo.professionName

        C_Timer.After(1, function()
            self:CollectAdvancedData(charKey, charData, professionInfo.professionName)
        end)
    end

    return true
end

function DataManager:UpdateCurrentProfession()
    if not currentOpenProfession then return false end

    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    self:CollectAdvancedData(charKey, charData, currentOpenProfession)

    return true
end

function DataManager:CollectAdvancedData(charKey, charData, professionName)
    if not charKey or not charData or not professionName then return false end

    ns.ProfessionAdvanced:CollectData(charKey, charData, professionName)

    ns.ProfessionCooldowns:CollectData(charKey, charData, professionName)

    return true
end

function DataManager:OnTrainerShow()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.ProfessionTrainers:CollectData(charKey, charData)

    return true
end

function DataManager:UpdateEquipment()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.ProfessionBasics:CollectData(charKey, charData)

    ns.ProfessionEquipment:CollectData(charKey, charData)

    return true
end

function DataManager:CollectAllBasicData()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.ProfessionBasics:CollectData(charKey, charData)
    ns.ProfessionEquipment:CollectData(charKey, charData)

    return true
end

function DataManager:ForceFullScan()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.ProfessionBasics:CollectData(charKey, charData)
    ns.ProfessionEquipment:CollectData(charKey, charData)

    if C_TradeSkillUI.IsTradeSkillReady() then
        local professionInfo = C_TradeSkillUI.GetBaseProfessionInfo()
        if professionInfo and professionInfo.professionName then
            self:CollectAdvancedData(charKey, charData, professionInfo.professionName)
        end
    end

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
