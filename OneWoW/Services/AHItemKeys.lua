local _, ns = ...

local format = string.format
local tonumber = tonumber
local tinsert = tinsert
local strsplit = strsplit

local C_AuctionHouse = C_AuctionHouse
local C_Item = C_Item

ns.AHItemKeys = ns.AHItemKeys or {}
local IK = ns.AHItemKeys

IK.GEAR_ILVL_THRESHOLD = 168

local EQUIPMENT_CLASS_IDS = {
    [Enum.ItemClass.Weapon] = true,
    [Enum.ItemClass.Armor] = true,
}

local function IsEquipmentItemID(itemID)
    local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
    if not classID then return false end
    return EQUIPMENT_CLASS_IDS[classID] == true
end

local function ParseItemLinkFields(itemLink)
    if type(itemLink) ~= "string" then return nil end
    local linkOptions = itemLink:match("|Hitem:(.+)|h") or itemLink:match("^item:(.+)")
    if not linkOptions then return nil end
    linkOptions = linkOptions:gsub("|h.*$", "")
    local itemID, _, _, _, _, _, suffixID, _, linkLevel = strsplit(":", linkOptions)
    itemID = tonumber(itemID)
    if not itemID then return nil end
    return itemID, tonumber(suffixID) or 0, tonumber(linkLevel) or 0
end

--- Build an ItemKey from a hyperlink. GetItemKeyFromItem only accepts ItemLocation.
local function MakeItemKeyFromLink(itemLink)
    local itemID, suffixID, linkLevel = ParseItemLinkFields(itemLink)
    if not itemID then return nil end

    local ilvl = 0
    if IsEquipmentItemID(itemID) then
        local detailed = C_Item.GetDetailedItemLevelInfo(itemLink)
        if detailed and detailed > 0 then
            ilvl = detailed
        elseif linkLevel > 0 then
            ilvl = linkLevel
        end
    end

    return C_AuctionHouse.MakeItemKey(itemID, ilvl, suffixID, 0)
end

function IK:SerializeItemKey(itemKey)
    if not itemKey or not itemKey.itemID then return nil end
    local ilvl = itemKey.itemLevel or 0
    local suffix = itemKey.itemSuffix or 0
    local species = itemKey.battlePetSpeciesID or 0
    return format("%d:%d:%d:%d", itemKey.itemID, ilvl, suffix, species)
end

function IK:DeserializeStorageKey(storageKey)
    if type(storageKey) ~= "string" then return nil end
    local id, ilvl, suffix, species = storageKey:match("^(%d+):(%d+):(%d+):(%d+)$")
    if not id then return nil end
    return {
        itemID = tonumber(id),
        itemLevel = tonumber(ilvl) or 0,
        itemSuffix = tonumber(suffix) or 0,
        battlePetSpeciesID = tonumber(species) or 0,
    }
end

function IK:KeysFromItemKey(itemKey)
    if not itemKey or not itemKey.itemID then return {} end
    local keys = {}
    local primary = self:SerializeItemKey(itemKey)
    if primary then
        tinsert(keys, primary)
    end
    if itemKey.battlePetSpeciesID and itemKey.battlePetSpeciesID > 0 then
        return keys
    end
    local ilvl = itemKey.itemLevel or 0
    if ilvl >= self.GEAR_ILVL_THRESHOLD and IsEquipmentItemID(itemKey.itemID) then
        local base = format("%d:0:0:0", itemKey.itemID)
        if base ~= primary then
            tinsert(keys, base)
        end
    end
    return keys
end

function IK:KeysFromSpeciesID(speciesID)
    if not speciesID or speciesID <= 0 then return {} end
    local itemKey = C_AuctionHouse.MakeItemKey(82800, 0, 0, speciesID)
    return self:KeysFromItemKey(itemKey)
end

function IK:KeysFromItemLink(itemLink, itemID)
    if not itemLink then
        if itemID then
            return self:KeysFromItemKey(C_AuctionHouse.MakeItemKey(itemID))
        end
        return {}
    end

    if itemLink:find("|Hbattlepet:", 1, true) then
        local speciesID = tonumber(itemLink:match("|Hbattlepet:(%d+):"))
        if speciesID and speciesID > 0 then
            return self:KeysFromSpeciesID(speciesID)
        end
        return {}
    end

    local itemKey = MakeItemKeyFromLink(itemLink)
    if itemKey and itemKey.itemID then
        return self:KeysFromItemKey(itemKey)
    end

    local linkItemID = itemID or tonumber(itemLink:match("item:(%d+)"))
    if linkItemID then
        return self:KeysFromItemKey(C_AuctionHouse.MakeItemKey(linkItemID))
    end
    return {}
end

function IK:KeysFromReplicateIndex(index)
    local _, _, _, _, _, _, level, _, _, _, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(index)
    if not itemID or itemID <= 0 then return nil, nil end
    if not C_Item.DoesItemExistByID(itemID) then return nil, nil end

    local levelNum = tonumber(level) or 0

    local link = C_AuctionHouse.GetReplicateItemLink(index)
    if link and link:find("|Hbattlepet:", 1, true) then
        local speciesID = tonumber(link:match("|Hbattlepet:(%d+):"))
        if speciesID and speciesID > 0 then
            local itemKey = C_AuctionHouse.MakeItemKey(itemID, levelNum, 0, speciesID)
            return self:SerializeItemKey(itemKey), itemKey
        end
    end

    if link then
        local itemKey = MakeItemKeyFromLink(link)
        if itemKey and itemKey.itemID then
            if (not itemKey.itemLevel or itemKey.itemLevel == 0) and levelNum > 0 then
                itemKey.itemLevel = levelNum
            end
            return self:SerializeItemKey(itemKey), itemKey
        end
    end

    local itemKey = C_AuctionHouse.MakeItemKey(itemID, levelNum, 0, 0)
    return self:SerializeItemKey(itemKey), itemKey
end

function IK:NeedsItemDataLoad(index)
    local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, itemID, hasAllInfo =
        C_AuctionHouse.GetReplicateItemInfo(index)
    if not itemID or itemID <= 0 then return false end
    return not hasAllInfo
end
