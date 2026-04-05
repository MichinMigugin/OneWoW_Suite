-- ============================================================================
-- OneWoW_Bags PredicateEngine
-- ============================================================================
-- Two-layer architecture:
--   Layer 1 (BuildProps): enriches a bag slot into a flat property table
--   Layer 2 (Compiler):   tokenizes + parses expressions into function(props)->bool
--
-- Design decisions:
--   - Hybrid bind detection: API primary, tooltip fallback when isBound is nil
--   - Strict soulbound: character-only; account-bound does NOT match #soulbound
--   - ~ operator is string-contains ONLY; negation uses ! or "not"
--   - ${CONSTANT} curly-brace syntax for named constants / parameters
--   - Lazy tooltip metatable for the few remaining tooltip-only fields
-- ============================================================================

local _, OneWoW_Bags = ...

OneWoW_Bags.PredicateEngine = {}
local PE = OneWoW_Bags.PredicateEngine

local tconcat, tinsert, wipe = table.concat, tinsert, wipe
local ipairs, pairs, tonumber, tostring = ipairs, pairs, tonumber, tostring
local strlower, strfind = string.lower, string.find
local strmatch = string.match
local rawset, rawget, setmetatable = rawset, rawget, setmetatable
local pcall = pcall
local C_Item = C_Item
local C_Container = C_Container
local C_TooltipInfo = C_TooltipInfo
local C_ToyBox, PlayerHasToy = C_ToyBox, PlayerHasToy
local C_MountJournal = C_MountJournal
local C_PetJournal = C_PetJournal
local C_TransmogCollection = C_TransmogCollection
local C_TradeSkillUI = C_TradeSkillUI
local TooltipUtil = TooltipUtil
local Enum = Enum

