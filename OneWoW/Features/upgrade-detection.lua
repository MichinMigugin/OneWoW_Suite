local ADDON_NAME, OneWoW = ...

local UpgradeDetection = {}
OneWoW.UpgradeDetection = UpgradeDetection

local ARMOR_CLASSES = {
    CLOTH   = {PRIEST = true, MAGE = true, WARLOCK = true, EVOKER = true},
    LEATHER = {DRUID = true, ROGUE = true, MONK = true, DEMONHUNTER = true},
    MAIL    = {HUNTER = true, SHAMAN = true},
    PLATE   = {WARRIOR = true, PALADIN = true, DEATHKNIGHT = true},
}

local WEAPON_CLASSES = {
    WARRIOR = {
        [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true,
        [6] = true, [7] = true, [8] = true, [13] = true, [15] = true, [18] = true,
    },
    PALADIN = {
        [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true,
    },
    HUNTER = {
        [0] = true, [1] = true, [2] = true, [3] = true, [6] = true, [7] = true,
        [8] = true, [10] = true, [18] = true,
    },
    ROGUE = {
        [0] = true, [4] = true, [7] = true, [13] = true, [15] = true,
    },
    PRIEST = {
        [4] = true, [10] = true, [15] = true, [19] = true,
    },
    MAGE = {
        [7] = true, [10] = true, [15] = true, [19] = true,
    },
    WARLOCK = {
        [7] = true, [10] = true, [15] = true, [19] = true,
    },
    SHAMAN = {
        [0] = true, [1] = true, [4] = true, [5] = true, [10] = true, [13] = true, [15] = true,
    },
    DRUID = {
        [4] = true, [6] = true, [10] = true, [13] = true, [15] = true,
    },
    DEATHKNIGHT = {
        [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true,
    },
    MONK = {
        [0] = true, [4] = true, [6] = true, [7] = true, [10] = true, [13] = true,
    },
    DEMONHUNTER = {
        [0] = true, [7] = true, [13] = true, [9] = true,
    },
    EVOKER = {
        [0] = true, [4] = true, [7] = true, [10] = true, [13] = true, [15] = true,
    },
}

local SHIELD_CLASSES = {WARRIOR = true, PALADIN = true, SHAMAN = true}

local OFFHAND_CLASSES = {
    WARRIOR = true, PALADIN = true, SHAMAN = true,
    PRIEST = true, MAGE = true, WARLOCK = true, EVOKER = true,
    DRUID = true, ROGUE = true, MONK = true, DEMONHUNTER = true,
}

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
    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    return db and db.overlays and db.overlays.upgrade
end

local function GetMode()
    local cfg = GetDB()
    return cfg and cfg.mode or "ILVL"
end

local function GetItemArmorType(itemID)
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    if classID ~= Enum.ItemClass.Armor then return nil end
    local armorTypes = {[1] = "CLOTH", [2] = "LEATHER", [3] = "MAIL", [4] = "PLATE"}
    return armorTypes[subclassID]
end

local function CanClassUseArmor(class, armorType)
    if not class or not armorType then return false end
    if armorType == "CLOTH" then return true end
    local classes = ARMOR_CLASSES[armorType]
    return classes and classes[class] or false
end

local function CanClassUseWeapon(class, weaponSubclassID)
    if not class or not weaponSubclassID then return false end
    local classWeapons = WEAPON_CLASSES[class]
    return classWeapons and classWeapons[weaponSubclassID] or false
end

local function CanClassUseShield(class)
    return SHIELD_CLASSES[class] == true
end

local function HasTwoHanderEquipped()
    local mainHandLink = GetInventoryItemLink("player", 16)
    if not mainHandLink then return false end
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(mainHandLink)
    return equipLoc == "INVTYPE_2HWEAPON"
end

local function CanPlayerUseItem(itemLink)
    if not itemLink then return false end

    local itemID, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemLink)
    if not itemID then return false end

    local _, playerClass = UnitClass("player")

    if equipLoc == "INVTYPE_SHIELD" then
        if not CanClassUseShield(playerClass) then return false end
    end

    if equipLoc == "INVTYPE_HOLDABLE" or equipLoc == "INVTYPE_WEAPONOFFHAND" or equipLoc == "INVTYPE_SHIELD" then
        if HasTwoHanderEquipped() then return false end
    end

    if classID == Enum.ItemClass.Armor then
        local armorType = GetItemArmorType(itemID)
        if armorType and not CanClassUseArmor(playerClass, armorType) then
            return false
        end
    elseif classID == Enum.ItemClass.Weapon then
        if not CanClassUseWeapon(playerClass, subclassID) then
            return false
        end
    end

    return true
end

function UpgradeDetection:CheckPawnUpgrade(itemLink)
    if not self.hasPawn or not itemLink then return nil end
    if not _G.PawnShouldItemLinkHaveUpgradeArrow then return nil end
    local ok, result = pcall(_G.PawnShouldItemLinkHaveUpgradeArrow, itemLink, true)
    if ok then return result end
    return nil
end

function UpgradeDetection:GetBestPawnScore(itemLink)
    if not self.hasPawn or not itemLink then return nil, nil end
    if not _G.PawnGetItemData then return nil, nil end

    local ok, itemData = pcall(_G.PawnGetItemData, itemLink)
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
    if not _G.PawnAddValuesToTooltip then return end
    if self.pawnTooltipHooked then return end

    local originalFn = _G.PawnAddValuesToTooltip
    _G.PawnAddValuesToTooltip = function(tooltip, itemValues, upgradeInfo, bestItemFor, secondBestItemFor, needsEnhancements, onlyFirstValue)
        local mode = GetMode()
        if mode == "PAWN" or mode == "PAWN>ILVL" then
            return
        end
        return originalFn(tooltip, itemValues, upgradeInfo, bestItemFor, secondBestItemFor, needsEnhancements, onlyFirstValue)
    end

    self.pawnTooltipHooked = true
end

function UpgradeDetection:CheckItemUpgrade(itemLink, itemLocation)
    if not itemLink then return false end

    local mode = GetMode()
    if mode == "OFF" then return false end

    local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(itemLink)
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" then return false end
    if classID ~= Enum.ItemClass.Armor and classID ~= Enum.ItemClass.Weapon then return false end

    if mode == "PAWN" then
        local pawnResult = self:CheckPawnUpgrade(itemLink)
        if pawnResult ~= nil then return pawnResult == true end
        return false
    end

    if mode == "PAWN>ILVL" then
        local pawnResult = self:CheckPawnUpgrade(itemLink)
        if pawnResult ~= nil then return pawnResult == true end
    end

    if not CanPlayerUseItem(itemLink) then return false end

    local ilvl
    if itemLocation and C_Item.DoesItemExist(itemLocation) then
        ilvl = C_Item.GetCurrentItemLevel(itemLocation)
    end
    if not ilvl or ilvl == 0 then
        ilvl = C_Item.GetDetailedItemLevelInfo(itemLink)
    end
    if not ilvl or ilvl == 0 then return false end

    local slots = EQUIPLOC_TO_SLOTS[equipLoc]
    if not slots then return false end

    for _, slotIndex in ipairs(slots) do
        local equippedLink = GetInventoryItemLink("player", slotIndex)
        if equippedLink then
            local equippedIlvl = C_Item.GetDetailedItemLevelInfo(equippedLink)
            if equippedIlvl and ilvl > equippedIlvl then
                return true
            end
        else
            if slotIndex == 17 and HasTwoHanderEquipped() then
                -- skip
            else
                return true
            end
        end
    end
    return false
end

function UpgradeDetection:CheckItemUpgradeDetailed(itemLink, itemLocation)
    if not itemLink then return nil end

    local mode = GetMode()
    if mode == "OFF" then return nil end

    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemLink)
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

    local ilvl
    if itemLocation and C_Item.DoesItemExist(itemLocation) then
        ilvl = C_Item.GetCurrentItemLevel(itemLocation)
    end
    if not ilvl or ilvl == 0 then
        ilvl = C_Item.GetDetailedItemLevelInfo(itemLink)
    end
    if not ilvl or ilvl == 0 then return nil end

    local slots = EQUIPLOC_TO_SLOTS[equipLoc]
    if not slots then return nil end

    local bestSlot, bestEquippedIlvl, bestDiff
    for _, slotIndex in ipairs(slots) do
        local equippedLink = GetInventoryItemLink("player", slotIndex)
        if equippedLink then
            local equippedIlvl = C_Item.GetDetailedItemLevelInfo(equippedLink)
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

    local ilvl
    if itemLocation and C_Item.DoesItemExist(itemLocation) then
        ilvl = C_Item.GetCurrentItemLevel(itemLocation)
    end
    if not ilvl or ilvl == 0 then
        ilvl = C_Item.GetDetailedItemLevelInfo(itemLink)
    end
    if not ilvl or ilvl == 0 then return nil end

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
            local equippedIlvl = C_Item.GetDetailedItemLevelInfo(equippedLink)
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

    local _, _, _, equipLoc, _, classID, subclassID = C_Item.GetItemInfoInstant(itemLink or itemID)
    if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP" then return nil end
    if classID ~= Enum.ItemClass.Armor and classID ~= Enum.ItemClass.Weapon then return nil end

    local altClass = altData.class

    if equipLoc == "INVTYPE_SHIELD" then
        if not CanClassUseShield(altClass) then return nil end
    end

    if classID == Enum.ItemClass.Armor then
        local armorType = GetItemArmorType(itemID)
        if armorType and not CanClassUseArmor(altClass, armorType) then
            return nil
        end
    elseif classID == Enum.ItemClass.Weapon then
        if not CanClassUseWeapon(altClass, subclassID) then
            return nil
        end
    end

    local ilvl = C_Item.GetDetailedItemLevelInfo(itemLink)
    if not ilvl or ilvl <= 0 then return nil end

    local slots = EQUIPLOC_TO_SLOTS[equipLoc]
    if not slots then return nil end

    local equipment = altData.equipment
    if not equipment then return nil end

    for _, slotID in ipairs(slots) do
        local equipped = equipment[slotID]
        if not equipped then
            return {
                slot     = slotID,
                slotName = SLOT_NAMES[slotID] or "Unknown",
                equipped = 0,
                new      = ilvl,
                diff     = ilvl,
            }
        end

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

    local charAPI = _G.OneWoW_AltTracker_Character_API
    local charDB = _G.OneWoW_AltTracker_Character_DB
    if not charAPI or not charDB then return upgrades end

    local currentKey = charAPI.GetCurrentCharacterKey and charAPI.GetCurrentCharacterKey()

    for charKey, charData in pairs(charDB) do
        if charKey ~= currentKey and type(charData) == "table" and charData.class and charData.name then
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
    self.hasPawn = _G.PawnShouldItemLinkHaveUpgradeArrow ~= nil

    if self.hasPawn then
        self:HookPawnTooltips()

        local mode = GetMode()
        if mode ~= "PAWN" and mode ~= "PAWN>ILVL" then
            local cfg = GetDB()
            if cfg and cfg.showPawnPrompt ~= false then
                self:ShowPawnModePrompt()
            end
        else
            print("|cFF00FF00OneWoW|r: Pawn detected - upgrade detection using " .. mode .. " mode.")
        end
    else
        local mode = GetMode()
        if mode == "PAWN" then
            local cfg = GetDB()
            if cfg then cfg.mode = "ILVL" end
            print("|cFF00FF00OneWoW|r: Pawn not found - upgrade detection switched to Item Level mode.")
        end
    end
end

function UpgradeDetection:ShowPawnModePrompt()
    local L = OneWoW.L or {}
    StaticPopupDialogs["ONEWOW_ENABLE_PAWN_MODE"] = {
        text = "|cFF00FF00OneWoW - Upgrade Detection|r\n\n" .. (L["OVR_UPGRADE_PAWN_DETECTED_TEXT"] or "Pawn has been detected. Would you like OneWoW to use Pawn for upgrade detection instead of item level comparison?"),
        button1 = L["OVR_UPGRADE_PAWN_ENABLE"] or "Enable Pawn Mode",
        button2 = L["OVR_UPGRADE_PAWN_NO_THANKS"] or "No Thanks",
        OnAccept = function()
            local cfg = GetDB()
            if cfg then
                cfg.mode = "PAWN"
                cfg.showPawnPrompt = false
            end
            print("|cFF00FF00OneWoW|r: Upgrade detection set to Pawn mode.")
        end,
        OnCancel = function()
            local cfg = GetDB()
            if cfg then cfg.showPawnPrompt = false end
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

UpgradeDetection.CanPlayerUseItem = function(self, itemLink) return CanPlayerUseItem(itemLink) end
UpgradeDetection.SLOT_NAMES = SLOT_NAMES
