local _, ns = ...

ns.TradeskillScanner = {}
local Scanner = ns.TradeskillScanner

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

local OneWoW_GUI = OneWoW_GUI
local function GetCharKey()
    return OneWoW_GUI and OneWoW_GUI:GetCharacterKey() or nil
end

-- Canonical base profession name for scanCache keys. Must match
-- CollectCurrentProfessionNames (parent over expansion skill-line) or
-- CleanupStaleProfessions deletes the bucket after every scan.
local function ResolveProfessionName(baseInfo, learned)
    baseInfo = baseInfo or {}
    if baseInfo.parentProfessionName and baseInfo.parentProfessionName ~= "" then
        return baseInfo.parentProfessionName
    end

    if learned and ns.TradeskillData and ns.TradeskillData.GetRecipeProfession then
        local tally = {}
        for recipeID in pairs(learned) do
            local profName = ns.TradeskillData:GetRecipeProfession(recipeID)
            if profName then
                tally[profName] = (tally[profName] or 0) + 1
            end
        end
        local bestName, bestCount = nil, 0
        for name, count in pairs(tally) do
            if count > bestCount then
                bestName, bestCount = name, count
            end
        end
        if bestName then
            return bestName
        end
    end

    if baseInfo.professionName and baseInfo.professionName ~= "" then
        return baseInfo.professionName
    end
    return nil
end

local function MergeKnownRecipes(dest, src)
    if not src then
        return 0
    end
    local added = 0
    for recipeID in pairs(src) do
        if not dest[recipeID] then
            dest[recipeID] = true
            added = added + 1
        end
    end
    return added
end

local function CountKnown(known)
    local n = 0
    if known then
        for _ in pairs(known) do
            n = n + 1
        end
    end
    return n
end

