-- ============================================================================
-- Icon Browser catalog
-- ============================================================================
-- Thin wrapper over LibRPMedia-1.2 (Unlicense, Meorawr). Filter labels use
-- Blizzard globals / C_* display names where they exist; remaining phrases
-- are module locale keys.
-- ============================================================================

local _, ns = ...
local M, L = ns.ModuleRegistry:Current()
if not M then return end

local LibStub = LibStub
local LRPM12 = LibStub:GetLibrary("LibRPMedia-1.2")

local C_CreatureInfo = C_CreatureInfo
local C_Item = C_Item
local C_TradeSkillUI = C_TradeSkillUI
local format = string.format
local gsub = string.gsub
local lower = string.lower
local tostring = tostring
local tinsert = tinsert

local Catalog = {}
M.Catalog = Catalog

local QUESTION_MARK = 134400

local CLASS_ORDER = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK",
    "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}

local CLASS_CATEGORY = {
    DEATHKNIGHT = "DeathKnight",
    DEMONHUNTER = "DemonHunter",
    DRUID       = "Druid",
    EVOKER      = "Evoker",
    HUNTER      = "Hunter",
    MAGE        = "Mage",
    MONK        = "Monk",
    PALADIN     = "Paladin",
    PRIEST      = "Priest",
    ROGUE       = "Rogue",
    SHAMAN      = "Shaman",
    WARLOCK     = "Warlock",
    WARRIOR     = "Warrior",
}

local SKILL_LINE = {
    Alchemy        = 171,
    Archaeology    = 794,
    Blacksmithing  = 164,
    Cooking        = 185,
    Enchanting     = 333,
    Engineering    = 202,
    FirstAid       = 129,
    Fishing        = 356,
    Herbalism      = 182,
    Inscription    = 773,
    Jewelcrafting  = 755,
    Leatherworking = 165,
    Mining         = 186,
    Skinning       = 393,
    Tailoring      = 197,
}

--- @return table lib LibRPMedia-1.2
function Catalog.GetLibrary()
    return LRPM12
end

--- @return number
function Catalog.GetNumIcons()
    return LRPM12:GetNumIcons()
end

--- @param index number
--- @return table|nil
function Catalog.GetIconInfo(index)
    return LRPM12:GetIconInfoByIndex(index)
end

--- @return function
function Catalog.EnumerateIcons()
    return LRPM12:EnumerateIcons({ reuseTable = {} })
end

--- @param categories number[]
--- @return function|nil
function Catalog.CategoryPredicate(categories)
    if not categories or #categories == 0 then
        return nil
    end
    return LRPM12:GenerateIconCategoryPredicate(categories)
end

--- @param name string
--- @return number|nil
function Catalog.Category(name)
    return LRPM12.IconCategory[name]
end

--- @param texture Texture
--- @param info table
function Catalog.ApplyToTexture(texture, info)
    if info.type == LRPM12.IconType.Atlas and info.name then
        texture:SetAtlas(info.name)
    else
        texture:SetTexture(info.file or QUESTION_MARK)
    end
end

--- @param text string|nil
--- @return string
function Catalog.NormalizeQuery(text)
    text = lower(text or "")
    return (gsub(text, "[%s_%-]", ""))
end

--- @param info table
--- @param query string already normalized
--- @return boolean
function Catalog.NameMatches(info, query)
    if query == "" then
        return true
    end
    local name = Catalog.NormalizeQuery(info.name)
    local fileStr = info.file and tostring(info.file) or ""
    return (name ~= "" and name:find(query, 1, true) ~= nil)
        or (fileStr ~= "" and fileStr:find(query, 1, true) ~= nil)
end

local function RaceName(raceID)
    local info = C_CreatureInfo.GetRaceInfo(raceID)
    return info and info.raceName or nil
end

local function ProfessionName(skillLineID)
    local name = C_TradeSkillUI.GetTradeSkillDisplayName(skillLineID)
    if name and name ~= "" then
        return name
    end
    return nil
end

local function ArmorName(subclass, fallback)
    local name = C_Item.GetItemSubClassInfo(Enum.ItemClass.Armor, subclass)
    if name and name ~= "" then
        return name
    end
    return fallback
end

local function AppendIf(list, category, label)
    if category and label then
        tinsert(list, { category = category, label = label })
    end
end

local function ClassLabel(classFile)
    local names = LOCALIZED_CLASS_NAMES_MALE
    local name = names and names[classFile] or classFile
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = colors and colors[classFile]
    if color and color.WrapTextInColorCode then
        return color:WrapTextInColorCode(name)
    end
    return name
end

