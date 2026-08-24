local _, ns = ...

-- Maps NPC SubName (merchant tooltip subtitle) → VendorCategories key.
-- Uses Blizzard GlobalStrings at runtime (locale-safe), plus a small curated
-- exact / needle table for titles that have no tracking GlobalString
-- ("General Goods", "Quartermaster"). Profession supply vendors use
-- "{Profession} Supplies" (and locale remainders) built from
-- C_TradeSkillUI.GetTradeSkillDisplayName. Never uses suite L[] labels.

ns.VendorCategoryMap = ns.VendorCategoryMap or {}
local Map = ns.VendorCategoryMap

local strlower = strlower
local strfind = strfind
local strsub = strsub
local tinsert = tinsert
local C_TradeSkillUI = C_TradeSkillUI

-- GlobalString name → category key. Values are read at first resolve.
local GLOBAL_SOURCES = {
    { "MINIMAP_TRACKING_VENDOR_FOOD",          "food" },
    { "MINIMAP_TRACKING_VENDOR_REAGENT",       "reagent" },
    { "MINIMAP_TRACKING_REPAIR",               "repair" },
    { "MINIMAP_TRACKING_INNKEEPER",            "innkeeper" },
    { "MINIMAP_TRACKING_BANKER",              "banker" },
    { "MINIMAP_TRACKING_FLIGHTMASTER",        "flight_master" },
    { "MINIMAP_TRACKING_STABLEMASTER",        "stable_master" },
    { "MINIMAP_TRACKING_TRAINER_CLASS",       "class_trainer" },
    { "MINIMAP_TRACKING_TRAINER_PROFESSION",  "profession_trainer" },
    { "MINIMAP_TRACKING_AUCTIONEER",          "auction_house" },
    { "MINIMAP_TRACKING_BARBER",              "barbershop" },
    { "MINIMAP_TRACKING_TRANSMOGRIFIER",      "transmog" },
    { "MINIMAP_TRACKING_ITEM_UPGRADE_MASTER", "item_upgrade" },
    { "AUCTION_CATEGORY_HOUSING",            "decor" },
}

-- Exact subtitle → key (client SubName strings with no GlobalString).
-- Machine-drafted for non-enUS; exact match only.
local EXACT_CURATED = {
    -- General Goods
    ["General Goods"] = "general",
    ["Gemischtwaren"] = "general",
    ["Fournitures générales"] = "general",
    ["Pertrechos"] = "general",
    ["Bens Diversos"] = "general",
    ["Beni Generici"] = "general",
    ["Хозяйственные товары"] = "general",
    ["일용품 상인"] = "general",
    ["杂货商"] = "general",
    ["雜貨商"] = "general",
    -- Quartermaster (exact)
    ["Quartermaster"] = "quartermaster",
    ["Rüstmeister"] = "quartermaster",
    ["Intendant"] = "quartermaster",
    ["Intendente"] = "quartermaster",
    ["Quartiermeister"] = "quartermaster",
    ["Intendencia"] = "quartermaster",
    ["Quartel-mestre"] = "quartermaster",
    ["Quartiermastro"] = "quartermaster",
    ["Интендант"] = "quartermaster",
    ["병참장교"] = "quartermaster",
    ["军需官"] = "quartermaster",
    ["軍需官"] = "quartermaster",
}

-- Lowercased needle → key. Quartermaster translations first so
-- "Renown Quartermaster" stays quartermaster, not a generic match.
local NEEDLE_CURATED = {
    { "quartermaster", "quartermaster" },
    { "rüstmeister", "quartermaster" },
    { "intendant", "quartermaster" },
    { "intendente", "quartermaster" },
    { "quartiermeister", "quartermaster" },
    { "intendencia", "quartermaster" },
    { "quartel-mestre", "quartermaster" },
    { "quartiermastro", "quartermaster" },
    { "интендант", "quartermaster" },
    { "병참장교", "quartermaster" },
    { "军需官", "quartermaster" },
    { "軍需官", "quartermaster" },
    { "renown", "quartermaster" },
    { "reputation", "reputation" },
    { "guild vendor", "guild_vendor" },
    { "pvp", "pvp" },
    { "conquest", "pvp" },
    { "delve", "delve" },
    { "housing", "decor" },
    { "decor", "decor" },
}