--- Transforms an enum table into a lookup table with custom aliases and synonyms
local function ConfigEnum(sourceEnum, config, autoRegisterMissing)
    if type(sourceEnum) ~= "table" then
       error("sourceEnum must be a table")
    end

    if type(config) ~= "table" then
       error("config must be a table")
    end

    local enumTable = {}

    for name, value in pairs(sourceEnum) do
       name = name:lower()
       local synonyms = config[name]

       if synonyms then
          local keep_key = synonyms[#synonyms]

          if keep_key then
             enumTable[name] = value
          end

          for i=1, #synonyms - 1 do
             enumTable[synonyms[i]] = value
          end
       else
          if autoRegisterMissing then
             enumTable[name] = value
          end
       end
    end

    return enumTable
 end

-- ============================================================================
-- SECTION 2: CACHES
-- ============================================================================
-- propsCache:    keyed by "bagID:slotID", stores the enriched property table
-- tooltipCache:  keyed by "bagID:slotID", stores concatenated tooltip left-text
-- compiledCache: keyed by expression string, stores compiled function(props)->bool

local propsCache = {}
local tooltipCache = {}
local compiledCache = {}

-- ============================================================================
-- SECTION 3: CONSTANTS AND LOCALE PATTERNS
-- ============================================================================

local BATTLE_PET_CAGE_ID = 82800

-- Hearthstone item IDs: base + all known toy variants.
-- Module-level so it's not recreated per-call.
local HS_IDS = {
    [6948]=true,[64488]=true,[54452]=true,[93672]=true,[110560]=true,
    [140192]=true,[141605]=true,[162973]=true,[163045]=true,[165669]=true,
    [165670]=true,[165802]=true,[166746]=true,[166747]=true,[168907]=true,
    [172179]=true,[180290]=true,[182773]=true,[183716]=true,[184353]=true,
    [188952]=true,[190196]=true,[193588]=true,[200630]=true,[206195]=true,
    [208704]=true,[209035]=true,[210455]=true,[212337]=true,[228940]=true,
}

-- Locale-aware charges pattern built from Blizzard's ITEM_SPELL_CHARGES global.
-- The English fallback matches "3 Charges" / "1 Charge".
local chargesPattern
if ITEM_SPELL_CHARGES then
    chargesPattern = ITEM_SPELL_CHARGES:gsub("%%d", "(%%d+)"):gsub("|4.-;", "%%a+")
else
    chargesPattern = "(%d+) Charges?"
end

-- Expansion ID mapping using the ConfigEnum helper from Core.lua.
-- Each entry: { alias1, alias2, ..., keepOriginalKey (bool) }
local EXPANSION_IDS_CONFIG = {
    ["none"]              = {"classic", "vanilla", false},
    ["burningcrusade"]    = {"tbc", true},
    ["northrend"]         = {"wrath", "wotlk", false},
    ["cataclysm"]         = {"cata", true},
    ["mistsofpandaria"]   = {"mists", "mop", "pandaria", false},
    ["draenor"]           = {"wod", "warlords", true},
    ["legion"]            = {true},
    ["battleforazeroth"]  = {"bfa", true},
    ["shadowlands"]       = {"sl", true},
    ["dragonflight"]      = {"df", true},
    ["warwithin"]         = {"tww", "thewarwithin", true},
    ["midnight"]          = {true},
    ["lasttitan"]         = {"titan", true},
}
local EXPANSION_IDS_MAP = ConfigEnum(Enum.ExpansionLevel, EXPANSION_IDS_CONFIG, true)

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

local function RegisterPropAlias(name, field, propType)
    PROP_REGISTRY[strlower(name)] = { field = field, type = propType or "number" }
end

-- Numeric properties
RegisterPropAlias("ilvl",           "ilvl")
RegisterPropAlias("itemlevel",      "ilvl")
RegisterPropAlias("level",          "ilvl")
RegisterPropAlias("id",             "id")
RegisterPropAlias("itemid",         "id")
RegisterPropAlias("count",          "count")
RegisterPropAlias("stacks",         "count")
RegisterPropAlias("quality",        "quality")
RegisterPropAlias("vendorprice",    "vendorPrice")
RegisterPropAlias("price",          "vendorPrice")
RegisterPropAlias("unitvalue",      "vendorPrice")
RegisterPropAlias("maxstack",       "maxStack")
RegisterPropAlias("stacksize",      "maxStack")
RegisterPropAlias("reqlevel",       "reqLevel")
RegisterPropAlias("minlevel",       "reqLevel")
RegisterPropAlias("expansion",      "expansionID")
RegisterPropAlias("expac",          "expansionID")
RegisterPropAlias("class",          "classID")
RegisterPropAlias("typeid",         "classID")
RegisterPropAlias("subclass",       "subClassID")
RegisterPropAlias("subtypeid",      "subClassID")
RegisterPropAlias("bindtype",       "bindType")
RegisterPropAlias("totalvalue",     "totalValue")
RegisterPropAlias("craftedquality", "craftedQuality")
RegisterPropAlias("upgradelevel",   "upgradeLevel")
RegisterPropAlias("upgrademax",     "upgradeMax")
RegisterPropAlias("maxlevel",       "maxLevel")
RegisterPropAlias("setid",          "setID")
RegisterPropAlias("sockets",        "sockets")

-- String properties
RegisterPropAlias("name",     "name",     "string")
RegisterPropAlias("equiploc", "equipLoc", "string")

-- ============================================================================
-- SECTION 6: FLAG_REGISTRY
-- ============================================================================
-- Maps lowercased bare-word flags to props field names.
-- Used by the tokenizer for verbose/Vendor-style rules:
--   IsEquipment & IsSoulbound & !IsInEquipmentSet

local FLAG_REGISTRY = {
    -- Core boolean flags
    isequipment          = "isEquipment",
    issoulbound          = "isSoulbound",
    isboe                = "isBOE",
    isboa                = "isBOA",
    isbou                = "isBOU",
    iswue                = "isWUE",
    isinequipmentset     = "isInEquipmentSet",
    iscollected          = "isCollected",
    isusable             = "isUsable",
    isjunk               = "isJunk",
    isupgrade            = "isUpgrade",
    istoy                = "isToy",
    ismount              = "isMount",
    ispet                = "isPet",
    iscosmetic           = "isCosmetic",
    islocked             = "isLocked",
    isunsellable         = "isUnsellable",
    hascharges           = "hasCharges",
    isunique             = "isUnique",
    isquestitem          = "isQuestItem",
    istierset            = "isTierSet",
    isappearancecollected = "isAppearanceCollected",
    isunknownappearance   = "isUnknownAppearance",
    hasappearance         = "hasAppearance",
    isupgradeable         = "isUpgradeable",
    isfullyupgraded       = "isFullyUpgraded",
    isprofessionequipment = "isProfessionEquipment",
    isequipped            = "isEquipped",
    isequippable          = "isEquippable",
    iscraftingreagent    = "isCraftingReagent",
    hassocket            = "hasSocket",

    -- Tooltip-derived flags (lazy)
    hasuseability        = "hasUseAbility",
    isalreadyknown       = "isAlreadyKnown",
    istradeableloot      = "isTradeableLoot",

    -- Aliases mapping to canonical props fields
    iswarbound            = "isBOA",
    iswarbounduntilequip  = "isWUE",
    isbindonequip         = "isBOE",
    isaccountbound        = "isBOA",
    isbindonuse           = "isBOU",
}

-- ============================================================================
-- SECTION 7: KEYWORD_MAP
-- ============================================================================
-- Every #keyword maps to a function(props) -> bool.
-- Keywords are the terse search-bar syntax; flags (above) are the verbose
-- Vendor-rule syntax. Both resolve against the same props table.

local KEYWORD_MAP = {}

local function RegisterKeyword(name, func)
    KEYWORD_MAP[strlower(name)] = func
end

-- ---- 7.1  Quality keywords ----
for _, def in ipairs({
    {"poor",IQ.Poor},{"junk",IQ.Poor},{"grey",IQ.Poor},{"gray",IQ.Poor},{"trash",IQ.Poor},
    {"common",IQ.Common},{"white",IQ.Common},
    {"uncommon",IQ.Uncommon},{"green",IQ.Uncommon},
    {"rare",IQ.Rare},{"blue",IQ.Rare},
    {"epic",IQ.Epic},{"purple",IQ.Epic},
    {"legendary",IQ.Legendary},{"orange",IQ.Legendary},
    {"artifact",IQ.Artifact},
    {"heirloom",IQ.Heirloom},
}) do
    local q = def[2]
    RegisterKeyword(def[1], function(p) return p.quality == q end)
end

-- ---- 7.2  Bind keywords ----
RegisterKeyword("soulbound",          function(p) return p.isSoulbound end)
RegisterKeyword("bound",              function(p) return p.isSoulbound end)
RegisterKeyword("bop",                function(p) return p.isSoulbound end)
RegisterKeyword("boe",                function(p) return p.isBOE end)
RegisterKeyword("bindonequip",        function(p) return p.isBOE end)
RegisterKeyword("boa",                function(p) return p.isBOA end)
RegisterKeyword("accountbound",       function(p) return p.isBOA end)
RegisterKeyword("warbound",           function(p) return p.isBOA end)
RegisterKeyword("bou",                function(p) return p.isBOU end)
RegisterKeyword("bindonuse",          function(p) return p.isBOU end)
RegisterKeyword("wue",                function(p) return p.isWUE end)
RegisterKeyword("warbounduntilequip", function(p) return p.isWUE end)

-- ---- 7.3  Item class keywords ----
-- Same order as found in Enum.ItemClass
RegisterKeyword("consumable",       function(p) return p.classID == Enum.ItemClass.Consumable end)
RegisterKeyword("container",        function(p) return p.classID == Enum.ItemClass.Container end)
RegisterKeyword("bag",              function(p) return p.classID == Enum.ItemClass.Container end)
RegisterKeyword("weapon",           function(p) return p.classID == Enum.ItemClass.Weapon end)
RegisterKeyword("gem",              function(p) return p.classID == Enum.ItemClass.Gem end)
RegisterKeyword("armor",            function(p) return p.classID == Enum.ItemClass.Armor end)
RegisterKeyword("reagent",          function(p) return p.classID == Enum.ItemClass.Reagent end)
RegisterKeyword("projectile",       function(p) return p.classID == Enum.ItemClass.Projectile end)
RegisterKeyword("tradegoods",       function(p) return p.classID == Enum.ItemClass.Tradegoods end)
RegisterKeyword("tradegood",        function(p) return p.classID == Enum.ItemClass.Tradegoods end)
RegisterKeyword("itemenhancement",  function(p) return p.classID == Enum.ItemClass.ItemEnhancement end)
RegisterKeyword("enhancement",      function(p) return p.classID == Enum.ItemClass.ItemEnhancement end)
RegisterKeyword("recipe",           function(p) return p.classID == Enum.ItemClass.Recipe end)
-- CurrencyTokenObsolete (skipped)
RegisterKeyword("quiver",           function(p) return p.classID == Enum.ItemClass.Quiver end)

-- Quest items: classID OR C_Container quest info (populated in BuildProps)
RegisterKeyword("quest",     function(p) return p.isQuestItem end)
RegisterKeyword("questitem", function(p) return p.isQuestItem end)

RegisterKeyword("key",              function(p) return p.classID == Enum.ItemClass.Key end)
-- PermanentObsolete (skipped)
RegisterKeyword("miscellaneous",    function(p) return p.classID == Enum.ItemClass.Miscellaneous end)
RegisterKeyword("misc",             function(p) return p.classID == Enum.ItemClass.Miscellaneous end)
RegisterKeyword("glyph",            function(p) return p.classID == Enum.ItemClass.Glyph end)
-- Battlepet is handled in BuildProps
RegisterKeyword("tradeskill",       function(p) return p.classID == Enum.ItemClass.Profession end)
RegisterKeyword("profession",       function(p) return p.classID == Enum.ItemClass.Profession end)
RegisterKeyword("wowtoken",         function(p) return p.classID == Enum.ItemClass.WoWToken end)
RegisterKeyword("housing",          function(p) return p.classID == Enum.ItemClass.Housing end)

-- ---- 7.4  Composite consumable keywords ----
-- #potion includes potions, elixirs, and flasks
RegisterKeyword("potion", function(p)
    if p.classID ~= Enum.ItemClass.Consumable then return false end
    local sub = p.subClassID
    return sub == Enum.ItemConsumableSubclass.Potion
        or sub == Enum.ItemConsumableSubclass.Elixir
        or sub == Enum.ItemConsumableSubclass.Flasksphials
end)
RegisterKeyword("food", function(p)
    return p.classID == Enum.ItemClass.Consumable
       and p.subClassID == Enum.ItemConsumableSubclass.Fooddrink
end)
RegisterKeyword("drink", function(p)
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

-- ---- 7.5  Equipment keywords ----
RegisterKeyword("gear",         function(p) return p.isEquipment end)
RegisterKeyword("equipment",    function(p) return p.isEquipment end)
RegisterKeyword("equippable",   function(p) return p.isEquipment end)
RegisterKeyword("set",          function(p) return p.isInEquipmentSet end)
RegisterKeyword("equipmentset", function(p) return p.isInEquipmentSet end)
RegisterKeyword("cosmetic",     function(p)
    return p.classID == Enum.ItemClass.Armor
       and p.subClassID == Enum.ItemArmorSubclass.Cosmetic
end)

-- ---- 7.6  Armor subclass keywords ----
for _, def in ipairs({
    {"cloth",   Enum.ItemArmorSubclass.Cloth},
    {"leather", Enum.ItemArmorSubclass.Leather},
    {"mail",    Enum.ItemArmorSubclass.Mail},
    {"plate",   Enum.ItemArmorSubclass.Plate},
    {"shield",  Enum.ItemArmorSubclass.Shield},
    {"libram",  Enum.ItemArmorSubclass.Libram},
    {"idol",    Enum.ItemArmorSubclass.Idol},
    {"totem",   Enum.ItemArmorSubclass.Totem},
    {"sigil",   Enum.ItemArmorSubclass.Sigil},
    {"relic",   Enum.ItemArmorSubclass.Relic},
}) do
    local sub = def[2]
    RegisterKeyword(def[1], function(p)
        return p.classID == Enum.ItemClass.Armor and p.subClassID == sub
    end)
end

-- ---- 7.7  Slot keywords ----
-- Map keyword -> equip location string(s).
-- "chest" matches both INVTYPE_CHEST and INVTYPE_ROBE.
local SLOT_MAP = {
    head     = "INVTYPE_HEAD",    helm     = "INVTYPE_HEAD",    helmet   = "INVTYPE_HEAD",
    neck     = "INVTYPE_NECK",    necklace = "INVTYPE_NECK",    amulet   = "INVTYPE_NECK",
    shoulder = "INVTYPE_SHOULDER", shoulders = "INVTYPE_SHOULDER",
    waist    = "INVTYPE_WAIST",   belt     = "INVTYPE_WAIST",
    legs     = "INVTYPE_LEGS",    pants    = "INVTYPE_LEGS",
    feet     = "INVTYPE_FEET",    boots    = "INVTYPE_FEET",
    wrist    = "INVTYPE_WRIST",   bracers  = "INVTYPE_WRIST",  bracer = "INVTYPE_WRIST",
    hands    = "INVTYPE_HAND",    gloves   = "INVTYPE_HAND",
    finger   = "INVTYPE_FINGER",  ring     = "INVTYPE_FINGER",
    trinket  = "INVTYPE_TRINKET",
    back     = "INVTYPE_CLOAK",   cloak    = "INVTYPE_CLOAK",  cape = "INVTYPE_CLOAK",
    mainhand = "INVTYPE_WEAPONMAINHAND",
    shield   = "INVTYPE_SHIELD",
    tabard   = "INVTYPE_TABARD",
    shirt    = "INVTYPE_BODY",
}

for name, loc in pairs(SLOT_MAP) do
    local capturedLoc = loc
    RegisterKeyword(name, function(p) return p.equipLoc == capturedLoc end)
end

-- Special multi-location slot keywords
RegisterKeyword("chest", function(p)
    return p.equipLoc == "INVTYPE_CHEST" or p.equipLoc == "INVTYPE_ROBE"
end)
RegisterKeyword("robe", function(p) return p.equipLoc == "INVTYPE_ROBE" end)
RegisterKeyword("offhand", function(p)
    return p.equipLoc == "INVTYPE_WEAPONOFFHAND" or p.equipLoc == "INVTYPE_HOLDABLE"
end)
RegisterKeyword("holdable", function(p) return p.equipLoc == "INVTYPE_HOLDABLE" end)
RegisterKeyword("ranged", function(p)
    return p.equipLoc == "INVTYPE_RANGED" or p.equipLoc == "INVTYPE_RANGEDRIGHT"
end)
RegisterKeyword("wand", function(p) return p.equipLoc == "INVTYPE_RANGEDRIGHT" end)

-- ---- 7.8  Expansion keywords ----
-- Built from ConfigEnum expansion map so aliases (tww, df, sl, etc.) all work.
for name, id in pairs(EXPANSION_IDS_MAP) do
    local capturedID = id
    RegisterKeyword(name, function(p) return p.expansionID == capturedID end)
end

-- ---- 7.9  Collectible keywords ----
RegisterKeyword("toy",         function(p) return p.isToy end)
RegisterKeyword("mount",       function(p) return p.isMount end)
RegisterKeyword("pet",         function(p) return p.isPet end)
RegisterKeyword("battlepet",   function(p) return p.isPet end)
RegisterKeyword("collected",   function(p) return p.isCollected end)
RegisterKeyword("uncollected", function(p) return not p.isCollected end)
RegisterKeyword("alreadyknown", function(p) return p.isAlreadyKnown end)

-- ---- 7.10  Transmog keywords ----
RegisterKeyword("transmog",        function(p) return p.hasAppearance end)
RegisterKeyword("knowntransmog",   function(p) return p.isAppearanceCollected end)
RegisterKeyword("unknowntransmog", function(p) return p.isUnknownAppearance end)

-- ---- 7.11  State keywords ----
RegisterKeyword("usable",   function(p) return p.isUsable end)
RegisterKeyword("use",      function(p) return p.isUsable end)
RegisterKeyword("unusable",  function(p) return not p.isUsable end)
RegisterKeyword("locked",   function(p) return p.isLocked end)
RegisterKeyword("charges",  function(p) return p.hasCharges end)
RegisterKeyword("unique",   function(p) return p.isUnique end)
RegisterKeyword("socket",   function(p) return p.hasSocket end)
RegisterKeyword("equipped",  function(p) return p.isEquipped end)

-- ---- 7.12  Vendor / value keywords ----
RegisterKeyword("unsellable", function(p) return p.isUnsellable end)
RegisterKeyword("sellable",   function(p) return not p.isUnsellable end)

-- ---- 7.13  Crafting keywords ----
RegisterKeyword("craftingreagent",     function(p) return p.isCraftingReagent end)
RegisterKeyword("crafted",             function(p) return (p.craftedQuality or 0) > 0 end)
RegisterKeyword("professionequipment", function(p) return p.isProfessionEquipment end)

-- ---- 7.14  Upgrade keywords ----
RegisterKeyword("upgradeable",   function(p) return p.isUpgradeable end)
RegisterKeyword("fullyupgraded", function(p) return p.isFullyUpgraded end)

-- ---- 7.15  Tooltip-text keywords ----
-- These trigger the lazy tooltip scan on first access to tooltipText.
RegisterKeyword("reputation", function(p)
    local tt = p.tooltipText
    return tt and strfind(tt, "Reputation") ~= nil
end)
RegisterKeyword("tradeableloot", function(p) return p.isTradeableLoot end)
RegisterKeyword("openable", function(p)
    local tt = p.tooltipText
    return tt and (strfind(tt, "Right Click to Open") ~= nil)
end)

-- ---- 7.16  Special keywords ----
RegisterKeyword("hearthstone", function(p) return p._isHearthstone end)
RegisterKeyword("keystone",    function(p) return p._isKeystone end)
RegisterKeyword("tierset",     function(p) return p.isTierSet end)

-- ============================================================================
-- SECTION 8: LAYER 1 — UTILITY FUNCTIONS
-- ============================================================================

-- ---------- GetTooltipText ----------
-- Returns the concatenated left-text of all tooltip lines for a bag slot.
-- Cached per bagID:slotID; wiped on BAG_UPDATE_DELAYED.
local function GetTooltipText(bagID, slotID)
    if not bagID or not slotID then return "" end
    local key = bagID .. ":" .. slotID
    if tooltipCache[key] then return tooltipCache[key] end

    local tooltipData = C_TooltipInfo.GetBagItem(bagID, slotID)
    if not tooltipData then
        tooltipCache[key] = ""
        return ""
    end

    TooltipUtil.SurfaceArgs(tooltipData)
    local parts = {}
    for _, line in ipairs(tooltipData.lines) do
        TooltipUtil.SurfaceArgs(line)
        parts[#parts + 1] = line.leftText or ""
    end
    local text = tconcat(parts, "\n")
    tooltipCache[key] = text
    return text
end

-- ---------- ResolveCollected ----------
-- Checks toy/mount/pet collection status for a specific item.
local function ResolveCollected(itemID, classID, subClassID, hyperlink)
    -- Toy check
    local toyInfo = C_ToyBox.GetToyInfo(itemID)
    if toyInfo then
        return PlayerHasToy(itemID)
    end
    -- Battle pet check
    if itemID == BATTLE_PET_CAGE_ID and hyperlink then
        local petID = hyperlink:match("battlepet:(%d+)")
        if petID then
            local speciesID = tonumber(petID)
            if speciesID then
                local num = C_PetJournal.GetNumCollectedInfo(speciesID)
                return num and num > 0
            end
        end
    end
    -- Mount check
    if classID == Enum.ItemClass.Miscellaneous and subClassID == Enum.ItemMiscellaneousSubclass.Mount then
        local mountIDs = C_MountJournal.GetMountIDs()
        if mountIDs then
            for _, mountID in ipairs(mountIDs) do
                local _, _, _, _, _, _, _, _, _, _, isCollected, _, itemIDMount = C_MountJournal.GetMountInfoByID(mountID)
                if itemIDMount == itemID and isCollected then return true end
            end
        end
    end
    return false
end

-- ---------- ResolveTooltipFields ----------
-- Lazily populates the tooltip-derived fields on first access.
-- Called by the propsMT.__index metatable handler.
-- Only the fields that genuinely require tooltip scanning live here;
-- bind, crafting reagent, and socket detection all use API calls instead.
local function ResolveTooltipFields(props)
    local bagID, slotID = rawget(props, "_bagID"), rawget(props, "_slotID")
    if not bagID or not slotID then
        rawset(props, "hasCharges", false)
        rawset(props, "hasUseAbility", false)
        rawset(props, "isAlreadyKnown", false)
        rawset(props, "isTradeableLoot", false)
        rawset(props, "tooltipText", "")
        return
    end

    local tt = GetTooltipText(bagID, slotID)
    rawset(props, "tooltipText", tt)
    rawset(props, "hasCharges",      tt:match(chargesPattern) ~= nil)
    rawset(props, "hasUseAbility",   strfind(tt, "^Use:") ~= nil or strfind(tt, "\nUse:") ~= nil)
    rawset(props, "isAlreadyKnown",  strfind(tt, ITEM_SPELL_KNOWN or "Already Known") ~= nil)
    rawset(props, "isTradeableLoot", strfind(tt, "You may trade this item") ~= nil)
end

-- ---------- ResolveBind_Tooltip ----------
-- Tooltip-based bind fallback, called ONLY when the API couldn't determine
-- bind status (containerInfo.isBound was nil or bindType was nil).
-- Implements strict soulbound: account-bound text does NOT match isSoulbound.
local function ResolveBind_Tooltip(props)
    local bagID, slotID = rawget(props, "_bagID"), rawget(props, "_slotID")
    if not bagID or not slotID then
        rawset(props, "isSoulbound", false)
        rawset(props, "isBOE", false)
        rawset(props, "isBOA", false)
        rawset(props, "isBOU", false)
        rawset(props, "isWUE", false)
        return
    end

    local tt = GetTooltipText(bagID, slotID)

    local isAccountBoundText = (strfind(tt, ITEM_ACCOUNTBOUND or "Account Bound") ~= nil)
                            or (strfind(tt, ITEM_BNETACCOUNTBOUND or "Blizzard Account Bound") ~= nil)

    -- Strict soulbound: "Soulbound" in tooltip AND not account-bound text
    local isSoulboundText = strfind(tt, ITEM_SOULBOUND) ~= nil
    rawset(props, "isSoulbound", isSoulboundText and not isAccountBoundText)

    rawset(props, "isBOE", strfind(tt, ITEM_BIND_ON_EQUIP) ~= nil)
    rawset(props, "isBOA", isAccountBoundText)
    rawset(props, "isBOU", strfind(tt, ITEM_BIND_ON_USE) ~= nil)
    rawset(props, "isWUE", strfind(tt, "Warbound until equipped") ~= nil)
end

-- ============================================================================
-- SECTION 9: LAYER 1 — BUILDPROPS
-- ============================================================================

-- Fields that are resolved lazily via __index (tooltip scan on first access)
local TOOLTIP_FIELDS_SET = {
    hasCharges     = true,
    hasUseAbility  = true,
    isAlreadyKnown = true,
    isTradeableLoot = true,
    tooltipText    = true,
}

-- Bind fields that might need tooltip fallback if API returned nil
local BIND_FIELDS_SET = {
    isSoulbound = true,
    isBOE       = true,
    isBOA       = true,
    isBOU       = true,
    isWUE       = true,
}

-- Metatable applied to every props table for lazy field resolution.
-- Stays permanently; uses _tooltipResolved and _bindResolved flags to
-- avoid redundant scans (rather than stripping the metatable).
local propsMT = {
    __index = function(self, key)
        -- Tooltip-derived fields: scan once, populate all on first access
        if TOOLTIP_FIELDS_SET[key] then
            if not rawget(self, "_tooltipResolved") then
                ResolveTooltipFields(self)
                rawset(self, "_tooltipResolved", true)
            end
            return rawget(self, key)
        end
        -- Bind fields: tooltip fallback only when API didn't populate them
        if BIND_FIELDS_SET[key] then
            if not rawget(self, "_bindResolved") then
                ResolveBind_Tooltip(self)
                rawset(self, "_bindResolved", true)
            end
            return rawget(self, key)
        end
        return nil
    end
}

-- ---------- BuildProps ----------
-- Core Layer 1 function. Enriches a bag slot into a flat property table.
-- Cached by "bagID:slotID". Returns the same table on subsequent calls
-- until the cache is invalidated (BAG_UPDATE_DELAYED, etc.).
function PE:BuildProps(itemID, bagID, slotID, itemInfo)
    if not itemID then return {} end

    local cacheKey = bagID and slotID and (bagID .. ":" .. slotID) or tostring(itemID)
    if propsCache[cacheKey] then return propsCache[cacheKey] end

    itemInfo = itemInfo or {}
    local hyperlink = itemInfo.hyperlink

    local props = {
        id        = itemID,
        _bagID    = bagID,
        _slotID   = slotID,
        hyperlink = hyperlink,
    }

    -- ---- C_Item.GetItemInfo: 18 return values ----
    local itemName, _, itemQuality, itemLevel, itemMinLevel,
          _, _, itemStackCount, itemEquipLoc, _,
          sellPrice, classID, subclassID, bindType, expansionID,
          setID, apiCraftingReagent

    if hyperlink then
        itemName, _, itemQuality, itemLevel, itemMinLevel,
            _, _, itemStackCount, itemEquipLoc, _,
            sellPrice, classID, subclassID, bindType, expansionID,
            setID, apiCraftingReagent = C_Item.GetItemInfo(hyperlink)
    end

    -- Synchronous fallback for uncached items
    if not classID then
        -- Always returns immediately for valid itemID, even when full item data hasn't been downloaded yet
        _, _, _, itemEquipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    end

    props.nameRaw     = itemName or (C_Item.GetItemNameByID(itemID) or "")
    props.name        = strlower(props.nameRaw)
    props.quality     = itemQuality or itemInfo.quality or 0
    props.ilvl        = itemLevel or 0
    props.reqLevel    = itemMinLevel or 0
    props.equipLoc    = itemEquipLoc or ""
    props.vendorPrice = sellPrice or 0
    props.classID     = classID
    props.subClassID  = subclassID
    props.expansionID = expansionID
    props.bindType    = bindType
    props.maxStack    = itemStackCount or 1
    props.setID       = setID
    props.isTierSet   = setID ~= nil
    props.isCraftingReagent = apiCraftingReagent == true

    -- ---- C_Container.GetContainerItemInfo ----
    local containerInfo
    if bagID and slotID then
        containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
    end
    props.count    = containerInfo and containerInfo.stackCount or itemInfo.count or 1
    props.isLocked = containerInfo and containerInfo.isLocked or false

    -- ---- Computed value ----
    props.totalValue = props.vendorPrice * props.count

    -- ---- Battle pet cage override ----
    if itemID == BATTLE_PET_CAGE_ID then
        props.classID = Enum.ItemClass.Battlepet
    end

    -- ---- Hybrid bind detection (strict soulbound) ----
    -- API-based primary path: uses containerInfo.isBound + bindType.
    -- If either is nil, bind fields are left unset and the __index metatable
    -- triggers ResolveBind_Tooltip on first access.
    local IB = Enum.ItemBind
    if containerInfo and containerInfo.isBound ~= nil and bindType ~= nil then
        local isAccountBindType = (bindType == IB.ToWoWAccount
                                or bindType == IB.ToBnetAccount
                                or bindType == IB.ToBnetAccountUntilEquipped)
        props.isSoulbound = containerInfo.isBound == true and not isAccountBindType
        props.isBOE       = bindType == IB.OnEquip and not containerInfo.isBound
        props.isBOA       = isAccountBindType
        props.isBOU       = bindType == IB.OnUse and not containerInfo.isBound
        props.isWUE       = bindType == IB.ToBnetAccountUntilEquipped
        props._bindResolved = true
    end
    -- else: bind fields are nil, __index will call ResolveBind_Tooltip

    -- ---- Equipment ----
    props.isEquipment = C_Item.IsEquippableItem(itemID) == true

    -- ---- Equipment set (API-based, no cache needed) ----
    props.isInEquipmentSet = false
    if bagID and slotID then
        local inSet = C_Container.GetContainerItemEquipmentSetInfo(bagID, slotID)
        props.isInEquipmentSet = inSet == true
    end

    -- ---- Usability ----
    props.isUsable = (C_Item.IsUsableItem(itemID) == true)

    -- ---- Unique ----
    props.isUnique = C_Item.GetItemUniquenessByID(itemID) == true

    -- ---- Socket detection (API-based, no tooltip needed) ----
    local socketCount = hyperlink and C_Item.GetItemNumSockets(hyperlink) or 0
    props.hasSocket = socketCount > 0
    props.sockets   = socketCount

    -- ---- Unsellable (fully API-based) ----
    props.isUnsellable = (props.vendorPrice == 0) or (containerInfo and containerInfo.hasNoValue == true)

    -- ---- Collection status (toy / mount / pet) ----
    props.isToy = C_ToyBox.GetToyInfo(itemID) ~= nil
    
    props.isPet = (itemID == BATTLE_PET_CAGE_ID)
               or (props.classID == Enum.ItemClass.Battlepet)
               or (props.classID == Enum.ItemClass.Miscellaneous and props.subClassID == Enum.ItemMiscellaneousSubclass.CompanionPet)

    props.isMount = (props.classID == Enum.ItemClass.Miscellaneous and props.subClassID == Enum.ItemMiscellaneousSubclass.Mount)
    props.isCosmetic = (props.classID == Enum.ItemClass.Armor and props.subClassID == Enum.ItemArmorSubclass.Cosmetic)
    props.isCollected = ResolveCollected(itemID, props.classID, props.subClassID, hyperlink)

    -- ---- Quest item (classID + C_Container quest info) ----
    props.isQuestItem = (classID == Enum.ItemClass.Questitem)
    if not props.isQuestItem and bagID and slotID then
        local qInfo = C_Container.GetContainerItemQuestInfo(bagID, slotID)
        if qInfo and (qInfo.isQuestItem or qInfo.isActive) then
            props.isQuestItem = true
        end
    end

    -- ---- Junk (quality + OneWoW hook) ----
    props.isJunk = (props.quality == IQ.Poor)
    if not props.isJunk and _G.OneWoW and _G.OneWoW.ItemStatus then
        props.isJunk = _G.OneWoW.ItemStatus:IsItemJunk(itemID) or false
    end

    -- ---- Upgrade (OneWoW hook) ----
    props.isUpgrade = false
    if _G.OneWoW and _G.OneWoW.UpgradeDetection and hyperlink then
        local UD = _G.OneWoW.UpgradeDetection
        if UD.IsUpgrade then
            props.isUpgrade = UD:IsUpgrade(bagID, slotID, itemID, hyperlink) or false
        end
    end

    -- ---- Special items ----
    props._isHearthstone = HS_IDS[itemID] or false
    if not props._isHearthstone and props.isToy then
        local hsName = C_Item.GetItemNameByID(itemID)
        if hsName and strfind(strlower(hsName), "hearthstone") then
            props._isHearthstone = true
        end
    end

    props._isKeystone = C_Item.IsItemKeystoneByID(itemID) == true

    -- ---- Crafted quality ----
    props.craftedQuality = hyperlink and C_TradeSkillUI.GetItemCraftedQualityByItemInfo(hyperlink) or 0

    -- ---- Upgrade track info ----
    props.upgradeLevel    = 0
    props.upgradeMax      = 0
    props.maxLevel        = props.ilvl
    props.isUpgradeable   = false
    props.isFullyUpgraded = false

    local upgradeInfo = C_Item.GetItemUpgradeInfo(itemID)
    if upgradeInfo then
        props.upgradeLevel    = upgradeInfo.currentLevel or 0
        props.upgradeMax      = upgradeInfo.maxLevel or 0
        props.maxLevel        = upgradeInfo.maxItemLevel or props.ilvl
        props.isUpgradeable   = (props.upgradeMax > 0)
        props.isFullyUpgraded = (props.upgradeLevel >= props.upgradeMax and props.upgradeMax > 0)
    end

    -- ---- Transmog / appearance ----
    props.hasAppearance         = false
    props.isAppearanceCollected = false
    props.isUnknownAppearance  = false

    if hyperlink then
        local _, sourceID = C_TransmogCollection.GetItemInfo(hyperlink)
        if sourceID then
            props.hasAppearance = true
            local collected = C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID)
            props.isAppearanceCollected = collected == true
            props.isUnknownAppearance   = not collected
        end
    end

    -- ---- Profession equipment ----
    props.isProfessionEquipment = false
    if props.classID == Enum.ItemClass.Profession and props.isEquipment then
        props.isProfessionEquipment = true
    end

    -- ---- Equipped status ----
    props.isEquipped = C_Item.IsEquippedItem(itemID) == true

    -- ---- Equippable (by this character) ----
    props.isEquippable = C_Item.IsEquippableItem(itemID) == true

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

local function Tokenize(searchStr)
    local tokens = {}
    local i = 1
    local len = #searchStr

    while i <= len do
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

        -- ---- Standalone ~: not a valid operator on its own. Skip it. ----
        -- ~ is only meaningful as part of a prop_compare (name~sword).
        -- A lone ~ (e.g. from a user who thinks ~ is NOT) is consumed harmlessly.
        elseif c == "~" then
            i = i + 1

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
        elseif c == ">" or c == "<" then
            local j = i + 1
            if j <= len and searchStr:sub(j, j) == "=" then j = j + 1 end
            local numStart = j
            while j <= len and searchStr:sub(j, j):match("%d") do j = j + 1 end
            local opStr = searchStr:sub(i, numStart - 1)
            local num = tonumber(searchStr:sub(numStart, j - 1))
            if num then
                tinsert(tokens, {
                    type = "prop_compare", prop = "ilvl",
                    op = opStr, value = num,
                })
            end
            i = j

        -- ---- Bare number: could be ilvl exact match or ilvl range ----
        -- 623 becomes ilvl==623; 200-300 becomes ilvl:200-300
        elseif c:match("%d") then
            local j = i
            while j <= len and searchStr:sub(j, j):match("%d") do j = j + 1 end
            if j <= len and searchStr:sub(j, j) == "-" then
                local k = j + 1
                while k <= len and searchStr:sub(k, k):match("%d") do k = k + 1 end
                local low  = tonumber(searchStr:sub(i, j - 1))
                local high = tonumber(searchStr:sub(j + 1, k - 1))
                if low and high then
                    tinsert(tokens, {
                        type = "prop_range", prop = "ilvl",
                        low = low, high = high,
                    })
                end
                i = k
            else
                local num = tonumber(searchStr:sub(i, j - 1))
                if num then
                    tinsert(tokens, {
                        type = "prop_compare", prop = "ilvl",
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
                    local opStart = i
                    local opEnd = i
                    -- Check for two-char operators: >= <= != ==
                    if i + 1 <= len then
                        local twoChar = searchStr:sub(i, i + 1)
                        if twoChar == ">=" or twoChar == "<="
                        or twoChar == "!=" or twoChar == "==" then
                            opEnd = i + 1
                        end
                    end
                    local opStr = searchStr:sub(opStart, opEnd)
                    i = opEnd + 1

                    -- Consume the value (everything until next break char)
                    local valStart = i
                    while i <= len do
                        local ch = searchStr:sub(i, i)
                        if OP_CHARS[ch] or ch == " " or ch == "\t"
                        or ch == "#" or ch == "~" or ch == ":" then break end
                        if ch == ">" or ch == "<" or ch == "=" then break end
                        i = i + 1
                    end
                    local valStr = searchStr:sub(valStart, i - 1)

                    local reg = PROP_REGISTRY[wordLower]
                    local val
                    if reg.type == "number" then
                        val = tonumber(valStr)
                    else
                        val = strlower(valStr)
                    end

                    if val ~= nil then
                        tinsert(tokens, {
                            type = "prop_compare",
                            prop = wordLower,
                            op   = opStr,
                            value = val,
                        })
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
                    local low, high = rangeStr:match("^(%d+)-(%d+)$")
                    if low and high then
                        tinsert(tokens, {
                            type = "prop_range",
                            prop = wordLower,
                            low  = tonumber(low),
                            high = tonumber(high),
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

    -- #keyword -> lookup in KEYWORD_MAP
    if token.type == "keyword" then
        local fn = KEYWORD_MAP[token.value]
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

        if reg.type == "number" then
            return function(props)
                local actual = props[field] or 0
                if     op == ">=" then return actual >= val
                elseif op == "<=" then return actual <= val
                elseif op == ">"  then return actual >  val
                elseif op == "<"  then return actual <  val
                elseif op == "!=" then return actual ~= val
                else   return actual == val end
            end, pos + 1
        else
            -- String comparison: = / == for exact, != for not-equal, ~ for contains
            return function(props)
                local actual = strlower(props[field] or "")
                if op == "=" or op == "==" then
                    return actual == val
                elseif op == "!=" then
                    return actual ~= val
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

--- Transforms an enum table into a lookup table with custom aliases and synonyms.
--- `config` table uses lowercase keys matching the sourceEnum: [synonyms..., keepOriginalBool].
--- last element in each config array acts as a boolean toggle to include the original key in the returned table
--- Returns a new table with mapped synonyms and/or original keys pointing to the enum values.
function PE:ConfigEnum(sourceEnum, config, autoRegisterMissing)
    return ConfigEnum(sourceEnum, config, autoRegisterMissing)
end

--- Compile an expression string into a predicate function.
--- Returns the compiled function(props)->bool, cached for repeated use.
--- Returns nil, errorMessage on failure or empty input.
function PE:Compile(expr)
    if not expr or expr == "" then return nil end

    if compiledCache[expr] then
        return compiledCache[expr]
    end

    local singleKeyword = strmatch(expr, "^%s*#([%w_]+)%s*$")
    if singleKeyword then
        local fn = KEYWORD_MAP[strlower(singleKeyword)]
        if fn then
            compiledCache[expr] = fn
            return fn
        end
    end

    local negatedKeyword = strmatch(expr, "^%s*!%s*#([%w_]+)%s*$")
    if negatedKeyword then
        local fn = KEYWORD_MAP[strlower(negatedKeyword)]
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
--- Returns result (bool), errorMessage (nil on success).
function PE:SafeEvaluate(compiled, props)
    local ok, result = pcall(compiled, props)
    if not ok then
        return false, tostring(result)
    end
    return result, nil
end

--- High-level: compile + evaluate in one call. Builds props if needed.
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

--- Register a custom keyword (for third-party / suite extensions).
--- Wipes the compiled cache since available keywords changed.
function PE:RegisterKeyword(name, func)
    KEYWORD_MAP[strlower(name)] = func
    wipe(compiledCache)
end

--- Register a custom numeric/string property for comparison syntax.
--- def = { field = "fieldName", type = "number"|"string" }
function PE:RegisterProperty(name, def)
    PROP_REGISTRY[strlower(name)] = { field = def.field, type = def.type or "number" }
    wipe(compiledCache)
end

--- Invalidate all caches (compiled expressions + props + tooltip).
function PE:InvalidateCache()
    wipe(compiledCache)
    wipe(propsCache)
    wipe(tooltipCache)
end

--- Invalidate only props and tooltip caches (lighter, for frequent events).
--- Compiled expressions are still valid since the grammar didn't change.
function PE:InvalidatePropsCache()
    wipe(propsCache)
    wipe(tooltipCache)
end

--- Expose raw tooltip text for consumers that still need it
--- (e.g. Categories:GetSubCategory for charges display).
function PE:GetTooltipText(bagID, slotID)
    return GetTooltipText(bagID, slotID)
end

--- Backward compat: get expansion ID for an item.
function PE:GetExpansionID(itemID, hyperlink)
    local expacID = nil

    if hyperlink then
        _, _, _, _, _, _, _, _, _, _, _, _, _, _, expacID = C_Item.GetItemInfo(hyperlink)
        if expacID ~= nil then
            return expacID
        end
    end

    if itemID then
        _, _, _, _, _, _, _, _, _, _, _, _, _, _, expacID = C_Item.GetItemInfo(itemID)
        if expacID ~= nil then
            return expacID
        end
    end

    return nil
end

--- Backward compat: get localized expansion name from ID.
function PE:GetExpansionName(expID)
    if not expID then return nil end
    return _G["EXPANSION_NAME" .. expID]
end

PE.BATTLE_PET_CAGE_ID = BATTLE_PET_CAGE_ID