--- Builds the filter menu spec. Labels are resolved at call time.
--- @return table
function Catalog.GetFilterSpec()
    local Cat = LRPM12.IconCategory

    local classes = {}
    for i = 1, #CLASS_ORDER do
        local file = CLASS_ORDER[i]
        local key = CLASS_CATEGORY[file]
        tinsert(classes, { category = Cat[key], label = ClassLabel(file) })
    end

    local cultures = {
        { category = Cat.Dracthyr, label = RaceName(52) or L["ICONBROWSER_DRACTHYR"] },
        { category = Cat.Draenei,  label = RaceName(11) or L["ICONBROWSER_DRAENEI"] },
        { category = Cat.Dwarven,  label = L["ICONBROWSER_DWARVEN"] },
        { category = Cat.Elven,    label = L["ICONBROWSER_ELVEN"] },
        { category = Cat.Gnomish,  label = L["ICONBROWSER_GNOMISH"] },
        { category = Cat.Goblin,   label = RaceName(9) or L["ICONBROWSER_GOBLIN"] },
        { category = Cat.Haranir,  label = L["ICONBROWSER_HARANIR"] },
        { category = Cat.Human,    label = RaceName(1) or L["ICONBROWSER_HUMAN"] },
        { category = Cat.Orcish,   label = L["ICONBROWSER_ORCISH"] },
        { category = Cat.Pandaren, label = RaceName(24) or L["ICONBROWSER_PANDAREN"] },
        { category = Cat.Tauren,   label = RaceName(6) or L["ICONBROWSER_TAUREN"] },
        { category = Cat.Troll,    label = RaceName(8) or L["ICONBROWSER_TROLL"] },
        { category = Cat.Undead,   label = RaceName(5) or L["ICONBROWSER_UNDEAD"] },
        { category = Cat.Vulpera,  label = RaceName(35) or L["ICONBROWSER_VULPERA"] },
        { category = Cat.Worgen,   label = RaceName(22) or L["ICONBROWSER_WORGEN"] },
    }

    local melee = {
        { category = Cat.WeaponTypeAxe,       label = L["ICONBROWSER_AXE"] },
        { category = Cat.WeaponTypeDagger,    label = L["ICONBROWSER_DAGGER"] },
        { category = Cat.WeaponTypeFists,     label = L["ICONBROWSER_FIST"] },
        { category = Cat.WeaponTypeMace,      label = L["ICONBROWSER_MACE"] },
        { category = Cat.WeaponTypePolearm,   label = L["ICONBROWSER_POLEARM"] },
        { category = Cat.WeaponTypeStaff,     label = L["ICONBROWSER_STAFF"] },
        { category = Cat.WeaponTypeSword,     label = L["ICONBROWSER_SWORD"] },
        { category = Cat.WeaponTypeWand,      label = L["ICONBROWSER_WAND"] },
        { category = Cat.WeaponTypeWarglaive, label = L["ICONBROWSER_WARGLAIVE"] },
    }

    local ranged = {
        { category = Cat.WeaponTypeAmmo,     label = INVTYPE_AMMO },
        { category = Cat.WeaponTypeBow,      label = L["ICONBROWSER_BOW"] },
        { category = Cat.WeaponTypeCrossbow, label = L["ICONBROWSER_CROSSBOW"] },
        { category = Cat.WeaponTypeGun,      label = L["ICONBROWSER_GUN"] },
        { category = Cat.WeaponTypeThrown,   label = L["ICONBROWSER_THROWN"] },
    }

    local armorTypes = {
        { category = Cat.ClothArmor,   label = ArmorName(Enum.ItemArmorSubclass.Cloth, L["ICONBROWSER_CLOTH"]) },
        { category = Cat.LeatherArmor, label = ArmorName(Enum.ItemArmorSubclass.Leather, L["ICONBROWSER_LEATHER"]) },
        { category = Cat.MailArmor,    label = ArmorName(Enum.ItemArmorSubclass.Mail, L["ICONBROWSER_MAIL_ARMOR"]) },
        { category = Cat.PlateArmor,   label = ArmorName(Enum.ItemArmorSubclass.Plate, L["ICONBROWSER_PLATE"]) },
        { category = Cat.Jewelry,      label = L["ICONBROWSER_JEWELRY"] },
    }

    local slots = {
        { category = Cat.InventorySlotHead,      label = INVTYPE_HEAD },
        { category = Cat.InventorySlotNeck,      label = INVTYPE_NECK },
        { category = Cat.InventorySlotShoulders, label = INVTYPE_SHOULDER },
        { category = Cat.InventorySlotBack,      label = INVTYPE_CLOAK },
        { category = Cat.InventorySlotChest,     label = INVTYPE_CHEST },
        { category = Cat.InventorySlotShirt,     label = INVTYPE_BODY },
        { category = Cat.InventorySlotTabard,    label = INVTYPE_TABARD },
        { category = Cat.InventorySlotWrists,    label = INVTYPE_WRIST },
        { category = Cat.InventorySlotHands,     label = INVTYPE_HAND },
        { category = Cat.InventorySlotWaist,     label = INVTYPE_WAIST },
        { category = Cat.InventorySlotLegs,      label = INVTYPE_LEGS },
        { category = Cat.InventorySlotFeet,      label = INVTYPE_FEET },
        { category = Cat.InventorySlotRing,      label = INVTYPE_FINGER },
        { category = Cat.InventorySlotTrinket,   label = INVTYPE_TRINKET },
        { category = Cat.InventorySlotOffHand,   label = INVTYPE_HOLDABLE },
        { category = Cat.InventorySlotShield,    label = INVTYPE_SHIELD },
    }

    local magic = {
        { category = Cat.ArcaneMagic, label = STRING_SCHOOL_ARCANE },
        { category = Cat.FelMagic,    label = RELIC_SLOT_TYPE_FEL },
        { category = Cat.FireMagic,   label = STRING_SCHOOL_FIRE },
        { category = Cat.FrostMagic,  label = STRING_SCHOOL_FROST },
        { category = Cat.HolyMagic,   label = STRING_SCHOOL_HOLY },
        { category = Cat.NatureMagic, label = STRING_SCHOOL_NATURE },
        { category = Cat.ShadowMagic, label = STRING_SCHOOL_SHADOW },
        { category = Cat.VoidMagic,   label = L["ICONBROWSER_VOID"] },
    }

    local factions = {
        { category = Cat.Alliance,      label = FACTION_ALLIANCE },
        { category = Cat.Horde,         label = FACTION_HORDE },
        { category = Cat.OtherFactions, label = OTHER },
    }

    local professions = {}
    AppendIf(professions, Cat.Alchemy, ProfessionName(SKILL_LINE.Alchemy))
    AppendIf(professions, Cat.Archaeology, ProfessionName(SKILL_LINE.Archaeology) or L["ICONBROWSER_ARCHAEOLOGY"])
    AppendIf(professions, Cat.Blacksmithing, ProfessionName(SKILL_LINE.Blacksmithing))
    AppendIf(professions, Cat.Cooking, ProfessionName(SKILL_LINE.Cooking))
    AppendIf(professions, Cat.Enchanting, ProfessionName(SKILL_LINE.Enchanting))
    AppendIf(professions, Cat.Engineering, ProfessionName(SKILL_LINE.Engineering))
    AppendIf(professions, Cat.FirstAid, ProfessionName(SKILL_LINE.FirstAid) or L["ICONBROWSER_FIRST_AID"])
    AppendIf(professions, Cat.Fishing, ProfessionName(SKILL_LINE.Fishing))
    AppendIf(professions, Cat.Herbalism, ProfessionName(SKILL_LINE.Herbalism))
    AppendIf(professions, Cat.Inscription, ProfessionName(SKILL_LINE.Inscription) or INSCRIPTION)
    AppendIf(professions, Cat.Jewelcrafting, ProfessionName(SKILL_LINE.Jewelcrafting))
    AppendIf(professions, Cat.Leatherworking, ProfessionName(SKILL_LINE.Leatherworking))
    AppendIf(professions, Cat.Mining, ProfessionName(SKILL_LINE.Mining))
    AppendIf(professions, Cat.Skinning, ProfessionName(SKILL_LINE.Skinning))
    AppendIf(professions, Cat.Tailoring, ProfessionName(SKILL_LINE.Tailoring))

    local items = {
        { category = Cat.Drink,      label = L["ICONBROWSER_DRINK"] },
        { category = Cat.Food,       label = POWER_TYPE_FOOD },
        { category = Cat.Mount,      label = MOUNT },
        { category = Cat.Pet,        label = PET },
        { category = Cat.Potion,     label = L["ICONBROWSER_POTION"] },
        { category = Cat.TradeGoods, label = AUCTION_CATEGORY_TRADE_GOODS },
    }

    return {
        ability     = Cat.Ability,
        achievement = Cat.Achievement,
        housing     = Cat.Housing,
        weaponAll   = Cat.Weapon,
        professionAll = Cat.Professions,
        itemAll     = Cat.Item,
        classes     = classes,
        cultures    = cultures,
        melee       = melee,
        ranged      = ranged,
        armorTypes  = armorTypes,
        slots       = slots,
        magic       = magic,
        factions    = factions,
        professions = professions,
        items       = items,
    }
end

--- Tooltip second line for an icon.
--- @param file number|nil
--- @return string
function Catalog.FormatFileID(file)
    return format(L["ICONBROWSER_FILE_ID"], file or 0)
end
