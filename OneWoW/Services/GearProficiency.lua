local _, ns = ...

-- ============================================================================
-- GearProficiency
-- ============================================================================
-- Single-purpose core service: does this class's weapon/armor proficiency
-- include this item (plus cloak / holdable slot rules)?
--
-- Not loot-spec eligibility (PE:CanClassEquip / DoesItemContainSpec) and not
-- Blizzard transmog collectability alone (PlayerCanCollectSource). Collection
-- / "yours to farm" UX uses this layer. See Docs/GEAR_PROFICIENCY.md.
--
-- Named flags via FrameXML FlagsUtil (dense suite enum). Class masks are
-- owned here.
-- ============================================================================

local GearProficiency = {}
ns.GearProficiency = GearProficiency

local Flags = FlagsUtil.MakeFlags(
    "Cloak",
    "Holdable",
    "Cloth",
    "Leather",
    "Mail",
    "Plate",
    "Shield",
    "Axe1H",
    "Axe2H",
    "Sword1H",
    "Sword2H",
    "Mace1H",
    "Mace2H",
    "Dagger",
    "Staff",
    "Wand",
    "Bow",
    "Gun",
    "Crossbow",
    "Polearm",
    "Fist",
    "Warglaive"
)
GearProficiency.Flags = Flags

local ARMOR_SUBCLASS_FLAG = {
    [Enum.ItemArmorSubclass.Cloth] = Flags.Cloth,
    [Enum.ItemArmorSubclass.Leather] = Flags.Leather,
    [Enum.ItemArmorSubclass.Mail] = Flags.Mail,
    [Enum.ItemArmorSubclass.Plate] = Flags.Plate,
    [Enum.ItemArmorSubclass.Shield] = Flags.Shield,
}

local WEAPON_SUBCLASS_FLAG = {
    [Enum.ItemWeaponSubclass.Axe1H] = Flags.Axe1H,
    [Enum.ItemWeaponSubclass.Axe2H] = Flags.Axe2H,
    [Enum.ItemWeaponSubclass.Bows] = Flags.Bow,
    [Enum.ItemWeaponSubclass.Guns] = Flags.Gun,
    [Enum.ItemWeaponSubclass.Mace1H] = Flags.Mace1H,
    [Enum.ItemWeaponSubclass.Mace2H] = Flags.Mace2H,
    [Enum.ItemWeaponSubclass.Polearm] = Flags.Polearm,
    [Enum.ItemWeaponSubclass.Sword1H] = Flags.Sword1H,
    [Enum.ItemWeaponSubclass.Sword2H] = Flags.Sword2H,
    [Enum.ItemWeaponSubclass.Warglaive] = Flags.Warglaive,
    [Enum.ItemWeaponSubclass.Staff] = Flags.Staff,
    [Enum.ItemWeaponSubclass.Unarmed] = Flags.Fist,
    [Enum.ItemWeaponSubclass.Dagger] = Flags.Dagger,
    [Enum.ItemWeaponSubclass.Crossbow] = Flags.Crossbow,
    [Enum.ItemWeaponSubclass.Wand] = Flags.Wand,
}

