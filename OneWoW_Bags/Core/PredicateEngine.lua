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
-- ============================================================================

local _, OneWoW_Bags = ...

OneWoW_Bags.PredicateEngine = {}
local PE = OneWoW_Bags.PredicateEngine

local tconcat, tinsert, wipe = table.concat, tinsert, wipe
local ipairs, pairs, tonumber, tostring = ipairs, pairs, tonumber, tostring
local strlower, strfind = string.lower, string.find
local strmatch = string.match
local rawset, rawget, setmetatable = rawset, rawget, setmetatable
local pcall, select = pcall, select
local Enum = Enum
local C_Item = C_Item
local C_Container = C_Container
local C_NewItems = C_NewItems
local C_TooltipInfo = C_TooltipInfo
local C_ToyBox, PlayerHasToy = C_ToyBox, PlayerHasToy
local C_MountJournal, C_PetJournal = C_MountJournal, C_PetJournal
local C_TransmogCollection = C_TransmogCollection
local C_TradeSkillUI = C_TradeSkillUI
local C_PlayerInfo = C_PlayerInfo
local GetSpecialization, GetSpecializationInfo = GetSpecialization, GetSpecializationInfo
local BattlePetToolTip_UnpackBattlePetLink = BattlePetToolTip_UnpackBattlePetLink

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

