local _, ns = ...

local PE = ns.PredicateEngine
local ItemLevel = ns.ItemLevel

local UpgradeDetection = {}
ns.UpgradeDetection = UpgradeDetection

local EQUIPLOC_TO_SLOTS = {
    INVTYPE_HEAD            = {1},
    INVTYPE_NECK            = {2},
    INVTYPE_SHOULDER        = {3},
    INVTYPE_CHEST           = {5},
    INVTYPE_ROBE            = {5},
    INVTYPE_WAIST           = {6},
    INVTYPE_LEGS            = {7},
    INVTYPE_FEET            = {8},
    INVTYPE_WRIST           = {9},
    INVTYPE_HAND            = {10},
    INVTYPE_FINGER          = {11, 12},
    INVTYPE_TRINKET         = {13, 14},
    INVTYPE_CLOAK           = {15},
    INVTYPE_WEAPON          = {16},
    INVTYPE_SHIELD          = {17},
    INVTYPE_2HWEAPON        = {16},
    INVTYPE_WEAPONMAINHAND  = {16},
    INVTYPE_WEAPONOFFHAND   = {17},
    INVTYPE_HOLDABLE        = {17},
    -- Bows / guns / crossbows / wands: no separate ranged slot on Retail;
    -- they occupy main hand (same mapping as Collectibles / Pawn).
    INVTYPE_RANGED          = {16},
    INVTYPE_RANGEDRIGHT     = {16},
}

local SLOT_NAMES = {
    [1]  = "Head",
    [2]  = "Neck",
    [3]  = "Shoulder",
    [5]  = "Chest",
    [6]  = "Waist",
    [7]  = "Legs",
    [8]  = "Feet",
    [9]  = "Wrist",
    [10] = "Hands",
    [11] = "Finger 1",
    [12] = "Finger 2",
    [13] = "Trinket 1",
    [14] = "Trinket 2",
    [15] = "Back",
    [16] = "Main Hand",
    [17] = "Off Hand",
}

local function GetDB()
    return ns.SettingsFeatureRegistry:GetFeatureSettings("overlays", "upgrade")
end

local function GetMode()
    return GetDB().mode or "ILVL"
end

local function HasTwoHanderEquipped()
    local mainHandLink = GetInventoryItemLink("player", 16)
    if not mainHandLink then return false end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(mainHandLink)
    return equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_RANGED"
end

local function AltHasTwoHanderEquipped(equipment)
    local mh = equipment and equipment[16]
    local link = mh and mh.itemLink
    if not link then return false end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
    return equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_RANGED"
end

local function GetCurrentSpecID()
    local specIndex = C_SpecializationInfo.GetSpecialization()
    if not specIndex then return nil end
    return select(1, C_SpecializationInfo.GetSpecializationInfo(specIndex))
end

local function CanPlayerUseItem(itemLink)
    if not itemLink then return false end
    local itemID, _, _, equipLoc = C_Item.GetItemInfoInstant(itemLink)
    if not itemID then return false end
    if not PE:CanClassEquip(itemID, itemLink) then return false end

    local cfg = GetDB()
    if cfg.selfSpecMatch then
        local specID = GetCurrentSpecID()
        if specID then
            local _, _, classID = UnitClass("player")
            if classID and not C_Item.DoesItemContainSpec(itemLink, classID, specID) then
                return false
            end
        end
    end

    if equipLoc == "INVTYPE_SHIELD"
       or equipLoc == "INVTYPE_HOLDABLE"
       or equipLoc == "INVTYPE_WEAPONOFFHAND" then
        if HasTwoHanderEquipped() then return false end
    end
    return true
end

function UpgradeDetection:CheckPawnUpgrade(itemLink)
    if not self.hasPawn or not itemLink then return nil end
    if not PawnShouldItemLinkHaveUpgradeArrow then return nil end
    local enforceReqLevel = GetDB().pawnEnforceReqLevel ~= false
    local ok, result = pcall(PawnShouldItemLinkHaveUpgradeArrow, itemLink, enforceReqLevel)
    if ok then return result end
    return nil
end