-- Class file token → proficiency mask
local CLASS_MASKS = {
    DEATHKNIGHT = Flags_CreateMask(
        Flags.Holdable, Flags.Cloak, Flags.Plate,
        Flags.Axe1H, Flags.Axe2H, Flags.Mace1H, Flags.Mace2H,
        Flags.Sword1H, Flags.Sword2H, Flags.Polearm
    ),
    DEMONHUNTER = Flags_CreateMask(
        Flags.Holdable, Flags.Cloak, Flags.Leather,
        Flags.Axe1H, Flags.Sword1H, Flags.Fist, Flags.Warglaive
    ),
    DRUID = Flags_CreateMask(
        Flags.Holdable, Flags.Cloak, Flags.Leather,
        Flags.Dagger, Flags.Mace1H, Flags.Mace2H, Flags.Staff, Flags.Polearm, Flags.Fist
    ),
    EVOKER = Flags_CreateMask(
        Flags.Holdable, Flags.Cloak, Flags.Mail,
        Flags.Dagger, Flags.Axe1H, Flags.Axe2H, Flags.Mace1H, Flags.Mace2H,
        Flags.Sword1H, Flags.Sword2H, Flags.Staff, Flags.Fist
    ),
    HUNTER = Flags_CreateMask(
        Flags.Holdable, Flags.Cloak, Flags.Mail,
        Flags.Dagger, Flags.Axe1H, Flags.Axe2H, Flags.Sword1H, Flags.Sword2H,
        Flags.Staff, Flags.Polearm, Flags.Gun, Flags.Bow, Flags.Crossbow, Flags.Fist
    ),
    MAGE = Flags_CreateMask(
        Flags.Holdable, Flags.Cloak, Flags.Cloth,
        Flags.Dagger, Flags.Sword1H, Flags.Wand, Flags.Staff
    ),
    MONK = Flags_CreateMask(
        Flags.Holdable, Flags.Cloak, Flags.Leather,
        Flags.Axe1H, Flags.Mace1H, Flags.Sword1H, Flags.Staff, Flags.Polearm, Flags.Fist
    ),
    PALADIN = Flags_CreateMask(
        Flags.Holdable, Flags.Cloak, Flags.Plate, Flags.Shield,
        Flags.Axe1H, Flags.Axe2H, Flags.Mace1H, Flags.Mace2H,
        Flags.Sword1H, Flags.Sword2H, Flags.Polearm
    ),
    PRIEST = Flags_CreateMask(
        Flags.Holdable, Flags.Cloak, Flags.Cloth,
        Flags.Dagger, Flags.Mace1H, Flags.Wand, Flags.Staff
    ),
    ROGUE = Flags_CreateMask(
        Flags.Holdable, Flags.Cloak, Flags.Leather,
        Flags.Dagger, Flags.Axe1H, Flags.Mace1H, Flags.Sword1H,
        Flags.Gun, Flags.Bow, Flags.Crossbow, Flags.Fist
    ),
    SHAMAN = Flags_CreateMask(
        Flags.Holdable, Flags.Cloak, Flags.Mail, Flags.Shield,
        Flags.Dagger, Flags.Axe1H, Flags.Axe2H, Flags.Mace1H, Flags.Mace2H,
        Flags.Staff, Flags.Fist
    ),
    WARLOCK = Flags_CreateMask(
        Flags.Holdable, Flags.Cloak, Flags.Cloth,
        Flags.Dagger, Flags.Sword1H, Flags.Wand, Flags.Staff
    ),
    WARRIOR = Flags_CreateMask(
        Flags.Holdable, Flags.Cloak, Flags.Plate, Flags.Shield,
        Flags.Dagger, Flags.Axe1H, Flags.Axe2H, Flags.Mace1H, Flags.Mace2H,
        Flags.Sword1H, Flags.Sword2H, Flags.Staff, Flags.Polearm,
        Flags.Gun, Flags.Bow, Flags.Crossbow, Flags.Fist
    ),
}

--- Resolve the proficiency flag for an item, or nil when not armor/weapon/cloak/holdable.
---@param itemID number
---@return number|nil flag
function GearProficiency.GetItemFlag(itemID)
    itemID = tonumber(itemID)
    if not itemID then return nil end

    local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
    if not classID then return nil end

    if equipLoc == "INVTYPE_CLOAK" then
        return Flags.Cloak
    end
    if equipLoc == "INVTYPE_HOLDABLE" then
        return Flags.Holdable
    end
    if classID == Enum.ItemClass.Armor then
        return ARMOR_SUBCLASS_FLAG[subClassID]
    end
    if classID == Enum.ItemClass.Weapon then
        return WEAPON_SUBCLASS_FLAG[subClassID]
    end
    return nil
end

--- Flag value → name (debug / tooltips).
---@param flag number
---@return string|nil
function GearProficiency.GetFlagName(flag)
    if not flag then return nil end
    for name, value in pairs(Flags) do
        if value == flag then
            return name
        end
    end
    return nil
end

---@param classToken string|nil UnitClass second return; nil = current player
---@return number|nil mask
local function GetClassMask(classToken)
    if not classToken then
        _, classToken = UnitClass("player")
    end
    return classToken and CLASS_MASKS[classToken] or nil
end

--- Whether the class's proficiency includes this item.
--- Unknown / non-gear items return true (callers should not drop unrelated IDs).
---@param itemID number
---@param classToken string|nil
---@return boolean
function GearProficiency.ClassAllowsItem(itemID, classToken)
    local flag = GearProficiency.GetItemFlag(itemID)
    if not flag then
        return true
    end
    local mask = GetClassMask(classToken)
    if not mask then
        return true
    end
    return FlagsUtil.IsSet(mask, flag)
end