-- Keys that outrank General Goods / pet / repair on visit and at emit.
Map.SPECIAL = {
    quartermaster = true,
    reputation = true,
    decor = true,
    pvp = true,
    guild_vendor = true,
    delve = true,
}

--- True for Quartermaster, Reputation, Decor, PvP, Guild, and Delve.
---@param key string|nil
---@return boolean
function Map.IsSpecial(key)
    return key ~= nil and Map.SPECIAL[key] == true
end

-- TradeSkillLineIDs (same set RecipeKnownUtil uses for display names).
local PROFESSION_SKILL_IDS = {
    171, 164, 333, 202, 182,
    773, 755, 165, 186, 393,
    197, 185, 356, 129, 794,
}

-- Remainder after localized profession name for "{Profession} Supplies" titles.
-- Space-prefixed forms use " " .. remainder; compounds use remainder alone (deDE).
local SUPPLIES_REMAINDERS = {
    "Supplies",   -- enUS (Alchemy Supplies, Inscription Supplies, …)
    "Bedarf",     -- deDE compound / spaced
    "bedarf",
    "Vorräte",
    "Fournitures", -- frFR
    "suministros", -- esES/esMX
    "Suministros",
    "suprimentos", -- ptBR
    "Suprimentos",
    "forniture",   -- itIT
    "Forniture",
    "товары",      -- ruRU
    "Товары",
    "용품",        -- koKR
    "用品",        -- zhCN/zhTW
}

local exactLookup -- built once: GlobalString values + EXACT_CURATED + profession supplies
local professionNames -- localized profession display names

local function EnsureLookup()
    if exactLookup then return end
    exactLookup = {}
    professionNames = {}

    for _, entry in ipairs(GLOBAL_SOURCES) do
        local globalName, key = entry[1], entry[2]
        local value = _G[globalName]
        if type(value) == "string" and value ~= "" then
            exactLookup[value] = key
        end
    end
    for text, key in pairs(EXACT_CURATED) do
        exactLookup[text] = key
    end

    for _, skillID in ipairs(PROFESSION_SKILL_IDS) do
        local name = C_TradeSkillUI.GetTradeSkillDisplayName(skillID)
        if type(name) == "string" and name ~= "" then
            tinsert(professionNames, name)
            for _, rem in ipairs(SUPPLIES_REMAINDERS) do
                exactLookup[name .. " " .. rem] = "profession_supplies"
                exactLookup[name .. rem] = "profession_supplies"
            end
        end
    end
end

--- True when subtitle is "{Profession} <supplies-word>" (or a compound form).
local function MatchProfessionSupplies(subtitle)
    for _, name in ipairs(professionNames) do
        if strsub(subtitle, 1, #name) == name then
            local rest = strsub(subtitle, #name + 1)
            if rest ~= "" then
                local token = rest
                if strsub(rest, 1, 1) == " " then
                    token = strsub(rest, 2)
                end
                for _, rem in ipairs(SUPPLIES_REMAINDERS) do
                    if token == rem then
                        return "profession_supplies"
                    end
                end
            end
        end
    end
    return nil
end

--- Map an NPC subtitle (and optional canRepair) to a category key.
---@param subtitle string|nil
---@param canRepair boolean|nil
---@return string|nil categoryKey
function Map.Resolve(subtitle, canRepair)
    EnsureLookup()

    if subtitle and subtitle ~= "" then
        local key = exactLookup[subtitle]
        if key then
            return key
        end
        key = MatchProfessionSupplies(subtitle)
        if key then
            return key
        end
        local lower = strlower(subtitle)
        for _, entry in ipairs(NEEDLE_CURATED) do
            if strfind(lower, entry[1], 1, true) then
                return entry[2]
            end
        end
    end

    if canRepair then
        return "repair"
    end
    return nil
end
