local _, ns = ...

-- ============================================================================
-- Disenchant
-- ============================================================================
-- Owns "can this item be disenchanted?" for Bags PE (#disenchantable / #de)
-- and OneWoW_Mail Shipments. Heuristic mirrors Molinari; curated allow/block
-- lists override false negatives/positives.
--
-- Bind state is intentionally NOT considered here — callers that need mailable
-- DE fodder AND !#soulbound (or scan unbound bag slots only).
-- Knowing Disenchant (13262) is also NOT required — mailing to an enchanter
-- alt must work on non-enchanter characters.
-- ============================================================================

local PE = ns.PredicateEngine

local Disenchant = {}
ns.Disenchant = Disenchant

local allowlist = ns.DisenchantAllowlist
local blocklist = ns.DisenchantBlocklist

--- Resolve a numeric itemID from an itemID, link, or string.
---@param item number|string|nil
---@return number|nil itemID
local function ResolveItemID(item)
    if type(item) == "number" then
        return item
    end
    if type(item) ~= "string" or item == "" then
        return nil
    end
    local id = tonumber(item)
    if id then
        return id
    end
    return tonumber(item:match("item:(%d+)"))
end

--- Whether the item can be disenchanted (bind-agnostic).
---@param item number|string|nil itemID or item link
---@return boolean
function Disenchant:IsDisenchantable(item)
    local itemID = ResolveItemID(item)
    if not itemID then
        return false
    end

    if allowlist[itemID] then
        return true
    end
    if blocklist[itemID] then
        return false
    end

    local _, _, quality, _, _, _, _, _, _, _, _, classID, subClassID = C_Item.GetItemInfo(itemID)
    if not quality then
        return false
    end

    if quality < Enum.ItemQuality.Uncommon or quality > Enum.ItemQuality.Epic then
        return false
    end

    local classOk = classID == Enum.ItemClass.Weapon
        or classID == Enum.ItemClass.Armor
        or classID == Enum.ItemClass.Profession
        or (classID == Enum.ItemClass.Gem and subClassID == Enum.ItemGemSubclass.Artifactrelic)
    if not classOk then
        return false
    end

    if C_Item.GetItemInventoryTypeByID(itemID) == Enum.InventoryType.IndexBodyType then
        return false
    end

    if C_Item.IsCosmeticItem(itemID) then
        return false
    end

    return true
end

-- PE keywords — same registration pattern as UpgradeDetection / #upgrade.
PE:RegisterKeyword({"disenchantable", "de"}, function(p)
    return p.id and Disenchant:IsDisenchantable(p.id)
end)
