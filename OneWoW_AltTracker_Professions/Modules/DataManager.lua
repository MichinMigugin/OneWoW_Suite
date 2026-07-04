local _, ns = ...

ns.DataManager = {}
local DataManager = ns.DataManager

local eventFrame = nil
local initialized = false

function DataManager:Initialize()
    if initialized then return end
    initialized = true
end

-- Recipe scanning is owned by the core OneWoW.ProfessionRecipe funnel; this unit
-- subscribes to its "window ready" and "closed" channels for the live-query
-- collectors (basics / equipment / concentration / expansion bands) and keeps a
-- private frame only for the two non-trade-skill events a LoD unit cannot route
-- through the core's private ns.RegisterEvent (equipment + concentration currency).
function DataManager:RegisterEvents()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
    end

    eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    eventFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")

    eventFrame:SetScript("OnEvent", function(_, event, ...)
        DataManager:HandleEvent(event, ...)
    end)

    OneWoW.ProfessionRecipe.RegisterOpenCallback("AltTracker_Professions", function()
        DataManager:OnProfessionWindowReady()
    end)
end

function DataManager:HandleEvent(event, ...)
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        local slotID = ...
        if slotID >= 20 and slotID <= 30 then
            C_Timer.After(0.5, function()
                self:UpdateEquipment()
            end)
        end

    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        C_Timer.After(0.5, function()
            self:UpdateConcentration()
        end)
    end
end

-- Driven by OneWoW.ProfessionRecipe's ready-gated, debounced open callback, so
-- the trade-skill APIs are guaranteed queryable here.
function DataManager:OnProfessionWindowReady()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.ProfessionBasics:CollectData(charKey, charData)
    ns.ProfessionEquipment:CollectData(charKey, charData)
    ns.ProfessionConcentration:CollectData(charKey, charData)
    ns.ProfessionBasics:CollectExpansionSkills(charKey, charData)

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

function DataManager:UpdateConcentration()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    if not charData.professions then
        ns.ProfessionBasics:CollectData(charKey, charData)
    end

    ns.ProfessionConcentration:CollectData(charKey, charData)

    return true
end

function DataManager:CollectAllBasicData()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.ProfessionBasics:CollectData(charKey, charData)
    ns.ProfessionEquipment:CollectData(charKey, charData)
    ns.ProfessionConcentration:CollectData(charKey, charData)

    return true
end

function DataManager:ForceFullScan()
    local charKey = ns:GetCharacterKey()
    if not charKey then return false end

    local charData = ns:GetCharacterData(charKey)
    if not charData then return false end

    ns.ProfessionBasics:CollectData(charKey, charData)
    ns.ProfessionEquipment:CollectData(charKey, charData)
    ns.ProfessionConcentration:CollectData(charKey, charData)

    -- Recipes flow through the core OneWoW.ProfessionRecipe funnel; if a window is
    -- open it has already delivered (and committed) a scan. Refresh the live
    -- collectors and expansion bands here.
    if C_TradeSkillUI.IsTradeSkillReady() then
        ns.ProfessionBasics:CollectExpansionSkills(charKey, charData)
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
