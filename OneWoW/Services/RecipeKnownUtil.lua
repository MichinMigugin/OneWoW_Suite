local _, ns = ...

local RecipeKnownUtil = {}
ns.RecipeKnownUtil = RecipeKnownUtil

local knownRecipeSpells = {}
local sessionMap = {}

local LEARN_LINE_TYPE = Enum.TooltipDataLineType.ItemSpellTriggerLearn

local eventFrame = CreateFrame("Frame")

local function GetSavedMap()
    return OneWoW_AltTracker_Professions_API and OneWoW_AltTracker_Professions_API.GetRecipeItemMap()
end

local function SaveToMap(itemID, recipeSpellID)
    sessionMap[itemID] = recipeSpellID
    if OneWoW_AltTracker_Professions_API then
        OneWoW_AltTracker_Professions_API.SetRecipeItemMapEntry(itemID, recipeSpellID)
    end
end

local function BuildCacheFromTradeSkill()
    local ids = C_TradeSkillUI.GetAllRecipeIDs()
    if not ids or #ids == 0 then return end

    for _, recipeSpellID in ipairs(ids) do
        local info = C_TradeSkillUI.GetRecipeInfo(recipeSpellID)
        if info and info.learned then
            knownRecipeSpells[recipeSpellID] = true
        end

        local link = C_TradeSkillUI.GetRecipeItemLink(recipeSpellID)
        if link then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then
                SaveToMap(itemID, recipeSpellID)
            end
        end
    end
end

eventFrame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")
eventFrame:RegisterEvent("NEW_RECIPE_LEARNED")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "NEW_RECIPE_LEARNED" then
        local recipeSpellID = ...
        if recipeSpellID then
            knownRecipeSpells[recipeSpellID] = true
        end
        BuildCacheFromTradeSkill()
    elseif event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_SHOW" then
        BuildCacheFromTradeSkill()
    end
end)

local function GetSpellIDFromTooltip(itemID)
    local td = C_TooltipInfo.GetItemByID(itemID)
    if not td or not td.lines then return nil end
    for _, line in ipairs(td.lines) do
        if line.type == LEARN_LINE_TYPE and line.spellID then
            return line.spellID
        end
    end
    return nil
end

function RecipeKnownUtil:GetRecipeSpellID(itemID)
    if not itemID then return nil end

    local spellID = GetSpellIDFromTooltip(itemID)
    if spellID then
        SaveToMap(itemID, spellID)
        return spellID
    end

    if sessionMap[itemID] then return sessionMap[itemID] end

    local saved = GetSavedMap()
    if saved and saved[itemID] then
        sessionMap[itemID] = saved[itemID]
        return saved[itemID]
    end

    return nil
end

function RecipeKnownUtil:IsRecipeKnown(itemID)
    if not itemID then return nil end

    local recipeSpellID = self:GetRecipeSpellID(itemID)
    if not recipeSpellID then return nil end

    if knownRecipeSpells[recipeSpellID] then
        return true
    end

    if OneWoW_AltTracker_Professions_API then
        local OneWoW_GUI = OneWoW_GUI
        local charKey = OneWoW_GUI and OneWoW_GUI:BuildCharKey()
        local charData = charKey and OneWoW_AltTracker_Professions_API.GetCharacterData(charKey)
        if charData and charData.recipes then
            for _, recipeSet in pairs(charData.recipes) do
                if recipeSet[recipeSpellID] then
                    knownRecipeSpells[recipeSpellID] = true
                    return true
                end
            end
        end
    end

    local info = C_TradeSkillUI.GetRecipeInfo(recipeSpellID)
    if info and info.learned then
        knownRecipeSpells[recipeSpellID] = true
        return true
    end

    return nil
end

function RecipeKnownUtil:IsAltRecipeKnown(charRecipeSet, itemID)
    if not charRecipeSet or not itemID then return false end

    local recipeSpellID = self:GetRecipeSpellID(itemID)
    if recipeSpellID and charRecipeSet[recipeSpellID] then
        return true
    end

    return false
end

function RecipeKnownUtil:RegisterMapping(itemID, recipeSpellID)
    if itemID and recipeSpellID then
        SaveToMap(itemID, recipeSpellID)
    end
end

--- Resolve the learnable recipe-scroll item ID for a recipe spell ID.
--- Uses the live profession UI link when available, otherwise the item→spell map
--- built while professions are open (same map Recipe Knowledge tooltips use).
function RecipeKnownUtil:GetRecipeItemID(recipeSpellID)
    if not recipeSpellID then return nil end

    local link = C_TradeSkillUI.GetRecipeItemLink(recipeSpellID)
    if link then
        local itemID = tonumber(link:match("item:(%d+)"))
        if itemID then
            SaveToMap(itemID, recipeSpellID)
            return itemID
        end
    end

    for itemID, spellID in pairs(sessionMap) do
        if spellID == recipeSpellID then
            return itemID
        end
    end

    local saved = GetSavedMap()
    if saved then
        for itemID, spellID in pairs(saved) do
            if spellID == recipeSpellID then
                sessionMap[itemID] = spellID
                return itemID
            end
        end
    end

    return nil
end

function RecipeKnownUtil:IsCacheReady()
    local saved = GetSavedMap()
    return saved and next(saved) ~= nil
end