function Scanner:Initialize()
    -- Consume the core OneWoW.ProfessionRecipe funnel instead of owning a private
    -- TRADE_SKILL_SHOW frame. The snapshot is ready-gated and debounced upstream.
    OneWoW.ProfessionRecipe.RegisterScanCallback("CatalogData_Tradeskills", function(scan)
        Scanner:OnScan(scan)
    end)

    C_Timer.After(3, function()
        local charKey = GetCharKey()
        if charKey then
            Scanner:CleanupStaleProfessions(charKey)
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

-- Merge one ephemeral scan snapshot from the core funnel into scanCache. Keyed
-- by the base (parent) profession name so cleanup and Catalog filters agree.
function Scanner:OnScan(scan)
    if not scan then return end

    local charKey = scan.charKey or GetCharKey()
    if not charKey then return end

    local profName = ResolveProfessionName(scan.baseInfo, scan.learned)
    if not profName then return end

    local db = ns:GetDB()
    if not db.scanCache then db.scanCache = {} end
    if not db.scanCache[charKey] then db.scanCache[charKey] = {} end

    local knownRecipes = {}
    local recipeCount = 0
    if scan.learned then
        for recipeID in pairs(scan.learned) do
            knownRecipes[recipeID] = true
            recipeCount = recipeCount + 1
        end
    end
    -- Monotonic: a partial/empty scan never wipes a prior good set.
    if recipeCount == 0 then
        return
    end

    local bucket = db.scanCache[charKey][profName]
    if not bucket then
        bucket = { known = {} }
        db.scanCache[charKey][profName] = bucket
    end
    bucket.known = bucket.known or {}
    MergeKnownRecipes(bucket.known, knownRecipes)

    local expansions, bestExpansion, bestSkill = self:ScanExpansionSkills()
    bucket.lastScan = time()
    bucket.skillLevel = (scan.baseInfo and scan.baseInfo.skillLevel) or bucket.skillLevel or 0
    bucket.maxSkillLevel = (scan.baseInfo and scan.baseInfo.maxSkillLevel) or bucket.maxSkillLevel or 0
    bucket.expansions = expansions
    bucket.bestExpansion = bestExpansion
    bucket.bestSkill = bestSkill

    self:CleanupStaleProfessions(charKey)

    ns:FireScanCallbacks({
        charKey = charKey,
        professionName = profName,
        recipeCount = CountKnown(bucket.known),
    })
end

local function CollectCurrentProfessionNames()
    local names = {}
    for _, skillLineID in ipairs(C_TradeSkillUI.GetAllProfessionTradeSkillLines()) do
        local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
        if info and (info.skillLevel or 0) > 0 then
            local name = info.professionName
            if info.parentProfessionName and info.parentProfessionName ~= "" then
                name = info.parentProfessionName
            end
            if name and name ~= "" then
                names[name] = true
            end
        end
    end
    return names
end

local function SalvageProfessionTarget(profData, currentProfNames)
    if not (profData and profData.known and ns.TradeskillData and ns.TradeskillData.GetRecipeProfession) then
        return nil
    end
    local tally = {}
    for recipeID in pairs(profData.known) do
        local profName = ns.TradeskillData:GetRecipeProfession(recipeID)
        if profName and currentProfNames[profName] then
            tally[profName] = (tally[profName] or 0) + 1
        end
    end
    local bestName, bestCount = nil, 0
    for name, count in pairs(tally) do
        if count > bestCount then
            bestName, bestCount = name, count
        end
    end
    return bestName
end

function Scanner:CleanupStaleProfessions(charKey)
    local db = ns:GetDB()
    if not db.scanCache or not db.scanCache[charKey] then return end

    local currentProfNames = CollectCurrentProfessionNames()
    local cache = db.scanCache[charKey]
    local stale = {}

    for profName, profData in pairs(cache) do
        if not currentProfNames[profName] then
            local target = SalvageProfessionTarget(profData, currentProfNames)
            if target then
                local bucket = cache[target]
                if not bucket then
                    bucket = { known = {} }
                    cache[target] = bucket
                end
                bucket.known = bucket.known or {}
                MergeKnownRecipes(bucket.known, profData.known)
                if (profData.lastScan or 0) > (bucket.lastScan or 0) then
                    bucket.lastScan = profData.lastScan
                    bucket.skillLevel = profData.skillLevel or bucket.skillLevel
                    bucket.maxSkillLevel = profData.maxSkillLevel or bucket.maxSkillLevel
                    bucket.expansions = profData.expansions or bucket.expansions
                    bucket.bestExpansion = profData.bestExpansion or bucket.bestExpansion
                    bucket.bestSkill = profData.bestSkill or bucket.bestSkill
                end
            end
            tinsert(stale, profName)
        end
    end

    for _, profName in ipairs(stale) do
        cache[profName] = nil
    end
end

function Scanner:GetKnownRecipes(charKey, professionName)
    local db = ns:GetDB()
    if not db.scanCache then return nil end
    if not db.scanCache[charKey] then return nil end
    if not db.scanCache[charKey][professionName] then return nil end
    return db.scanCache[charKey][professionName]
end

-- Drop all cached tradeskill scans for one character. Returns true if anything
-- was removed (drives the AltTracker "Manage Alts" purge report).
function Scanner:PurgeCharacter(charKey)
    local db = ns:GetDB()
    if db and db.scanCache and db.scanCache[charKey] then
        db.scanCache[charKey] = nil
        return true
    end
    return false
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

local function AppendAltTrackerKnownBy(recipeID, knownBy, seen)
    local api = OneWoW_AltTracker_Professions_API
    if not api or not api.GetAllCharacters then
        return
    end
    for charKey, charData in pairs(api.GetAllCharacters()) do
        if not seen[charKey] and charData and charData.recipes then
            for _, recipeSet in pairs(charData.recipes) do
                if recipeSet[recipeID] then
                    seen[charKey] = true
                    tinsert(knownBy, charKey)
                    break
                end
            end
        end
    end
end

function Scanner:IsRecipeKnown(recipeID)
    local db = ns:GetDB()
    if db.scanCache then
        for charKey, professions in pairs(db.scanCache) do
            for _, profData in pairs(professions) do
                if profData.known and profData.known[recipeID] then
                    return true, charKey
                end
            end
        end
    end

    local api = OneWoW_AltTracker_Professions_API
    if api and api.GetAllCharacters then
        for charKey, charData in pairs(api.GetAllCharacters()) do
            if charData and charData.recipes then
                for _, recipeSet in pairs(charData.recipes) do
                    if recipeSet[recipeID] then
                        return true, charKey
                    end
                end
            end
        end
    end
    return false, nil
end

function Scanner:GetRecipeKnownBy(recipeID)
    local knownBy = {}
    local seen = {}
    local db = ns:GetDB()
    if db.scanCache then
        for charKey, professions in pairs(db.scanCache) do
            for _, profData in pairs(professions) do
                if profData.known and profData.known[recipeID] and not seen[charKey] then
                    seen[charKey] = true
                    tinsert(knownBy, charKey)
                end
            end
        end
    end
    AppendAltTrackerKnownBy(recipeID, knownBy, seen)
    sort(knownBy)
    return knownBy
end