-- icons shared by knowledge items (Use: Study to increase your ... knowledge by #)
local KNOWLEDGE_ICONS = {[236225]=true, [136175]=true}

-- information about the item source: Enum.ItemCreationContext
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

-- Locale-aware patterns built from Blizzard globals.
local chargesPattern = ITEM_SPELL_CHARGES:match("|4(.-):.-%;")
local tradeablePattern = BIND_TRADE_TIME_REMAINING:match("^(.-)%%s")
local uniqueEquipPattern = ITEM_UNIQUE_EQUIPPABLE:gsub("%-", "%%-")

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

local function RegisterPropAlias(nameOrNames, field, propType)
    local entry = { field = field, type = propType or "number" }
    if type(nameOrNames) == "table" then
        for _, name in ipairs(nameOrNames) do
            PROP_REGISTRY[strlower(name)] = entry
        end
    else
        PROP_REGISTRY[strlower(nameOrNames)] = entry
    end
end

-- Numeric properties
RegisterPropAlias({"ilvl", "itemlevel", "level"},           "ilvl")
RegisterPropAlias({"id", "itemid"},                         "id")
RegisterPropAlias({"count", "stacks"},                      "count")
RegisterPropAlias({"vendorprice", "price", "unitvalue"},    "vendorPrice")
RegisterPropAlias({"maxstack", "stacksize"},                "maxStack")
RegisterPropAlias({"reqlevel", "minlevel"},                 "reqLevel")
RegisterPropAlias({"expansion", "expac"},                   "expansionID")
RegisterPropAlias({"class", "typeid"},                      "classID")
RegisterPropAlias({"subclass", "subtypeid"},                "subClassID")
RegisterPropAlias("pettype",                                "petType")
RegisterPropAlias("petquality",                             "petQuality")
RegisterPropAlias("petlevel",                               "petLevel")
RegisterPropAlias("petmaxhealth",                           "petMaxHealth")
RegisterPropAlias("petpower",                               "petPower")
RegisterPropAlias("petspeed",                               "petSpeed")

RegisterPropAlias("quality",        "quality")
RegisterPropAlias("bindtype",       "bindType")
RegisterPropAlias("currentbind",    "currentbind")
RegisterPropAlias("totalvalue",     "totalValue")
RegisterPropAlias("craftedquality", "craftedQuality")
RegisterPropAlias("upgradelevel",   "upgradeLevel")
RegisterPropAlias("upgrademax",     "upgradeMax")
RegisterPropAlias("maxlevel",       "maxLevel")
RegisterPropAlias("setid",          "setID")
RegisterPropAlias("sockets",        "sockets")
RegisterPropAlias("armor",          "statArmor")

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
    isupgrade               = "isUpgrade",
    istoy                   = "isToy",
    ismount                 = "isMount",
    ispet                   = "isPet",
    iscosmetic              = "isCosmetic",
    islocked                = "isLocked",
    isunsellable            = "isUnsellable",
    hascharges              = "hasCharges",
    isunique                = "isUnique",
    isuniqueequipped        = "isUniqueEquipped",
    isquestitem             = "isQuestItem",
    istierset               = "isTierSet",
    isappearancecollected   = "isAppearanceCollected",
    isunknownappearance     = "isUnknownAppearance",
    hasappearance           = "hasAppearance",
    isupgradeable           = "isUpgradeable",
    isfullyupgraded         = "isFullyUpgraded",
    isprofessionequipment   = "isProfessionEquipment",
    isequipped              = "isEquipped",
    isequippable            = "isEquipment",
    iscraftingreagent       = "isCraftingReagent",
    hassocket               = "hasSocket",
    isknowledge             = "isKnowledge",
    isrefundable            = "isRefundable",
    isenchanted             = "isEnchanted",

    -- Tooltip-derived flags (lazy)
    hasuseability           = "hasUseAbility",
    hasEquipAbility         = "hasEquipAbility",
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

local function RegisterKeyword(nameOrNames, func)
    if type(nameOrNames) == "table" then
        for _, name in ipairs(nameOrNames) do
            KEYWORD_MAP[strlower(name)] = func
        end
    else
        KEYWORD_MAP[strlower(nameOrNames)] = func
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
RegisterKeyword("consumable",                           function(p) return p.classID == Enum.ItemClass.Consumable end)
RegisterKeyword({"container", "bag"},                   function(p) return p.classID == Enum.ItemClass.Container end)
RegisterKeyword("weapon",                               function(p) return p.classID == Enum.ItemClass.Weapon end)
RegisterKeyword("gem",                                  function(p) return p.classID == Enum.ItemClass.Gem end)
RegisterKeyword("armor",                                function(p) return p.classID == Enum.ItemClass.Armor end)
RegisterKeyword("reagent",                              function(p) return p.classID == Enum.ItemClass.Reagent end)
RegisterKeyword("projectile",                           function(p) return p.classID == Enum.ItemClass.Projectile end)
RegisterKeyword({"tradegoods", "tradegood"},            function(p) return p.classID == Enum.ItemClass.Tradegoods end)
RegisterKeyword({"itemenhancement", "enhancement"},     function(p) return p.classID == Enum.ItemClass.ItemEnhancement end)
RegisterKeyword("recipe",                               function(p) return p.classID == Enum.ItemClass.Recipe end)
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
RegisterKeyword({"gear", "equipment", "equippable"}, function(p) return p.isEquipment end)
RegisterKeyword({"set", "equipmentset"},             function(p) return p.isInEquipmentSet end)
RegisterKeyword("cosmetic", function(p)
    return p.classID == Enum.ItemClass.Armor and p.subClassID == Enum.ItemArmorSubclass.Cosmetic
end)

RegisterKeyword("myclass",  function(p) return p.isEquipment and C_PlayerInfo.CanUseItem(p.id) end)
RegisterKeyword("myspec",   function(p)
    if not p.isEquipment then return false end
    if not C_PlayerInfo.CanUseItem(p.id) then return false end
    local hyperlink = p.hyperlink
    if not hyperlink then return false end
    local specs = C_Item.GetItemSpecInfo(hyperlink)
    if not specs or #specs == 0 then return true end  -- universal gear
    local currentSpec = GetSpecializationInfo(GetSpecialization())
    for _, specID in ipairs(specs) do
        if specID == currentSpec then return true end
    end
    return false
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
}) do
    local sub = def[2]
    RegisterKeyword(def[1], function(p)
        return p.classID == Enum.ItemClass.Recipe and p.subClassID == sub
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
RegisterKeyword("chest",    function(p) return p.equipLoc == "INVTYPE_CHEST" or p.equipLoc == "INVTYPE_ROBE" end)
RegisterKeyword("robe",     function(p) return p.equipLoc == "INVTYPE_ROBE" end)
RegisterKeyword("offhand",  function(p) return p.equipLoc == "INVTYPE_WEAPONOFFHAND" or p.equipLoc == "INVTYPE_HOLDABLE" end)
RegisterKeyword("holdable", function(p) return p.equipLoc == "INVTYPE_HOLDABLE" end)
RegisterKeyword("ranged",   function(p) return p.equipLoc == "INVTYPE_RANGED" or p.equipLoc == "INVTYPE_RANGEDRIGHT" end)
RegisterKeyword("wand",     function(p) return p.equipLoc == "INVTYPE_RANGEDRIGHT" end)

-- ---- 7.15  Expansion keywords ----
for _, def in ipairs({
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
RegisterKeyword("toy",                  function(p) return p.isToy end)
RegisterKeyword("mount",                function(p) return p.isMount end)
RegisterKeyword({"pet", "battlepet"},   function(p) return p.isPet end)
RegisterKeyword("collected",            function(p) return p.isCollected end)
RegisterKeyword("uncollected",          function(p) return not p.isCollected end)
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

-- ---- 7.17  Transmog keywords ----
RegisterKeyword("transmog",        function(p) return p.hasAppearance end)
RegisterKeyword("knowntransmog",   function(p) return p.isAppearanceCollected end)
RegisterKeyword("unknowntransmog", function(p) return p.isUnknownAppearance end)

-- ---- 7.18  State keywords ----
RegisterKeyword({"usable", "use"},  function(p) return p.isUsable end)
RegisterKeyword("unusable",         function(p) return not p.isUsable end)
RegisterKeyword("locked",           function(p) return p.isLocked end)
RegisterKeyword("new",              function(p) return p.isNew end)
RegisterKeyword("socket",           function(p) return p.hasSocket end)
RegisterKeyword("equipped",         function(p) return p.isEquipped end)
RegisterKeyword("knowledge",        function(p) return p.isKnowledge end)
RegisterKeyword("refundable",       function(p) return p.isRefundable end)
RegisterKeyword("enchanted",        function(p) return p.isEnchanted end)

-- ---- 7.19  Vendor / value keywords ----
RegisterKeyword("unsellable", function(p) return p.isUnsellable end)
RegisterKeyword("sellable",   function(p) return not p.isUnsellable end)

-- ---- 7.20  Crafting keywords ----
RegisterKeyword("craftingreagent",     function(p) return p.isCraftingReagent end)
RegisterKeyword("crafted",             function(p) return p.isCrafted end)
RegisterKeyword("professionequipment", function(p) return p.isProfessionEquipment end)

-- ---- 7.21  Upgrade keywords ----
RegisterKeyword("upgrade",          function(p) return p.isUpgrade end)
RegisterKeyword("upgradeable",      function(p) return p.isUpgradeable end)
RegisterKeyword("fullyupgraded",    function(p) return p.isFullyUpgraded end)

-- ---- 7.22  Tooltip-text keywords ----
-- These trigger the lazy tooltip scan on first access to tooltipText.
RegisterKeyword("charges",          function(p) return p.hasCharges end)
RegisterKeyword("onuse",            function(p) return p.hasUseAbility end)
RegisterKeyword("onequip",          function(p) return p.hasEquipAbility end)
RegisterKeyword("unique",           function(p) return p.isUnique end)
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
RegisterKeyword("hearthstone", function(p) return p._isHearthstone end)
RegisterKeyword("keystone",    function(p) return p._isKeystone end)
RegisterKeyword("tierset",     function(p) return p.isTierSet end)

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

-- ---- 7.25  Item creation context keywords ----
RegisterKeyword("raid", function(p) return p.itemContextCategory == "raid" end)
RegisterKeyword("dungeon", function(p) return p.itemContextCategory == "dungeon" end)
RegisterKeyword("delves", function(p) return p.itemContextCategory == "delves" end)
RegisterKeyword("worldquest", function(p) return p.itemContextCategory == "worldquest" end)
RegisterKeyword("pvp", function(p) return p.itemContextCategory == "pvp" end)
RegisterKeyword("store", function(p) return p.itemContextCategory == "store" end)

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

    local parts = {}
    for _, line in ipairs(tooltipData.lines) do
        parts[#parts + 1] = line.leftText or ""
    end
    local text = tconcat(parts, "\n")
    tooltipCache[key] = text
    return text
end

-- ---------- ResolveCollected ----------
-- Checks toy/mount/pet collection status for a specific item.
local function GetBattlePetCageData(itemID, hyperlink)
    if itemID ~= BATTLE_PET_CAGE_ID or not hyperlink or not BattlePetToolTip_UnpackBattlePetLink then
        return nil
    end

    local speciesID, level, breedQuality, maxHealth, power, speed = BattlePetToolTip_UnpackBattlePetLink(hyperlink)
    if not speciesID then
        return nil
    end

    local petName, _, petType = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
    return {
        speciesID = speciesID,
        petLevel = level or 0,
        petQuality = breedQuality or 0,
        petMaxHealth = maxHealth or 0,
        petPower = power or 0,
        petSpeed = speed or 0,
        petType = petType or 0,
        petName = petName,
    }
end

local function GetItemIdentityKey(itemID, hyperlink)
    if not itemID then return nil end

    if itemID ~= BATTLE_PET_CAGE_ID then
        return tostring(itemID)
    end

    local petData = GetBattlePetCageData(itemID, hyperlink)
    if not petData then
        return tostring(itemID)
    end

    return tostring(itemID)
        .. ":" .. tostring(petData.speciesID)
        .. ":" .. tostring(petData.petLevel)
        .. ":" .. tostring(petData.petQuality)
        .. ":" .. tostring(petData.petMaxHealth)
        .. ":" .. tostring(petData.petPower)
        .. ":" .. tostring(petData.petSpeed)
end

local function GetItemCacheKey(itemID, bagID, slotID, hyperlink)
    local cacheKey
    if bagID and slotID then
        cacheKey = bagID .. ":" .. slotID
    else
        cacheKey = GetItemIdentityKey(itemID, hyperlink)
    end

    return cacheKey
end

local function ResolveCollected(itemID, classID, subClassID, hyperlink)
    -- Toy check
    local toyInfo = C_ToyBox.GetToyInfo(itemID)
    if toyInfo then
        return PlayerHasToy(itemID)
    end
    -- Caged battle pet check
    local petData = GetBattlePetCageData(itemID, hyperlink)
    if petData and petData.speciesID then
        local num = C_PetJournal.GetNumCollectedInfo(petData.speciesID)
        return num and num > 0
    end
    -- Non-caged pet check
    if classID == Enum.ItemClass.Battlepet or (classID == Enum.ItemClass.Miscellaneous and subClassID == Enum.ItemMiscellaneousSubclass.CompanionPet) then
        local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(itemID))
        local num = C_PetJournal.GetNumCollectedInfo(speciesID)
        return num and num > 0
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
-- Only the fields that genuinely require tooltip scanning live here
local function ResolveTooltipFields(props)
    local bagID, slotID = rawget(props, "_bagID"), rawget(props, "_slotID")
    if not bagID or not slotID then
        rawset(props, "hasCharges", false)
        rawset(props, "hasUseAbility", false)
        rawset(props, "hasEquipAbility", false)
        rawset(props, "isAlreadyKnown", false)
        rawset(props, "isTradeableLoot", false)
        rawset(props, "isUnique", false)
        rawset(props, "isUniqueEquipped", false)
        rawset(props, "tooltipText", "")
        return
    end

    local tt = GetTooltipText(bagID, slotID)

    local isUniqueEquipped = strfind(tt, "^"..uniqueEquipPattern) ~= nil or strfind(tt, "\n"..ITEM_UNIQUE_EQUIPPABLE, 1, true) ~= nil

    rawset(props, "tooltipText",        tt)
    rawset(props, "hasCharges",         strfind(tt, "(%d+) |4" .. chargesPattern) ~= nil)
    rawset(props, "hasUseAbility",      strfind(tt, "^"..USE_COLON) ~= nil or strfind(tt, "\n"..USE_COLON, 1, true) ~= nil)
    rawset(props, "hasEquipAbility",    strfind(tt, "^"..ITEM_SPELL_TRIGGER_ONEQUIP) ~= nil or strfind(tt, "\n"..ITEM_SPELL_TRIGGER_ONEQUIP, 1, true) ~= nil)
    rawset(props, "isAlreadyKnown",     strfind(tt, ITEM_SPELL_KNOWN, 1, true) ~= nil)
    rawset(props, "isTradeableLoot",    strfind(tt, tradeablePattern, 1, true) ~= nil)
    rawset(props, "isUniqueEquipped",   isUniqueEquipped)
    rawset(props, "isUnique",           isUniqueEquipped or strfind(tt, "^"..ITEM_UNIQUE) ~= nil or strfind(tt, "\n"..ITEM_UNIQUE, 1, true) ~= nil)
end

-- ---------- ResolveBind ----------
-- Tooltip-based bind detection. Reflects the current state of binding on an item.
-- Implements strict soulbound: account-bound text does NOT match isSoulbound.
local TDIB = Enum.TooltipDataItemBinding
local BIND_LINE_TYPE = 20

local function ResolveBind(props)
    local bagID, slotID = rawget(props, "_bagID"), rawget(props, "_slotID")
    if not bagID or not slotID then
        rawset(props, "isSoulbound", false)
        rawset(props, "isBOE", false)
        rawset(props, "isBOA", false)
        rawset(props, "isBOU", false)
        rawset(props, "isWUE", false)
        rawset(props, "isWarbound", false)
        return
    end

    local tooltipData = C_TooltipInfo.GetBagItem(bagID, slotID)
    local bonding
    if tooltipData then
        for _, line in ipairs(tooltipData.lines) do
            if line.type == BIND_LINE_TYPE and line.bonding ~= nil then
                bonding = line.bonding
                break
            end
        end
    end

    if bonding == nil then
        rawset(props, "isSoulbound", false)
        rawset(props, "isBOE", false)
        rawset(props, "isBOA", false)
        rawset(props, "isBOU", false)
        rawset(props, "isWUE", false)
        rawset(props, "isWarbound", false)
        return
    end

    local isBOA = bonding == TDIB.Account or bonding == TDIB.BnetAccount or bonding == TDIB.BindToAccount or bonding == TDIB.BindToBnetAccount
    local isWUE = bonding == TDIB.AccountUntilEquipped or bonding == TDIB.BindToAccountUntilEquipped

    rawset(props, "currentbind", bonding)
    rawset(props, "isSoulbound", bonding == TDIB.Soulbound or bonding == TDIB.BindOnPickup)
    rawset(props, "isBOE",       bonding == TDIB.BindOnEquip)
    rawset(props, "isBOA",       isBOA)
    rawset(props, "isBOU",       bonding == TDIB.BindOnUse)
    rawset(props, "isWUE",       isWUE)
    rawset(props, "isWarbound",  isBOA or isWUE)
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

-- ============================================================================
-- SECTION 9: LAYER 1 — BUILDPROPS
-- ============================================================================

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
        return nil
    end
}

-- ---------- BuildProps ----------
-- Core Layer 1 function. Enriches a bag slot into a flat property table.
-- Cached by "bagID:slotID". Returns the same table on subsequent calls
-- until the cache is invalidated (BAG_UPDATE_DELAYED, etc.).
function PE:BuildProps(itemID, bagID, slotID, itemInfo)
    if not itemID then return {} end

    itemInfo = itemInfo or {}
    local hyperlink = itemInfo.hyperlink

    -- tostring(itemID) here is to satisfy Lua linter
    local cacheKey = GetItemCacheKey(itemID, bagID, slotID, itemInfo) or tostring(itemID)
    if propsCache[cacheKey] then return propsCache[cacheKey] end

    local itemLocation
    if bagID and slotID then
        itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    end

    local petData = GetBattlePetCageData(itemID, hyperlink)

    local props = {
        id        = itemID,
        _bagID    = bagID,
        _slotID   = slotID,
        hyperlink = hyperlink,
    }

    -- ---- C_Item.GetItemInfo: 18 return values ----
    local itemName, itemLink, itemQuality, itemLevel, itemMinLevel,
          _, _, itemStackCount, itemEquipLoc, _,
          sellPrice, classID, subclassID, bindType, expansionID,
          setID, apiCraftingReagent

    if hyperlink then
        itemName, itemLink, itemQuality, itemLevel, itemMinLevel,
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
    props.quality     = itemQuality or itemInfo.quality or -1 -- don't use 0 since that == "poor" and causes bad matches
    props.ilvl        = itemLevel or 0
    props.reqLevel    = itemMinLevel or 0
    props.equipLoc    = itemEquipLoc or ""
    props.vendorPrice = sellPrice or 0
    props.classID     = classID
    props.subClassID  = subclassID
    props.expansionID = expansionID
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
    props.isKnowledge = false
    props.isEnchanted = false
    props.isCrafted = false

    -- ---- C_Container.GetContainerItemInfo ----
    local containerInfo
    if bagID and slotID then
        containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
    end
    props.count    = containerInfo and containerInfo.stackCount or itemInfo.count or 1
    props.isLocked = containerInfo and containerInfo.isLocked or false
    props.isNew    = (bagID and slotID and C_NewItems.IsNewItem(bagID, slotID)) == true

    -- ---- Computed value ----
    props.totalValue = props.vendorPrice * props.count

    -- ---- Battle pet cage override ----
    if itemID == BATTLE_PET_CAGE_ID then
        props.classID = Enum.ItemClass.Battlepet
    end

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
        if UD.CheckItemUpgrade then
            if itemLocation and C_Item.DoesItemExist(itemLocation) then
                props.isUpgrade = UD:CheckItemUpgrade(hyperlink, itemLocation) or false
            else
                props.isUpgrade = UD:CheckItemUpgrade(hyperlink) or false
            end
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

    -- ---- Knowledge items ----
    local _, spellName = C_Item.GetItemSpell(hyperlink)
    if spellName then
        local spellinfo = C_Spell.GetSpellInfo(spellName)
        local spellIconID = spellinfo.iconID
        props.isKnowledge = KNOWLEDGE_ICONS[spellIconID] == true
    end

    -- ---- Refundable items ----
    props.isRefundable = C_Item.CanBeRefunded(itemLocation)

    -- ---- Item link parsed properties ----
    local itemLinkProperties = ParseItemLink(itemLink)
    if itemLinkProperties then
        props.isEnchanted = itemLinkProperties.enchantID ~= nil
        props.isCrafted = itemLinkProperties.crafterGUID ~= nil
        props.itemContextCategory = ITEM_CONTEXT_CATEGORY[itemLinkProperties.itemContext]
    end

    -- BIND DETECTION NOTE: API-based bind detection removed as it's not detailed enough. Warbound == Soulbound according to the API.
    -- UNIQUE DETECTION NOTE: C_Item.GetItemUniquenessByID only matches unique-equipped items; its purpose is to identify restrictions on equipping items, not on owning them.

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
                    if reg.type == "number" then
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

function PE:GetBattlePetCageData(itemID, hyperlink)
    return GetBattlePetCageData(itemID, hyperlink)
end

function PE:GetItemCacheKey(itemID, bagID, slotID, hyperlink)
    return GetItemCacheKey(itemID, bagID, slotID, hyperlink)
end

function PE:GetItemIdentityKey(itemID, hyperlink)
    return GetItemIdentityKey(itemID, hyperlink)
end

function PE:ParseItemLink(link)
    return ParseItemLink(link)
end

--- Register custom keyword (for third-party / suite extensions).
--- Wipes the compiled cache since available keywords changed.
function PE:RegisterKeyword(nameOrNames, func)
    if type(nameOrNames) == "table" then
        for _, name in ipairs(nameOrNames) do
            KEYWORD_MAP[strlower(name)] = func
        end
    else
        KEYWORD_MAP[strlower(nameOrNames)] = func
    end
    wipe(compiledCache)
end

--- Register custom numeric/string property for comparison syntax.
--- def = { field = "fieldName", type = "number"|"string" }
function PE:RegisterProperty(nameOrNames, def)
    local entry = { field = def.field, type = def.type or "number" }
    if type(nameOrNames) == "table" then
        for _, name in ipairs(nameOrNames) do
            PROP_REGISTRY[strlower(name)] = entry
        end
    else
        PROP_REGISTRY[strlower(nameOrNames)] = entry
    end
    wipe(compiledCache)
end

--- Invalidate all caches
function PE:InvalidateCache()
    wipe(compiledCache)
    wipe(propsCache)
    wipe(tooltipCache)
end

--- Invalidate props and tooltip caches (lighter, for frequent events).
--- Compiled expressions are still valid since the grammar didn't change.
function PE:InvalidatePropsCache()
    wipe(propsCache)
    wipe(tooltipCache)
end

--- Expose raw tooltip text
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
