local ADDON_NAME, OneWoW = ...

local RecipeKnownUtil = {}
OneWoW.RecipeKnownUtil = RecipeKnownUtil

local knownRecipeSpells = {}
local sessionMap = {}

local eventFrame = CreateFrame("Frame")

local function GetSavedMap()
    local db = _G.OneWoW_AltTracker_Professions_DB
    return db and db.recipeItemMap
end

local function SaveToMap(itemID, recipeSpellID)
    sessionMap[itemID] = recipeSpellID
    local db = _G.OneWoW_AltTracker_Professions_DB
    if db then
        if not db.recipeItemMap then db.recipeItemMap = {} end
        db.recipeItemMap[itemID] = recipeSpellID
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

        if C_TradeSkillUI.GetRecipeItemLink then
            local link = C_TradeSkillUI.GetRecipeItemLink(recipeSpellID)
            if link then
                local itemID = tonumber(link:match("item:(%d+)"))
                if itemID then
                    SaveToMap(itemID, recipeSpellID)
                end
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

function RecipeKnownUtil:GetRecipeSpellID(itemID)
    if not itemID then return nil end

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
    if recipeSpellID then
        if knownRecipeSpells[recipeSpellID] then
            return true
        end

        local info = C_TradeSkillUI.GetRecipeInfo(recipeSpellID)
        if info and info.learned ~= nil then
            if info.learned then
                knownRecipeSpells[recipeSpellID] = true
            end
            return info.learned
        end

        if IsSpellKnown(recipeSpellID) then
            knownRecipeSpells[recipeSpellID] = true
            return true
        end

        if IsSpellKnownOrOverridesKnown(recipeSpellID) then
            knownRecipeSpells[recipeSpellID] = true
            return true
        end
    end

    local _, spellID = C_Item.GetItemSpell(itemID)
    if spellID then
        if IsPlayerSpell(spellID) then return true end
        if IsSpellKnown(spellID) then return true end
        if IsSpellKnownOrOverridesKnown(spellID) then return true end
    end

    return nil
end

function RecipeKnownUtil:IsAltRecipeKnown(charRecipeSet, itemID)
    if not charRecipeSet or not itemID then return false end

    local recipeSpellID = self:GetRecipeSpellID(itemID)
    if recipeSpellID and charRecipeSet[recipeSpellID] then
        return true
    end

    local _, spellID = C_Item.GetItemSpell(itemID)
    if spellID and charRecipeSet[spellID] then
        return true
    end

    return false
end

function RecipeKnownUtil:RegisterMapping(itemID, recipeSpellID)
    if itemID and recipeSpellID then
        SaveToMap(itemID, recipeSpellID)
    end
end

function RecipeKnownUtil:IsCacheReady()
    local saved = GetSavedMap()
    return saved and next(saved) ~= nil
end
