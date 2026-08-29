-- ============================================================================
-- PredicateEngine
-- ============================================================================
-- Two-layer architecture:
--   Layer 1 (BuildProps): enriches a bag slot into a flat property table
--   Layer 2 (Compiler):   tokenizes + parses expressions into function(props)->bool
--
-- Design decisions:
--   - Structured tooltip bind detection via TooltipDataItemBinding
--   - Strict soulbound: character-only; account-bound does NOT match #soulbound
--   - ~ operator is string-contains ONLY; negation uses ! or "not"
--   - ${CONSTANT} curly-brace syntax for named constants / parameters
--   - Lazy tooltip metatable for the few remaining tooltip-only fields
--   - #currentseason: expansion guard + gear checks + season tooltip line
--     (CURRENT_SEASON_BONUS_IDS + EXPANSION_FIRST_GLOBAL_MPLUS_SEASON; see PREDICATE_ENGINE.md)
--   - #midnights1 / #midnights2: frozen Midnight track list IDs + season tooltip
--     label (generated SeasonTrackBonusListIDs; gray headers match)
-- ============================================================================

local _, ns = ...

ns.PredicateEngine = {}
local PE = ns.PredicateEngine
local ItemLevel = ns.ItemLevel

local tinsert, wipe = tinsert, wipe
local ipairs, pairs, tonumber, tostring = ipairs, pairs, tonumber, tostring
local strlower, strfind, strmatch, strtrim, strsplit = string.lower, string.find, string.match, strtrim, strsplit
local rawset, rawget, setmetatable = rawset, rawget, setmetatable
local pcall, select, math = pcall, select, math
local Enum = Enum
local C_Item, C_NewItems = C_Item, C_NewItems
local C_SeasonInfo = C_SeasonInfo
local C_Container = C_Container
local C_TooltipInfo = C_TooltipInfo
local C_ToyBox = C_ToyBox
local C_PetJournal = C_PetJournal
local C_TransmogCollection = C_TransmogCollection
local C_TradeSkillUI = C_TradeSkillUI
local C_HousingCatalog = C_HousingCatalog
local C_MythicPlus = C_MythicPlus
local GetSpecialization, GetSpecializationInfo = C_SpecializationInfo.GetSpecialization, C_SpecializationInfo.GetSpecializationInfo
local BattlePetToolTip_UnpackBattlePetLink = BattlePetToolTip_UnpackBattlePetLink
local UnitLevel = UnitLevel
local print, format = print, string.format
local GetMouseFoci = GetMouseFoci
local GameTooltip = GameTooltip
local GetCursorInfo = GetCursorInfo

-- ============================================================================
-- SECTION 2: CACHES
-- ============================================================================
-- propsCache:            keyed by "bagID:slotID", stores the per-slot enriched
--                        property table (slot-overlay applied over base).
-- identityPropsCache:    keyed by item-identity (hyperlink or itemID/pet stats),
--                        stores the slot-INDEPENDENT subset of props. Shared
--                        across every slot holding the same item.
-- tooltip caches: owned by TooltipScanner (bagDataCache, linkDataCache,
-- bagTextCache, linkTextCache). PredicateEngine forwards through thin wrappers.
-- compiledCache:         keyed by expression string, stores compiled
--                        function(props)->bool.

local propsCache = {}
local identityPropsCache = {}
local compiledCache = {}
--- Bank usability fallback keyed by GetItemIdentityKey (character-level, not per-slot).
local characterUsableCache = {}
--- Combine-item reagent lists keyed by itemID: false = not a combine item,
--- else an array of { itemID?/currencyID, quantityRequired }. Static game data
--- (recipe schematics), so it survives bag updates and character-context
--- changes; evicted per-item by InvalidateItemIDs and wiped by InvalidateCache.
local combineSchematicCache = {}
local Scanner = ns.TooltipScanner

-- ============================================================================
-- SECTION 3: CONSTANTS AND LOCALE PATTERNS
-- ============================================================================

-- Curated / generated ID sets (loaded before this file via TOC).
local ITEM_ID_OVERRIDES = ns.ItemIDOverrides
local HS_IDS = ns.HearthstoneIDs
local GEAR_TOKEN_IDS = ns.GearTokenIDs
local SEASON_TRACK_BONUS_LIST_IDS = ns.SeasonTrackBonusListIDs

local BATTLE_PET_CAGE_ID = 82800
local BATTLE_PET_TYPES = {
    Humanoid = 1,
    Dragonkin = 2,
    Flying = 3,
    Undead = 4,
    Critter = 5,
    Magic = 6,
    Elemental = 7,
    Beast = 8,
    Aquatic = 9,
    Mechanical = 10,
}

PE.BattlePetTypes = BATTLE_PET_TYPES