function UpgradeDetection:GetBestPawnScore(itemLink)
    if not self.hasPawn or not itemLink then return nil, nil end
    if not PawnGetItemData then return nil, nil end

    local ok, itemData = pcall(PawnGetItemData, itemLink)
    if not ok or not itemData or not itemData.Values then return nil, nil end

    local bestScore = 0
    local bestScaleName = nil

    for _, entry in pairs(itemData.Values) do
        local scaleName = entry[1]
        local value = entry[2]
        if value and value > bestScore then
            bestScore = value
            bestScaleName = scaleName
        end
    end

    if bestScaleName then
        local cleanName = bestScaleName:match('^%("([^"]+)"') or bestScaleName
        return bestScore, cleanName
    end
    return nil, nil
end

function UpgradeDetection:HookPawnTooltips()
    if not PawnAddValuesToTooltip then return end
    if self.pawnTooltipHooked then return end

    local originalFn = PawnAddValuesToTooltip
    PawnAddValuesToTooltip = function(tooltip, itemValues, upgradeInfo, bestItemFor, secondBestItemFor, needsEnhancements, onlyFirstValue)
        local mode = GetMode()
        if mode == "PAWN" or mode == "PAWN>ILVL" then
            return
        end
        return originalFn(tooltip, itemValues, upgradeInfo, bestItemFor, secondBestItemFor, needsEnhancements, onlyFirstValue)
    end

    self.pawnTooltipHooked = true
end

