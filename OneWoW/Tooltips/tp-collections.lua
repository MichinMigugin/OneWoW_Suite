local ADDON_NAME, OneWoW = ...

local BATTLE_PET_CAGE_ID = 82800

local function NormalizeCageItemClass(itemID, classID, subclassID)
    if itemID == BATTLE_PET_CAGE_ID then
        return Enum.ItemClass.Battlepet, subclassID or 0
    end
    return classID, subclassID
end

local ITEM_TYPE_COLORS = {
    [0]  = {0.47, 0.94, 0.47},
    [1]  = {0.80, 0.70, 0.50},
    [2]  = {0.47, 1.00, 1.00},
    [3]  = {1.00, 0.50, 1.00},
    [4]  = {0.47, 1.00, 1.00},
    [5]  = {0.60, 0.80, 0.60},
    [7]  = {0.32, 0.73, 0.91},
    [8]  = {0.80, 0.60, 1.00},
    [9]  = {1.00, 0.80, 0.40},
    [12] = {0.80, 0.80, 0.40},
    [15] = {0.70, 0.70, 0.70},
    [16] = {0.60, 0.80, 1.00},
    [17] = {0.40, 0.80, 0.40},
    [18] = {1.00, 0.82, 0.00},
    [19] = {0.32, 0.73, 0.91},
}

OneWoW.ITEM_TYPE_COLORS = ITEM_TYPE_COLORS

local COLLECTED_STRING = COLLECTED or "Collected"
local NOT_COLLECTED_STRING = NOT_COLLECTED or "Not Collected"
local APPEARANCE_UNKNOWN_STRING = TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN or "You haven't collected this appearance"

local function CheckCollectionStatus(itemID, itemLink, classID, subclassID)
    if not itemID or not itemLink then return nil end

    classID, subclassID = NormalizeCageItemClass(itemID, classID, subclassID)
    if not classID then return nil end

    local isMisc = (classID == Enum.ItemClass.Miscellaneous)

    if classID == Enum.ItemClass.Recipe then
        local td = C_TooltipInfo.GetHyperlink(itemLink)
        if td and td.lines then
            for _, line in ipairs(td.lines) do
                if line.leftText and line.leftText == ITEM_SPELL_KNOWN then
                    return true
                end
            end
        end
        return false
    end

    if classID == Enum.ItemClass.Battlepet or itemID == BATTLE_PET_CAGE_ID then
        local speciesID = tonumber(itemLink:match("|Hbattlepet:(%d+):"))
        if speciesID then
            local numCollected = C_PetJournal.GetNumCollectedInfo(speciesID)
            return numCollected ~= nil and numCollected > 0
        end
        return false
    end

    if isMisc and subclassID == Enum.ItemMiscellaneousSubclass.Mount then
        local td = C_TooltipInfo.GetHyperlink(itemLink)
        if td and td.lines then
            for _, line in ipairs(td.lines) do
                if line.leftText and line.leftText == ITEM_SPELL_KNOWN then
                    return true
                end
            end
        end
        return false
    end

    if isMisc and subclassID == Enum.ItemMiscellaneousSubclass.CompanionPet then
        local td = C_TooltipInfo.GetHyperlink(itemLink)
        if td and td.lines then
            for _, line in ipairs(td.lines) do
                if line.leftText and line.leftText:find(COLLECTED_STRING, 1, true) then
                    return true
                end
            end
        end
        return false
    end

    if C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(itemID) then
        return PlayerHasToy(itemID) == true
    end

    if classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor then
        local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
        if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_TRINKET"
            or equipLoc == "INVTYPE_FINGER" or equipLoc == "INVTYPE_NECK" then
            return nil
        end
        if C_TransmogCollection then
            local sourceID = select(2, C_TransmogCollection.GetItemInfo(itemLink))
            if not sourceID then return nil end
            if C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID) then
                return true
            end
            local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID)
            if sourceInfo then
                if sourceInfo.isCollected then return true end
                if sourceInfo.visualID then
                    local allSources = C_TransmogCollection.GetAllAppearanceSources(sourceInfo.visualID)
                    if allSources then
                        for _, otherID in ipairs(allSources) do
                            if otherID ~= sourceID then
                                if C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(otherID) then
                                    local otherInfo = C_TransmogCollection.GetSourceInfo(otherID)
                                    if otherInfo and otherInfo.isCollected and otherInfo.categoryID == sourceInfo.categoryID then
                                        return true
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return false
        end
    end

    local td = C_TooltipInfo.GetHyperlink(itemLink)
    if td and td.lines then
        for _, line in ipairs(td.lines) do
            if line.leftText then
                if line.leftText == ITEM_SPELL_KNOWN then
                    return true
                end
                if line.leftText:find(APPEARANCE_UNKNOWN_STRING, 1, true) or line.leftText:find(NOT_COLLECTED_STRING, 1, true) then
                    return false
                end
            end
        end
    end

    return nil
end

local function CollectionsProvider(tooltip, context)
    if not context.itemID then return nil end

    local classID, subclassID, typeString, typeColor

    local _, itemType, itemSubType
    _, itemType, itemSubType, _, _, classID, subclassID = C_Item.GetItemInfoInstant(context.itemID)
    if not itemType then return nil end
    typeString = itemType
    if itemSubType and itemSubType ~= "" and itemSubType ~= itemType then
        typeString = itemType .. " | " .. itemSubType
    end
    typeColor = ITEM_TYPE_COLORS[classID] or {0.9, 0.9, 0.9}

    local status = CheckCollectionStatus(context.itemID, context.itemLink, classID, subclassID)

    if status == nil then
        return {
            {type = "headerRight", text = typeString, r = typeColor[1], g = typeColor[2], b = typeColor[3]}
        }
    elseif status == true then
        local L = OneWoW.L
        local text = "|cFF66CC66" .. L["TIPS_COLLECTIONS_COLLECTED"] .. "|r | " .. typeString
        return {
            {type = "headerRight", text = text, r = typeColor[1], g = typeColor[2], b = typeColor[3]}
        }
    else
        local L = OneWoW.L
        local text = "|cFFCC6666" .. L["TIPS_COLLECTIONS_NOT_COLLECTED"] .. "|r | " .. typeString
        return {
            {type = "headerRight", text = text, r = typeColor[1], g = typeColor[2], b = typeColor[3]}
        }
    end
end

OneWoW.TooltipEngine:RegisterProvider({
    id = "collections",
    order = 9,
    featureId = "collections",
    tooltipTypes = {"item"},
    callback = CollectionsProvider,
})
