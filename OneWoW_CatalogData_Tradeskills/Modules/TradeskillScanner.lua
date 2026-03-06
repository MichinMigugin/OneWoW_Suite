-- OneWoW Addon File
-- OneWoW_CatalogData_Tradeskills/Modules/TradeskillScanner.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.TradeskillScanner = {}
local Scanner = ns.TradeskillScanner

local scannedThisSession = {}

local function GetCharKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if name and realm then
        return realm .. "-" .. name
    end
    return nil
end

function Scanner:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("TRADE_SKILL_SHOW")
    frame:SetScript("OnEvent", function(_, event)
        if event == "TRADE_SKILL_SHOW" then
            C_Timer.After(0.5, function()
                Scanner:ScanCurrentProfession()
            end)
        end
    end)
end

function Scanner:ScanCurrentProfession()
    if not C_TradeSkillUI.IsTradeSkillReady() then return end

    local profInfo = C_TradeSkillUI.GetBaseProfessionInfo()
    if not profInfo or not profInfo.professionName then return end

    local profName = profInfo.professionName
    local charKey = GetCharKey()
    if not charKey then return end

    local sessionKey = charKey .. ":" .. profName
    if scannedThisSession[sessionKey] then return end
    scannedThisSession[sessionKey] = true

    local db = ns:GetDB()
    if not db.scanCache then db.scanCache = {} end
    if not db.scanCache[charKey] then db.scanCache[charKey] = {} end
    if not db.scanCache[charKey][profName] then db.scanCache[charKey][profName] = {} end

    local knownRecipes = {}
    local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs()
    if recipeIDs then
        for _, recipeID in ipairs(recipeIDs) do
            local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
            if recipeInfo and recipeInfo.learned then
                knownRecipes[recipeID] = true
            end
        end
    end

    db.scanCache[charKey][profName] = {
        known = knownRecipes,
        lastScan = time(),
        skillLevel = profInfo.skillLevel or 0,
        maxSkillLevel = profInfo.maxSkillLevel or 0,
    }

    ns:FireScanCallbacks({
        charKey = charKey,
        professionName = profName,
        recipeCount = #(recipeIDs or {}),
    })
end

function Scanner:GetKnownRecipes(charKey, professionName)
    local db = ns:GetDB()
    if not db.scanCache then return nil end
    if not db.scanCache[charKey] then return nil end
    if not db.scanCache[charKey][professionName] then return nil end
    return db.scanCache[charKey][professionName]
end

function Scanner:GetAllCharacters()
    local db = ns:GetDB()
    if not db.scanCache then return {} end
    local chars = {}
    for charKey, _ in pairs(db.scanCache) do
        table.insert(chars, charKey)
    end
    table.sort(chars)
    return chars
end

function Scanner:IsRecipeKnown(recipeID)
    local db = ns:GetDB()
    if not db.scanCache then return false, nil end
    for charKey, professions in pairs(db.scanCache) do
        for profName, profData in pairs(professions) do
            if profData.known and profData.known[recipeID] then
                return true, charKey
            end
        end
    end
    return false, nil
end

function Scanner:GetRecipeKnownBy(recipeID)
    local db = ns:GetDB()
    if not db.scanCache then return {} end
    local knownBy = {}
    for charKey, professions in pairs(db.scanCache) do
        for profName, profData in pairs(professions) do
            if profData.known and profData.known[recipeID] then
                table.insert(knownBy, charKey)
            end
        end
    end
    table.sort(knownBy)
    return knownBy
end