-- Boolean "is this an upgrade?" used by the #upgrade predicate keyword and the
-- "1W Upgrades" bag overlay/category. Delegates to GetItemComparison so the
-- keyword, overlay, and tooltip "Gear Comparison" line all agree on the same
-- answer. In particular this avoids the divergence between Pawn's arrow
-- function (which compares against Pawn's best-known item across bag/bank)
-- and the direct best-score-vs-equipped comparison shown in the tooltip.
function UpgradeDetection:CheckItemUpgrade(itemLink, itemLocation)
    if not itemLink then return false end
    if GetMode() == "OFF" then return false end

    local comparison = self:GetItemComparison(itemLink, itemLocation)
    if not comparison then return false end
    return comparison.isUpgrade == true
end

function UpgradeDetection:CheckItemUpgradeDetailed(itemLink, itemLocation)
    if not itemLink then return nil end

    local mode = GetMode()
    if mode == "OFF" then return nil end

    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(itemLink)
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" then return nil end
    if classID ~= Enum.ItemClass.Armor and classID ~= Enum.ItemClass.Weapon then return nil end

    local usedMode = mode
    local pawnScore, pawnScale, equippedPawnScore

    if mode == "PAWN" or mode == "PAWN>ILVL" then
        local pawnResult = self:CheckPawnUpgrade(itemLink)
        if pawnResult ~= nil then
            if pawnResult == true then
                pawnScore, pawnScale = self:GetBestPawnScore(itemLink)
                usedMode = "PAWN"
            elseif mode == "PAWN" then
                return nil
            end
        end
        if mode == "PAWN" and pawnResult == nil then return nil end
    end

    if not CanPlayerUseItem(itemLink) then return nil end

    local ilvl = ItemLevel.Get(itemLink, itemLocation)
    if not ilvl then return nil end

    local slots = EQUIPLOC_TO_SLOTS[equipLoc]
    if not slots then return nil end

    local bestSlot, bestEquippedIlvl, bestDiff
    for _, slotIndex in ipairs(slots) do
        local equippedLink = GetInventoryItemLink("player", slotIndex)
        if equippedLink then
            local equippedIlvl = ItemLevel.GetFromEquipmentSlot(slotIndex)
            if equippedIlvl then
                local diff = ilvl - equippedIlvl
                if diff > 0 and (not bestDiff or diff > bestDiff) then
                    bestSlot = slotIndex
                    bestEquippedIlvl = equippedIlvl
                    bestDiff = diff

                    if usedMode == "PAWN" and equippedLink then
                        equippedPawnScore = self:GetBestPawnScore(equippedLink)
                    end
                end
            end
        else
            if slotIndex == 17 and HasTwoHanderEquipped() then
                -- skip
            else
                bestSlot = slotIndex
                bestEquippedIlvl = 0
                bestDiff = ilvl
                break
            end
        end
    end

    if not bestSlot then return nil end

    return {
        isUpgrade       = true,
        slot            = bestSlot,
        slotName        = SLOT_NAMES[bestSlot] or "Unknown",
        itemIlvl        = ilvl,
        equippedIlvl    = bestEquippedIlvl,
        diff            = bestDiff,
        mode            = usedMode,
        pawnScore       = pawnScore,
        pawnScale       = pawnScale,
        equippedPawnScore = equippedPawnScore,
    }
end

function UpgradeDetection:GetItemComparison(itemLink, itemLocation)
    if not itemLink then return nil end

    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(itemLink)
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" then return nil end
    if classID ~= Enum.ItemClass.Armor and classID ~= Enum.ItemClass.Weapon then return nil end

    if not CanPlayerUseItem(itemLink) then
        return { unusable = true }
    end

    local ilvl = ItemLevel.Get(itemLink, itemLocation)
    if not ilvl then return nil end

    local slots = EQUIPLOC_TO_SLOTS[equipLoc]
    if not slots then return nil end

    local mode = GetMode()
    local usePawn = self.hasPawn and (mode == "PAWN" or mode == "PAWN>ILVL")
    local pawnScore
    if usePawn then
        pawnScore = self:GetBestPawnScore(itemLink)
    end

    local bestSlot, bestEquippedIlvl, bestDiff, bestEquippedLink
    for _, slotIndex in ipairs(slots) do
        local equippedLink = GetInventoryItemLink("player", slotIndex)
        if equippedLink then
            local equippedIlvl = ItemLevel.GetFromEquipmentSlot(slotIndex)
            if equippedIlvl then
                local diff = ilvl - equippedIlvl
                if not bestDiff or diff > bestDiff then
                    bestSlot = slotIndex
                    bestEquippedIlvl = equippedIlvl
                    bestDiff = diff
                    bestEquippedLink = equippedLink
                end
            end
        else
            if slotIndex == 17 and HasTwoHanderEquipped() then
                -- skip
            else
                bestSlot = slotIndex
                bestEquippedIlvl = 0
                bestDiff = ilvl
                bestEquippedLink = nil
                break
            end
        end
    end

    if not bestSlot then return nil end

    local equippedPawnScore
    if usePawn and pawnScore and bestEquippedLink then
        equippedPawnScore = self:GetBestPawnScore(bestEquippedLink)
    end

    local usedMode = mode
    local thisValue, equipValue, compDiff, isDecimal

    if usePawn and pawnScore and equippedPawnScore and equippedPawnScore > 0 then
        usedMode = "PAWN"
        thisValue = pawnScore
        equipValue = equippedPawnScore
        compDiff = pawnScore - equippedPawnScore
        isDecimal = true
    else
        if mode == "PAWN" and not (pawnScore and equippedPawnScore) then
            usedMode = "PAWN"
        else
            usedMode = "ILVL"
        end
        thisValue = ilvl
        equipValue = bestEquippedIlvl
        compDiff = bestDiff
        isDecimal = false
    end

    return {
        isUpgrade       = compDiff > 0,
        isDowngrade     = compDiff < 0,
        isEqual         = compDiff == 0,
        slot            = bestSlot,
        slotName        = SLOT_NAMES[bestSlot] or "Unknown",
        thisValue       = thisValue,
        equipValue      = equipValue,
        diff            = compDiff,
        isDecimal       = isDecimal,
        itemIlvl        = ilvl,
        equippedIlvl    = bestEquippedIlvl,
        mode            = usedMode,
    }
end

function UpgradeDetection:IsItemUpgradeForAlt(itemID, itemLink, altData)
    if not itemID or not altData or not altData.class then return nil end

    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(itemLink or itemID)
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" then return nil end
    if classID ~= Enum.ItemClass.Armor and classID ~= Enum.ItemClass.Weapon then return nil end

    if not PE:CanClassEquip(itemID, itemLink, altData.class) then return nil end

    local cfg = GetDB()
    if cfg.altSpecMatch and altData.stats and altData.stats.specID then
        local altClassID = PE.ClassID[altData.class]
        if not altClassID or not C_Item.DoesItemContainSpec(itemLink or itemID, altClassID, altData.stats.specID) then
            return nil
        end
    end

    local ilvl = ItemLevel.Get(itemLink)
    if not ilvl then return nil end

    local slots = EQUIPLOC_TO_SLOTS[equipLoc]
    if not slots then return nil end

    local equipment = altData.equipment
    if not equipment then return nil end

    for _, slotID in ipairs(slots) do
        local equipped = equipment[slotID]
        if not equipped then
            if slotID == 17 and AltHasTwoHanderEquipped(equipment) then
                -- skip
            else
                return {
                    slot     = slotID,
                    slotName = SLOT_NAMES[slotID] or "Unknown",
                    equipped = 0,
                    new      = ilvl,
                    diff     = ilvl,
                }
            end
        else
            local equippedIlvl = equipped.itemLevel or 0
            if ilvl > equippedIlvl then
                return {
                    slot     = slotID,
                    slotName = SLOT_NAMES[slotID] or "Unknown",
                    equipped = equippedIlvl,
                    new      = ilvl,
                    diff     = ilvl - equippedIlvl,
                }
            end
        end
    end
    return nil
end

function UpgradeDetection:GetAltsWhoNeedItem(itemID, itemLink)
    if not itemID then return {} end

    local upgrades = {}

    local selfResult = self:CheckItemUpgradeDetailed(itemLink)
    if selfResult then
        local _, playerClass = UnitClass("player")
        selfResult.character = UnitName("player")
        selfResult.class = playerClass
        selfResult.isSelf = true
        selfResult.level = UnitLevel("player")
        upgrades[#upgrades + 1] = selfResult
    end

    local charAPI = OneWoW_AltTracker_Character_API
    if not charAPI or not charAPI.GetAllCharacters then return upgrades end

    local currentKey = charAPI.GetCurrentCharacterKey and charAPI.GetCurrentCharacterKey()
    local characters = charAPI.GetAllCharacters() or {}

    for charKey, charData in pairs(characters) do
        if charKey and charKey ~= currentKey and type(charData) == "table" then
            local altResult = self:IsItemUpgradeForAlt(itemID, itemLink, charData)
            if altResult then
                altResult.character = charData.name
                altResult.class = charData.class
                altResult.isSelf = false
                altResult.level = charData.level or 1
                upgrades[#upgrades + 1] = altResult
            end
        end
    end

    table.sort(upgrades, function(a, b)
        if a.isSelf ~= b.isSelf then return a.isSelf end
        return (a.diff or 0) > (b.diff or 0)
    end)

    return upgrades
end

function UpgradeDetection:Initialize()
    self.hasPawn = PawnShouldItemLinkHaveUpgradeArrow ~= nil

    PE:RegisterKeyword("upgrade", function(p)
        if not p.hyperlink then return false end
        local loc
        if p._bagID and p._slotID then
            loc = ItemLocation:CreateFromBagAndSlot(p._bagID, p._slotID)
            if loc and not C_Item.DoesItemExist(loc) then loc = nil end
        end
        return UpgradeDetection:CheckItemUpgrade(p.hyperlink, loc) == true
    end)

    if self.hasPawn then
        self:HookPawnTooltips()

        local mode = GetMode()
        if mode ~= "PAWN" and mode ~= "PAWN>ILVL" then
            if GetDB().showPawnPrompt ~= false then
                self:ShowPawnModePrompt()
            end
        else
            print("|cFF00FF00OneWoW|r: Pawn detected - upgrade detection using " .. mode .. " mode.")
        end
    else
        local mode = GetMode()
        if mode == "PAWN" then
            ns.SettingsFeatureRegistry:SetOverlaySetting("upgrade", "mode", "ILVL")
            print("|cFF00FF00OneWoW|r: Pawn not found - upgrade detection switched to Item Level mode.")
        end
    end
end

function UpgradeDetection:ShowPawnModePrompt()
    local L = ns.L or {}
    StaticPopupDialogs["ONEWOW_ENABLE_PAWN_MODE"] = {
        text = "|cFF00FF00OneWoW - Upgrade Detection|r\n\n" .. (L["OVR_UPGRADE_PAWN_DETECTED_TEXT"]),
        button1 = L["OVR_UPGRADE_PAWN_ENABLE"],
        button2 = L["OVR_UPGRADE_PAWN_NO_THANKS"],
        OnAccept = function()
            local reg = ns.SettingsFeatureRegistry
            reg:SetOverlaySetting("upgrade", "mode", "PAWN")
            reg:SetOverlaySetting("upgrade", "showPawnPrompt", false)
            print("|cFF00FF00OneWoW|r: Upgrade detection set to Pawn mode.")
        end,
        OnCancel = function()
            ns.SettingsFeatureRegistry:SetOverlaySetting("upgrade", "showPawnPrompt", false)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    C_Timer.After(2, function()
        StaticPopup_Show("ONEWOW_ENABLE_PAWN_MODE")
    end)
end

UpgradeDetection.CanPlayerUseItem = function(_, itemLink) return CanPlayerUseItem(itemLink) end
UpgradeDetection.SLOT_NAMES = SLOT_NAMES

ns:RegisterCoreLoginHandler("UpgradeDetection", function()
    UpgradeDetection:Initialize()
end, "early")
