-- OneWoW Addon File
-- OneWoW_CatalogData_Tradeskills/Modules/TradeskillScanner.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.TradeskillScanner = {}
local Scanner = ns.TradeskillScanner

local scannedThisSession = {}

local EXPANSION_KEYWORDS = {
    { pattern = "Midnight",        order = 12, label = "Midnight" },
    { pattern = "Khaz Algar",      order = 11, label = "Khaz Algar" },
    { pattern = "War Within",      order = 11, label = "War Within" },
    { pattern = "Dragon",          order = 10, label = "Dragonflight" },
    { pattern = "Shadowlands",     order = 9,  label = "Shadowlands" },
    { pattern = "Kul Tiran",       order = 8,  label = "BfA" },
    { pattern = "Zandalari",       order = 8,  label = "BfA" },
    { pattern = "Battle",          order = 8,  label = "BfA" },
    { pattern = "Legion",          order = 7,  label = "Legion" },
    { pattern = "Draenor",         order = 6,  label = "Draenor" },
    { pattern = "Pandaria",        order = 5,  label = "Pandaria" },
    { pattern = "Cataclysm",       order = 4,  label = "Cataclysm" },
    { pattern = "Northrend",       order = 3,  label = "Northrend" },
    { pattern = "Lich King",       order = 3,  label = "Northrend" },
    { pattern = "Outland",         order = 2,  label = "Outland" },
    { pattern = "Burning Crusade", order = 2,  label = "Outland" },
    { pattern = "Classic",         order = 1,  label = "Classic" },
}

local function GetExpansionLabel(catName)
    if not catName then return nil, 0 end
    for _, entry in ipairs(EXPANSION_KEYWORDS) do
        if catName:find(entry.pattern) then
            return entry.label, entry.order
        end
    end
    return nil, 0
end

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
local function GetCharKey()
    return OneWoW_GUI and OneWoW_GUI:GetCharacterKey() or nil
end

function Scanner:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("TRADE_SKILL_SHOW")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function(_, event)
        if event == "TRADE_SKILL_SHOW" then
            C_Timer.After(0.5, function()
                Scanner:ScanCurrentProfession()
            end)
        elseif event == "PLAYER_LOGIN" then
            C_Timer.After(3, function()
                local charKey = GetCharKey()
                if charKey then
                    Scanner:CleanupStaleProfessions(charKey)
                end
            end)
        end
    end)
end

function Scanner:ScanExpansionSkills()
    local expansions = {}
    local categories = { C_TradeSkillUI.GetCategories() }
    if not categories or #categories == 0 then return expansions end

    local bestOrder = 0
    local bestLabel = nil
    local bestSkill = 0

    for _, categoryID in ipairs(categories) do
        local catInfo = C_TradeSkillUI.GetCategoryInfo(categoryID)
        if catInfo and catInfo.name and catInfo.hasProgressBar and (catInfo.skillLineMaxLevel or 0) > 0 then
            local currentSkill = catInfo.skillLineCurrentLevel or 0
            if currentSkill > 0 then
                local label, order = GetExpansionLabel(catInfo.name)
                if label then
                    table.insert(expansions, {
                        label = label,
                        order = order,
                        skillLevel = currentSkill,
                        maxSkill = catInfo.skillLineMaxLevel or 0,
                    })
                    if order > bestOrder then
                        bestOrder = order
                        bestLabel = label
                        bestSkill = currentSkill
                    end
                end
            end
        end
    end

    return expansions, bestLabel, bestSkill
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

    local expansions, bestExpansion, bestSkill = self:ScanExpansionSkills()

    db.scanCache[charKey][profName] = {
        known = knownRecipes,
        lastScan = time(),
        skillLevel = profInfo.skillLevel or 0,
        maxSkillLevel = profInfo.maxSkillLevel or 0,
        expansions = expansions,
        bestExpansion = bestExpansion,
        bestSkill = bestSkill,
    }

    self:CleanupStaleProfessions(charKey)

    ns:FireScanCallbacks({
        charKey = charKey,
        professionName = profName,
        recipeCount = #(recipeIDs or {}),
    })
end

function Scanner:CleanupStaleProfessions(charKey)
    local db = ns:GetDB()
    if not db.scanCache or not db.scanCache[charKey] then return end

    local currentProfNames = {}
    local prof1, prof2, archaeology, fishing, cooking = GetProfessions()
    local slots = { prof1, prof2, archaeology, fishing, cooking }
    for _, index in ipairs(slots) do
        if index then
            local name = GetProfessionInfo(index)
            if name then
                currentProfNames[name] = true
            end
        end
    end

    for profName, _ in pairs(db.scanCache[charKey]) do
        if not currentProfNames[profName] then
            db.scanCache[charKey][profName] = nil
        end
    end
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