-- icons shared by knowledge items (Use: Study to increase your ... knowledge by #)
local KNOWLEDGE_ICONS = {[236225]=true, [136175]=true}

-- information about the item source: Enum.ItemCreationContext
-- https://warcraft.wiki.gg/wiki/ItemLink#Item_Context
local ITEM_CONTEXT_CATEGORY = {}
local function MapContexts(category, values)
    for _, v in ipairs(values) do
        ITEM_CONTEXT_CATEGORY[v] = category
    end
end
MapContexts("raid",       {3, 4, 5, 6, 81, 82, 83, 84, 85, 89, 90, 91, 92, 93, 94, 95, 96, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158})
MapContexts("dungeon",    {1, 2, 16, 17, 18, 19, 20, 23, 33, 34, 35, 87, 101, 102, 103, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 159, 160, 161})
MapContexts("delves",     {104, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138})
MapContexts("worldquest", {25, 26, 27, 28, 29, 30, 36, 37, 42, 43, 53, 54, 55, 74})
MapContexts("pvp",        {7, 8, 24, 38, 39, 40, 41, 44, 45, 46, 47, 48, 49, 50, 51, 52, 56, 76, 77, 78, 88})
MapContexts("store",      {12})

-- #currentseason: bonus IDs for crafted/voidforged gear (update each season).
local CURRENT_SEASON_BONUS_IDS = {
    [13653] = true, -- Voidforged
    [13654] = true, -- Voidforged
    [13655] = true, -- Voidforged
    [12066] = true, -- Radiance Crafted
    [13786] = true, -- Sporefused: Myth
}

-- First C_MythicPlus.GetCurrentSeason() global ID per expansion (ordinal 1 in tooltips).
-- DisplaySeason.Season for that expansion's first row; update when a new expansion begins.
local EXPANSION_FIRST_GLOBAL_MPLUS_SEASON = {
    [Enum.ExpansionLevel.Midnight] = 17,
}

local MIDNIGHT_EXPANSION_ID = Enum.ExpansionLevel.Midnight
local MIDNIGHT_SEASON_TRACK_LISTS = SEASON_TRACK_BONUS_LIST_IDS[MIDNIGHT_EXPANSION_ID]

local UPGRADE_PATH_PATTERN = ITEM_UPGRADE_TOOLTIP_FORMAT_STRING
    and ("^" .. ITEM_UPGRADE_TOOLTIP_FORMAT_STRING:gsub("%%s", ".*"):gsub("%%d", ".*"))

-- ItemUpgradeInfo.trackStringID tier constants (locale-independent; stable across seasons).
local UPGRADE_TRACK_IDS = {
    explorer   = 970,
    adventurer = 971,
    veteran    = 972,
    champion   = 973,
    hero       = 974,
    myth       = 978,
}

-- Published for category grouping (tier rank: myth → explorer).
PE.UpgradeTrackIDs  = UPGRADE_TRACK_IDS
PE.UpgradeTrackOrder = { 978, 974, 973, 972, 971, 970 }

local currentSeasonLabelCache

-- Class token (UnitClass second return, uppercase) -> classID used by
-- C_Item.DoesItemContainSpec. Needed for alt-path eligibility checks where
-- we start from a stored class string; UnitClass("player") already returns
-- classID for self-checks.
local CLASS_ID = {
    WARRIOR     = 1,
    PALADIN     = 2,
    HUNTER      = 3,
    ROGUE       = 4,
    PRIEST      = 5,
    DEATHKNIGHT = 6,
    SHAMAN      = 7,
    MAGE        = 8,
    WARLOCK     = 9,
    MONK        = 10,
    DRUID       = 11,
    DEMONHUNTER = 12,
    EVOKER      = 13,
}

PE.ClassID = CLASS_ID

-- ============================================================================
-- SECTION 4: CONSTANT_MAP
-- ============================================================================
-- Named constants for ${...} resolution in ResolveParams.
-- quality==${EPIC} becomes quality==4 before tokenizing.
local IQ = Enum.ItemQuality
local EL = Enum.ExpansionLevel

local CONSTANT_MAP = {
    -- Item quality
    POOR      = IQ.Poor,
    COMMON    = IQ.Common,
    UNCOMMON  = IQ.Uncommon,
    RARE      = IQ.Rare,
    EPIC      = IQ.Epic,
    LEGENDARY = IQ.Legendary,
    ARTIFACT  = IQ.Artifact,
    HEIRLOOM  = IQ.Heirloom,
    -- Expansion IDs
    CURRENTEXPANSION = LE_EXPANSION_LEVEL_CURRENT,
    CLASSIC     = EL.None,
    TBC         = EL.BurningCrusade,
    WRATH       = EL.Northrend,
    CATA        = EL.Cataclysm,
    MOP         = EL.MistsOfPandaria,
    WOD         = EL.Draenor,
    LEGION      = EL.Legion,
    BFA         = EL.BattleForAzeroth,
    SHADOWLANDS = EL.Shadowlands,
    DRAGONFLIGHT = EL.Dragonflight,
    WARWITHIN   = EL.WarWithin,
    MIDNIGHT    = EL.Midnight,
    LASTTITAN   = EL.LastTitan,
}

-- ============================================================================
-- SECTION 5: PROP_REGISTRY
-- ============================================================================
-- Maps user-facing property names (lowercased) to { field, type }.
-- Used by the tokenizer to recognize prop_compare (ilvl>=200) and
-- prop_range (ilvl:200-300) syntax.
-- "number" props support >=, <=, >, <, =, ==, !=
-- "string" props support =, ==, != (exact) and ~ (contains)

local PROP_REGISTRY = {}

local function RegisterPropAlias(nameOrNames, field, propType, unit)
    local entry = { field = field, type = propType or "number", unit = unit }
    if type(nameOrNames) == "table" then
        for _, name in ipairs(nameOrNames) do
            PROP_REGISTRY[strlower(name)] = entry
        end
    else
        PROP_REGISTRY[strlower(nameOrNames)] = entry
    end
end

local function ParseMoney(str)
    if not str or str == "" then return nil end
    local s = strlower(str)
    local hasUnit = false
    local copper = 0
    local pos = 1
    local len = #s
    while pos <= len do
        local numStart = pos
        while pos <= len and s:sub(pos, pos):match("[%d%.]") do
            pos = pos + 1
        end
        if pos == numStart then return nil end
        local n = tonumber(s:sub(numStart, pos - 1))
        if not n then return nil end
        local unit = s:sub(pos, pos)
        if unit == "g" then
            copper = copper + math.floor(n * 10000)
        elseif unit == "s" then
            copper = copper + math.floor(n * 100)
        elseif unit == "c" then
            copper = copper + math.floor(n)
        else
            return nil
        end
        hasUnit = true
        pos = pos + 1
    end
    return hasUnit and copper or nil
end
PE.ParseMoney = ParseMoney

local MONEY_CHAR_CLASS = "[%d%.gGsScC]"

-- Numeric properties
RegisterPropAlias({"vendorprice", "price", "unitvalue"},    "vendorPrice", "number", "money")
RegisterPropAlias({"ilvl", "itemlevel", "level"},           "ilvl")
RegisterPropAlias({"id", "itemid"},                         "id")
RegisterPropAlias({"count", "stacks"},                      "count")
RegisterPropAlias({"maxstack", "stacksize"},                "maxStack")
RegisterPropAlias({"reqlevel", "minlevel"},                 "reqLevel")
RegisterPropAlias({"expansion", "expac"},                   "expansionID")
RegisterPropAlias({"class", "typeid"},                      "classID")
RegisterPropAlias({"subclass", "subtypeid"},                "subClassID")

RegisterPropAlias("decorstorage",       "decorNumStorage")
RegisterPropAlias("decorplaced",        "decorNumPlaced")
RegisterPropAlias("decorredeemable",    "decorNumRedeemable")
RegisterPropAlias("decortotal",         "decorNumTotal")

RegisterPropAlias("pettype",        "petType")
RegisterPropAlias("petquality",     "petQuality")
RegisterPropAlias("petlevel",       "petLevel")
RegisterPropAlias("petmaxhealth",   "petMaxHealth")
RegisterPropAlias("petpower",       "petPower")
RegisterPropAlias("petspeed",       "petSpeed")
RegisterPropAlias("petcollected",   "petCollected")
RegisterPropAlias("petlimit",       "petLimit")

RegisterPropAlias("quality",        "quality")
RegisterPropAlias("bindtype",       "bindType")
RegisterPropAlias("currentbind",    "currentbind")
RegisterPropAlias("totalvalue",     "totalValue",     "number", "money")
RegisterPropAlias("craftedquality", "craftedQuality")
RegisterPropAlias("reagentquality", "reagentQuality")
RegisterPropAlias("upgradelevel",   "upgradeLevel")
RegisterPropAlias("upgrademax",     "upgradeMax")
RegisterPropAlias("maxlevel",       "maxLevel")
RegisterPropAlias("setid",          "setID")
RegisterPropAlias("sockets",        "sockets")
RegisterPropAlias("armor",          "statArmor")
RegisterPropAlias("durability",     "durability")
RegisterPropAlias("maxdurability",  "maxDurability")
RegisterPropAlias("durabilitypct",  "durabilityPct")

-- Stat properties (comparison syntax)
RegisterPropAlias({"intellect", "int"},         "statIntellect")
RegisterPropAlias({"agility", "agi"},           "statAgility")
RegisterPropAlias({"strength", "str"},          "statStrength")
RegisterPropAlias({"stamina", "stam"},          "statStamina")
RegisterPropAlias("crit",                       "statCrit")
RegisterPropAlias("haste",                      "statHaste")
RegisterPropAlias("mastery",                    "statMastery")
RegisterPropAlias({"versatility", "vers"},      "statVersatility")
RegisterPropAlias("speed",                      "statSpeed")
RegisterPropAlias("leech",                      "statLeech")
RegisterPropAlias("avoidance",                  "statAvoidance")

RegisterPropAlias("mylevel",        "playerLevel")
RegisterPropAlias("upgradelevel",   "upgradeLevel")
RegisterPropAlias("upgrademax",     "upgradeMax")

-- Spec membership (set type: `forclass=ID` / `forspec=ID` test membership;
-- viewer-independent via DoesItemContainSpec, NOT the link's spec field).
RegisterPropAlias("forclass",   "eligibleClasses", "set")
RegisterPropAlias("forspec",    "eligibleSpecs",   "set")

-- String properties
RegisterPropAlias("name",       "name",           "string")
RegisterPropAlias("equiploc",   "equipLoc",       "string")
RegisterPropAlias("tooltip",    "tooltipText",    "string")

-- ============================================================================
-- SECTION 6: FLAG_REGISTRY
-- ============================================================================
-- Maps lowercased bare-word flags to props field names.
-- Used by the tokenizer for verbose/Vendor-style rules:
--   IsEquipment & IsSoulbound & !IsInEquipmentSet

local FLAG_REGISTRY = {
    -- Core boolean flags
    isequipment             = "isEquipment",
    issoulbound             = "isSoulbound",
    isboe                   = "isBOE",
    isboa                   = "isBOA",
    isbou                   = "isBOU",
    iswue                   = "isWUE",
    isinequipmentset        = "isInEquipmentSet",
    iscollected             = "isCollected",
    isusable                = "isUsable",
    isjunk                  = "isJunk",
    isnew                   = "isNew",
    istoy                   = "isToy",
    ismount                 = "isMount",
    ispet                   = "isPet",
    iswildpet               = "isWildPet",
    canpetbattle            = "canPetBattle",
    ispettradeable          = "isPetTradeable",
    iscosmetic              = "isCosmetic",
    islocked                = "isLocked",
    hasloot                 = "hasLoot",
    isunsellable            = "isUnsellable",
    hascharges              = "hasCharges",
    isunique                = "isUnique",
    isuniqueequipped        = "isUniqueEquipped",
    isquestitem             = "isQuestItem",
    istierset               = "isTierSet",
    isgeartoken             = "isGearToken",
    isappearancecollected   = "isAppearanceCollected",
    hasappearance           = "hasAppearance",
    isensemble              = "isEnsemble",
    isupgradeable           = "isUpgradeable",
    isfullyupgraded         = "isFullyUpgraded",
    isupgradetrack          = "isUpgradeTrack",
    isprofessionequipment   = "isProfessionEquipment",
    isequipped              = "isEquipped",
    isequippable            = "isEquipment",
    iscraftingreagent       = "isCraftingReagent",
    hassocket               = "hasSocket",
    isknowledge             = "isKnowledge",
    isrefundable            = "isRefundable",
    isscrappable            = "isScrappable",
    isenchanted             = "isEnchanted",
    iscurrentseason         = "isCurrentSeason",
    isactiveseason          = "isCurrentSeason",
    ismidnights1            = "isMidnightS1",
    ismidnightseason1       = "isMidnightS1",
    ismidnights2            = "isMidnightS2",
    ismidnightseason2       = "isMidnightS2",

    -- Tooltip-derived flags (lazy)
    hasuseability           = "hasUseAbility",
    hasequipability         = "hasEquipAbility",
    isalreadyknown          = "isAlreadyKnown",
    istradeableloot         = "isTradeableLoot",

    -- Aliases mapping to canonical props fields
    iswarbound              = "isWarbound",
    iswarbounduntilequip    = "isWUE",
    isbindonequip           = "isBOE",
    isaccountbound          = "isWarbound",
    isbindonuse             = "isBOU",
}

-- ============================================================================
-- SECTION 7: KEYWORD_MAP
-- ============================================================================
-- Every #keyword maps to a function(props) -> bool.
-- Keywords are the terse search-bar syntax; flags (above) are the verbose
-- Vendor-rule syntax. Both resolve against the same props table.

local KEYWORD_MAP = {}

local KEYWORD_CANONICAL = {}
local KEYWORD_CANONICAL_ORDER = {}

-- User-defined tokens are not the engine's data. Rather than hold a table of
-- synonyms read out of SavedVariables, the engine holds one resolver callback
-- (installed by SearchExpand) that maps an unknown #token to an expression
-- body. Two consequences: no user state lives in the pure engine, and a token
-- may stand for any expression rather than only a built-in keyword.
local keywordResolver ---@type (fun(name: string): string|nil)|nil

-- Compiled token predicates keyed by lowercased token name. `false` records a
-- token that resolved to nothing, so repeat misses cost a table lookup instead
-- of a resolver round trip. Wiped whenever the resolver's data changes.
local resolvedTokens = {}

-- Tokens on the current resolution stack, for the cycle guard. `cycleCount`
-- ticks on every refusal; a resolution that saw one is left uncached, so an
-- innocent token reached through a cyclic walk cannot inherit that walk's cut.
local resolvingTokens = {}
local cycleCount = 0

--- Resolve a #keyword name to its predicate function.
--- Built-ins always win. An unknown token goes to the resolver, and its body is
--- compiled in place — so a token body may itself nest tokens, and (because
--- SearchExpand expands before returning) SAVED(...) and CATEGORY(...) too.
--- Unresolvable and cyclic tokens fail closed as always-false.
---@param name string lowercased keyword without #
---@return (fun(props: table): boolean)|nil
local function ResolveKeywordFn(name)
    local fn = KEYWORD_MAP[name]
    if fn then return fn end
    if not keywordResolver then return nil end

    local cached = resolvedTokens[name]
    if cached ~= nil then return cached or nil end

    if resolvingTokens[name] then
        cycleCount = cycleCount + 1
        return nil
    end

    local body = keywordResolver(name)
    if type(body) ~= "string" or body == "" then
        resolvedTokens[name] = false
        return nil
    end

    local mark = cycleCount
    resolvingTokens[name] = true
    local compiled = PE:Compile(body)
    resolvingTokens[name] = nil

    if cycleCount == mark then
        resolvedTokens[name] = compiled or false
    end
    return compiled
end

local function RegisterKeyword(nameOrNames, func)
    local names
    if type(nameOrNames) == "table" then
        names = nameOrNames
    else
        names = { nameOrNames }
    end
    for _, name in ipairs(names) do
        KEYWORD_MAP[strlower(name)] = func
    end
    if not KEYWORD_CANONICAL[func] then
        local firstName = strlower(names[1])
        KEYWORD_CANONICAL[func] = firstName
        tinsert(KEYWORD_CANONICAL_ORDER, { name = firstName, fn = func })
    end
end

-- ---- 7.1  Quality keywords ----
for _, def in ipairs({
    {{"poor", "grey", "gray"}, IQ.Poor},
    {{"common", "white"},      IQ.Common},
    {{"uncommon", "green"},    IQ.Uncommon},
    {{"rare", "blue"},         IQ.Rare},
    {{"epic", "purple"},       IQ.Epic},
    {{"legendary", "orange"},  IQ.Legendary},
    {"artifact",               IQ.Artifact},
    {"heirloom",               IQ.Heirloom},
}) do
    local q = def[2]
    RegisterKeyword(def[1], function(p) return p.quality == q end)
end

RegisterKeyword({"junk", "trash"}, function(p) return p.isJunk end)

-- ---- 7.2  Bind keywords ----
RegisterKeyword({"soulbound", "bound", "bop"},          function(p) return p.isSoulbound end)
RegisterKeyword({"boe", "bindonequip"},                 function(p) return p.isBOE end)
RegisterKeyword({"boa", "accountbound", "warbound"},    function(p) return p.isBOA or p.isWUE end)
RegisterKeyword({"bou", "bindonuse"},                   function(p) return p.isBOU end)
RegisterKeyword({"wue", "warbounduntilequip"},          function(p) return p.isWUE end)

-- ---- 7.3  Item class keywords ----
-- Same order as found in Enum.ItemClass
local function PropsIsRecipeItem(props)
    return props.classID == Enum.ItemClass.Recipe
end

RegisterKeyword("consumable", function(p)
    return p.classID == Enum.ItemClass.Consumable and not PropsIsRecipeItem(p)
end)
RegisterKeyword({"container", "bag"},                   function(p) return p.classID == Enum.ItemClass.Container end)
RegisterKeyword("weapon",                               function(p) return p.classID == Enum.ItemClass.Weapon end)
RegisterKeyword("gem",                                  function(p) return p.classID == Enum.ItemClass.Gem end)
RegisterKeyword("armor",                                function(p) return p.classID == Enum.ItemClass.Armor end)
RegisterKeyword("reagent",                              function(p) return p.classID == Enum.ItemClass.Reagent end)
RegisterKeyword("projectile",                           function(p) return p.classID == Enum.ItemClass.Projectile end)
RegisterKeyword({"tradegoods", "tradegood"},            function(p) return p.classID == Enum.ItemClass.Tradegoods end)
RegisterKeyword({"itemenhancement", "enhancement"},     function(p) return p.classID == Enum.ItemClass.ItemEnhancement end)

--- Identity-tier recipe check without BuildProps (safe for Collectibles.ResolveKeyFromItem).
local function IdentityIsRecipeItem(itemID)
    if not itemID then return false end
    local override = ITEM_ID_OVERRIDES[itemID]
    if override and override.classID then
        return override.classID == Enum.ItemClass.Recipe
    end
    -- GetItemInfoInstant: itemID, itemType, itemSubType, equipLoc, icon, classID, subclassID
    local classID = select(6, C_Item.GetItemInfoInstant(itemID))
    return classID == Enum.ItemClass.Recipe
end

RegisterKeyword("recipe",                               function(p) return PropsIsRecipeItem(p) end)
-- CurrencyTokenObsolete (skipped)
RegisterKeyword("quiver",                               function(p) return p.classID == Enum.ItemClass.Quiver end)

-- Quest items: classID OR C_Container quest info (populated in BuildProps)
RegisterKeyword({"quest", "questitem"},                 function(p) return p.isQuestItem end)
RegisterKeyword("key",                                  function(p) return p.classID == Enum.ItemClass.Key end)
-- PermanentObsolete (skipped)
RegisterKeyword({"miscellaneous", "misc"},              function(p) return p.classID == Enum.ItemClass.Miscellaneous end)
RegisterKeyword("glyph",                                function(p) return p.classID == Enum.ItemClass.Glyph end)
-- Battlepet is handled in BuildProps
RegisterKeyword({"tradeskill", "profession"},           function(p) return p.classID == Enum.ItemClass.Profession end)
RegisterKeyword("wowtoken",                             function(p) return p.classID == Enum.ItemClass.WoWToken end)
RegisterKeyword("housing",                              function(p) return p.classID == Enum.ItemClass.Housing end)

-- ---- 7.4  Composite consumable keywords ----
-- #potion includes potions, elixirs, and flasks
RegisterKeyword("potion", function(p)
    if p.classID ~= Enum.ItemClass.Consumable then return false end
    local sub = p.subClassID
    return sub == Enum.ItemConsumableSubclass.Potion
        or sub == Enum.ItemConsumableSubclass.Elixir
        or sub == Enum.ItemConsumableSubclass.Flasksphials
end)
RegisterKeyword({"food", "drink"}, function(p)
    return p.classID == Enum.ItemClass.Consumable
       and p.subClassID == Enum.ItemConsumableSubclass.Fooddrink
end)
RegisterKeyword("flask", function(p)
    return p.classID == Enum.ItemClass.Consumable
       and p.subClassID == Enum.ItemConsumableSubclass.Flasksphials
end)
RegisterKeyword("elixir", function(p)
    return p.classID == Enum.ItemClass.Consumable
       and p.subClassID == Enum.ItemConsumableSubclass.Elixir
end)
RegisterKeyword("bandage", function(p)
    return p.classID == Enum.ItemClass.Consumable
       and p.subClassID == Enum.ItemConsumableSubclass.Bandage
end)

RegisterKeyword("scroll", function(p)
    return p.classID == Enum.ItemClass.Consumable
       and p.subClassID == Enum.ItemConsumableSubclass.Scroll
end)
RegisterKeyword("vantusrune", function(p)
    return p.classID == Enum.ItemClass.Consumable
       and p.subClassID == Enum.ItemConsumableSubclass.VantusRune
end)
RegisterKeyword("utilitycurio", function(p)
    return p.classID == Enum.ItemClass.Consumable
       and p.subClassID == Enum.ItemConsumableSubclass.UtilityCurio
end)
RegisterKeyword("combatcurio", function(p)
    return p.classID == Enum.ItemClass.Consumable
       and p.subClassID == Enum.ItemConsumableSubclass.CombatCurio
end)
RegisterKeyword("curio", function(p)
    if p.classID ~= Enum.ItemClass.Consumable then return false end
    return p.subClassID == Enum.ItemConsumableSubclass.UtilityCurio
        or p.subClassID == Enum.ItemConsumableSubclass.CombatCurio
end)
RegisterKeyword("explosive", function(p)
    return p.classID == Enum.ItemClass.Consumable
       and p.subClassID == Enum.ItemConsumableSubclass.Generic
end)

-- ---- 7.5  Equipment keywords ----
RegisterKeyword({"gear", "equipment", "equippable"},    function(p) return p.isEquipment end)
RegisterKeyword({"set", "equipmentset"},                function(p) return p.isInEquipmentSet end)
RegisterKeyword("needsrepair",                          function(p) return p.needsRepair end)
RegisterKeyword("broken",                               function(p) return p.isBroken end)

RegisterKeyword("myclass", function(p)
    if p.classID == Enum.ItemClass.Profession then return false end -- some tradeskill items show up as equipment
    local _, _, classID = UnitClass("player")
    return classID and p.eligibleClasses[classID] == true
end)
RegisterKeyword("myspec", function(p)
    if not p.isEquipment then return false end
    if p.classID == Enum.ItemClass.Profession then return false end -- some tradeskill items show up as equipment
    local _, _, classID = UnitClass("player")
    local specID = GetSpecializationInfo(GetSpecialization())
    if not classID or not specID then return false end
    local item = p.hyperlink or p.id
    return item and C_Item.DoesItemContainSpec(item, classID, specID) == true
end)

-- ---- 7.6  Armor subclass keywords ----
for _, def in ipairs({
    {"cloth",       Enum.ItemArmorSubclass.Cloth},
    {"leather",     Enum.ItemArmorSubclass.Leather},
    {"mail",        Enum.ItemArmorSubclass.Mail},
    {"plate",       Enum.ItemArmorSubclass.Plate},
    {"cosmetic",    Enum.ItemArmorSubclass.Cosmetic},
    {"shield",      Enum.ItemArmorSubclass.Shield},
    {"libram",      Enum.ItemArmorSubclass.Libram},
    {"idol",        Enum.ItemArmorSubclass.Idol},
    {"totem",       Enum.ItemArmorSubclass.Totem},
    {"sigil",       Enum.ItemArmorSubclass.Sigil},
    {"relic",       Enum.ItemArmorSubclass.Relic},
}) do
    local sub = def[2]
    RegisterKeyword(def[1], function(p)
        return p.classID == Enum.ItemClass.Armor and p.subClassID == sub
    end)
end

-- ---- 7.7  Weapon subclass keywords ----
for _, def in ipairs({
    {{"1haxe", "onehandaxe"},       Enum.ItemWeaponSubclass.Axe1H},
    {{"2haxe", "twohandaxe"},       Enum.ItemWeaponSubclass.Axe2H},
    {{"1hsword", "onehandsword"},   Enum.ItemWeaponSubclass.Sword1H},
    {{"2hsword", "twohandsword"},   Enum.ItemWeaponSubclass.Sword2H},
    {{"1hmace", "onehandmace"},     Enum.ItemWeaponSubclass.Mace1H},
    {{"2hmace", "twohandmace"},     Enum.ItemWeaponSubclass.Mace2H},
    {{"dagger", "daggers"},         Enum.ItemWeaponSubclass.Dagger},
    {{"staff", "staves"},           Enum.ItemWeaponSubclass.Staff},
    {"polearm",                     Enum.ItemWeaponSubclass.Polearm},
    {{"bow", "bows"},               Enum.ItemWeaponSubclass.Bows},
    {{"gun", "guns"},               Enum.ItemWeaponSubclass.Guns},
    {"crossbow",                    Enum.ItemWeaponSubclass.Crossbow},
    {{"warglaive", "glaive"},       Enum.ItemWeaponSubclass.Warglaive},
    {{"fist", "fistweapon"},        Enum.ItemWeaponSubclass.Unarmed},
    {"thrown",                      Enum.ItemWeaponSubclass.Thrown},
    {"fishingpole",                  Enum.ItemWeaponSubclass.Fishingpole},
}) do
    local sub = def[2]
    RegisterKeyword(def[1], function(p)
        return p.classID == Enum.ItemClass.Weapon and p.subClassID == sub
    end)
end

-- Composite: #axe, #sword, #mace match both 1H and 2H variants
RegisterKeyword("axe", function(p)
    if p.classID ~= Enum.ItemClass.Weapon then return false end
    return p.subClassID == Enum.ItemWeaponSubclass.Axe1H
        or p.subClassID == Enum.ItemWeaponSubclass.Axe2H
end)
RegisterKeyword("sword", function(p)
    if p.classID ~= Enum.ItemClass.Weapon then return false end
    return p.subClassID == Enum.ItemWeaponSubclass.Sword1H
        or p.subClassID == Enum.ItemWeaponSubclass.Sword2H
end)
RegisterKeyword("mace", function(p)
    if p.classID ~= Enum.ItemClass.Weapon then return false end
    return p.subClassID == Enum.ItemWeaponSubclass.Mace1H
        or p.subClassID == Enum.ItemWeaponSubclass.Mace2H
end)

-- Composite: handedness
RegisterKeyword({"2h", "twohand"}, function(p)
    if p.classID ~= Enum.ItemClass.Weapon then return false end
    local s = p.subClassID
    return s == Enum.ItemWeaponSubclass.Axe2H
        or s == Enum.ItemWeaponSubclass.Sword2H
        or s == Enum.ItemWeaponSubclass.Mace2H
        or s == Enum.ItemWeaponSubclass.Polearm
        or s == Enum.ItemWeaponSubclass.Staff
end)
RegisterKeyword({"1h", "onehand"}, function(p)
    if p.classID ~= Enum.ItemClass.Weapon then return false end
    local s = p.subClassID
    return s == Enum.ItemWeaponSubclass.Axe1H
        or s == Enum.ItemWeaponSubclass.Sword1H
        or s == Enum.ItemWeaponSubclass.Mace1H
        or s == Enum.ItemWeaponSubclass.Dagger
        or s == Enum.ItemWeaponSubclass.Unarmed
        or s == Enum.ItemWeaponSubclass.Warglaive
end)

-- ---- 7.8  Gem subclass keywords ----
for _, def in ipairs({
    {{"intgem", "intellectgem"},        Enum.ItemGemSubclass.Intellect},
    {{"agigem", "agilitygem"},          Enum.ItemGemSubclass.Agility},
    {{"strgem", "strengthgem"},         Enum.ItemGemSubclass.Strength},
    {{"stagem", "staminagem"},          Enum.ItemGemSubclass.Stamina},
    {{"critgem", "criticalgem"},        Enum.ItemGemSubclass.Criticalstrike},
    {"masterygem",                      Enum.ItemGemSubclass.Mastery},
    {"hastegem",                        Enum.ItemGemSubclass.Haste},
    {{"versgem", "versatilitygem"},     Enum.ItemGemSubclass.Versatility},
    {"multigem",                        Enum.ItemGemSubclass.Multiplestats},
    {"artifactrelic",                   Enum.ItemGemSubclass.Artifactrelic},
}) do
    local sub = def[2]
    RegisterKeyword(def[1], function(p)
        return p.classID == Enum.ItemClass.Gem and p.subClassID == sub
    end)
end

-- ---- 7.9  Housing subclass keywords ----
for _, def in ipairs({
    {"decor",                   Enum.ItemHousingSubclass.Decor},
    {{"dye", "housingdye"},     Enum.ItemHousingSubclass.Dye},
    {"room",                    Enum.ItemHousingSubclass.Room},
    {"roomcustomization",       Enum.ItemHousingSubclass.RoomCustomization},
    {"exteriorcustomization",   Enum.ItemHousingSubclass.ExteriorCustomization},
    {"serviceitem",             Enum.ItemHousingSubclass.ServiceItem},
}) do
    local sub = def[2]
    RegisterKeyword(def[1], function(p)
        return p.classID == Enum.ItemClass.Housing and p.subClassID == sub
    end)
end

-- Housing decor by item shape: any Housing-class item, or a non-Housing item
-- that grants decor per C_Item.IsDecorItem (e.g. redeemable furniture drops).
RegisterKeyword({"housingdecor", "itemdecor"}, function(p)
    if p.classID == Enum.ItemClass.Housing then return true end
    return p.hyperlink ~= nil and C_Item.IsDecorItem(p.hyperlink) == true
end)

-- ---- 7.10  Profession subclass keywords ----
for _, def in ipairs({
    {"blacksmithing",   Enum.ItemProfessionSubclass.Blacksmithing},
    {"leatherworking",  Enum.ItemProfessionSubclass.Leatherworking},
    {"alchemy",         Enum.ItemProfessionSubclass.Alchemy},
    {"herbalism",       Enum.ItemProfessionSubclass.Herbalism},
    {"cooking",         Enum.ItemProfessionSubclass.Cooking},
    {"mining",          Enum.ItemProfessionSubclass.Mining},
    {"tailoring",       Enum.ItemProfessionSubclass.Tailoring},
    {"engineering",     Enum.ItemProfessionSubclass.Engineering},
    {"enchanting",      Enum.ItemProfessionSubclass.Enchanting},
    {"fishing",         Enum.ItemProfessionSubclass.Fishing},
    {"skinning",        Enum.ItemProfessionSubclass.Skinning},
    {"jewelcrafting",   Enum.ItemProfessionSubclass.Jewelcrafting},
    {"inscription",     Enum.ItemProfessionSubclass.Inscription},
    {"archaeology",     Enum.ItemProfessionSubclass.Archaeology},
}) do
    local sub = def[2]
    RegisterKeyword(def[1], function(p)
        return p.classID == Enum.ItemClass.Profession and p.subClassID == sub
    end)
end

-- ---- 7.10b  Character-aware profession keyword ----
-- #myprofs matches profession tools AND recipes whose subclass belongs to a
-- profession the current character has learned. Uses GetProfessions() +
-- GetProfessionInfo().skillLine (TradeSkillLineID) for locale-independent
-- identification. The known set is built lazily and invalidated on
-- SKILL_LINES_CHANGED.

local PROFESSION_NAMES_BY_SKILL_LINE = {
    [171] = "alchemy",       [164] = "blacksmithing",
    [185] = "cooking",       [333] = "enchanting",
    [202] = "engineering",   [356] = "fishing",
    [182] = "herbalism",     [773] = "inscription",
    [755] = "jewelcrafting", [165] = "leatherworking",
    [186] = "mining",        [393] = "skinning",
    [197] = "tailoring",     [794] = "archaeology",
}

local PROF_TOOL_NAME = {
    [Enum.ItemProfessionSubclass.Blacksmithing]  = "blacksmithing",
    [Enum.ItemProfessionSubclass.Leatherworking] = "leatherworking",
    [Enum.ItemProfessionSubclass.Alchemy]        = "alchemy",
    [Enum.ItemProfessionSubclass.Herbalism]      = "herbalism",
    [Enum.ItemProfessionSubclass.Cooking]        = "cooking",
    [Enum.ItemProfessionSubclass.Mining]         = "mining",
    [Enum.ItemProfessionSubclass.Tailoring]      = "tailoring",
    [Enum.ItemProfessionSubclass.Engineering]    = "engineering",
    [Enum.ItemProfessionSubclass.Enchanting]     = "enchanting",
    [Enum.ItemProfessionSubclass.Fishing]        = "fishing",
    [Enum.ItemProfessionSubclass.Skinning]       = "skinning",
    [Enum.ItemProfessionSubclass.Jewelcrafting]  = "jewelcrafting",
    [Enum.ItemProfessionSubclass.Inscription]    = "inscription",
    [Enum.ItemProfessionSubclass.Archaeology]    = "archaeology",
}

-- Recipe subclass enum uses different numeric values than profession subclass
-- enum; we must pivot through the lowercase name.
local PROF_RECIPE_NAME = {
    [Enum.ItemRecipeSubclass.Alchemy]        = "alchemy",
    [Enum.ItemRecipeSubclass.Blacksmithing]  = "blacksmithing",
    [Enum.ItemRecipeSubclass.Cooking]        = "cooking",
    [Enum.ItemRecipeSubclass.Enchanting]     = "enchanting",
    [Enum.ItemRecipeSubclass.Engineering]    = "engineering",
    [Enum.ItemRecipeSubclass.Inscription]    = "inscription",
    [Enum.ItemRecipeSubclass.Jewelcrafting]  = "jewelcrafting",
    [Enum.ItemRecipeSubclass.Leatherworking] = "leatherworking",
    [Enum.ItemRecipeSubclass.Tailoring]      = "tailoring",
    [Enum.ItemRecipeSubclass.Fishing]        = "fishing",
    [Enum.ItemRecipeSubclass.FirstAid]       = "firstaid",
    [Enum.ItemRecipeSubclass.Book]           = "book"
}

local knownProfs

local function RefreshKnownProfessions()
    knownProfs = {}
    local slots = { GetProfessions() }
    for _, idx in ipairs(slots) do
        if idx then
            local skillLine = select(7, GetProfessionInfo(idx))
            local name = PROFESSION_NAMES_BY_SKILL_LINE[skillLine]
            if name then knownProfs[name] = true end
        end
    end
end

function PE:InvalidateKnownProfessions()
    knownProfs = nil
end

RegisterKeyword({"myprofs", "myprofession", "myprofessions"}, function(p)
    if not knownProfs then RefreshKnownProfessions() end
    local cid = p.classID
    if cid == Enum.ItemClass.Profession then
        local name = PROF_TOOL_NAME[p.subClassID]
        return name ~= nil and knownProfs[name] == true
    end
    if cid == Enum.ItemClass.Recipe then
        local name = PROF_RECIPE_NAME[p.subClassID]
        return name ~= nil and knownProfs[name] == true
    end
    return false
end)

-- ---- 7.11  Miscellaneous subclass keywords ----
RegisterKeyword("holiday", function(p)
    return p.classID == Enum.ItemClass.Miscellaneous
       and p.subClassID == Enum.ItemMiscellaneousSubclass.Holiday
end)
RegisterKeyword("companionpet", function(p)
    return p.classID == Enum.ItemClass.Miscellaneous
       and p.subClassID == Enum.ItemMiscellaneousSubclass.CompanionPet
end)
RegisterKeyword("mountequipment", function(p)
    return p.classID == Enum.ItemClass.Miscellaneous
       and p.subClassID == Enum.ItemMiscellaneousSubclass.MountEquipment
end)

-- ---- 7.12  Reagent subclass keywords ----
RegisterKeyword("contexttoken", function(p)
    return p.classID == Enum.ItemClass.Reagent
       and p.subClassID == Enum.ItemReagentSubclass.ContextToken
end)

-- ---- 7.13  Recipe subclass keywords ----
for _, def in ipairs({
    {"alchemyrecipe",           Enum.ItemRecipeSubclass.Alchemy},
    {"blacksmithingrecipe",     Enum.ItemRecipeSubclass.Blacksmithing},
    {"cookingrecipe",           Enum.ItemRecipeSubclass.Cooking},
    {"enchantingrecipe",        Enum.ItemRecipeSubclass.Enchanting},
    {"engineeringrecipe",       Enum.ItemRecipeSubclass.Engineering},
    {"inscriptionrecipe",       Enum.ItemRecipeSubclass.Inscription},
    {"jewelcraftingrecipe",     Enum.ItemRecipeSubclass.Jewelcrafting},
    {"leatherworkingrecipe",    Enum.ItemRecipeSubclass.Leatherworking},
    {"tailoringrecipe",         Enum.ItemRecipeSubclass.Tailoring},
    {"fishingrecipe",           Enum.ItemRecipeSubclass.Fishing},
    {"firstaidrecipe",          Enum.ItemRecipeSubclass.FirstAid},
    {"bookrecipe",              Enum.ItemRecipeSubclass.Book},
}) do
    local sub = def[2]
    RegisterKeyword(def[1], function(p)
        return p.classID == Enum.ItemClass.Recipe and p.subClassID == sub
    end)
end

-- ---- 7.13b  Glyph subclass keywords ----
for _, def in ipairs({
    {"warriorglyph",      1},
    {"paladinglyph",      2},
    {"hunterglyph",       3},
    {"rogueglyph",        4},
    {"priestglyph",       5},
    {"deathknightglyph",  6},
    {"shamanglyph",       7},
    {"mageglyph",         8},
    {"warlockglyph",      9},
    {"monkglyph",        10},
    {"druidglyph",       11},
    {"demonhunterglyph", 12},
}) do
    local sub = def[2]
    RegisterKeyword(def[1], function(p)
        return p.classID == Enum.ItemClass.Glyph and p.subClassID == sub
    end)
end

-- ---- 7.13c  Tradegoods subclass keywords ----
for _, def in ipairs({
    {"craftingreagentparts",                            1},
    {"craftingreagentjewelcrafting",                    4},
    {"craftingreagentcloth",                            5},
    {"craftingreagentleather",                          6},
    {{"craftingreagentmetal", "craftingreagentstone"},  7},
    {"craftingreagentcooking",                          8},
    {"craftingreagentherb",                             9},
    {"craftingreagentelemental",                        10},
    {"craftingreagentother",                            11},
    {"craftingreagentenchanting",                       12},
    {"craftingreagentinscription",                      16},
    {"craftingreagentoptional",                         18},
    {"craftingreagentfinishing",                        19},
}) do
    local sub = def[2]
    RegisterKeyword(def[1], function(p)
        return p.classID == Enum.ItemClass.Tradegoods and p.subClassID == sub
    end)
end

-- ---- 7.14  Slot keywords ----
for _, def in ipairs({
    {{"head", "helm", "helmet"},        "INVTYPE_HEAD"},
    {{"neck", "necklace", "amulet"},    "INVTYPE_NECK"},
    {{"shoulder", "shoulders"},         "INVTYPE_SHOULDER"},
    {{"waist", "belt"},                 "INVTYPE_WAIST"},
    {{"legs", "pants"},                 "INVTYPE_LEGS"},
    {{"feet", "boots"},                 "INVTYPE_FEET"},
    {{"wrist", "bracers", "bracer"},    "INVTYPE_WRIST"},
    {{"hands", "gloves"},               "INVTYPE_HAND"},
    {{"finger", "ring"},                "INVTYPE_FINGER"},
    {"trinket",                         "INVTYPE_TRINKET"},
    {{"back", "cloak", "cape"},         "INVTYPE_CLOAK"},
    {"mainhand",                        "INVTYPE_WEAPONMAINHAND"},
    {"tabard",                          "INVTYPE_TABARD"},
    {"shirt",                           "INVTYPE_BODY"},
}) do
    local loc = def[2]
    RegisterKeyword(def[1], function(p) return p.equipLoc == loc end)
end

-- Special multi-location slot keywords
RegisterKeyword("chest",            function(p) return p.equipLoc == "INVTYPE_CHEST" or p.equipLoc == "INVTYPE_ROBE" end)
RegisterKeyword("robe",             function(p) return p.equipLoc == "INVTYPE_ROBE" end)
RegisterKeyword("offhand",          function(p) return p.equipLoc == "INVTYPE_WEAPONOFFHAND" or p.equipLoc == "INVTYPE_HOLDABLE" end)
RegisterKeyword("holdable",         function(p) return p.equipLoc == "INVTYPE_HOLDABLE" end)
RegisterKeyword("ranged",           function(p) return p.equipLoc == "INVTYPE_RANGED" or p.equipLoc == "INVTYPE_RANGEDRIGHT" end)
RegisterKeyword({"wand", "wands"},  function(p) return p.equipLoc == "INVTYPE_RANGEDRIGHT" or (p.classID == Enum.ItemClass.Weapon and p.subClassID == Enum.ItemWeaponSubclass.Wand) end)

-- ---- 7.15  Expansion keywords ----
for _, def in ipairs({
    {"currentexpansion",                                LE_EXPANSION_LEVEL_CURRENT},
    {{"classic", "vanilla"},                            EL.None},
    {{"burningcrusade", "tbc"},                         EL.BurningCrusade},
    {{"wrath", "wotlk", "northrend"},                   EL.Northrend},
    {{"cataclysm", "cata"},                             EL.Cataclysm},
    {{"mistsofpandaria", "mists", "mop", "pandaria"},   EL.MistsOfPandaria},
    {{"draenor", "wod", "warlords"},                    EL.Draenor},
    {"legion",                                          EL.Legion},
    {{"battleforazeroth", "bfa"},                       EL.BattleForAzeroth},
    {{"shadowlands", "sl"},                             EL.Shadowlands},
    {{"dragonflight", "df"},                            EL.Dragonflight},
    {{"warwithin", "tww", "thewarwithin"},              EL.WarWithin},
    {"midnight",                                        EL.Midnight},
    {{"lasttitan", "titan"},                            EL.LastTitan},
}) do
    local id = def[2]
    RegisterKeyword(def[1], function(p) return p.expansionID == id end)
end

-- ---- 7.16  Collectible keywords ----
-- Tri-state collection ownership for collectible-shaped items only. Backed by
-- `OneWoW.Collectibles.GetItemCollectionStatus` (true = owned, false = missing,
-- nil = not a collectible). Cached on props as 0/1/2.
local function GetCollectionContext(props)
    if not props then return nil end
    local bagID, slotID = rawget(props, "_bagID"), rawget(props, "_slotID")
    if not (bagID and slotID) and not rawget(props, "hyperlink") then
        return nil
    end
    return {
        bagID = bagID,
        slotID = slotID,
        hyperlink = rawget(props, "hyperlink"),
    }
end

local function ResolveCollectionStatus(p)
    local cached = rawget(p, "_collectionStatus")
    if cached ~= nil then
        if cached == 0 then return nil end
        return cached == 1
    end

    local st = OneWoW.Collectibles.GetItemCollectionStatus(p.id, p.hyperlink, GetCollectionContext(p))
    local status
    if st then
        status = st.collected == true
    end

    rawset(p, "_collectionStatus", status == nil and 0 or (status and 1 or 2))
    return status
end

local function ResolveAltCollectionStatus(p)
    if ResolveCollectionStatus(p) == true then return false end
    if ResolveCollectionStatus(p) == nil then return nil end

    local cached = rawget(p, "_altCollectionStatus")
    if cached ~= nil then
        return cached == 1
    end

    local st = OneWoW.Collectibles.GetItemCollectionStatus(p.id, p.hyperlink, GetCollectionContext(p))
    local alt = st and st.collectedByAlt == true
    rawset(p, "_altCollectionStatus", alt and 1 or 0)
    return alt
end

RegisterKeyword("toy",                  function(p) return p.isToy end)
RegisterKeyword("mount",                function(p) return p.isMount end)
RegisterKeyword({"pet", "battlepet"},   function(p) return p.isPet end)
RegisterKeyword({"collected", "collectionknown"}, function(p) return ResolveCollectionStatus(p) == true end)
RegisterKeyword({"uncollected", "collectionmissing"}, function(p) return ResolveCollectionStatus(p) == false end)
RegisterKeyword("altcollected",         function(p) return ResolveAltCollectionStatus(p) == true end)
RegisterKeyword("altuncollected",       function(p)
    local selfStatus = ResolveCollectionStatus(p)
    if selfStatus == nil or selfStatus == true then return false end
    return ResolveAltCollectionStatus(p) ~= true
end)
RegisterKeyword("alreadyknown",         function(p) return p.isAlreadyKnown end)

for _, def in ipairs({
    {"pethumanoid",   BATTLE_PET_TYPES.Humanoid},
    {"petdragonkin",  BATTLE_PET_TYPES.Dragonkin},
    {"petflying",     BATTLE_PET_TYPES.Flying},
    {"petundead",     BATTLE_PET_TYPES.Undead},
    {"petcritter",    BATTLE_PET_TYPES.Critter},
    {"petmagic",      BATTLE_PET_TYPES.Magic},
    {"petelemental",  BATTLE_PET_TYPES.Elemental},
    {"petbeast",      BATTLE_PET_TYPES.Beast},
    {"petaquatic",    BATTLE_PET_TYPES.Aquatic},
    {"petmechanical", BATTLE_PET_TYPES.Mechanical},
}) do
    local petType = def[2]
    RegisterKeyword(def[1], function(p) return p.petType == petType end)
end

RegisterKeyword("wildpet",         function(p) return p.isWildPet end)
RegisterKeyword("petcanbattle",       function(p) return p.canPetBattle end)
RegisterKeyword("pettradeable",    function(p) return p.isPetTradeable end)

-- ---- 7.17  Transmog keywords ----
RegisterKeyword("transmog",         function(p) return p.hasAppearance end)
RegisterKeyword("ensemble",         function(p) return p.isEnsemble end)
RegisterKeyword("knowntransmog",    function(p) return p.isAppearanceCollected end)
RegisterKeyword("unknowntransmog",  function(p) return not p.isAppearanceCollected end)
RegisterKeyword("catalyst",         function(p) return p.isCatalyst end)
RegisterKeyword("catalystupgrade",  function(p) return p.isCatalystUpgrade end)

-- ---- 7.18  State keywords ----
RegisterKeyword("usable",           function(p) return p.isUsable end)
RegisterKeyword("unusable",         function(p) return not p.isUsable end)
RegisterKeyword("locked",           function(p) return p.isLocked end)
RegisterKeyword("hasloot",          function(p) return p.hasLoot end)
RegisterKeyword("new",              function(p) return p.isNew end)
RegisterKeyword("socket",           function(p) return p.hasSocket end)
RegisterKeyword("equipped",         function(p) return p.isEquipped end)
RegisterKeyword("knowledge",        function(p) return p.isKnowledge end)
RegisterKeyword("refundable",       function(p) return p.isRefundable end)
RegisterKeyword("enchanted",        function(p) return p.isEnchanted end)
RegisterKeyword("scrappable",       function(p) return p.isScrappable end)

-- ---- 7.19  Vendor / value keywords ----
RegisterKeyword("unsellable", function(p) return p.isUnsellable end)
RegisterKeyword("sellable",   function(p) return not p.isUnsellable end)

-- ---- 7.20  Crafting keywords ----
RegisterKeyword("craftingreagent",     function(p) return p.isCraftingReagent end)
RegisterKeyword("crafted",             function(p) return p.isCrafted end)
RegisterKeyword("professionequipment", function(p) return p.isProfessionEquipment end)

-- ---- 7.21  Upgrade keywords ----
-- #upgrade is registered by ns.UpgradeDetection via PE:RegisterKeyword
-- at runtime since "is this an upgrade" is policy (mode, equipped state) that
-- belongs to that module. Without UpgradeDetection loaded, #upgrade is simply
-- unregistered and predicates using it evaluate to false.
-- #disenchantable / #de are registered by ns.Disenchant the same way.
RegisterKeyword("upgradeable",      function(p) return p.isUpgradeable end)
RegisterKeyword("fullyupgraded",    function(p) return p.isFullyUpgraded end)
RegisterKeyword({"currentseason", "activeseason"}, function(p) return p.isCurrentSeason == true end)
RegisterKeyword({"midnights1", "midnightseason1"}, function(p) return p.isMidnightS1 == true end)
RegisterKeyword({"midnights2", "midnightseason2"}, function(p) return p.isMidnightS2 == true end)

-- ---- 7.22  Tooltip-text keywords ----
-- These trigger the lazy tooltip scan on first access to tooltipText.
RegisterKeyword("charges",          function(p) return p.hasCharges end)
RegisterKeyword("onuse",            function(p) return p.hasUseAbility end)
RegisterKeyword("onequip",          function(p) return p.hasEquipAbility end)
RegisterKeyword("unique",           function(p) return p.isUnique or p.isPetUnique end)
RegisterKeyword("uniqueequipped",   function(p) return p.isUniqueEquipped end)
RegisterKeyword("reputation", function(p)
    local tt = p.tooltipText
    return tt and strfind(tt, REPUTATION, 1, true) ~= nil
end)
RegisterKeyword("tradeableloot", function(p) return p.isTradeableLoot end)
RegisterKeyword("openable", function(p)
    local tt = p.tooltipText
    return tt and (strfind(tt, ITEM_OPENABLE, 1, true) ~= nil)
end)

-- ---- 7.23  Special keywords ----
RegisterKeyword("hearthstone",  function(p) return p.isHearthstone end)
RegisterKeyword("keystone",     function(p) return p.isKeystone end)
RegisterKeyword("tierset",      function(p) return p.isTierSet end)
RegisterKeyword("geartoken",    function(p) return p.isGearToken end)
RegisterKeyword("battlepay",    function(p) return p.isBattlePayItem end)
RegisterKeyword("currency",     function(p) return p.isCurrency end)

-- ---- 7.24  Stat keywords ----
-- Primary stats
RegisterKeyword({"intellect", "int"},           function(p) return (p.statIntellect or 0) > 0 end)
RegisterKeyword({"agility", "agi"},             function(p) return (p.statAgility or 0) > 0 end)
RegisterKeyword({"strength", "str"},            function(p) return (p.statStrength or 0) > 0 end)
RegisterKeyword({"stamina", "stam"},            function(p) return (p.statStamina or 0) > 0 end)

-- Secondary stats
RegisterKeyword({"crit", "criticalstrike"},     function(p) return (p.statCrit or 0) > 0 end)
RegisterKeyword("haste",                        function(p) return (p.statHaste or 0) > 0 end)
RegisterKeyword("mastery",                      function(p) return (p.statMastery or 0) > 0 end)
RegisterKeyword({"versatility", "vers"},         function(p) return (p.statVersatility or 0) > 0 end)

-- Tertiary stats
RegisterKeyword("speed",                        function(p) return (p.statSpeed or 0) > 0 end)
RegisterKeyword("leech",                        function(p) return (p.statLeech or 0) > 0 end)
RegisterKeyword("avoidance",                    function(p) return (p.statAvoidance or 0) > 0 end)

-- ---- 7.25  Socket type keywords ----
RegisterKeyword("prismatic",       function(p) return (p.socketPrismatic or 0) > 0 end)
RegisterKeyword("metasocket",      function(p) return (p.socketMeta or 0) > 0 end)
RegisterKeyword("redsocket",       function(p) return (p.socketRed or 0) > 0 end)
RegisterKeyword("yellowsocket",    function(p) return (p.socketYellow or 0) > 0 end)
RegisterKeyword("bluesocket",      function(p) return (p.socketBlue or 0) > 0 end)
RegisterKeyword("cogwheel",        function(p) return (p.socketCogwheel or 0) > 0 end)
RegisterKeyword("tinkersocket",    function(p) return (p.socketTinker or 0) > 0 end)
RegisterKeyword("dominationsocket", function(p) return (p.socketDomination or 0) > 0 end)
RegisterKeyword("primordial",      function(p) return (p.socketPrimordial or 0) > 0 end)

-- ---- 7.26  Item creation context keywords ----
RegisterKeyword("raid", function(p) return p.itemContextCategory == "raid" end)
RegisterKeyword("dungeon", function(p) return p.itemContextCategory == "dungeon" end)
RegisterKeyword("delves", function(p) return p.itemContextCategory == "delves" end)
RegisterKeyword("worldquest", function(p) return p.itemContextCategory == "worldquest" end)
RegisterKeyword("pvp", function(p) return p.itemContextCategory == "pvp" end)
RegisterKeyword("store", function(p) return p.itemContextCategory == "store" end)

-- ---- 7.27  Item track upgrade keywords ----
RegisterKeyword("upgradetrack", function(p) return p.isUpgradeTrack end)
for _, keyword in ipairs({ "explorer", "adventurer", "veteran", "champion", "hero", "myth" }) do
    local trackID = UPGRADE_TRACK_IDS[keyword]
    RegisterKeyword(keyword, function(p) return p.upgradeTrackStringID == trackID end)
end

-- ============================================================================
-- SECTION 8: LAYER 1 — UTILITY FUNCTIONS
-- ============================================================================

-- ---------- ParseItemLink ----------
-- Fixed-position field indices (1-based, relative to strsplit output)
local FIXED_FIELDS = {
    itemID            = 1,
    enchantID         = 2,
    -- gemIDs occupy 3-6, handled separately
    suffixID          = 7,
    uniqueID          = 8,
    linkLevel         = 9,
    specializationID  = 10,
    modifiersMask     = 11,
    itemContext        = 12,
}

--- Extracts quality enum value from |cnIQx| color prefix.
--- NOTE: Some items emit |cnIQx:| with a trailing colon before |H.
--- Undocumented as of 11.1.5; we accept it optionally.
local function ExtractItemQuality(link)
    local q = link:match("|cnIQ(%d+):?|")
    return q and tonumber(q)
end

--- Extracts display name from hyperlink brackets.
local function ExtractItemName(link)
    return link:match("|h%[(.-)%]|h")
end

--- Consumes a count-prefixed variable-length segment from fields array.
--- Pattern: numEntries [:entry1 :entry2 ...]
local function ConsumeCountedSegment(fields, idx)
    local count = tonumber(fields[idx])
    if not count or count == 0 then
        return nil, idx + 1
    end
    local entries = {}
    for i = 1, count do
        entries[i] = tonumber(fields[idx + i])
    end
    return entries, idx + count + 1
end

--- Consumes item modifiers segment (key-value pairs).
--- Pattern: numModifiers [:type1 :value1 :type2 :value2 ...]
local function ConsumeModifiers(fields, idx)
    local count = tonumber(fields[idx])
    if not count or count == 0 then
        return nil, idx + 1
    end
    local modifiers = {}
    for i = 1, count do
        local offset = (i - 1) * 2
        modifiers[i] = {
            type  = tonumber(fields[idx + offset + 1]),
            value = tonumber(fields[idx + offset + 2]),
        }
    end
    return modifiers, idx + count * 2 + 1
end

--- Parses full item hyperlink or item string into a structured table.
--- Based on ItemLink format at warcraft.wiki.gg/wiki/ItemLink
--- Retail 12+ (Patch 11.1.5+: |cnIQx| color scheme)
---
--- Accepts either:
---   - Full hyperlink:  |cnIQ4|Hitem:12345:...|h[Name]|h|r
---   - Bare item string: item:12345:...
---
--- Returned table fields:
---   .itemID            number|nil
---   .enchantID         number|nil
---   .gems              table|nil   -- sparse array [1..4] of gem itemIDs
---   .suffixID          number|nil
---   .uniqueID          number|nil
---   .linkLevel         number|nil
---   .specializationID  number|nil
---   .modifiersMask     number|nil
---   .itemContext        number|nil  -- Enum.ItemCreationContext
---   .bonusIDs          table|nil   -- array of bonus ID numbers
---   .modifiers         table|nil   -- array of {type, value}
---   .relicBonusIDs     table|nil   -- sparse array [1..3], each an array of bonus IDs
---   .crafterGUID       string|nil  -- Player GUID string
---   .extraEnchantID    number|nil
---   .quality           number|nil  -- Enum.ItemQuality (from |cnIQx| prefix)
---   .name              string|nil  -- Display name from bracket text
local function ParseItemLink(link)
    if not link then return nil end

    local linkOptions = link:match("|Hitem:(.+)|h") or link:match("^item:(.+)")
    if not linkOptions then return nil end

    linkOptions = linkOptions:gsub("|h.*$", "")

    local fields = { strsplit(":", linkOptions) }
    local t = {}

    t.quality = ExtractItemQuality(link)
    t.name    = ExtractItemName(link)

    -- Fixed-position numeric fields
    for key, pos in pairs(FIXED_FIELDS) do
        t[key] = tonumber(fields[pos])
    end

    -- Gem IDs (positions 3-6); gemID4 is unused per the wiki but we parse it anyway
    for i = 1, 4 do
        local gem = tonumber(fields[i + 2])
        if gem then
            t.gems = t.gems or {}
            t.gems[i] = gem
        end
    end

    -- Variable-length segments start at index 13
    local idx = 13

    t.bonusIDs, idx = ConsumeCountedSegment(fields, idx)
    t.modifiers, idx = ConsumeModifiers(fields, idx)

    for i = 1, 3 do
        local relicBonuses
        relicBonuses, idx = ConsumeCountedSegment(fields, idx)
        if relicBonuses then
            t.relicBonusIDs = t.relicBonusIDs or {}
            t.relicBonusIDs[i] = relicBonuses
        end
    end

    local crafterGUID = fields[idx]
    if crafterGUID and #crafterGUID > 0 then
        t.crafterGUID = crafterGUID
    end
    idx = idx + 1

    t.extraEnchantID = tonumber(fields[idx])

    return t
end

-- ---------- Tooltip data (delegates to TooltipScanner) ----------

local function GetTooltipData(bagID, slotID)
    return Scanner:GetBagItemData(bagID, slotID)
end

local function GetTooltipDataByHyperlink(hyperlink)
    return Scanner:GetHyperlinkData(hyperlink)
end

local function GetTooltipText(bagID, slotID)
    return Scanner:GetBagItemText(bagID, slotID)
end

local function GetTooltipTextByHyperlink(hyperlink)
    return Scanner:GetHyperlinkText(hyperlink)
end

local function GetPropsTooltipData(props)
    return Scanner:GetPropsData(props)
end

-- ---------- GetBattlePetData ----------
---@param itemID number
---@param hyperlink string|nil
---@return table|nil
local function GetBattlePetData(itemID, hyperlink)
    local petGUID, speciesID, level, breedQuality, maxHealth, power, speed
    local petName, petType, isWild, canBattle, isTradeable, isUnique

    if itemID == BATTLE_PET_CAGE_ID and hyperlink then
        speciesID, level, breedQuality, maxHealth, power, speed = BattlePetToolTip_UnpackBattlePetLink(hyperlink)

        if speciesID then
            petName, _, petType, _, _, _, isWild, canBattle, isTradeable, isUnique = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
        end
    else
        petName, _, petType, _, _, _, isWild, canBattle, isTradeable, isUnique, _, _, speciesID = C_PetJournal.GetPetInfoByItemID(itemID)

        if petName then
            petGUID = select(2, C_PetJournal.FindPetIDByName(petName))

            if petGUID then
                _, maxHealth, power, speed, breedQuality = C_PetJournal.GetPetStats(petGUID)
            end
        end
    end

    if not speciesID then return nil end
    local numCollected, limit = C_PetJournal.GetNumCollectedInfo(speciesID)

    return {
        petGUID = petGUID,
        speciesID = speciesID,
        petLevel = level or 0,
        petQuality = breedQuality or 0,
        petMaxHealth = maxHealth or 0,
        petPower = power or 0,
        petSpeed = speed or 0,
        petType = petType or 0,
        petName = petName,
        isWild = isWild or false,
        canBattle = canBattle or false,
        isTradeable = isTradeable or false,
        isUnique = isUnique or false,
        numCollected = numCollected,
        limit = limit,
    }
end

---@param itemID number
---@param hyperlink string|nil
---@return string
local function GetItemIdentityKey(itemID, hyperlink)
    local petData = GetBattlePetData(itemID, hyperlink)

    -- Key always starts with "<itemID>|" so surgical per-itemID invalidation
    -- can prefix-match against caches keyed by identity (identityPropsCache,
    -- baseCategoryCache) in a single pass. The "|" separator never appears
    -- in raw hyperlinks, keeping the boundary unambiguous.
    if not petData then
        if hyperlink and hyperlink ~= "" then
            return tostring(itemID) .. "|" .. hyperlink
        end

        return tostring(itemID) .. "|"
    end

    return tostring(itemID)
        .. "|" .. tostring(petData.speciesID)
        .. ":" .. tostring(petData.petLevel)
        .. ":" .. tostring(petData.petQuality)
        .. ":" .. tostring(petData.petMaxHealth)
        .. ":" .. tostring(petData.petPower)
        .. ":" .. tostring(petData.petSpeed)
end

---@param itemID number
---@param bagID number|nil
---@param slotID number|nil
---@param hyperlink string|nil
---@return string
local function GetItemCacheKey(itemID, bagID, slotID, hyperlink)
    local cacheKey
    if bagID and slotID then
        cacheKey = bagID .. ":" .. slotID
    else
        cacheKey = GetItemIdentityKey(itemID, hyperlink)
    end

    return cacheKey
end

--- Whether the current character owns the collectible this item grants.
---@param itemID number
---@param hyperlink string|nil
---@return boolean
local function ItemCollectionOwned(itemID, hyperlink)
    local st = OneWoW.Collectibles.GetItemCollectionStatus(itemID, hyperlink)
    return st and st.collected == true or false
end

-- ---------- ResolveTooltipFields ----------
-- Lazily populates the tooltip-derived fields on first access.
-- Delegates to TooltipScanner:PopulateTooltipProps; recipe alreadyKnown
-- bridge stays here (Collectibles / RecipeKnownUtil context).
local function ResolveTooltipFields(props)
    return Scanner:PopulateTooltipProps(props, {
        recipeAlreadyKnown = function(p)
            if not PropsIsRecipeItem(p) then return false end
            local Util = OneWoW.RecipeKnownUtil
            if not Util then return false end
            return Util:IsRecipeKnown(rawget(p, "id"), GetCollectionContext(p)) == true
        end,
    })
end

-- ---------- ResolveBind ----------
-- Tooltip-based bind detection. Source-aware so the same enum value can carry
-- different semantics depending on which tooltip API supplied it:
--
--   * Bag mode (C_TooltipInfo.GetBagItem): the item is in the player's
--     possession. `bonding == BindOnPickup` is observed only for tradeable
--     BoP loot (within the trade timer) and is treated as currently-bound,
--     which is the historical behavior #bop / #soulbound users rely on.
--
--   * Link mode (C_TooltipInfo.GetHyperlink): the item is being inspected
--     out-of-container (vendor / loot / great vault / etc.). Here
--     `bonding == BindOnPickup` is the policy line shown for unowned items;
--     the player is not yet bound to it, so #bop / #soulbound must NOT match.
--
-- Other binding values (BindOnEquip, BindOnUse, Soulbound, account variants,
-- account-until-equipped) carry the same meaning in both modes.
--
-- Asymmetry note: in tooltip-only (link) mode, #boe / #bou / #warbound / #wue
-- match because the policy-line state is well-defined; #bop / #soulbound do
-- not match because we cannot infer current-bound state for an item the
-- player does not own. This is intentional and matches user expectations.
local TDIB = Enum.TooltipDataItemBinding

local BIND_FIELDS = { "isSoulbound", "isBOE", "isBOA", "isBOU", "isWUE", "isWarbound" }

local function ClearBindFields(props)
    for i = 1, #BIND_FIELDS do
        rawset(props, BIND_FIELDS[i], false)
    end
end

-- source: "bag" or "link". Controls whether BindOnPickup is treated as state
-- (bag) or policy-only (link).
local function ApplyBonding(props, bonding, source)
    local isBOA = bonding == TDIB.Account or bonding == TDIB.BnetAccount
               or bonding == TDIB.BindToAccount or bonding == TDIB.BindToBnetAccount
    local isWUE = bonding == TDIB.AccountUntilEquipped or bonding == TDIB.BindToAccountUntilEquipped

    -- Soulbound mapping: in bag mode, BindOnPickup folds into Soulbound to
    -- preserve #bop matching for tradeable BoP loot. In link mode it does not.
    local isSoulbound = bonding == TDIB.Soulbound
    if source == "bag" and bonding == TDIB.BindOnPickup then
        isSoulbound = true
    end

    rawset(props, "currentbind", bonding)
    rawset(props, "isSoulbound", isSoulbound)
    rawset(props, "isBOE",       bonding == TDIB.BindOnEquip)
    rawset(props, "isBOA",       isBOA)
    rawset(props, "isBOU",       bonding == TDIB.BindOnUse)
    rawset(props, "isWUE",       isWUE)
    rawset(props, "isWarbound",  isBOA or isWUE)
end

local function ResolveBind(props)
    local bagID, slotID = rawget(props, "_bagID"), rawget(props, "_slotID")
    local hyperlink = rawget(props, "hyperlink")

    -- Fetch through the shared tooltipData caches so ResolveTooltipFields and
    -- ResolveBind pay at most one C_TooltipInfo call per slot/hyperlink.
    -- Falls through (not elseif) so a slot whose bag-mode lookup yields
    -- nothing still gets a chance at the hyperlink-mode policy tooltip,
    -- matching ResolveTooltipFields' precedence.
    local tooltipData
    local source

    if bagID and slotID then
        tooltipData = GetTooltipData(bagID, slotID)
        source = "bag"
    end
    if not tooltipData and hyperlink then
        tooltipData = GetTooltipDataByHyperlink(hyperlink)
        source = "link"
    end

    local bonding = Scanner:GetBindState(tooltipData)

    if bonding == nil then
        ClearBindFields(props)
        return
    end

    ApplyBonding(props, bonding, source)
end

-- ---------- ResolveStats ----------
-- Lazily populates item stat fields on first access.
-- Called by the propsMT.__index metatable handler.
-- Keys returned by C_Item.GetItemStats are ITEM_MOD_*_SHORT global names (not localized).
local STAT_GLOBAL_MAP = {
    ITEM_MOD_INTELLECT_SHORT      = "statIntellect",
    ITEM_MOD_AGILITY_SHORT        = "statAgility",
    ITEM_MOD_STRENGTH_SHORT       = "statStrength",
    ITEM_MOD_STAMINA_SHORT        = "statStamina",
    ITEM_MOD_CRIT_RATING_SHORT    = "statCrit",
    ITEM_MOD_HASTE_RATING_SHORT   = "statHaste",
    ITEM_MOD_MASTERY_RATING_SHORT = "statMastery",
    ITEM_MOD_VERSATILITY          = "statVersatility",
    ITEM_MOD_CR_SPEED_SHORT       = "statSpeed",
    ITEM_MOD_CR_LIFESTEAL_SHORT   = "statLeech",
    ITEM_MOD_CR_AVOIDANCE_SHORT   = "statAvoidance",
    RESISTANCE0_NAME              = "statArmor",
    -- Socket types (from GetItemStats EMPTY_SOCKET_* keys)
    EMPTY_SOCKET_PRISMATIC          = "socketPrismatic",
    EMPTY_SOCKET_NO_COLOR           = "socketPrismatic",
    EMPTY_SOCKET_META               = "socketMeta",
    EMPTY_SOCKET_RED                = "socketRed",
    EMPTY_SOCKET_YELLOW             = "socketYellow",
    EMPTY_SOCKET_BLUE               = "socketBlue",
    EMPTY_SOCKET_COGWHEEL           = "socketCogwheel",
    EMPTY_SOCKET_HYDRAULIC          = "socketHydraulic",
    EMPTY_SOCKET_DOMINATION         = "socketDomination",
    EMPTY_SOCKET_CYPHER             = "socketCypher",
    EMPTY_SOCKET_TINKER             = "socketTinker",
    EMPTY_SOCKET_PRIMORDIAL         = "socketPrimordial",
    EMPTY_SOCKET_FRAGRANCE          = "socketFragrance",
    EMPTY_SOCKET_FIBER              = "socketFiber",
    EMPTY_SOCKET_PUNCHCARDRED       = "socketPunchcardRed",
    EMPTY_SOCKET_PUNCHCARDYELLOW    = "socketPunchcardYellow",
    EMPTY_SOCKET_PUNCHCARDBLUE      = "socketPunchcardBlue",
    EMPTY_SOCKET_SINGINGSEA         = "socketSingingSea",
    EMPTY_SOCKET_SINGINGTHUNDER     = "socketSingingThunder",
    EMPTY_SOCKET_SINGINGWIND        = "socketSingingWind",
    EMPTY_SOCKET_SINGING_SEA        = "socketSingingSea",
    EMPTY_SOCKET_SINGING_THUNDER    = "socketSingingThunder",
    EMPTY_SOCKET_SINGING_WIND       = "socketSingingWind",
}

local function ResolveStats(props)
    -- Zero out all stat fields first
    for _, field in pairs(STAT_GLOBAL_MAP) do
        rawset(props, field, 0)
    end

    local link = rawget(props, "hyperlink")
    if not link then return end

    local stats = C_Item.GetItemStats(link)
    if not stats then return end

    for globalKey, field in pairs(STAT_GLOBAL_MAP) do
        local val = stats[globalKey]
        if val then
            rawset(props, field, val)
        end
    end
end

-- ---------- ResolveSpecs ----------
-- Lazily populates the item's eligible-class and eligible-spec membership SETS,
-- backing the forclass/forspec "set" props. Viewer-independent.
-- Equippable gear: C_Item.DoesItemContainSpec with explicit class/spec IDs.
-- Fallback: tooltip ITEM_CLASSES_ALLOWED line (UsageRequirement) via
-- TooltipScanner:GetAllowedClassIDs — covers non-equippable class-locked
-- tokens (Baleful, …). eligibleSpecs stays empty for tooltip-only items.
local function ResolveSpecs(props)
    local classes, specs = {}, {}
    rawset(props, "eligibleClasses", classes)
    rawset(props, "eligibleSpecs", specs)

    local item = rawget(props, "hyperlink") or rawget(props, "id")
    if rawget(props, "isEquipment") and item then
        -- Probe ONLY with the 3-arg form (explicit specID). The 2-arg form
        -- (specID defaulting to 0) ignores the passed classID and tests the CURRENT
        -- player, which makes forclass/forspec viewer-relative. Class eligibility is
        -- derived from any matching spec, since loot eligibility is spec-driven.
        for classID = 1, GetNumClasses() do
            for specIndex = 1, C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do
                local specID = GetSpecializationInfoForClassID(classID, specIndex)
                if specID and C_Item.DoesItemContainSpec(item, classID, specID) then
                    specs[specID] = true
                    classes[classID] = true
                end
            end
        end
    end

    if next(classes) then return end

    local tooltipData = Scanner:GetPropsData(props)
    if not tooltipData then
        local itemID = rawget(props, "id")
        if itemID then
            tooltipData = Scanner:GetItemByIDData(itemID)
        end
    end
    local allowed = Scanner:GetAllowedClassIDs(tooltipData)
    if allowed then
        for classID in pairs(allowed) do
            classes[classID] = true
        end
    end
end

-- ---------- Current season helpers (#currentseason) ----------

-- EXPANSION_SEASON_NAME uses a per-expansion ordinal (1, 2, 3…), not the content
-- season UID from C_SeasonInfo.GetCurrentDisplaySeasonID (e.g. 34 for Midnight S1).
local MAX_EXPANSION_SEASON_ORDINAL = 12

---@return number|nil
local function GetCurrentExpansionSeasonNumber()
    local displayNum = C_MythicPlus.GetCurrentSeasonValues()
    if displayNum and displayNum > 0 and displayNum <= MAX_EXPANSION_SEASON_ORDINAL then
        return displayNum
    end
    local uiSeason = C_MythicPlus.GetCurrentUIDisplaySeason()
    if uiSeason and uiSeason > 0 and uiSeason <= MAX_EXPANSION_SEASON_ORDINAL then
        return uiSeason
    end
    local globalSeason = C_MythicPlus.GetCurrentSeason()
    if globalSeason == -1 then
        C_MythicPlus.RequestMapInfo()
        globalSeason = C_MythicPlus.GetCurrentSeason()
    end
    local firstGlobal = EXPANSION_FIRST_GLOBAL_MPLUS_SEASON[LE_EXPANSION_LEVEL_CURRENT]
    if globalSeason and globalSeason > 0 and firstGlobal then
        local ordinal = globalSeason - firstGlobal + 1
        if ordinal >= 1 and ordinal <= MAX_EXPANSION_SEASON_ORDINAL then
            return ordinal
        end
    end
    return nil
end

--- Build the localized season label Blizzard puts on current-expansion item tooltips.
--- Uses LE_EXPANSION_LEVEL_CURRENT for the expansion name and the per-expansion
--- season ordinal from C_MythicPlus (not C_SeasonInfo.GetCurrentDisplaySeasonID).
---@return string|nil
local function GetCurrentSeasonLabel()
    local seasonNum = GetCurrentExpansionSeasonNumber()
    if not seasonNum then return nil end
    local cacheKey = tostring(LE_EXPANSION_LEVEL_CURRENT) .. ":" .. tostring(seasonNum)
    if currentSeasonLabelCache and currentSeasonLabelCache.key == cacheKey then
        return currentSeasonLabelCache.label
    end
    local expName = ns:GetExpansionName(LE_EXPANSION_LEVEL_CURRENT)
    if not expName then
        local displayExpID = C_SeasonInfo.GetCurrentDisplaySeasonExpansion()
        expName = displayExpID and ns:GetExpansionName(displayExpID)
    end
    local label = expName and EXPANSION_SEASON_NAME:format(expName, seasonNum) or nil
    currentSeasonLabelCache = { key = cacheKey, label = label }
    return label
end

---@param row table|nil
---@return boolean
local function IsGrayTooltipLine(row)
    if not row or not row.leftColor then return false end
    local r = math.floor(row.leftColor.r * 100)
    local g = math.floor(row.leftColor.g * 100)
    local b = math.floor(row.leftColor.b * 100)
    return r == g and g == b and r < 60
end

---@param text string|nil
---@return string
local function StripTooltipLineText(text)
    if not text then return "" end
    local stripped = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    stripped = stripped:gsub("|r", "")
    stripped = stripped:gsub("|H.-|h", "")
    stripped = stripped:gsub("|h", "")
    return stripped
end

---@param row table|nil
---@return string
local function GetTooltipLineText(row)
    if not row then return "" end
    local text = StripTooltipLineText(row.leftText)
    if text ~= "" then return text end
    return StripTooltipLineText(row.rightText)
end

---@param bonusIDs table|nil
---@param lookup table|nil
---@return boolean
local function BonusIDsIntersect(bonusIDs, lookup)
    if not bonusIDs or not lookup then return false end
    for _, bonusID in ipairs(bonusIDs) do
        if lookup[bonusID] then
            return true
        end
    end
    return false
end

---@param bonusIDs table|nil
---@return boolean
local function HasCurrentSeasonBonusID(bonusIDs)
    return BonusIDsIntersect(bonusIDs, CURRENT_SEASON_BONUS_IDS)
end

--- Equipment branch: true/false, or nil when tooltip data is still unavailable.
---@param props table
---@param tooltipData table|nil
---@return boolean|nil
local function CheckEquipmentCurrentSeason(props, tooltipData)
    if not rawget(props, "isEquipment") then
        return false
    end
    if HasCurrentSeasonBonusID(rawget(props, "bonusIDs")) then
        return true
    end
    if not rawget(props, "upgradeTrackString") then
        return false
    end
    if not tooltipData then
        return nil
    end
    local seen = false
    for index = 1, math.min(#tooltipData.lines, 4) do
        local row = tooltipData.lines[index]
        if IsGrayTooltipLine(row) then
            return false
        end
        if UPGRADE_PATH_PATTERN and row.leftText and row.leftText:match(UPGRADE_PATH_PATTERN) then
            seen = true
        end
    end
    return seen
end

--- True when a tooltip line mentions the season label. Blizzard renders
--- standalone season headers via GameTooltip_AddDisabledLine; do not skip
--- DisabledLine rows. For #currentseason, gray standalone headers are rejected
--- so leftover stamps on old gear do not match while embedded mentions in use
--- text still match. Named-season keywords (#midnights1 / #midnights2) pass
--- allowGrayHeader so those leftover headers do match.
---@param row table|nil
---@param seasonLabel string
---@param allowGrayHeader boolean|nil
---@return boolean
local function TooltipLineMentionsSeason(row, seasonLabel, allowGrayHeader)
    if not row or not seasonLabel or seasonLabel == "" then return false end
    local text = GetTooltipLineText(row)
    if text == "" then return false end
    if strfind(text, seasonLabel, 1, true) == nil then return false end
    if not allowGrayHeader and text == seasonLabel and IsGrayTooltipLine(row) then
        return false
    end
    return true
end

--- Scan structured tooltip lines, then fall back to concatenated tooltip body
--- (same source as tooltip~ / props.tooltipText).
---@param props table
---@param seasonLabel string
---@param allowGrayHeader boolean|nil
---@return boolean
local function CheckSeasonTooltipMention(props, seasonLabel, allowGrayHeader)
    local tooltipData = GetPropsTooltipData(props)
    if tooltipData and tooltipData.lines then
        for index = 1, #tooltipData.lines do
            if TooltipLineMentionsSeason(tooltipData.lines[index], seasonLabel, allowGrayHeader) then
                return true
            end
        end
    end

    local bagID, slotID = rawget(props, "_bagID"), rawget(props, "_slotID")
    local hyperlink = rawget(props, "hyperlink")
    local tt = ""
    if bagID and slotID then
        tt = GetTooltipText(bagID, slotID)
    end
    if tt == "" and hyperlink then
        tt = GetTooltipTextByHyperlink(hyperlink)
    end
    return tt ~= "" and strfind(tt, seasonLabel, 1, true) ~= nil
end

---@param props table
---@return boolean
local function HasAnyTooltipBody(props)
    if GetPropsTooltipData(props) then return true end
    local bagID, slotID = rawget(props, "_bagID"), rawget(props, "_slotID")
    local hyperlink = rawget(props, "hyperlink")
    if bagID and slotID and GetTooltipText(bagID, slotID) ~= "" then
        return true
    end
    if hyperlink and GetTooltipTextByHyperlink(hyperlink) ~= "" then
        return true
    end
    return false
end

--- Lazily resolves props.isCurrentSeason on first access.
---@param props table
local function ResolveIsCurrentSeason(props)
    local expansionID = rawget(props, "expansionID")
    local itemID = rawget(props, "id")

    if expansionID >= 0 and expansionID ~= LE_EXPANSION_LEVEL_CURRENT then
        rawset(props, "isCurrentSeason", false)
        rawset(props, "_currentSeasonResolved", true)
        return
    end

    if expansionID == -1 and itemID and not C_Item.IsItemDataCachedByID(itemID) then
        C_Item.RequestLoadItemDataByID(itemID)
        rawset(props, "_tooltipDataMissing", true)
        return
    end

    local tooltipData = GetPropsTooltipData(props)
    local result = false
    local equipResult = CheckEquipmentCurrentSeason(props, tooltipData)

    if equipResult == true then
        result = true
    elseif equipResult == nil then
        rawset(props, "_tooltipDataMissing", true)
        return
    else
        local currentLabel = GetCurrentSeasonLabel()
        if not currentLabel then
            rawset(props, "_tooltipDataMissing", true)
            return
        end
        result = CheckSeasonTooltipMention(props, currentLabel)
        if not result and not HasAnyTooltipBody(props) then
            rawset(props, "_tooltipDataMissing", true)
            return
        end
    end

    rawset(props, "isCurrentSeason", result)
    rawset(props, "_currentSeasonResolved", true)
end

-- ---------- Named Midnight seasons (#midnights1 / #midnights2) ----------
-- Frozen PvE track list IDs plus tooltip label. Gray season headers match.
-- Not an alias of #currentseason.

local namedSeasonLabelCache = {}

---@param expansionID number
---@param ordinal number
---@return string|nil
local function GetNamedSeasonLabel(expansionID, ordinal)
    local cacheKey = tostring(expansionID) .. ":" .. tostring(ordinal)
    local cached = namedSeasonLabelCache[cacheKey]
    if cached ~= nil then
        return cached or nil
    end
    local expName = ns:GetExpansionName(expansionID)
    local label = expName and EXPANSION_SEASON_NAME:format(expName, ordinal) or false
    namedSeasonLabelCache[cacheKey] = label
    return label or nil
end

--- Lazily resolves props.isMidnightS1 / isMidnightS2 together on first access.
---@param props table
local function ResolveNamedSeasons(props)
    local expansionID = rawget(props, "expansionID")
    local itemID = rawget(props, "id")

    if expansionID >= 0 and expansionID ~= MIDNIGHT_EXPANSION_ID then
        rawset(props, "isMidnightS1", false)
        rawset(props, "isMidnightS2", false)
        rawset(props, "_namedSeasonsResolved", true)
        return
    end

    if expansionID == -1 and itemID and not C_Item.IsItemDataCachedByID(itemID) then
        C_Item.RequestLoadItemDataByID(itemID)
        rawset(props, "_tooltipDataMissing", true)
        return
    end

    local bonusIDs = rawget(props, "bonusIDs")
    local s1 = BonusIDsIntersect(bonusIDs, MIDNIGHT_SEASON_TRACK_LISTS[1])
    local s2 = BonusIDsIntersect(bonusIDs, MIDNIGHT_SEASON_TRACK_LISTS[2])

    if not s1 or not s2 then
        if not HasAnyTooltipBody(props) then
            rawset(props, "_tooltipDataMissing", true)
            return
        end
        if not s1 then
            local label = GetNamedSeasonLabel(MIDNIGHT_EXPANSION_ID, 1)
            s1 = label and CheckSeasonTooltipMention(props, label, true) or false
        end
        if not s2 then
            local label = GetNamedSeasonLabel(MIDNIGHT_EXPANSION_ID, 2)
            s2 = label and CheckSeasonTooltipMention(props, label, true) or false
        end
    end

    rawset(props, "isMidnightS1", s1)
    rawset(props, "isMidnightS2", s2)
    rawset(props, "_namedSeasonsResolved", true)
end

-- ============================================================================
-- SECTION 8.5: LATE-BOUND KEYWORDS
-- ============================================================================
-- Registered here instead of Section 7 because they capture helpers defined
-- between the two sections (GetPropsTooltipData) as upvalues.

-- #protected: item marked Protected via OneWoW ItemStatus (sibling of the
-- isJunk hook in PopulateBaseProps).
RegisterKeyword("protected", function(p)
    return ns.ItemStatus:IsItemProtected(p.id)
end)

-- #markedjunk: item explicitly marked Junk via OneWoW ItemStatus. Unlike
-- #junk, this does NOT include poor-quality (grey) items.
RegisterKeyword("markedjunk", function(p)
    return ns.ItemStatus:IsItemJunk(p.id)
end)

-- #teachable: the item's tooltip carries a "Use: Teaches you ..." learn line.
-- True for unlearned recipes, mount/pet/toy teaching items, etc.
RegisterKeyword("teachable", function(p)
    return Scanner:GetLearnSpellID(Scanner:GetPropsData(p)) ~= nil
end)

-- ============================================================================
-- SECTION 9: LAYER 1 — BUILDPROPS
-- ============================================================================

-- ---------- Combine items (Darkmoon decks, spear parts, ...) ----------

-- A handful of recipe schematics under-report quantityRequired; corrections
-- keyed by [recipeID] = { [reagentItemID] = actualQuantity }.
local COMBINE_QUANTITY_OVERRIDES = {
    [404592]  = { [204340] = 30 }, -- Torn Recipe Scrap
    [428667]  = { [211297] = 2 },  -- Fractured Spark (TWW S1)
    [467635]  = { [230905] = 2 },  -- Fractured Spark (TWW S2)
    [468717]  = { [231757] = 2 },  -- Fractured Spark (TWW S3)
    [1283168] = { [268650] = 5 },  -- Ascendant Voidcore
}

--- Required reagents when the item's Use: effect is a combine/craft spell,
--- nil for ordinary items. Detection is structural and locale-independent:
--- GetItemSpell → C_TradeSkillUI.GetRecipeSchematic (the reagent lists shown
--- on live tooltips come from other addons and never appear in C_TooltipInfo
--- data). Enchant scrolls (ItemEnhancement) also carry recipe spells and are
--- excluded. Trivial schematics — a single required reagent at quantity 1
--- (Baleful tokens and similar "Use: create …" items) — are treated as
--- ordinary Use: items, not combines. Schematics are static game data,
--- cached per itemID.
---@param itemID number
---@return table|nil reagents array of { itemID?, currencyID?, quantityRequired }
local function GetCombineReagents(itemID)
    local cached = combineSchematicCache[itemID]
    if cached ~= nil then
        return cached or nil
    end

    local spellID
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    if classID ~= Enum.ItemClass.ItemEnhancement then
        _, spellID = C_Item.GetItemSpell(itemID)
    end

    local reagents
    local schematic = spellID and C_TradeSkillUI.GetRecipeSchematic(spellID, false)
    if schematic and schematic.reagentSlotSchematics then
        local overrides = COMBINE_QUANTITY_OVERRIDES[schematic.recipeID]
        for _, slot in ipairs(schematic.reagentSlotSchematics) do
            local reagent = slot.required and slot.reagents and slot.reagents[1]
            if reagent and (reagent.itemID or reagent.currencyID) then
                local quantity = slot.quantityRequired or 1
                if reagent.itemID and overrides and overrides[reagent.itemID] then
                    quantity = overrides[reagent.itemID]
                end
                reagents = reagents or {}
                reagents[#reagents + 1] = {
                    itemID = reagent.itemID,
                    currencyID = reagent.currencyID,
                    quantityRequired = quantity,
                }
            end
        end
    end

    -- Single reagent at qty 1 is just "click Use", not a combine (gathering
    -- multiple reagents / stacks). Fall through to normal #usable / #onuse.
    if reagents and #reagents == 1 and reagents[1].quantityRequired == 1 then
        reagents = nil
    end

    combineSchematicCache[itemID] = reagents or false
    return reagents
end

--- Every reagent is owned in sufficient quantity (bags + bank + reagent bank
--- + warband bank), i.e. the combine can actually be performed. Deliberately
--- not memoized: the verdict depends on live inventory counts (cheap native
--- lookups), and recomputes naturally when propsCache is wiped on bag updates.
---@param reagents table from GetCombineReagents
---@return boolean
local function HasAllCombineReagents(reagents)
    for _, reagent in ipairs(reagents) do
        local count
        if reagent.itemID then
            count = C_Item.GetItemCount(reagent.itemID, true, false, true, true)
        else
            local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
            count = currencyInfo and currencyInfo.quantity or 0
        end
        if count < reagent.quantityRequired then
            return false
        end
    end
    return true
end

-- #combinable: item's Use: effect is a combine/craft spell with required
-- reagents (Darkmoon decks, fractured sparks, torn recipe scraps, …).
-- Structural via GetCombineReagents — not tooltip text. Excludes trivial
-- single-reagent qty-1 schematics (ordinary Use: tokens).
-- #combineready: shorthand for (#combinable & #usable) — schematic present
-- and character can perform the combine (all reagents owned).
RegisterKeyword("combinable", function(p)
    return p.id and GetCombineReagents(p.id) ~= nil
end)
RegisterKeyword("combineready", function(p)
    return p.id and GetCombineReagents(p.id) ~= nil and p.isUsable
end)

-- ---------- Teachable collectibles ----------

--- A teachable item (carries a "Use: Teaches you …" learn line) is only usable
--- while it can still teach something new: an uncollected mount/toy/recipe, or
--- a pet whose collected count is below its cap (e.g. 1/3). Backed by
--- `OneWoW.Collectibles.GetItemCollectionStatus`. Returns nil for non-collectible
--- teach items (spell tomes, etc.) so the caller keeps its conservative
--- "teachable → not usable" default. Depends on live collection counts, so the
--- caller must not memoize verdicts derived from it.
---@return boolean|nil learnable nil when the item is not a tracked collectible
local function TeachableStillLearnable(itemID, hyperlink, bagID, slotID)
    local Collectibles = OneWoW.Collectibles
    if not Collectibles then return nil end
    local status = Collectibles.GetItemCollectionStatus(itemID, hyperlink, {
        bagID = bagID,
        slotID = slotID,
        hyperlink = hyperlink,
    })
    if not status then return nil end
    if status.limit then
        return (status.numCollected or 0) < status.limit
    end
    return not status.collected
end

-- ---------- ResolveCharacterUsable ----------

---@param idSet table<number, boolean>|nil when nil, wipe all
local function EvictCharacterUsableCache(idSet)
    if not idSet then
        wipe(characterUsableCache)
        return
    end
    for key in pairs(characterUsableCache) do
        local cachedItemID = tonumber(key:match("^(%d+)|"))
        if cachedItemID and idSet[cachedItemID] then
            characterUsableCache[key] = nil
        end
    end
end

--- Character can use this item (level/class/spec/profession), independent of
--- Blizzard's inventory-gated IsUsableItem (bank-only stacks often false).
--- Resolved lazily via propsMT on first `isUsable` access. Fallback verdicts
--- are cached per item identity in `characterUsableCache`, which survives bag
--- updates and is cleared on character-context changes (level/spec/skills),
--- surgical item-ID eviction, and full InvalidateCache. Combine-item reagent
--- readiness and teachable-collectible learnability are the exception: they
--- depend on live inventory/collection counts and are recomputed on every
--- resolution instead of memoized.
---@param props table props table (id, hyperlink, _bagID, _slotID, isEquipment)
---@return boolean
local function ResolveCharacterUsable(props)
    local itemID = rawget(props, "id")
    local hyperlink = rawget(props, "hyperlink")

    local itemRef = hyperlink or itemID
    if itemRef and C_Item.IsUsableItem(itemRef) == true then
        return true
    end

    if not itemID then return false end

    -- Accessible bags: IsUsableItem false means genuinely unusable (combine
    -- gates, profession reqs, etc.). Bank/warband-only stacks need the
    -- tooltip fallback below.
    local bagID, slotID = rawget(props, "_bagID"), rawget(props, "_slotID")
    if not Scanner:NeedsUsabilityFallback(bagID, itemID) then
        return false
    end

    local idKey = GetItemIdentityKey(itemID, hyperlink)
    local cached = characterUsableCache[idKey]
    if cached ~= nil then
        return cached
    end

    local Profile = OneWoW_Bags_API and OneWoW_Bags_API.GetProfile()
    if Profile then Profile:Start("PE:ResolveCharacterUsable.fallback") end

    local usable = false
    local cacheable = true
    if not IdentityIsRecipeItem(itemID) then
        local combineReagents = GetCombineReagents(itemID)
        if combineReagents then
            -- Combine item: usable when every reagent is owned. Depends on
            -- live inventory counts, so never memoized in
            -- characterUsableCache (which survives bag updates).
            usable = HasAllCombineReagents(combineReagents)
            cacheable = false
        else
            -- Single contextual fetch: bag slot when known (carries the
            -- player-evaluated red requirement lines), else hyperlink
            -- template, else itemID template.
            local tooltipData
            if bagID and slotID then
                tooltipData = Scanner:GetBagItemData(bagID, slotID)
            elseif hyperlink then
                tooltipData = Scanner:GetHyperlinkData(hyperlink)
            else
                tooltipData = Scanner:GetItemByIDData(itemID)
            end

            local facts = Scanner:GetUsabilityFacts(tooltipData)
            if facts and not facts.unmetRequirements then
                if facts.learnSpellID then
                    -- Teachable: usable only while still learnable (uncollected,
                    -- or a pet below its cap). Verdict tracks live collection
                    -- counts, so it must not be memoized. Non-collectible teach
                    -- items (nil) keep the conservative "not usable" default.
                    local learnable = TeachableStillLearnable(itemID, hyperlink, bagID, slotID)
                    if learnable ~= nil then
                        usable = learnable
                        cacheable = false
                    end
                elseif facts.directUse
                    or (props.isEquipment and PE:CanClassEquip(itemID, hyperlink)) then
                    usable = true
                end
            end
        end
    end

    if Profile then Profile:Stop("PE:ResolveCharacterUsable.fallback") end

    if cacheable then
        characterUsableCache[idKey] = usable
    end
    return usable
end

-- Fields that are resolved lazily via __index (tooltip scan on first access)
local TOOLTIP_FIELDS_SET = {
    hasCharges          = true,
    hasUseAbility       = true,
    hasEquipAbility     = true,
    isAlreadyKnown      = true,
    isTradeableLoot     = true,
    isUnique            = true,
    isUniqueEquipped    = true,
    tooltipText         = true,
}

local CURRENT_SEASON_FIELDS_SET = {
    isCurrentSeason = true,
}

local NAMED_SEASON_FIELDS_SET = {
    isMidnightS1 = true,
    isMidnightS2 = true,
}

-- Bind fields
local BIND_FIELDS_SET = {
    isSoulbound = true,
    isBOE       = true,
    isBOA       = true,
    isBOU       = true,
    isWUE       = true,
    isWarbound  = true,
    currentbind = true,
}

-- Stat fields (lazy via C_Item.GetItemStats)
local STAT_FIELDS_SET = {
    statIntellect           = true,
    statAgility             = true,
    statStrength            = true,
    statStamina             = true,
    statCrit                = true,
    statHaste               = true,
    statMastery             = true,
    statVersatility         = true,
    statSpeed               = true,
    statLeech               = true,
    statAvoidance           = true,
    statArmor               = true,
    socketPrismatic         = true,
    socketMeta              = true,
    socketRed               = true,
    socketYellow            = true,
    socketBlue              = true,
    socketCogwheel          = true,
    socketHydraulic         = true,
    socketDomination        = true,
    socketCypher            = true,
    socketTinker            = true,
    socketPrimordial        = true,
    socketFragrance         = true,
    socketFiber             = true,
    socketPunchcardRed      = true,
    socketPunchcardYellow   = true,
    socketPunchcardBlue     = true,
    socketSingingSea        = true,
    socketSingingThunder    = true,
    socketSingingWind       = true,
}

-- Spec membership sets (lazy via C_Item.DoesItemContainSpec enumeration)
local SPEC_FIELDS_SET = {
    eligibleClasses = true,
    eligibleSpecs   = true,
}

-- Metatable applied to every props table for lazy field resolution.
-- Stays permanently; uses _tooltipResolved and _bindResolved flags to
-- avoid redundant scans (rather than stripping the metatable).
--
-- Tooltip resolution is retry-on-failure: if ResolveTooltipFields cannot
-- locate any tooltip data (cold streaming, hyperlink not yet cached client-
-- side), we leave _tooltipResolved unset and tag the props with
-- _tooltipDataMissing. Subsequent field reads will re-run the resolver, and
-- callers can opt out of caching verdicts that depended on missing data.
--
-- _tooltipDataMissing is STICKY-ON-FAILURE: we only set it, never clear it
-- here. This protects multi-predicate evaluations where an early predicate
-- gets a failed resolve and a later predicate happens to get a successful
-- one within the same evaluation -- the early predicate's verdict was still
-- computed against empty fields. Callers (ResolveBaseCategory) explicitly
-- clear the flag at the start of an evaluation window.
local propsMT = {
    __index = function(self, key)
        -- Character-usability: IsUsableItem fast path, tooltip fallback for
        -- bank/warband-only stacks (identity-cached in characterUsableCache).
        if key == "isUsable" then
            if not rawget(self, "_usableResolved") then
                rawset(self, "isUsable", ResolveCharacterUsable(self))
                rawset(self, "_usableResolved", true)
            end
            return rawget(self, key)
        end
        -- Tooltip-derived fields: scan once, populate all on first access
        if TOOLTIP_FIELDS_SET[key] then
            if not rawget(self, "_tooltipResolved") then
                local ok = ResolveTooltipFields(self)
                if ok then
                    rawset(self, "_tooltipResolved", true)
                else
                    rawset(self, "_tooltipDataMissing", true)
                end
            end
            return rawget(self, key)
        end
        -- Bind fields: tooltip fallback only when API didn't populate them
        if BIND_FIELDS_SET[key] then
            if not rawget(self, "_bindResolved") then
                ResolveBind(self)
                rawset(self, "_bindResolved", true)
            end
            return rawget(self, key)
        end
        -- Stat fields: C_Item.GetItemStats on first access
        if STAT_FIELDS_SET[key] then
            if not rawget(self, "_statsResolved") then
                ResolveStats(self)
                rawset(self, "_statsResolved", true)
            end
            return rawget(self, key)
        end
        -- Spec membership sets: DoesItemContainSpec enumeration on first access
        if SPEC_FIELDS_SET[key] then
            if not rawget(self, "_specsResolved") then
                ResolveSpecs(self)
                rawset(self, "_specsResolved", true)
            end
            return rawget(self, key)
        end
        if CURRENT_SEASON_FIELDS_SET[key] then
            if not rawget(self, "_currentSeasonResolved") then
                ResolveIsCurrentSeason(self)
            end
            return rawget(self, key)
        end
        if NAMED_SEASON_FIELDS_SET[key] then
            if not rawget(self, "_namedSeasonsResolved") then
                ResolveNamedSeasons(self)
            end
            return rawget(self, key)
        end
        return nil
    end
}

-- ---------- PopulateBaseProps ----------
-- Populates the slot-INDEPENDENT subset of an item's props (the "identity tier"
-- of the two-tier cache). All API calls in here key only on itemID and/or
-- hyperlink. Slot-state defaults (durability, isNew, etc.) are pre-initialized
-- so a shallow copy of the base table is a valid starting point for
-- BuildProps' per-slot overlay step.
local function PopulateBaseProps(props, itemID, hyperlink)
    props.id = itemID
    props.hyperlink = hyperlink

    -- C_Item.GetItemInfo returns 17 values; we capture all except `description`
    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel,
          itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture,
          sellPrice, classID, subclassID, bindType, expansionID,
          setID, apiCraftingReagent

    if hyperlink then
        itemName, itemLink, itemQuality, itemLevel, itemMinLevel,
            itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture,
            sellPrice, classID, subclassID, bindType, expansionID,
            setID, apiCraftingReagent = C_Item.GetItemInfo(hyperlink)
    end

    -- Synchronous fallback for uncached items. GetItemInfoInstant always returns
    -- immediately for a valid itemID, even when full item data hasn't been
    -- downloaded yet. Lower fidelity than GetItemInfo (no quality/ilvl/etc.) but
    -- carries class/subclass/equipLoc/icon/localized type strings.
    if not classID then
        _, itemType, itemSubType, itemEquipLoc, itemTexture, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    end

    local petData = GetBattlePetData(itemID, hyperlink)

    props.playerLevel = UnitLevel("player")
    props.nameRaw     = itemName or (C_Item.GetItemNameByID(itemID) or "")
    props.name        = strlower(props.nameRaw)
    props.quality     = itemQuality or -1 -- don't use 0 since that == "poor" and causes bad matches
    props.ilvl        = ItemLevel.Get(hyperlink) or itemLevel or 0
    props.reqLevel    = itemMinLevel or 0
    props.itemType    = itemType
    props.itemSubType = itemSubType
    props.equipLoc    = itemEquipLoc or ""
    props.icon        = itemTexture
    props.vendorPrice = sellPrice or 0
    props.classID     = classID
    props.subClassID  = subclassID
    props.expansionID = expansionID or -1
    props.bindType    = bindType    -- template bindType: what the item was designed to do; may not reflect current bindType
    props.maxStack    = itemStackCount or 1
    props.setID       = setID
    props.isTierSet   = setID ~= nil
    props.isCraftingReagent = apiCraftingReagent == true
    props.petSpeciesID = petData and petData.speciesID or 0
    props.petLevel = petData and petData.petLevel or 0
    props.petQuality = petData and petData.petQuality or 0
    props.petMaxHealth = petData and petData.petMaxHealth or 0
    props.petPower = petData and petData.petPower or 0
    props.petSpeed = petData and petData.petSpeed or 0
    props.petType = petData and petData.petType or 0
    props.isWildPet = petData and petData.isWild or false
    props.canPetBattle = petData and petData.canBattle or false
    props.isPetTradeable = petData and petData.isTradeable or false
    props.isPetUnique = petData and petData.isUnique or false
    props.petCollected = petData and petData.numCollected or 0
    props.petLimit = petData and petData.limit or 0
    props.isKnowledge = false
    props.isEnchanted = false
    props.isCrafted = false
    -- isCurrentSeason / isMidnightS1 / isMidnightS2: lazy via propsMT; do not preset here.
    props.bonusIDs = nil

    -- Slot-state defaults (BuildProps overlay may overwrite per slot).
    props.isRefundable = false
    props.isScrappable = false
    props.isBattlePayItem = false
    props.isInEquipmentSet = false
    props.equipmentSetList = {}
    props.needsRepair = false
    props.isBroken = false
    props.durability = nil
    props.maxDurability = nil
    props.durabilityPct = nil
    props.isCatalyst = false
    props.isCatalystUpgrade = false

    props.craftedQuality = hyperlink and C_TradeSkillUI.GetItemCraftedQualityByItemInfo(hyperlink) or 0
    props.reagentQuality = hyperlink and C_TradeSkillUI.GetItemReagentQualityByItemInfo(hyperlink) or 0

    props.isCurrency = hyperlink and C_CurrencyInfo.GetCurrencyInfoFromLink(hyperlink) or false
    props.isKeystone = C_Item.IsItemKeystoneByID(itemID) == true
    props.isEquipment = C_Item.IsEquippableItem(itemID) == true
    props.isProfessionEquipment = props.classID == Enum.ItemClass.Profession and props.isEquipment

    -- isUsable: lazy via propsMT (ResolveCharacterUsable); not identity-tier.

    -- ---- Socket detection (API-based, no tooltip needed) ----
    local socketCount = hyperlink and C_Item.GetItemNumSockets(hyperlink) or 0
    props.hasSocket = socketCount > 0
    props.sockets   = socketCount

    -- ---- Equipped status ----
    props.isEquipped = C_Item.IsEquippedItem(itemID) == true

    -- ---- Battle pet cage override ----
    if itemID == BATTLE_PET_CAGE_ID then
        props.classID = Enum.ItemClass.Battlepet
    end

    -- Vendor-price half of isUnsellable. BuildProps OR-s in containerInfo.hasNoValue.
    props.isUnsellable = (props.vendorPrice == 0)

    -- ---- Collectable items ----
    props.isToy = C_ToyBox.GetToyInfo(itemID) ~= nil

    props.isPet = (itemID == BATTLE_PET_CAGE_ID)
               or (props.classID == Enum.ItemClass.Battlepet)
               or (props.classID == Enum.ItemClass.Miscellaneous and props.subClassID == Enum.ItemMiscellaneousSubclass.CompanionPet)

    props.isMount = (props.classID == Enum.ItemClass.Miscellaneous and props.subClassID == Enum.ItemMiscellaneousSubclass.Mount)
    props.isCosmetic = (props.classID == Enum.ItemClass.Armor and props.subClassID == Enum.ItemArmorSubclass.Cosmetic)
    props.isCollected = ItemCollectionOwned(itemID, hyperlink)

    -- ---- Quest item (identity portion; BuildProps OR-s in C_Container quest-info fallback) ----
    props.isQuestItem = (classID == Enum.ItemClass.Questitem)

    -- ---- Junk (quality + OneWoW hook) ----
    props.isJunk = (props.quality == IQ.Poor)
    if not props.isJunk and ns.ItemStatus then
        props.isJunk = ns.ItemStatus:IsItemJunk(itemID) or false
    end

    -- ---- Special items ----
    props.isHearthstone = HS_IDS[itemID] or false
    if not props.isHearthstone and props.isToy then
        local hsName = C_Item.GetItemNameByID(itemID)
        if hsName and strfind(strlower(hsName), "hearthstone") then
            props.isHearthstone = true
        end
    end
    props.isGearToken = GEAR_TOKEN_IDS[itemID] or false

    -- ---- Upgrade track info ----
    props.upgradeLevel    = 0
    props.upgradeMax      = 0
    props.maxLevel        = props.ilvl
    props.isUpgradeable   = false
    props.isFullyUpgraded = false
    props.isUpgradeTrack  = false
    props.upgradeTrackString = nil
    props.upgradeTrackStringID = nil

    local upgradeInfo = C_Item.GetItemUpgradeInfo(hyperlink or itemID)
    if upgradeInfo then
        props.upgradeLevel         = upgradeInfo.currentLevel or 0
        props.upgradeMax           = upgradeInfo.maxLevel or 0
        props.maxLevel             = upgradeInfo.maxItemLevel or props.ilvl
        props.isUpgradeable        = (props.upgradeLevel < props.upgradeMax)
        props.isFullyUpgraded      = (props.upgradeLevel >= props.upgradeMax and props.upgradeMax > 0)
        props.upgradeTrackString   = upgradeInfo.trackString
        props.upgradeTrackStringID = upgradeInfo.trackStringID
        props.isUpgradeTrack       = upgradeInfo.trackStringID ~= nil
    end

    -- ---- Transmog / appearance ----
    -- PlayerHasTransmog(itemID) is the fast item-keyed check; source-keyed
    -- collection routes through OneWoW.Collectibles.ResolveTransmogSourceID.
    props.hasAppearance         = false
    props.isEnsemble            = false
    props.isAppearanceCollected = C_TransmogCollection.PlayerHasTransmog(itemID)

    local collectibleKey = OneWoW.Collectibles.ResolveKeyFromItem(itemID, hyperlink)
    if collectibleKey then
        if collectibleKey:find("^appearance:", 1) == 1 then
            props.hasAppearance = true
            if not props.isAppearanceCollected then
                local st = OneWoW.Collectibles.GetCollectionState(collectibleKey)
                props.isAppearanceCollected = (st and st.collected) == true
            end
        elseif collectibleKey:find("^set:", 1) == 1 then
            props.isEnsemble = true
        end
    end

    -- ---- Knowledge items ----
    if hyperlink then
        local _, spellName = C_Item.GetItemSpell(hyperlink)
        if spellName then
            local spellinfo = C_Spell.GetSpellInfo(spellName)
            local spellIconID = spellinfo.iconID
            props.isKnowledge = KNOWLEDGE_ICONS[spellIconID] == true
        end
    end

    -- ---- Item link parsed properties ----
    local linkForParse = hyperlink or itemLink
    local itemLinkProperties = ParseItemLink(linkForParse)
    if itemLinkProperties then
        props.isEnchanted = itemLinkProperties.enchantID ~= nil
        props.isCrafted = itemLinkProperties.crafterGUID ~= nil
        props.itemContextCategory = ITEM_CONTEXT_CATEGORY[itemLinkProperties.itemContext]
        props.bonusIDs = itemLinkProperties.bonusIDs
    end

    -- ---- Catalyst properties ----
    if hyperlink and TransmogUpgradeMaster_API and TransmogUpgradeMaster_API.IsAppearanceMissing then
        local ok, isCatalyst, isCatalystUpgrade = pcall(TransmogUpgradeMaster_API.IsAppearanceMissing, hyperlink)
        if ok then
            props.isCatalyst = isCatalyst == true
            props.isCatalystUpgrade = isCatalystUpgrade == true
        end
    end

    if props.classID == Enum.ItemClass.Housing and props.subClassID == Enum.ItemHousingSubclass.Decor then
        local info = C_HousingCatalog.GetCatalogEntryInfoByItem(hyperlink or itemID)

        if info then
            local numStored = info.totalNumStored or 0
            local numPlaced = info.totalNumPlaced or 0
            local remainingRedeemable = info.remainingRedeemable or 0
            local total = numStored + numPlaced + remainingRedeemable

            props.decorNumStorage = numStored
            props.decorNumPlaced = numPlaced
            props.decorNumRedeemable = remainingRedeemable
            props.decorNumTotal = total
        end
    end

    -- BIND DETECTION NOTE: API-based bind detection removed as it's not detailed enough. Warbound == Soulbound according to the API.
    -- UNIQUE DETECTION NOTE: C_Item.GetItemUniquenessByID only matches unique-equipped items; its purpose is to identify restrictions on equipping items, not on owning them.

    -- Override item properties for when they don't classify correctly.
    local itemOverride = ITEM_ID_OVERRIDES[itemID]
    if itemOverride then
        for propName, propValue in pairs(itemOverride) do
            props[propName] = propValue
        end
    end
end

-- ---------- GetOrCreateIdentityProps ----------
-- Identity-tier cache lookup. Returns the shared base props table for an item
-- identity, populating it on first miss. Bumps profile counters (identityHit
-- vs identityMiss) so /owbprof can show cache effectiveness.
local function GetOrCreateIdentityProps(itemID, hyperlink)
    local key = GetItemIdentityKey(itemID, hyperlink)
    local cached = identityPropsCache[key]
    local Profile = OneWoW_Bags_API and OneWoW_Bags_API.GetProfile()
    if cached then
        if Profile then
            Profile:Start("PE:BuildProps.identityHit")
            Profile:Stop("PE:BuildProps.identityHit")
        end
        return cached
    end

    if Profile then
        Profile:Start("PE:BuildProps.identityMiss")
        Profile:Start("PE:BuildProps.PopulateBaseProps")
    end

    local base = {}
    PopulateBaseProps(base, itemID, hyperlink)
    identityPropsCache[key] = base

    if Profile then
        Profile:Stop("PE:BuildProps.PopulateBaseProps")
        Profile:Stop("PE:BuildProps.identityMiss")
    end
    return base
end

-- ---------- BuildProps ----------
-- Core Layer 1 function. Enriches an item identity into a flat property table.
--
-- Cache strategy:
--   - When bagID/slotID are present, cached by "bagID:slotID" so slot-state
--     fields (durability, isNew, isLocked, hasLoot, equipment-set membership, current
--     bind state) can vary per slot.
--   - Otherwise cached by item identity (hyperlink for normal items, itemID
--     plus pet stats for caged battle pets) so independent calls for the same
--     item link share work.
--
-- Caches live for the session only (file-scope locals, never persisted) and
-- are invalidated by PE:InvalidateCache / PE:InvalidatePropsCache or on
-- BAG_UPDATE_DELAYED in the integration layer.
--
-- Input contract (any combination is valid; the function backfills missing
-- pieces from whichever sources can produce them):
--   - itemID:    item ID. Required for the function to do useful work, but may
--                be nil if bagID/slotID or a hyperlink can resolve it.
--   - bagID/slotID: container coordinates. Both must be present together.
--                   Source of truth for slot-state fields.
--   - itemInfo:  string | table | nil
--       * string: treated as a hyperlink.
--       * table:  preserves the historical container-info shape; only `.hyperlink`
--                 is consumed.
--       * nil:    no override; bag/slot path supplies the hyperlink when present.
--
-- Bag/slot-derived hyperlink takes precedence over itemInfo so callers can
-- safely pass slot coordinates without re-deriving the link.
--
-- Returns an empty {} when no usable identity can be resolved (consistent
-- early-exit for callers that pass partial information for empty slots, etc.).

---@param itemID number|nil
---@param bagID number|nil
---@param slotID number|nil
---@param itemInfo string|table|nil
---@return table
function PE:BuildProps(itemID, bagID, slotID, itemInfo)
    if (not itemID or itemID == 0) and not bagID and not slotID and not itemInfo then return {} end

    ---@type string|nil
    local hyperlink
    ---@type ContainerItemInfo
    local containerInfo
    ---@type table|ItemLocation
    local itemLocation

    if bagID and slotID then
        containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)

        if containerInfo then
            if not hyperlink then
                hyperlink = containerInfo.hyperlink
            end
            if not itemID then
                itemID = containerInfo.itemID
            end
        end

        itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)

        if itemLocation:IsValid() and C_Item.DoesItemExist(itemLocation) then
            if not hyperlink then
                hyperlink = C_Item.GetItemLink(itemLocation)
            end
            if not itemID then
                ---@cast itemLocation ItemLocation
                itemID = C_Item.GetItemID(itemLocation)
            end
        end
    end

    -- Bag/slot-derived hyperlink wins; itemInfo only fills in when bag/slot didn't.
    -- itemInfo accepts a hyperlink string, a container-info-shaped table with .hyperlink,
    -- or nil. Any combination of (itemID, bagID/slotID, itemInfo) is supported.
    if not hyperlink then
        if type(itemInfo) == "table" then
            hyperlink = itemInfo.hyperlink
        elseif type(itemInfo) == "string" then
            hyperlink = itemInfo
        end
    end

    if not itemID and hyperlink then
        itemID = C_Item.GetItemIDForItemInfo(hyperlink)
    end

    -- Without an itemID we cannot produce meaningful props; consistent with the
    -- "everything missing" early-return above.
    if not itemID then return {} end

    local cacheKey = GetItemCacheKey(itemID, bagID, slotID, hyperlink)
    if propsCache[cacheKey] then return propsCache[cacheKey] end

    -- Tier 1: identity-keyed base (slot-independent props). Shared across every
    -- slot holding the same item identity. Heavy API calls run only on miss.
    local base = GetOrCreateIdentityProps(itemID, hyperlink)

    -- Tier 2: per-slot shallow copy + slot-overlay fields. The metatable
    -- (__index) lazy-resolves tooltip/bind/stat fields on first access and
    -- writes them onto the per-slot table, not the shared base.
    local Profile = OneWoW_Bags_API and OneWoW_Bags_API.GetProfile()
    if Profile then Profile:Start("PE:BuildProps.PopulateSlotProps") end

    local props = {}
    for k, v in pairs(base) do props[k] = v end
    props._bagID    = bagID
    props._slotID   = slotID
    props.hyperlink = hyperlink

    -- Fresh per-slot equipmentSetList so we don't mutate the base's empty table.
    props.equipmentSetList = {}

    if bagID and slotID then
        props.isNew = C_NewItems.IsNewItem(bagID, slotID) == true
        props.isBattlePayItem = C_Container.IsBattlePayItem(bagID, slotID) == true

        -- ---- Item durability ----
        local durability, maxDurability = C_Container.GetContainerItemDurability(bagID, slotID)
        if durability then
            props.durability = durability
            props.maxDurability = maxDurability
            props.durabilityPct = (durability/maxDurability)*100    -- Let the caller decide if they want to floor, ceil, or round
            props.needsRepair = durability ~= maxDurability
            props.isBroken = durability == 0
        end

        -- ---- Equipment set (API-based, no cache needed) ----
        local inSet, setList = C_Container.GetContainerItemEquipmentSetInfo(bagID, slotID)
        props.isInEquipmentSet = inSet == true

        if props.isInEquipmentSet and type(setList) == "string" and setList ~= "" then
            local parts = { strsplit(",", setList) }
            for i = 1, #parts do
                local n = strtrim(parts[i])
                if n ~= "" then
                    tinsert(props.equipmentSetList, n)
                end
            end
        end

        if itemLocation and itemLocation:IsValid() then
            props.isRefundable = C_Item.CanBeRefunded(itemLocation)
            props.isScrappable = C_Item.CanScrapItem(itemLocation)
            local resolvedIlvl = ItemLevel.Get(hyperlink, itemLocation)
            if resolvedIlvl then
                props.ilvl = resolvedIlvl
            end
        end
    end

    props.count    = containerInfo and containerInfo.stackCount or 1
    props.isLocked = containerInfo and containerInfo.isLocked or false
    props.hasLoot = containerInfo and containerInfo.hasLoot or false

    -- ---- Computed value ----
    props.totalValue = props.vendorPrice * props.count

    -- ---- Unsellable: identity sets vendorPrice==0; slot OR-s in hasNoValue ----
    props.isUnsellable = (props.vendorPrice == 0) or (containerInfo and containerInfo.hasNoValue == true)

    -- ---- Quest item slot fallback (base set classID-derived value) ----
    if not props.isQuestItem and bagID and slotID then
        local qInfo = C_Container.GetContainerItemQuestInfo(bagID, slotID)
        if qInfo and (qInfo.isQuestItem or qInfo.isActive) then
            props.isQuestItem = true
        end
    end

    -- ---- Transmog itemLocation fallback (hyperlinkless path only) ----
    -- Mirrors the pre-two-tier `elseif itemLocation` branch: the hyperlink path in
    -- PopulateBaseProps is authoritative when a hyperlink exists. This fallback only
    -- runs for the edge case of itemLocation-only callers (no hyperlink resolved).
    --
    -- transmogInfo.appearanceID is Constants.Transmog.NoTransmogID (== 0) for items
    -- without an appearance, and 0 is truthy in Lua — a numeric check is required.
    if not props.hasAppearance and not hyperlink and itemLocation then
        local transmogInfo = C_Item.GetBaseItemTransmogInfo(itemLocation)
        local canTransmog = C_Item.CanItemTransmogAppearance(itemLocation)
        local hasAppearanceID = transmogInfo
            and transmogInfo.appearanceID
            and transmogInfo.appearanceID ~= 0
        if canTransmog or hasAppearanceID then
            props.hasAppearance = true
        end
    end

    if Profile then Profile:Stop("PE:BuildProps.PopulateSlotProps") end

    -- isUsable is resolved lazily via propsMT (ResolveCharacterUsable) so only
    -- expressions that reference #usable / #unusable pay the tooltip cost.

    -- ---- Apply lazy tooltip metatable ----
    setmetatable(props, propsMT)

    propsCache[cacheKey] = props
    return props
end

-- ============================================================================
-- SECTION 10: LAYER 2 — TOKENIZER
-- ============================================================================
-- Character-by-character scanner that produces a token array.
--
-- Token types:
--   op           ( ) & | !        and/or/not mapped to &/|/!
--   keyword      #word
--   prop_compare word OP value    where OP is >= <= > < = == != ~
--   prop_range   word:N-M
--   prop_flag    bare boolean flag name (IsEquipment, IsSoulbound, etc.)
--   text         unrecognized bare word (becomes name-substring match)
--
-- The ~ operator is string-contains.
-- Negation uses ! or the word "not".

local OP_CHARS = {
    ["("] = true, [")"] = true,
    ["&"] = true, ["|"] = true,
    ["!"] = true,
}

local function ReadQuotedValue(searchStr, startPos, len)
    local quote = searchStr:sub(startPos, startPos)
    local i = startPos + 1

    while i <= len do
        if searchStr:sub(i, i) == quote then
            return searchStr:sub(startPos + 1, i - 1), i + 1
        end
        i = i + 1
    end

    return nil, len + 1
end

local function Tokenize(searchStr)
    local tokens = {}
    local i = 1
    local len = #searchStr

    while i <= len do
        local prevI = i
        local c = searchStr:sub(i, i)

        -- ---- Whitespace: skip ----
        if c == " " or c == "\t" then
            i = i + 1

        -- ---- Operator characters: ( ) & | ! ----
        -- || (WoW escape for literal pipe) is consumed as a single OR token.
        elseif c == "|" and i + 1 <= len and searchStr:sub(i + 1, i + 1) == "|" then
            tinsert(tokens, { type = "op", value = "|" })
            i = i + 2
        elseif OP_CHARS[c] then
            tinsert(tokens, { type = "op", value = c })
            i = i + 1

        elseif c == "~" then
            local nextPos = i + 1
            while nextPos <= len do
                local nextChar = searchStr:sub(nextPos, nextPos)
                if nextChar ~= " " and nextChar ~= "\t" then break end
                nextPos = nextPos + 1
            end

            local nextChar = (nextPos <= len) and searchStr:sub(nextPos, nextPos) or ""
            if nextChar == "\"" or nextChar == "'" then
                local inner, afterQuote = ReadQuotedValue(searchStr, nextPos, len)
                i = afterQuote
                if inner ~= nil then
                    tinsert(tokens, {
                        type = "prop_compare",
                        prop = "name",
                        op = "~",
                        value = strlower(inner),
                    })
                end
            elseif nextChar == "~" then
                i = nextPos + 1
            else
                i = i + 1
            end

        -- ---- #keyword ----
        elseif c == "#" then
            local j = i + 1
            while j <= len do
                local ch = searchStr:sub(j, j)
                if OP_CHARS[ch] or ch == " " or ch == "\t" or ch == "#" then break end
                j = j + 1
            end
            local kw = searchStr:sub(i + 1, j - 1)
            if kw ~= "" then
                tinsert(tokens, { type = "keyword", value = strlower(kw) })
            end
            i = j

        -- ---- Bare comparison starting with > or <  (ilvl sugar like Bagantor) ----
        -- >=200 becomes prop_compare(ilvl, >=, 200)
        -- >100g becomes prop_compare(vendorprice, >, 1000000)
        elseif c == ">" or c == "<" then
            local j = i + 1
            if j <= len and searchStr:sub(j, j) == "=" then j = j + 1 end
            local valStart = j
            while j <= len and searchStr:sub(j, j):match(MONEY_CHAR_CLASS) do
                j = j + 1
            end
            local opStr = searchStr:sub(i, valStart - 1)
            local valStr = searchStr:sub(valStart, j - 1)
            local num = tonumber(valStr)
            local prop = "ilvl"
            if not num then
                local money = ParseMoney(valStr)
                if money then
                    num, prop = money, "vendorprice"
                end
            end
            if num then
                tinsert(tokens, {
                    type = "prop_compare", prop = prop,
                    op = opStr, value = num,
                })
            end
            i = j

        -- ---- Bare number: could be ilvl or vendorprice, exact match or range ----
        -- 623 becomes ilvl==623; 200-300 becomes ilvl:200-300
        -- 100g becomes vendorprice==1000000; 10s-50s becomes vendorprice:1000-5000
        elseif c:match("%d") then
            local j = i
            while j <= len and searchStr:sub(j, j):match(MONEY_CHAR_CLASS) do
                j = j + 1
            end
            local firstStr = searchStr:sub(i, j - 1)
            if j <= len and searchStr:sub(j, j) == "-" then
                local k = j + 1
                while k <= len and searchStr:sub(k, k):match(MONEY_CHAR_CLASS) do
                    k = k + 1
                end
                local secondStr = searchStr:sub(j + 1, k - 1)
                local low  = tonumber(firstStr)
                local high = tonumber(secondStr)
                local prop = "ilvl"
                if not (low and high) then
                    local lowM  = ParseMoney(firstStr)
                    local highM = ParseMoney(secondStr)
                    if lowM or highM then
                        low  = lowM  or tonumber(firstStr)
                        high = highM or tonumber(secondStr)
                        if low and high then
                            prop = "vendorprice"
                        end
                    end
                end
                if low and high then
                    tinsert(tokens, {
                        type = "prop_range", prop = prop,
                        low = low, high = high,
                    })
                end
                i = k
            else
                local num = tonumber(firstStr)
                local prop = "ilvl"
                if not num then
                    local money = ParseMoney(firstStr)
                    if money then
                        num, prop = money, "vendorprice"
                    end
                end
                if num then
                    tinsert(tokens, {
                        type = "prop_compare", prop = prop,
                        op = "=", value = num,
                    })
                end
                i = j
            end

        -- ---- Bare word: property comparison, flag, lua operator, or name text ----
        else
            -- Consume the word, stopping at operators, whitespace, and special chars
            local j = i
            while j <= len do
                local ch = searchStr:sub(j, j)
                if OP_CHARS[ch] or ch == "#" or ch == " " or ch == "\t" then break end
                if ch == ">" or ch == "<" or ch == "=" or ch == "~" or ch == ":" then break end
                j = j + 1
            end
            local word = searchStr:sub(i, j - 1)
            local wordLower = strlower(word)
            i = j

            -- Sub-case 1: Lua-style boolean operators -> op tokens
            if wordLower == "and" then
                tinsert(tokens, { type = "op", value = "&" })
            elseif wordLower == "or" then
                tinsert(tokens, { type = "op", value = "|" })
            elseif wordLower == "not" then
                tinsert(tokens, { type = "op", value = "!" })
            else
                -- Determine if a comparison operator follows this word
                local nextChar = (i <= len) and searchStr:sub(i, i) or ""
                local isCompareNext = false

                if nextChar == ">" or nextChar == "<" or nextChar == "=" then
                    isCompareNext = true
                elseif nextChar == "!" and i + 1 <= len
                       and searchStr:sub(i + 1, i + 1) == "=" then
                    isCompareNext = true
                elseif nextChar == "~" then
                    -- ~ is only valid as string-contains on string-type properties
                    local reg = PROP_REGISTRY[wordLower]
                    if reg and reg.type == "string" then
                        isCompareNext = true
                    end
                end

                -- Sub-case 2: Property comparison (word OP value)
                if isCompareNext and PROP_REGISTRY[wordLower] then
                    local reg = PROP_REGISTRY[wordLower]
                    local opStart = i
                    local opEnd = i
                    -- Check for two-char operators: >= <= != == ~~
                    if i + 1 <= len then
                        local twoChar = searchStr:sub(i, i + 1)
                        if twoChar == ">=" or twoChar == "<="
                        or twoChar == "!=" or twoChar == "=="
                        or twoChar == "~~" then
                            opEnd = i + 1
                        end
                    end
                    local opStr = searchStr:sub(opStart, opEnd)
                    i = opEnd + 1

                    local val
                    if reg.type == "number" or reg.type == "set" then
                        local valStart = i
                        while i <= len do
                            local ch = searchStr:sub(i, i)
                            if OP_CHARS[ch] or ch == " " or ch == "\t"
                            or ch == "#" or ch == "~" or ch == ":" then break end
                            if ch == ">" or ch == "<" or ch == "=" then break end
                            i = i + 1
                        end
                        local valStr = searchStr:sub(valStart, i - 1)
                        val = tonumber(valStr)
                        if not val and reg.unit == "money" then
                            val = ParseMoney(valStr)
                        end
                        if not val then
                            local rhsKey = strlower(valStr)
                            local rhsReg = PROP_REGISTRY[rhsKey]
                            if rhsReg and rhsReg.type == "number" then
                                val = rhsKey
                            end
                        end
                    elseif opStr == "=" or opStr == "==" or opStr == "!="
                    or opStr == "~" or opStr == "~~" then
                        while i <= len do
                            local ch = searchStr:sub(i, i)
                            if ch ~= " " and ch ~= "\t" then break end
                            i = i + 1
                        end

                        local valueChar = (i <= len) and searchStr:sub(i, i) or ""
                        if valueChar == "\"" or valueChar == "'" then
                            local inner
                            inner, i = ReadQuotedValue(searchStr, i, len)
                            if inner ~= nil then
                                val = strlower(inner)
                            end
                        else
                            local valStart = i
                            while i <= len do
                                local ch = searchStr:sub(i, i)
                                if OP_CHARS[ch] or ch == " " or ch == "\t"
                                or ch == "#" or ch == "~" or ch == ":" then break end
                                if ch == ">" or ch == "<" or ch == "=" then break end
                                i = i + 1
                            end
                            local valStr = searchStr:sub(valStart, i - 1)
                            val = strlower(valStr)
                        end
                    else
                        while i <= len do
                            local ch = searchStr:sub(i, i)
                            if ch ~= " " and ch ~= "\t" then break end
                            i = i + 1
                        end

                        local valueChar = (i <= len) and searchStr:sub(i, i) or ""
                        if valueChar == "\"" or valueChar == "'" then
                            local _, nextPos = ReadQuotedValue(searchStr, i, len)
                            i = nextPos
                        else
                            while i <= len do
                                local ch = searchStr:sub(i, i)
                                if OP_CHARS[ch] or ch == " " or ch == "\t"
                                or ch == "#" or ch == "~" or ch == ":" then break end
                                if ch == ">" or ch == "<" or ch == "=" then break end
                                i = i + 1
                            end
                        end
                    end

                    if val ~= nil then
                        tinsert(tokens, {
                            type = "prop_compare",
                            prop = wordLower,
                            op   = opStr,
                            value = val,
                        })
                    end

                elseif nextChar == "~" and PROP_REGISTRY[wordLower] then
                    if i + 1 <= len and searchStr:sub(i + 1, i + 1) == "~" then
                        i = i + 2
                    else
                        i = i + 1
                    end

                    while i <= len do
                        local ch = searchStr:sub(i, i)
                        if ch ~= " " and ch ~= "\t" then break end
                        i = i + 1
                    end

                    local valueChar = (i <= len) and searchStr:sub(i, i) or ""
                    if valueChar == "\"" or valueChar == "'" then
                        local _, nextPos = ReadQuotedValue(searchStr, i, len)
                        i = nextPos
                    else
                        while i <= len do
                            local ch = searchStr:sub(i, i)
                            if OP_CHARS[ch] or ch == " " or ch == "\t"
                            or ch == "#" or ch == "~" or ch == ":" then break end
                            if ch == ">" or ch == "<" or ch == "=" then break end
                            i = i + 1
                        end
                    end

                -- Sub-case 3: Property range (word:N-M)
                elseif nextChar == ":" and PROP_REGISTRY[wordLower] then
                    i = i + 1  -- skip the ':'
                    local rangeStart = i
                    while i <= len do
                        local ch = searchStr:sub(i, i)
                        if OP_CHARS[ch] or ch == " " or ch == "\t" or ch == "#" then break end
                        i = i + 1
                    end
                    local rangeStr = searchStr:sub(rangeStart, i - 1)
                    local reg = PROP_REGISTRY[wordLower]
                    local lowN, highN
                    local low, high = rangeStr:match("^(%d+)-(%d+)$")
                    if low and high then
                        lowN, highN = tonumber(low), tonumber(high)
                    elseif reg.unit == "money" then
                        local lowStr, highStr = rangeStr:match("^([%d%.gGsScC]+)-([%d%.gGsScC]+)$")
                        if lowStr and highStr then
                            lowN  = ParseMoney(lowStr)  or tonumber(lowStr)
                            highN = ParseMoney(highStr) or tonumber(highStr)
                        end
                    end
                    if lowN and highN then
                        tinsert(tokens, {
                            type = "prop_range",
                            prop = wordLower,
                            low  = lowN,
                            high = highN,
                        })
                    else
                        tinsert(tokens, { type = "text", value = word })
                    end

                -- Sub-case 4: Boolean flag (IsEquipment, IsSoulbound, etc.)
                elseif FLAG_REGISTRY[wordLower] then
                    tinsert(tokens, { type = "prop_flag", flag = wordLower })

                -- Sub-case 5: Fallback — name substring match
                elseif word ~= "" then
                    tinsert(tokens, { type = "text", value = word })
                end
            end
        end

        if i <= prevI then
            if PE._STRICT_TOKENIZER then
                error(("Tokenizer stalled at pos %d (char %q)"):format(prevI, c))
            end
            i = prevI + 1
        end
    end

    return tokens
end

-- ============================================================================
-- SECTION 11: LAYER 2 — PARSER
-- ============================================================================
-- Recursive descent parser. Produces a function(props) -> bool from tokens.
--
-- Grammar:
--   Expression = And ( "|" And )*
--   And        = Not ( "&" Not )*
--   Not        = "!" Not | Primary
--   Primary    = "(" Expression ")"
--             | keyword | prop_compare | prop_range
--             | prop_flag | text

local ParseExpression, ParseAnd, ParseNot, ParsePrimary

ParseExpression = function(tokens, pos)
    local left, newPos = ParseAnd(tokens, pos)
    while newPos <= #tokens
      and tokens[newPos].type == "op"
      and tokens[newPos].value == "|" do
        newPos = newPos + 1
        local right
        right, newPos = ParseAnd(tokens, newPos)
        local captL, captR = left, right
        left = function(props) return captL(props) or captR(props) end
    end
    return left, newPos
end

ParseAnd = function(tokens, pos)
    local left, newPos = ParseNot(tokens, pos)
    while newPos <= #tokens
      and tokens[newPos].type == "op"
      and tokens[newPos].value == "&" do
        newPos = newPos + 1
        local right
        right, newPos = ParseNot(tokens, newPos)
        local captL, captR = left, right
        left = function(props) return captL(props) and captR(props) end
    end
    return left, newPos
end

ParseNot = function(tokens, pos)
    -- Only ! is the negation operator (~ was removed as NOT and only means string-contains)
    if pos <= #tokens
       and tokens[pos].type == "op"
       and tokens[pos].value == "!" then
        local inner, newPos = ParseNot(tokens, pos + 1)
        local captInner = inner
        return function(props) return not captInner(props) end, newPos
    end
    return ParsePrimary(tokens, pos)
end

ParsePrimary = function(tokens, pos)
    if pos > #tokens then
        return function() return false end, pos
    end

    local token = tokens[pos]

    -- Parenthesized sub-expression
    if token.type == "op" and token.value == "(" then
        local inner, newPos = ParseExpression(tokens, pos + 1)
        if newPos <= #tokens
           and tokens[newPos].type == "op"
           and tokens[newPos].value == ")" then
            newPos = newPos + 1
        end
        return inner, newPos
    end

    -- #keyword -> KEYWORD_MAP, then user tokens via the keyword resolver
    if token.type == "keyword" then
        local fn = ResolveKeywordFn(token.value)
        if fn then
            return fn, pos + 1
        end
        return function() return false end, pos + 1
    end

    -- Property comparison: ilvl>=200, id=12345, quality==4, name~sword
    if token.type == "prop_compare" then
        local reg = PROP_REGISTRY[token.prop]
        if not reg then return function() return false end, pos + 1 end
        local field = reg.field
        local op = token.op
        local val = token.value

        if reg.type == "set" then
            -- Membership test against a lookup set (e.g. forspec=73). `=`/`==`
            -- mean "ID is in the set", `!=` means "not in the set"; ordered
            -- comparators are meaningless for nominal class/spec IDs.
            return function(props)
                local set = props[field]
                local present = (set ~= nil) and (set[val] == true)
                if op == "!=" then return not present end
                if op == "=" or op == "==" then return present end
                return false
            end, pos + 1
        elseif reg.type == "number" then
            if type(val) == "string" then
                local rhsField = PROP_REGISTRY[val].field
                return function(props)
                    local lhs = props[field] or 0
                    local rhs = props[rhsField] or 0
                    if     op == ">=" then return lhs >= rhs
                    elseif op == "<=" then return lhs <= rhs
                    elseif op == ">"  then return lhs >  rhs
                    elseif op == "<"  then return lhs <  rhs
                    elseif op == "!=" then return lhs ~= rhs
                    else   return lhs == rhs end
                end, pos + 1
            else
                return function(props)
                    local actual = props[field] or 0
                    if     op == ">=" then return actual >= val
                    elseif op == "<=" then return actual <= val
                    elseif op == ">"  then return actual >  val
                    elseif op == "<"  then return actual <  val
                    elseif op == "!=" then return actual ~= val
                    else   return actual == val end
                end, pos + 1
            end
        else
            -- String comparison: = / == for exact, != for not-equal, ~ for contains, ~~ for Lua patterns
            return function(props)
                local actual = strlower(props[field] or "")
                if op == "=" or op == "==" then
                    return actual == val
                elseif op == "!=" then
                    return actual ~= val
                elseif op == "~~" then
                    local ok, found = pcall(strfind, actual, val)
                    return ok and found ~= nil
                else
                    return strfind(actual, val, 1, true) ~= nil
                end
            end, pos + 1
        end
    end

    -- Property range: ilvl:200-300
    if token.type == "prop_range" then
        local reg = PROP_REGISTRY[token.prop]
        if not reg then return function() return false end, pos + 1 end
        if reg.type ~= "number" then return function() return false end, pos + 1 end
        local field = reg.field
        local low, high = token.low, token.high
        return function(props)
            local actual = props[field] or 0
            return actual >= low and actual <= high
        end, pos + 1
    end

    -- Boolean flag: IsEquipment, IsSoulbound, etc.
    if token.type == "prop_flag" then
        local field = FLAG_REGISTRY[token.flag]
        return function(props)
            return props[field] == true
        end, pos + 1
    end

    -- Text: name substring match
    if token.type == "text" then
        local searchText = strlower(token.value)
        return function(props)
            return props.name and strfind(props.name, searchText, 1, true) ~= nil
        end, pos + 1
    end

    -- Unknown token type — skip and return false
    return function() return false end, pos + 1
end

-- ============================================================================
-- SECTION 12: PUBLIC API
-- ============================================================================

--- NOTE: PE:BuildProps is also public, just further up in the code.

--- Compile an expression string into a predicate function.
--- Returns the compiled function(props)->bool, cached for repeated use.
--- Returns nil on empty input; returns nil, errorMessage on tokenize/parse failure.
---@param expr string|nil
---@return (fun(props: table): boolean)|nil compiled
---@return string|nil errorMessage
function PE:Compile(expr)
    if not expr or expr == "" then return nil end

    if compiledCache[expr] then
        return compiledCache[expr]
    end

    local singleKeyword = strmatch(expr, "^%s*#([%w_]+)%s*$")
    if singleKeyword then
        local fn = ResolveKeywordFn(strlower(singleKeyword))
        if fn then
            compiledCache[expr] = fn
            return fn
        end
    end

    local negatedKeyword = strmatch(expr, "^%s*!%s*#([%w_]+)%s*$")
    if negatedKeyword then
        local fn = ResolveKeywordFn(strlower(negatedKeyword))
        if fn then
            local compiled = function(props)
                return not fn(props)
            end
            compiledCache[expr] = compiled
            return compiled
        end
    end

    local ok, tokensOrErr = pcall(Tokenize, expr)
    if not ok then
        return nil, "Tokenize error: " .. tostring(tokensOrErr)
    end
    local tokens = tokensOrErr
    if #tokens == 0 then return nil end

    local ok2, funcOrErr = pcall(ParseExpression, tokens, 1)
    if not ok2 then
        return nil, "Parse error: " .. tostring(funcOrErr)
    end

    compiledCache[expr] = funcOrErr
    return funcOrErr
end

--- Evaluate a compiled predicate safely (pcall wrapped).
--- Returns result, errorMessage (errorMessage is nil on success).
---@param compiled fun(props: table): boolean
---@param props table
---@return boolean result
---@return string|nil errorMessage
function PE:SafeEvaluate(compiled, props)
    local ok, result = pcall(compiled, props)
    if not ok then
        return false, tostring(result)
    end
    return result, nil
end

--- True when the item is a profession recipe scroll, after ITEM_ID_OVERRIDES.
--- Identity-tier only (no BuildProps). Use from Collectibles key resolution.
---@param itemID number
---@return boolean
function PE:IsRecipeItemIdentity(itemID)
    return IdentityIsRecipeItem(itemID)
end

--- True when the item is a profession recipe scroll, after ITEM_ID_OVERRIDES.
--- Prefer this over raw C_Item.GetItemInfoInstant class checks.
---@param itemID number
---@param bagID number|nil
---@param slotID number|nil
---@param itemInfo string|table|nil
---@return boolean isRecipe
---@return table|nil props
function PE:IsRecipeItem(itemID, bagID, slotID, itemInfo)
    if not itemID then return false, nil end

    local props = self:BuildProps(itemID, bagID, slotID, itemInfo)
    if PropsIsRecipeItem(props) then
        return true, props
    end
    return false, nil
end

--- Required reagents when the item's Use: effect is a combine/craft spell.
--- Returns nil for ordinary items. Same detector as `#combinable` /
--- `#combineready` (identity-cached schematic; enchant scrolls and trivial
--- single-reagent qty-1 schematics excluded).
--- Each entry is `{ itemID?, currencyID?, quantityRequired }`.
---@param itemID number|nil
---@return table|nil
function PE:GetCombineReagents(itemID)
    if not itemID then return nil end
    return GetCombineReagents(itemID)
end

--- High-level: compile + evaluate in one call. Builds props if needed.
--- Returns false on any of: empty expression, missing itemID, compile failure.
---@param expr string|nil
---@param itemID number|nil
---@param bagID number|nil
---@param slotID number|nil
---@param itemInfo string|table|nil
---@return boolean
function PE:CheckItem(expr, itemID, bagID, slotID, itemInfo)
    if not expr or expr == "" or not itemID then return false end

    local compiled = self:Compile(expr)
    if not compiled then return false end

    local props = self:BuildProps(itemID, bagID, slotID, itemInfo)
    local result = self:SafeEvaluate(compiled, props)
    return result
end

--- Resolve ${PARAM_*} and ${CONSTANT} tokens in an expression string.
--- Called before Compile() for Vendor rules with user-configurable parameters.
---
--- Example:
---   quality==${EPIC} & ilvl<${PARAM_ILVL}
---   with params = { PARAM_ILVL = { value = 600 } }
---   becomes: quality==4 & ilvl<600
---
--- Passes nil through unchanged.
---@param expr string|nil
---@param params table<string, { value: any?, default: any? }>|nil
---@return string|nil
function PE:ResolveParams(expr, params)
    if not expr then return expr end
    local resolved = expr

    -- First pass: replace ${PARAM_*} with parameter values (params take priority)
    if params then
        resolved = resolved:gsub("%${(%w+)}", function(token)
            local def = params[token]
            if def then return tostring(def.value or def.default or 0) end
            return nil
        end)
    end

    -- Second pass: replace remaining ${CONSTANT} with CONSTANT_MAP values
    resolved = resolved:gsub("%${(%w+)}", function(token)
        local val = CONSTANT_MAP[token:upper()]
        if val ~= nil then return tostring(val) end
        return nil
    end)

    return resolved
end

--- Battle-pet metadata for caged pets (item 82800) or pet items.
--- Returns nil for items that have no associated pet species.
---@param itemID number
---@param hyperlink string|nil
---@return table|nil
function PE:GetBattlePetData(itemID, hyperlink)
    return GetBattlePetData(itemID, hyperlink)
end

--- Cache key used by BuildProps. Slot-aware ("bagID:slotID") when bag/slot
--- coordinates are present; otherwise an item-identity key (hyperlink for
--- normal items, itemID + pet stats for caged pets).
---@param itemID number
---@param bagID number|nil
---@param slotID number|nil
---@param hyperlink string|nil
---@return string
function PE:GetItemCacheKey(itemID, bagID, slotID, hyperlink)
    return GetItemCacheKey(itemID, bagID, slotID, hyperlink)
end

--- Stable identity key for an item. Uses hyperlink when available so suffixed
--- variants do not collide; for caged pets folds in pet stats so different
--- breed levels stack separately. Falls back to tostring(itemID) when no
--- hyperlink is provided.
---@param itemID number
---@param hyperlink string|nil
---@return string
function PE:GetItemIdentityKey(itemID, hyperlink)
    return GetItemIdentityKey(itemID, hyperlink)
end

--- Parse a full item hyperlink (or `item:...` string) into structured fields.
--- Returns nil for inputs that do not match the item link grammar.
---
--- Populated fields (any may be nil): id, enchantID, gemID1..gemID3, suffixID,
--- uniqueID, linkLevel, specID, modifiersMask, itemContext, gems[],
--- bonusIDs[], modifiers, relicBonusIDs[1..3], crafterGUID, extraEnchantID,
--- quality, name.
---@param link string|nil
---@return table|nil
function PE:ParseItemLink(link)
    return ParseItemLink(link)
end

--- Is this item usable by the given class (or the current player if class is nil).
--- Pass a class token ("WARRIOR", "PALADIN", ...) to check an alt. Returns a
--- plain boolean; treats universal gear (empty spec list) as usable and
--- correctly rejects class-locked drops on classes that cannot equip them.
--- Caller may pass itemID or a hyperlink; hyperlink is preferred when available
--- because it carries modified-itemID context for reworked/tokenized gear.
---@param itemID number|nil
---@param hyperlink string|nil
---@param class string|nil class token (UnitClass second return); nil means current player
---@return boolean
function PE:CanClassEquip(itemID, hyperlink, class)
    local classID
    if class then
        classID = CLASS_ID[class]
    else
        _, _, classID = UnitClass("player")
    end
    if not classID then return true end
    local item = hyperlink or itemID
    if not item then return false end
    return C_Item.DoesItemContainSpec(item, classID) == true
end

--- Register custom keyword (for third-party / suite extensions).
--- Wipes the compiled cache since available keywords changed.
---@param nameOrNames string|string[]
---@param func fun(props: table): boolean
function PE:RegisterKeyword(nameOrNames, func)
    local names
    if type(nameOrNames) == "table" then
        names = nameOrNames
    else
        names = { nameOrNames }
    end
    for _, name in ipairs(names) do
        KEYWORD_MAP[strlower(name)] = func
    end
    if not KEYWORD_CANONICAL[func] then
        local firstName = strlower(names[1])
        KEYWORD_CANONICAL[func] = firstName
        tinsert(KEYWORD_CANONICAL_ORDER, { name = firstName, fn = func })
    end
    -- Built-in wins. #upgrade, #combineready and #disenchantable register long
    -- after login, so a user token of the same name may already be resolved and
    -- cached; dropping the cache here is what makes the new built-in shadow it.
    wipe(resolvedTokens)
    wipe(compiledCache)
end

--- True when name is a built-in/registered keyword (not merely a user token).
---@param name string|nil
---@return boolean
function PE:IsBuiltinKeyword(name)
    if type(name) ~= "string" or name == "" then return false end
    -- Extra parens truncate gsub to its string return; the count must not reach
    -- a second parameter (harmless for strlower, not for every callee).
    local lower = strlower((name:gsub("^#", "")))
    return KEYWORD_MAP[lower] ~= nil
end

--- Install the resolver consulted for a `#token` that is not a built-in
--- keyword. It receives the lowercased token name (no leading `#`) and returns
--- an expression body, or nil when it owns no such token.
---
--- The engine compiles that body in place, so token bodies nest freely; the
--- resolver is expected to have already expanded any non-engine syntax of its
--- own (SearchExpand runs `SAVED(...)` / `CATEGORY(...)` through Expand first).
--- Cycles and unresolvable tokens fail closed as always-false.
---
--- Owning the tokens means owning the invalidation: call
--- `InvalidateKeywordTokens` whenever a body or name changes.
---@param fn (fun(name: string): string|nil)|nil
function PE:SetKeywordResolver(fn)
    keywordResolver = fn
    self:InvalidateKeywordTokens()
end

--- Drop every resolved token predicate and every compiled expression that may
--- have embedded one. Called by the resolver's owner on any change to its data.
function PE:InvalidateKeywordTokens()
    wipe(resolvedTokens)
    wipe(compiledCache)
end

--- List every registered keyword in registration order.
--- Returns an ordered array of `{ canonical = "poor", aliases = { "grey", "gray" } }`
--- entries. Intended for help/reference UIs that want to show every keyword
--- the engine currently knows about (including addons that registered extras
--- via RegisterKeyword). Aliases exclude the canonical name itself and are
--- sorted alphabetically for stable display.
---
--- Built-ins only. User-defined `#token` entries belong to whoever installed
--- the keyword resolver — ask `OneWoW.SearchExpand:GetTokens()` for those.
---@return { canonical: string, aliases: string[] }[]
function PE:GetAllKeywords()
    local results = {}
    local seen = {}

    for _, entry in ipairs(KEYWORD_CANONICAL_ORDER) do
        local canonical = entry.name
        local fn = entry.fn
        local aliases = {}
        for name, mapFn in pairs(KEYWORD_MAP) do
            if mapFn == fn and name ~= canonical then
                tinsert(aliases, name)
            end
        end
        table.sort(aliases)
        if not seen[canonical] then
            seen[canonical] = true
            tinsert(results, { canonical = canonical, aliases = aliases })
        end
    end

    return results
end

--- List every registered built-in keyword that matches a given item.
--- Returns an ordered array of canonical keyword names (without the leading "#").
--- Built-in PE aliases (e.g. #grey / #gray for #poor) are deduplicated by
--- predicate-function identity; the first name a keyword was registered under
--- is treated as canonical. User Search Shortcuts tokens are not included —
--- use `OneWoW.SearchExpand:GetMatchingTokens`.
---
--- Tooltip-only mode (bagID/slotID nil):
---   * `#boe`/`#bou`/`#warbound`/`#wue` work via a hyperlink-tooltip fallback
---     in ResolveBind.
---   * `#bop`/`#soulbound`/`#bound` will not match because current-bound state
---     cannot be inferred from a hyperlink (item is not in the player's
---     inventory). See ResolveBind comment for the source-aware mapping.
---   * Other slot-state-only properties degrade to false:
---     `#new`, `#locked`, `#tradeableloot`, `#alreadyknown` (toy/spell path),
---     `#unique`/`#uniqueequipped`, `#hascharges`. Slot-only fields read
---     directly (durability, equipmentSetList, isInEquipmentSet, count,
---     isRefundable, isScrappable, isBattlePayItem) are similarly absent.
---@param itemID number|nil
---@param bagID number|nil
---@param slotID number|nil
---@param itemInfo string|table|nil
---@return string[]
function PE:GetMatchingKeywords(itemID, bagID, slotID, itemInfo)
    local results = {}
    if not itemID then return results end

    local props = self:BuildProps(itemID, bagID, slotID, itemInfo)
    if not props then return results end

    for _, entry in ipairs(KEYWORD_CANONICAL_ORDER) do
        local ok, matched = pcall(entry.fn, props)
        if ok and matched then
            tinsert(results, entry.name)
        end
    end
    return results
end

--- Register custom numeric/string property for comparison syntax.
--- The optional unit = "money" enables money parsing (e.g. "100g") on the RHS
--- of comparisons for number-typed properties.
---@param nameOrNames string|string[]
---@param def { field: string, type: ("number"|"string")?, unit: ("money"|nil)? }
function PE:RegisterProperty(nameOrNames, def)
    local entry = { field = def.field, type = def.type or "number", unit = def.unit }
    if type(nameOrNames) == "table" then
        for _, name in ipairs(nameOrNames) do
            PROP_REGISTRY[strlower(name)] = entry
        end
    else
        PROP_REGISTRY[strlower(nameOrNames)] = entry
    end
    -- Same reason as RegisterKeyword: a token body that used this property
    -- before it existed compiled to always-false, and that compile is cached
    -- per token as well as per expression.
    wipe(resolvedTokens)
    wipe(compiledCache)
end

--- Invalidate all caches
function PE:InvalidateCache()
    wipe(resolvedTokens)
    wipe(compiledCache)
    wipe(propsCache)
    Scanner:InvalidateTooltipCaches()
    wipe(identityPropsCache)
    wipe(characterUsableCache)
    wipe(combineSchematicCache)
    currentSeasonLabelCache = nil
    wipe(namedSeasonLabelCache)
    knownProfs = nil
end

--- Invalidate props and slot-tier tooltip caches (lighter, for frequent events
--- like BAG_UPDATE_DELAYED). Compiled expressions are still valid since the
--- grammar didn't change. Also wipes identity-tier props since some fields
--- (collection state, equipped status) can shift between bag updates.
---
--- Deliberately preserved across bag updates (their inputs are item templates
--- + character context, not bag contents):
---   - Scanner link-tier tooltip caches (hyperlink-keyed template tooltips)
---   - characterUsableCache (wiped by InvalidateCharacterContext /
---     InvalidateCache; surgically evicted by InvalidateItemIDs)
function PE:InvalidatePropsCache()
    wipe(propsCache)
    Scanner:InvalidateSlotTooltipCaches()
    wipe(identityPropsCache)
end

--- Character-context invalidation (level up, spec/talent change, skill lines).
--- These change red requirement lines and usability verdicts everywhere, so
--- wipe the character-usability cache and both tooltip cache tiers on top of
--- the regular props wipe.
function PE:InvalidateCharacterContext()
    wipe(characterUsableCache)
    Scanner:InvalidateTooltipCaches()
    self:InvalidatePropsCache()
end

--- Surgical per-itemID invalidation. Used by GET_ITEM_INFO_RECEIVED batches
--- so streaming item info doesn't repeatedly wipe every other item's
--- already-resolved identity props.
---
--- Walks propsCache once, evicting entries whose `.id` is in idSet and
--- collecting their slot keys so TooltipScanner bag-slot caches can be
--- cleaned without re-walking. identityPropsCache hyperlink entries are
--- walked alongside.
---@param idSet table<number, boolean>|nil
---@return table<string, boolean> evictedSlotKeys
function PE:InvalidateItemIDs(idSet)
    local evictedSlotKeys = {}
    if not idSet then return evictedSlotKeys end

    for key, entry in pairs(propsCache) do
        if entry.id and idSet[entry.id] then
            propsCache[key] = nil
            Scanner:InvalidateBagSlot(key)
            evictedSlotKeys[key] = true
            local hyperlink = entry.hyperlink
            if hyperlink then
                Scanner:InvalidateHyperlink(hyperlink)
            end
        end
    end

    for key, entry in pairs(identityPropsCache) do
        if entry.id and idSet[entry.id] then
            identityPropsCache[key] = nil
            local hyperlink = entry.hyperlink
            if hyperlink then
                Scanner:InvalidateHyperlink(hyperlink)
            end
        end
    end

    EvictCharacterUsableCache(idSet)

    -- Late-arriving item data can flip GetItemSpell from nil to a spell, so
    -- drop any schematic verdict cached for these IDs.
    for id in pairs(idSet) do
        combineSchematicCache[id] = nil
    end

    return evictedSlotKeys
end

--- Expose raw concatenated tooltip left-text for a bag slot.
--- Returns the empty string when bagID/slotID are missing or no tooltip data
--- is available. Cached per "bagID:slotID" until invalidation.
---@param bagID number|nil
---@param slotID number|nil
---@return string
function PE:GetTooltipText(bagID, slotID)
    return Scanner:GetBagItemText(bagID, slotID)
end

-- ============================================================================
-- DEBUG: tooltip line dump (/petooltip, /owpetooltip)
-- ============================================================================

local DEBUG_PREFIX = "|cFF55CCFFPE|r"

local TOOLTIP_LINE_TYPE_NAMES do
    TOOLTIP_LINE_TYPE_NAMES = {}
    for name, value in pairs(Enum.TooltipDataLineType) do
        TOOLTIP_LINE_TYPE_NAMES[value] = name
    end
end

local function FormatTooltipColor(color)
    if not color then return "nil" end
    return format(
        "rgb(%d,%d,%d)",
        math.floor(color.r * 100),
        math.floor(color.g * 100),
        math.floor(color.b * 100)
    )
end

local function TruncateForChat(text, maxLen)
    if not text or text == "" then return "" end
    if #text <= maxLen then return text end
    return text:sub(1, maxLen) .. "..."
end

local function DumpTooltipDataSection(title, tooltipData, currentLabel)
    print(DEBUG_PREFIX .. ": " .. title)
    if not tooltipData or not tooltipData.lines then
        print(DEBUG_PREFIX .. ":   (no tooltip data)")
        return
    end
    print(DEBUG_PREFIX .. format(":   %d lines", #tooltipData.lines))
    for index, row in ipairs(tooltipData.lines) do
        local typeName = TOOLTIP_LINE_TYPE_NAMES[row.type] or tostring(row.type)
        local left = row.leftText or ""
        local right = row.rightText or ""
        local stripped = GetTooltipLineText(row)
        local gray = IsGrayTooltipLine(row)
        local mentions = currentLabel and TooltipLineMentionsSeason(row, currentLabel) or false
        print(DEBUG_PREFIX .. format(
            ":   [%d] type=%s gray=%s season=%s",
            index, typeName, tostring(gray), tostring(mentions)
        ))
        if left ~= "" then
            print(DEBUG_PREFIX .. format(":        left=%q", left))
        end
        if right ~= "" then
            print(DEBUG_PREFIX .. format(":       right=%q", right))
        end
        if stripped ~= "" and stripped ~= left and stripped ~= right then
            print(DEBUG_PREFIX .. format(":     stripped=%q", stripped))
        end
        if row.leftColor then
            print(DEBUG_PREFIX .. format(":        leftColor=%s", FormatTooltipColor(row.leftColor)))
        end
    end
end

--- Dev-only: dump C_TooltipInfo lines + #currentseason diagnostics to chat.
---@param itemID number|nil
---@param bagID number|nil
---@param slotID number|nil
---@param hyperlink string|nil
function PE:DumpTooltipDebug(itemID, bagID, slotID, hyperlink)
    local currentLabel = GetCurrentSeasonLabel()
    print(DEBUG_PREFIX .. ": === Tooltip debug ===")
    print(DEBUG_PREFIX .. format(
        ": itemID=%s bag=%s slot=%s",
        tostring(itemID), tostring(bagID), tostring(slotID)
    ))
    if hyperlink then
        print(DEBUG_PREFIX .. format(": hyperlink=%s", TruncateForChat(hyperlink, 120)))
    end
    print(DEBUG_PREFIX .. format(": currentSeasonLabel=%q", currentLabel or "nil"))
    local mplusDisplay, mplusMilestone, mplusReward = C_MythicPlus.GetCurrentSeasonValues()
    print(DEBUG_PREFIX .. format(
        ": M+ display=%s milestone=%s reward=%s uiDisplay=%s global=%s expansionOrdinal=%s",
        tostring(mplusDisplay),
        tostring(mplusMilestone),
        tostring(mplusReward),
        tostring(C_MythicPlus.GetCurrentUIDisplaySeason()),
        tostring(C_MythicPlus.GetCurrentSeason()),
        tostring(GetCurrentExpansionSeasonNumber())
    ))
    print(DEBUG_PREFIX .. format(
        ": SeasonInfo displayUID=%s displayExp=%s LE_CURRENT=%s itemExpansion=%s",
        tostring(C_SeasonInfo.GetCurrentDisplaySeasonID()),
        tostring(C_SeasonInfo.GetCurrentDisplaySeasonExpansion()),
        tostring(LE_EXPANSION_LEVEL_CURRENT),
        tostring(itemID and select(15, C_Item.GetItemInfo(hyperlink or itemID)))
    ))

    if bagID and slotID then
        DumpTooltipDataSection(
            "C_TooltipInfo.GetBagItem (fresh)",
            C_TooltipInfo.GetBagItem(bagID, slotID),
            currentLabel
        )
        DumpTooltipDataSection("GetTooltipData (cached)", GetTooltipData(bagID, slotID), currentLabel)
        local tt = GetTooltipText(bagID, slotID)
        print(DEBUG_PREFIX .. format(": GetTooltipText len=%d text=%q", #tt, TruncateForChat(tt, 240)))
    end

    if hyperlink then
        DumpTooltipDataSection(
            "C_TooltipInfo.GetHyperlink (fresh)",
            C_TooltipInfo.GetHyperlink(hyperlink),
            currentLabel
        )
        DumpTooltipDataSection(
            "GetTooltipDataByHyperlink (cached)",
            GetTooltipDataByHyperlink(hyperlink),
            currentLabel
        )
        local tt = GetTooltipTextByHyperlink(hyperlink)
        print(DEBUG_PREFIX .. format(": GetTooltipTextByHyperlink len=%d text=%q", #tt, TruncateForChat(tt, 240)))
    end

    if itemID then
        local props = self:BuildProps(itemID, bagID, slotID, hyperlink)
        print(DEBUG_PREFIX .. format(
            ": props.expansionID=%s isEquipment=%s",
            tostring(props.expansionID), tostring(props.isEquipment)
        ))
        print(DEBUG_PREFIX .. format(
            ": IsUsableItem=%s props.isUsable=%s",
            tostring(C_Item.IsUsableItem(hyperlink or itemID)),
            tostring(props.isUsable)
        ))
        -- Same tooltip routing as ResolveCharacterUsable: bag slot → link → itemID.
        local td
        if bagID and slotID then
            td = Scanner:GetBagItemData(bagID, slotID)
        elseif hyperlink then
            td = Scanner:GetHyperlinkData(hyperlink)
        else
            td = Scanner:GetItemByIDData(itemID)
        end
        local facts = Scanner:GetUsabilityFacts(td)
        local combineReagents = GetCombineReagents(itemID)
        local teachable = facts and facts.learnSpellID ~= nil
        print(DEBUG_PREFIX .. format(
            ": needsFallback=%s directUse=%s combine=%s combineReady=%s teachable=%s learnable=%s isRecipe=%s unmetReqs=%s canClassEquip=%s",
            tostring(Scanner:NeedsUsabilityFallback(bagID, itemID)),
            tostring(facts and facts.directUse),
            tostring(combineReagents ~= nil),
            tostring(combineReagents and HasAllCombineReagents(combineReagents) or false),
            tostring(teachable),
            tostring(teachable and TeachableStillLearnable(itemID, hyperlink, bagID, slotID)),
            tostring(IdentityIsRecipeItem(itemID)),
            tostring(facts and facts.unmetRequirements),
            tostring(props.isEquipment and self:CanClassEquip(itemID, hyperlink))
        ))
        if combineReagents then
            for i, reagent in ipairs(combineReagents) do
                local owned
                if reagent.itemID then
                    owned = C_Item.GetItemCount(reagent.itemID, true, false, true, true)
                else
                    local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
                    owned = currencyInfo and currencyInfo.quantity or 0
                end
                print(DEBUG_PREFIX .. format(
                    ":   reagent %d: %s=%s owned=%d required=%d",
                    i,
                    reagent.itemID and "item" or "currency",
                    tostring(reagent.itemID or reagent.currencyID),
                    owned,
                    reagent.quantityRequired
                ))
            end
        end
        print(DEBUG_PREFIX .. format(
            ": props.isCurrentSeason=%s resolved=%s tooltipMissing=%s",
            tostring(props.isCurrentSeason),
            tostring(rawget(props, "_currentSeasonResolved")),
            tostring(rawget(props, "_tooltipDataMissing"))
        ))
        print(DEBUG_PREFIX .. format(
            ": props.isMidnightS1=%s isMidnightS2=%s namedResolved=%s",
            tostring(props.isMidnightS1),
            tostring(props.isMidnightS2),
            tostring(rawget(props, "_namedSeasonsResolved"))
        ))
        local s1Label = GetNamedSeasonLabel(MIDNIGHT_EXPANSION_ID, 1)
        local s2Label = GetNamedSeasonLabel(MIDNIGHT_EXPANSION_ID, 2)
        print(DEBUG_PREFIX .. format(
            ": midnightS1Label=%q mention=%s midnightS2Label=%q mention=%s",
            s1Label or "nil",
            tostring(s1Label and CheckSeasonTooltipMention(props, s1Label, true)),
            s2Label or "nil",
            tostring(s2Label and CheckSeasonTooltipMention(props, s2Label, true))
        ))
        if currentLabel then
            print(DEBUG_PREFIX .. format(
                ": CheckSeasonTooltipMention=%s",
                tostring(CheckSeasonTooltipMention(props, currentLabel))
            ))
        end

        -- Compact class-eligibility snapshot (no per-line spam).
        rawset(props, "_specsResolved", nil)
        rawset(props, "eligibleClasses", nil)
        rawset(props, "eligibleSpecs", nil)
        local eligible = props.eligibleClasses
        local parts = {}
        if eligible then
            for classID in pairs(eligible) do
                parts[#parts + 1] = tostring(classID)
            end
            sort(parts)
        end
        local _, _, playerClassID = UnitClass("player")
        print(DEBUG_PREFIX .. format(
            ": eligibleClasses={%s} isGearToken=%s playerClass=%s #myclass=%s",
            table.concat(parts, ","),
            tostring(props.isGearToken),
            tostring(playerClassID),
            tostring(playerClassID and eligible and eligible[playerClassID] == true)
        ))
    end
end

local function FindBagButtonUnderMouse()
    local foci = GetMouseFoci()
    if not foci then return end

    local frames
    if foci.GetParent then
        frames = { foci }
    else
        frames = foci
    end

    for _, frame in ipairs(frames) do
        local walk = frame
        while walk do
            if walk.owb_bagID and walk.owb_slotID then
                return walk
            end
            walk = walk:GetParent()
        end
    end
end

local function ResolveTooltipDumpTarget(msg)
    msg = strtrim(msg or "")
    if msg ~= "" then
        local hyperlink = msg:match("(|c.-|Hitem:.-|h.-|h|r)")
        if not hyperlink and msg:find("item:", 1, true) then
            hyperlink = msg
        end
        if hyperlink then
            local itemID = C_Item.GetItemInfoInstant(hyperlink)
            return itemID, nil, nil, hyperlink
        end
        local itemID = tonumber(msg)
        if itemID then
            local _, itemLink = C_Item.GetItemInfo(itemID)
            return itemID, nil, nil, itemLink
        end
    end

    local bagButton = FindBagButtonUnderMouse()
    if bagButton then
        local info = bagButton.owb_itemInfo
        local itemID = info and info.itemID
        local hyperlink = info and info.hyperlink
        if not hyperlink and bagButton.owb_bagID and bagButton.owb_slotID then
            hyperlink = C_Container.GetContainerItemLink(bagButton.owb_bagID, bagButton.owb_slotID)
        end
        if not itemID and hyperlink then
            itemID = C_Item.GetItemInfoInstant(hyperlink)
        end
        return itemID, bagButton.owb_bagID, bagButton.owb_slotID, hyperlink
    end

    local _, link = GameTooltip:GetItem()
    if link then
        return C_Item.GetItemInfoInstant(link), nil, nil, link
    end

    local infoType, itemID, itemLink = GetCursorInfo()
    if infoType == "item" and itemID then
        return itemID, nil, nil, itemLink
    end
end

SLASH_PE_TOOLTIP_DUMP1 = "/1wpetooltip"
SlashCmdList["PE_TOOLTIP_DUMP"] = function(msg)
    local itemID, bagID, slotID, hyperlink = ResolveTooltipDumpTarget(msg)
    if not itemID then
        print(DEBUG_PREFIX .. ": hover a bag slot / tooltip item, pick up an item, or pass itemID / item link")
        return
    end
    PE:DumpTooltipDebug(itemID, bagID, slotID, hyperlink)
end

PE.BATTLE_PET_CAGE_ID = BATTLE_PET_CAGE_ID

local function OnCharacterContextChanged()
    PE:InvalidateCharacterContext()
end

ns.RegisterEvent("PLAYER_LEVEL_UP", "PredicateEngine", OnCharacterContextChanged)
ns.RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "PredicateEngine", OnCharacterContextChanged)
ns.RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "PredicateEngine", function(_, unit)
    if unit == "player" then
        OnCharacterContextChanged()
    end
end)
ns.RegisterEvent("SKILL_LINES_CHANGED", "PredicateEngine", function()
    PE:InvalidateKnownProfessions()
    OnCharacterContextChanged()
end)
