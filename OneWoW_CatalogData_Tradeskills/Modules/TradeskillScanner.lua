local _, ns = ...

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

local OneWoW_GUI = OneWoW_GUI
local function GetCharKey()
    return OneWoW_GUI and OneWoW_GUI:GetCharacterKey() or nil
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
-- by the base profession name (guarded non-empty); the funnel re-reads the base
-- info per scan so the name matches the learned set.
function Scanner:OnScan(scan)
    if not scan then return end

    local profName = scan.baseInfo and scan.baseInfo.professionName
    if not profName or profName == "" then return end

    local charKey = scan.charKey or GetCharKey()
    if not charKey then return end

    local sessionKey = charKey .. ":" .. profName
    if scannedThisSession[sessionKey] then return end
    scannedThisSession[sessionKey] = true

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

    local expansions, bestExpansion, bestSkill = self:ScanExpansionSkills()

    db.scanCache[charKey][profName] = {
        known = knownRecipes,
        lastScan = time(),
        skillLevel = scan.baseInfo.skillLevel or 0,
        maxSkillLevel = scan.baseInfo.maxSkillLevel or 0,
        expansions = expansions,
        bestExpansion = bestExpansion,
        bestSkill = bestSkill,
    }

    self:CleanupStaleProfessions(charKey)

    ns:FireScanCallbacks({
        charKey = charKey,
        professionName = profName,
        recipeCount = recipeCount,
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

function Scanner:IsRecipeKnown(recipeID)
    local db = ns:GetDB()
    if not db.scanCache then return false, nil end
    for charKey, professions in pairs(db.scanCache) do
        for _, profData in pairs(professions) do
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
        for _, profData in pairs(professions) do
            if profData.known and profData.known[recipeID] then
                table.insert(knownBy, charKey)
            end
        end
    end
    table.sort(knownBy)
    return knownBy
end
