local addonName, ns = ...

ns.ActionBars = {}
local Module = ns.ActionBars

local PickupSpell = C_Spell and C_Spell.PickupSpell or _G.PickupSpell
local PickupItem = C_Item and C_Item.PickupItem or _G.PickupItem
local PickupMacro = _G.PickupMacro
local PickupAction = _G.PickupAction
local PlaceAction = _G.PlaceAction
local GetCursorInfo = _G.GetCursorInfo
local ClearCursor = _G.ClearCursor

local ACTION_BAR_SLOTS = {
    [1] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12},
    [2] = {13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24},
    [3] = {25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36},
    [4] = {37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48},
    [5] = {49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60},
    [6] = {61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72},
    [7] = {73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84},
    [8] = {85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96},
    [9] = {97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108},
    [10] = {109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120},
    [11] = {121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132},
    [12] = {133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144},
    [13] = {145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156},
    [14] = {157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168},
    [15] = {169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180},
}

local function trim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local covenantSignatureAbilities = {
    [326526] = false,
    [324739] = true,
    [300728] = true,
    [324631] = true,
    [310143] = true,
}
local function IsCovenantSignatureAbility(id)
    return covenantSignatureAbilities[id] ~= nil
end
local function GetCovenantSignatureAbility()
    for id, valid in pairs(covenantSignatureAbilities) do
        if valid and IsSpellKnown(id, false) then
            return id
        end
    end
    return IsSpellKnown(326526, false) and 326526
end

function Module:GetActionInfo(slotID)
    if not HasAction(slotID) then
        return nil
    end

    local actionType, id, subType = GetActionInfo(slotID)
    local texture = GetActionTexture(slotID)
    local text = GetActionText(slotID)

    local actionData = {
        actionType = actionType,
        id = id,
        texture = texture,
        text = text,
        timestamp = time()
    }

    if subType and subType ~= actionType then
        actionData.subType = subType
    end

    if subType == "assistedcombat" then
        id = 1229376
        subType = "spell"
        actionType = "spell"
    end

    if actionType == "macro" then
        PickupAction(slotID)
        local cursorType, cursorId = GetCursorInfo()
        if cursorType == "macro" then
            id = cursorId
        else
            actionType = nil
            id = nil
        end
        PlaceAction(slotID)
    end

    if actionType == "spell" then
        if FindBaseSpellByID then
            id = FindBaseSpellByID(id) or id
        end

        if IsCovenantSignatureAbility(id) then
            id = GetCovenantSignatureAbility() or id
        end

        if C_Spell and C_Spell.GetSpellName then
            actionData.spellName = C_Spell.GetSpellName(id)
            actionData.spellID = id
        else
            local spellInfo = C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
            actionData.spellName = spellInfo and spellInfo.name or "Unknown Spell"
            actionData.spellID = id
        end
        actionData.displayName = actionData.spellName
    elseif actionType == "item" then
        local itemName, itemLink, itemQuality = GetItemInfo(id)
        actionData.itemName = itemName
        actionData.itemLink = itemLink
        actionData.itemQuality = itemQuality
        actionData.itemID = id
        actionData.displayName = itemName

        if C_ToyBox and C_ToyBox.GetToyInfo then
            local toyName, toyIcon = C_ToyBox.GetToyInfo(id)
            if toyName then
                actionData.isToy = true
                actionData.toyName = toyName
                actionData.toyIcon = toyIcon
                actionData.displayName = string.format("Toy: %s", toyName)
            end
        end
    elseif actionType == "macro" then
        if id and id ~= 0 then
            local macroName, macroIcon = GetMacroInfo(id)
            local macroBody = GetMacroBody(id)
            if macroName and macroBody then
                actionData.macroName = macroName
                actionData.macroIcon = macroIcon
                actionData.macroBody = macroBody
                actionData.displayName = string.format("Macro: %s", macroName)
            else
                return nil
            end
        else
            return nil
        end
    elseif actionType == "companion" then
        if subType ~= actionType then
            actionData.companionType = subType
        end

        if subType == "MOUNT" then
            if C_MountJournal and C_MountJournal.GetMountInfoByID then
                local mountName = C_MountJournal.GetMountInfoByID(id)
                if mountName then
                    actionData.companionName = mountName
                    actionData.displayName = string.format("Mount: %s", mountName)
                else
                    actionData.displayName = "Mount"
                end
            else
                actionData.displayName = "Mount"
            end
        elseif subType == "CRITTER" then
            if C_PetJournal and C_PetJournal.GetPetInfoByPetID then
                local _, customName, _, _, _, _, _, petName = C_PetJournal.GetPetInfoByPetID(id)
                local displayPetName = customName and customName ~= "" and customName or petName
                actionData.companionName = displayPetName
                actionData.displayName = displayPetName and string.format("Pet: %s", displayPetName) or "Pet"
            else
                actionData.displayName = "Pet"
            end
        else
            actionData.displayName = "Companion"
        end
    elseif actionType == "summonpet" then
        if subType and subType ~= actionType then
            actionData.petType = subType
        end
        if C_PetJournal and C_PetJournal.GetPetInfoByPetID then
            local _, customName, _, _, _, _, _, petName = C_PetJournal.GetPetInfoByPetID(id)
            local displayPetName = customName and customName ~= "" and customName or petName
            actionData.petName = displayPetName
            actionData.displayName = displayPetName and string.format("Pet: %s", displayPetName) or "Pet"
        else
            actionData.displayName = "Pet"
        end
    elseif actionType == "equipmentset" then
        if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo then
            local setID = tonumber(id)
            if not setID then
                for _, checkSetID in ipairs(C_EquipmentSet.GetEquipmentSetIDs() or {}) do
                    local setInfo = C_EquipmentSet.GetEquipmentSetInfo(checkSetID)
                    if setInfo and setInfo.name == id then
                        setID = checkSetID
                        break
                    end
                end
            end
            if setID then
                local setInfo = C_EquipmentSet.GetEquipmentSetInfo(setID)
                if setInfo then
                    actionData.equipmentSetName = setInfo.name
                    actionData.equipmentSetIcon = setInfo.iconFileID
                    actionData.displayName = string.format("Set: %s", setInfo.name)
                else
                    actionData.displayName = "Equipment Set"
                end
            else
                actionData.displayName = "Equipment Set"
            end
        else
            actionData.displayName = "Equipment Set"
        end
    elseif actionType == "flyout" then
        if GetFlyoutInfo then
            local flyoutName = GetFlyoutInfo(id)
            actionData.flyoutName = flyoutName
            actionData.displayName = flyoutName and string.format("Flyout: %s", flyoutName) or "Flyout"
        else
            actionData.displayName = "Flyout"
        end
    end

    return actionData
end

function Module:GetPetActionInfo(slotID)
    local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID = GetPetActionInfo(slotID)

    if not name and not spellID then
        return nil
    end

    local actionData = {
        actionType = "petaction",
        name = name,
        texture = texture,
        isToken = isToken,
        spellID = spellID,
        isActive = isActive,
        autoCastAllowed = autoCastAllowed,
        autoCastEnabled = autoCastEnabled,
        timestamp = time()
    }

    if isToken then
        actionData.displayName = name
    elseif spellID then
        if C_Spell and C_Spell.GetSpellName then
            local spellName = C_Spell.GetSpellName(spellID)
            actionData.displayName = spellName or name
            actionData.spellName = spellName
        else
            actionData.displayName = name
        end
    else
        actionData.displayName = name or "Pet Action"
    end

    return actionData
end

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    local specIndex = GetSpecialization()
    if not specIndex then
        return false
    end

    local specID, specName = GetSpecializationInfo(specIndex)
    if not specID or not specName then
        return false
    end

    if not charData.name then
        charData.name = UnitName("player")
    end
    if not charData.realm then
        charData.realm = GetRealmName()
    end
    if not charData.class then
        charData.class = select(2, UnitClass("player"))
    end
    charData.level = UnitLevel("player")
    charData.currentSpec = specName

    if not charData.specs then
        charData.specs = {}
    end

    if not charData.macros then
        charData.macros = {
            account = {},
            character = {},
            lastUpdate = time()
        }
    end

    if not charData.keybinds then
        charData.keybinds = {}
    end

    if not charData.specs[specName] then
        charData.specs[specName] = {}
    end

    local specData = charData.specs[specName]
    specData.specID = specID
    specData.specName = specName
    specData.lastUpdate = time()
    specData.bars = {}
    specData.petBar = {}

    for barNumber = 1, 15 do
        local slots = ACTION_BAR_SLOTS[barNumber]
        local barSlots = {}
        local hasContent = false

        for slotIndex = 1, 12 do
            local slotID = slots[slotIndex]
            local actionInfo = self:GetActionInfo(slotID)

            if actionInfo then
                hasContent = true
            end

            barSlots[slotIndex] = actionInfo
        end

        if hasContent then
            specData.bars[barNumber] = {
                barNumber = barNumber,
                slots = barSlots,
            }
        end
    end

    if IsPetActive() then
        for i = 1, NUM_PET_ACTION_SLOTS do
            local petActionInfo = self:GetPetActionInfo(i)
            if petActionInfo then
                specData.petBar[i] = petActionInfo
            end
        end
    end

    charData.macros.account = {}
    for i = 1, MAX_ACCOUNT_MACROS do
        local name, iconTexture, body = GetMacroInfo(i)
        if name then
            local macroIcon
            if type(iconTexture) == "number" then
                macroIcon = iconTexture
            elseif type(iconTexture) == "string" then
                macroIcon = iconTexture:gsub("^Interface\\Icons\\", "")
            else
                macroIcon = "INV_Misc_QuestionMark"
            end
            charData.macros.account[i] = {
                id = i,
                name = name,
                icon = macroIcon,
                body = body,
            }
        end
    end

    charData.macros.character = {}
    for i = MAX_ACCOUNT_MACROS + 1, MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS do
        local name, iconTexture, body = GetMacroInfo(i)
        if name then
            local macroIcon
            if type(iconTexture) == "number" then
                macroIcon = iconTexture
            elseif type(iconTexture) == "string" then
                macroIcon = iconTexture:gsub("^Interface\\Icons\\", "")
            else
                macroIcon = "INV_Misc_QuestionMark"
            end
            charData.macros.character[i] = {
                id = i,
                name = name,
                icon = macroIcon,
                body = body,
            }
        end
    end
    charData.macros.lastUpdate = time()

    if not charData.keybinds then
        charData.keybinds = {}
    end

    local keybindData = {}
    for i = 1, GetNumBindings() do
        local command, _, key1, key2 = GetBinding(i)
        if command and (key1 or key2) then
            keybindData[i] = {
                command = command,
                key1 = key1,
                key2 = key2,
            }
        end
    end
    charData.keybinds.bindings = keybindData
    charData.keybinds.lastUpdate = time()

    return true
end

function Module:CollectActionBarsData()
    local playerName = UnitName("player")
    local realmName = GetRealmName()

    if not playerName or not realmName then
        return nil
    end

    local charKey = playerName .. "-" .. realmName

    local specIndex = GetSpecialization()
    if not specIndex then
        print("|cFFFFD100OneWoW|r AltTracker: Cannot collect action bar data: No active specialization")
        return nil
    end

    local specID, specName = GetSpecializationInfo(specIndex)
    if not specID or not specName then
        print("|cFFFFD100OneWoW|r AltTracker: Cannot collect action bar data: No spec info")
        return nil
    end

    if not OneWoW_AltTracker_Character_DB then
        OneWoW_AltTracker_Character_DB = {}
    end
    if not OneWoW_AltTracker_Character_DB.characters then
        OneWoW_AltTracker_Character_DB.characters = {}
    end

    local charData = OneWoW_AltTracker_Character_DB.characters[charKey]
    if not charData then
        charData = {}
        OneWoW_AltTracker_Character_DB.characters[charKey] = charData
    end

    local success = self:CollectData(charKey, charData)

    if success then
        print(string.format("|cFFFFD100OneWoW|r AltTracker: Action bar data saved for %s (%s)", playerName, specName))
        return charData, specName
    else
        return nil
    end
end

function Module:GetCharacterData(charKey)
    if not OneWoW_AltTracker_Character_DB or not OneWoW_AltTracker_Character_DB.characters then
        return nil
    end
    return OneWoW_AltTracker_Character_DB.characters[charKey]
end

function Module:GetSpecData(charKey, specName)
    local charData = self:GetCharacterData(charKey)
    if not charData or not charData.specs then
        return nil
    end

    return charData.specs[specName]
end

function Module:GetCharacterSpecs(charKey)
    local charData = self:GetCharacterData(charKey)
    if not charData or not charData.specs then
        return {}
    end

    local specs = {}
    for specName, _ in pairs(charData.specs) do
        table.insert(specs, specName)
    end

    table.sort(specs)
    return specs
end

function Module:HasActionBarData(charKey, specName)
    local charData = self:GetCharacterData(charKey)
    if not charData or not charData.specs then
        return false
    end

    if specName then
        local specData = charData.specs[specName]
        if not specData or not specData.bars then
            return false
        end

        for _, barData in pairs(specData.bars) do
            if barData.slots then
                for _, slot in pairs(barData.slots) do
                    if slot then
                        return true
                    end
                end
            end
        end
        return false
    else
        for _, specData in pairs(charData.specs) do
            if specData.bars then
                for _, barData in pairs(specData.bars) do
                    if barData.slots then
                        for _, slot in pairs(barData.slots) do
                            if slot then
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

function Module:GetAllCharacters()
    if not OneWoW_AltTracker_Character_DB or not OneWoW_AltTracker_Character_DB.characters then
        return {}
    end
    return OneWoW_AltTracker_Character_DB.characters
end

function Module:GetActionBarSets()
    if not OneWoW_AltTracker_Character_DB then
        OneWoW_AltTracker_Character_DB = {}
    end
    if not OneWoW_AltTracker_Character_DB.actionBarSets then
        OneWoW_AltTracker_Character_DB.actionBarSets = {}
    end
    return OneWoW_AltTracker_Character_DB.actionBarSets
end

function Module:GetActionBarSet(setName)
    local sets = self:GetActionBarSets()
    return sets[setName]
end

function Module:SaveActionBarSet(setName)
    local playerName = UnitName("player")
    local realmName = GetRealmName()
    if not playerName or not realmName then return nil end

    local charKey = playerName .. "-" .. realmName
    local specIndex = GetSpecialization()
    if not specIndex then
        print("|cFFFFD100OneWoW|r AltTracker: Cannot backup: No active specialization")
        return nil
    end

    local specID, specName = GetSpecializationInfo(specIndex)
    if not specID or not specName then
        print("|cFFFFD100OneWoW|r AltTracker: Cannot backup: No spec info")
        return nil
    end

    if not OneWoW_AltTracker_Character_DB then
        OneWoW_AltTracker_Character_DB = {}
    end
    if not OneWoW_AltTracker_Character_DB.characters then
        OneWoW_AltTracker_Character_DB.characters = {}
    end

    local charData = OneWoW_AltTracker_Character_DB.characters[charKey]
    if not charData then
        charData = {}
        OneWoW_AltTracker_Character_DB.characters[charKey] = charData
    end

    local success = self:CollectData(charKey, charData)
    if not success then return nil end

    local sets = self:GetActionBarSets()
    local specData = charData.specs and charData.specs[specName]
    if not specData then return nil end

    sets[setName] = {
        name = setName,
        sourceChar = charKey,
        sourceSpec = specName,
        sourceClass = charData.class or select(2, UnitClass("player")),
        createdAt = sets[setName] and sets[setName].createdAt or time(),
        lastUpdate = time(),
        specID = specData.specID,
        bars = specData.bars,
        petBar = specData.petBar,
        macros = charData.macros and {
            account = charData.macros.account,
            character = charData.macros.character,
            lastUpdate = charData.macros.lastUpdate,
        } or nil,
        keybinds = charData.keybinds and {
            bindings = charData.keybinds.bindings,
            lastUpdate = charData.keybinds.lastUpdate,
        } or nil,
    }

    print(string.format("|cFFFFD100OneWoW|r AltTracker: Set \"%s\" saved (%s - %s)", setName, playerName, specName))
    return sets[setName]
end

function Module:DeleteActionBarSet(setName)
    local sets = self:GetActionBarSets()
    if sets[setName] then
        sets[setName] = nil
        print(string.format("|cFFFFD100OneWoW|r AltTracker: Set \"%s\" deleted", setName))
        return true
    end
    return false
end

function Module:RenameActionBarSet(oldName, newName)
    if oldName == newName then return false end
    local sets = self:GetActionBarSets()
    if not sets[oldName] then return false end
    if sets[newName] then return false end

    sets[newName] = sets[oldName]
    sets[newName].name = newName
    sets[oldName] = nil
    print(string.format("|cFFFFD100OneWoW|r AltTracker: Set renamed \"%s\" -> \"%s\"", oldName, newName))
    return true
end

function Module:HasSetBarData(setName)
    local setData = self:GetActionBarSet(setName)
    if not setData or not setData.bars then return false end
    for _, barData in pairs(setData.bars) do
        if barData.slots then
            for _, slot in pairs(barData.slots) do
                if slot then return true end
            end
        end
    end
    return false
end

function Module:GetAllSetNames()
    local sets = self:GetActionBarSets()
    local names = {}
    for setName, _ in pairs(sets) do
        table.insert(names, setName)
    end
    table.sort(names)
    return names
end

local function RestoreBars(mod, barsData, petBarData, options)
    if InCombatLockdown() then
        print("|cFFFFD100OneWoW|r AltTracker: Cannot restore action bars while in combat")
        return false
    end

    if not barsData then
        print("|cFFFFD100OneWoW|r AltTracker: No action bar data found")
        return false
    end

    local singleBar = options and options.singleBar
    local targetBarOverride = options and options.targetBar

    if singleBar then
        local sourceBarData = barsData[singleBar]
        if not sourceBarData or not sourceBarData.slots then
            print(string.format("|cFFFFD100OneWoW|r AltTracker: No data found for source bar %d", singleBar))
            return false
        end
        local targetBar = targetBarOverride or singleBar
        local targetSlots = ACTION_BAR_SLOTS[targetBar]
        if not targetSlots then
            print(string.format("|cFFFFD100OneWoW|r AltTracker: Invalid target bar number: %d", targetBar))
            return false
        end
    end

    local restoredCount = 0
    local failedCount = 0
    local failedItems = {}

    local flyouts = mod:CreateFlyoutSpellbookMap()
    local mountCache = mod:CreateMountCache()
    local spellOverride = mod:CreateSpellOverrideMap()

    local startBar = singleBar or 1
    local endBar = singleBar or 15

    for barNumber = startBar, endBar do
        local barData = barsData[barNumber]
        if barData and barData.slots then
            local targetBar = (singleBar and targetBarOverride) or barNumber
            local slots = ACTION_BAR_SLOTS[targetBar]
            if slots then
                for slotIndex = 1, 12 do
                    local slotData = barData.slots[slotIndex]
                    if slotData then
                        local slotID = slots[slotIndex]
                        local success, failReason = mod:RestoreActionSlot(slotID, slotData, flyouts, mountCache, spellOverride)
                        if success then
                            restoredCount = restoredCount + 1
                        else
                            failedCount = failedCount + 1
                            table.insert(failedItems, {
                                slotData = slotData,
                                barNumber = targetBar,
                                slotIndex = slotIndex,
                                reason = failReason or "Unknown error"
                            })
                        end
                    end
                end
            end
        end
    end

    if not singleBar and petBarData and IsPetActive() then
        for i = 1, NUM_PET_ACTION_SLOTS do
            local petActionData = petBarData[i]
            if petActionData then
                local success, failReason = mod:RestorePetActionSlot(i, petActionData)
                if success then
                    restoredCount = restoredCount + 1
                else
                    failedCount = failedCount + 1
                    table.insert(failedItems, {
                        slotData = petActionData,
                        barNumber = "Pet",
                        slotIndex = i,
                        reason = failReason or "Unknown error"
                    })
                end
            end
        end
    end

    if singleBar then
        local targetBar = targetBarOverride or singleBar
        print(string.format("|cFFFFD100OneWoW|r AltTracker: Bar %d to %d restore: %d restored, %d failed", singleBar, targetBar, restoredCount, failedCount))
    else
        print(string.format("|cFFFFD100OneWoW|r AltTracker: Restore complete: %d restored, %d failed", restoredCount, failedCount))
    end

    if failedCount > 0 then
        for _, failedItem in ipairs(failedItems) do
            local slotData = failedItem.slotData
            local barNumber = failedItem.barNumber
            local slotIndex = failedItem.slotIndex
            local reason = failedItem.reason or "Unknown error"
            local displayName = mod:GetDisplayText(slotData) or "Unknown"
            local iconText = ""
            if slotData.texture then
                iconText = string.format("|T%s:16:16|t ", slotData.texture)
            end
            if barNumber == "Pet" then
                print(string.format("|cFFFFD100OneWoW|r AltTracker: Failed: %s%s pet bar, slot %d (%s)", iconText, displayName, slotIndex, reason))
            elseif singleBar then
                print(string.format("|cFFFFD100OneWoW|r AltTracker: Failed: %s%s slot %d (%s)", iconText, displayName, slotIndex, reason))
            else
                print(string.format("|cFFFFD100OneWoW|r AltTracker: Failed: %s%s bar %d, slot %d (%s)", iconText, displayName, barNumber, slotIndex, reason))
            end
        end
    end

    return true
end

function Module:RestoreSingleBarFromSet(setName, sourceBarNumber, targetBarNumber)
    local setData = self:GetActionBarSet(setName)
    if not setData or not setData.bars then
        print("|cFFFFD100OneWoW|r AltTracker: No action bar data found")
        return false
    end
    return RestoreBars(self, setData.bars, nil, { singleBar = sourceBarNumber, targetBar = targetBarNumber })
end

function Module:RestoreAllBarsFromSet(setName)
    local setData = self:GetActionBarSet(setName)
    if not setData or not setData.bars then
        print("|cFFFFD100OneWoW|r AltTracker: No action bar data found")
        return false
    end
    return RestoreBars(self, setData.bars, setData.petBar, nil)
end

local function RestoreKeybindsGeneric(keybindData)
    if not keybindData or not keybindData.bindings then
        print("|cFFFFD100OneWoW|r AltTracker: No keybind data found")
        return false
    end

    LoadBindings(2)

    for _, bindData in pairs(keybindData.bindings) do
        local command = bindData.command
        local key1 = bindData.key1
        local key2 = bindData.key2

        if key1 then
            local bindingContext = 1
            if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
                bindingContext = C_KeyBindings.GetBindingContextForAction(command)
            end
            SetBinding(key1, command, bindingContext)
        end

        if key2 then
            local bindingContext = 1
            if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
                bindingContext = C_KeyBindings.GetBindingContextForAction(command)
            end
            SetBinding(key2, command, bindingContext)
        end
    end

    SaveBindings(2)

    local bindCount = 0
    for _ in pairs(keybindData.bindings) do
        bindCount = bindCount + 1
    end

    print(string.format("|cFFFFD100OneWoW|r AltTracker: Restored %d keybinds", bindCount))
    return true
end

function Module:RestoreKeybindsFromSet(setName)
    local setData = self:GetActionBarSet(setName)
    return RestoreKeybindsGeneric(setData and setData.keybinds)
end

local function RestoreMacrosGeneric(macroData, restoreType)
    if not macroData then
        print("|cFFFFD100OneWoW|r AltTracker: No macro data found")
        return false
    end

    restoreType = restoreType or "both"
    local restoredCount = 0
    local macroMapping = {}

    for _, scope in ipairs({"account", "character"}) do
        if (restoreType == scope or restoreType == "both") and macroData[scope] then
            for oldId, macroInfo in pairs(macroData[scope]) do
                local newId = GetMacroByText(macroInfo.body)
                if newId then
                    macroMapping[oldId] = newId
                    restoredCount = restoredCount + 1
                end
            end
        end
    end

    print(string.format("|cFFFFD100OneWoW|r AltTracker: Restored %d macros", restoredCount))
    return macroMapping
end

function Module:RestoreMacrosFromSet(setName, restoreType)
    local setData = self:GetActionBarSet(setName)
    return RestoreMacrosGeneric(setData and setData.macros, restoreType)
end

function Module:MigrateToNamedSets()
    if not OneWoW_AltTracker_Character_DB then return end
    if OneWoW_AltTracker_Character_DB.actionBarSetsMigrated then return end

    local characters = OneWoW_AltTracker_Character_DB.characters
    if not characters then
        OneWoW_AltTracker_Character_DB.actionBarSetsMigrated = true
        return
    end

    if not OneWoW_AltTracker_Character_DB.actionBarSets then
        OneWoW_AltTracker_Character_DB.actionBarSets = {}
    end
    local sets = OneWoW_AltTracker_Character_DB.actionBarSets

    local migratedCount = 0

    for charKey, charData in pairs(characters) do
        if charData.specs then
            local charName = charData.name or charKey:match("^([^%-]+)")
            for specName, specData in pairs(charData.specs) do
                local hasBars = false
                if specData.bars then
                    for _, barData in pairs(specData.bars) do
                        if barData.slots then
                            for _, slot in pairs(barData.slots) do
                                if slot then hasBars = true; break end
                            end
                        end
                        if hasBars then break end
                    end
                end

                if hasBars then
                    local setName = charName .. " " .. specName
                    sets[setName] = {
                        name = setName,
                        sourceChar = charKey,
                        sourceSpec = specName,
                        sourceClass = charData.class,
                        createdAt = specData.lastUpdate or time(),
                        lastUpdate = specData.lastUpdate or time(),
                        specID = specData.specID,
                        bars = specData.bars,
                        petBar = specData.petBar,
                        macros = charData.macros and {
                            account = charData.macros.account,
                            character = charData.macros.character,
                            lastUpdate = charData.macros.lastUpdate,
                        } or nil,
                        keybinds = charData.keybinds and {
                            bindings = charData.keybinds.bindings,
                            lastUpdate = charData.keybinds.lastUpdate,
                        } or nil,
                    }
                    migratedCount = migratedCount + 1
                end
            end

            charData.specs = nil
            charData.macros = nil
            charData.keybinds = nil
        end
    end

    OneWoW_AltTracker_Character_DB.actionBarSetsMigrated = true

    if migratedCount > 0 then
        print(string.format("|cFFFFD100OneWoW|r AltTracker: Migrated %d action bar backups to named sets", migratedCount))
    end
end

function Module:GetActionColor(actionData)
    if not actionData then
        return {0.5, 0.5, 0.5}
    end

    local colors = {
        spell = {0.0, 0.8, 1.0},
        item = {1.0, 0.8, 0.0},
        macro = {0.8, 0.0, 1.0},
        companion = {0.0, 1.0, 0.5},
        summonpet = {0.0, 1.0, 0.5},
        summonmount = {0.0, 0.8, 0.8},
        equipmentset = {1.0, 0.6, 0.2},
        flyout = {1.0, 0.5, 0.0},
        petaction = {0.5, 1.0, 0.5}
    }

    return colors[actionData.actionType] or {1.0, 1.0, 1.0}
end

function Module:GetDisplayText(actionData)
    if not actionData then
        return ""
    end

    if actionData.displayName then
        return actionData.displayName
    end

    if actionData.text and actionData.text ~= "" then
        return actionData.text
    elseif actionData.spellName then
        return actionData.spellName
    elseif actionData.itemName then
        return actionData.itemName
    elseif actionData.macroName then
        return actionData.macroName
    else
        return actionData.actionType or "Unknown"
    end
end

function Module:CreateFlyoutSpellbookMap()
    local flyouts = {}

    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        for skillLineIndex = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)
            if skillLineInfo then
                for i = 1, skillLineInfo.numSpellBookItems do
                    local spellIndex = skillLineInfo.itemIndexOffset + i
                    local spellTypeEnum, spellId = C_SpellBook.GetSpellBookItemType(spellIndex, Enum.SpellBookSpellBank.Player)
                    if spellId and spellTypeEnum == Enum.SpellBookItemType.Flyout then
                        flyouts[spellId] = { spellIndex, Enum.SpellBookSpellBank.Player }
                    end
                end
            end
        end
    end

    return flyouts
end

function Module:CreateMountCache()
    local mounts = {}

    if C_MountJournal and C_MountJournal.GetNumMounts then
        for i = 1, C_MountJournal.GetNumMounts() do
            local _, _, _, _, _, _, _, _, _, _, isCollected, mountId = C_MountJournal.GetDisplayedMountInfo(i)
            if isCollected then
                mounts[mountId] = i
            end
        end
    end

    return mounts
end

function Module:CreateSpellOverrideMap()
    local spellOverride = {}

    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        for skillLineIndex = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)
            if skillLineInfo then
                for i = 1, skillLineInfo.numSpellBookItems do
                    local spellIndex = skillLineInfo.itemIndexOffset + i
                    local spellType, id, spellId = C_SpellBook.GetSpellBookItemType(spellIndex, Enum.SpellBookSpellBank.Player)
                    if spellId and C_Spell and C_Spell.GetOverrideSpell then
                        local newid = C_Spell.GetOverrideSpell(spellId)
                        if newid ~= spellId then
                            spellOverride[newid] = spellId
                        end
                    elseif spellType == Enum.SpellBookItemType.Flyout then
                        local _, _, numSlots, isKnown = GetFlyoutInfo(id)
                        if isKnown and (numSlots > 0) then
                            for k = 1, numSlots do
                                local spellID, overrideSpellID = GetFlyoutSlotInfo(id, k)
                                if spellID and overrideSpellID then
                                    spellOverride[overrideSpellID] = spellID
                                end
                            end
                        end
                    end
                end
            end
        end

        local isInspect = false
        for specIndex = 1, GetNumSpecGroups(isInspect) do
            for tier = 1, MAX_TALENT_TIERS do
                for column = 1, NUM_TALENT_COLUMNS do
                    local spellId = select(6, GetTalentInfo(tier, column, specIndex))
                    if spellId and C_Spell and C_Spell.GetOverrideSpell then
                        local newid = C_Spell.GetOverrideSpell(spellId)
                        if newid ~= spellId then
                            spellOverride[newid] = spellId
                        end
                    end
                end
            end
        end

        for pvpTalentSlot = 1, 3 do
            local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(pvpTalentSlot)
            if slotInfo then
                for i, pvpTalentID in ipairs(slotInfo.availableTalentIDs) do
                    local spellId = select(6, GetPvpTalentInfoByID(pvpTalentID))
                    if spellId and C_Spell and C_Spell.GetOverrideSpell then
                        local newid = C_Spell.GetOverrideSpell(spellId)
                        if newid ~= spellId then
                            spellOverride[newid] = spellId
                        end
                    end
                end
            end
        end
    end

    return spellOverride
end

local function GetMacroByText(text)
    if not text then
        return nil
    end

    text = trim(text)

    local global, character = GetNumMacros()
    for i = 1, global do
        if trim(GetMacroBody(i)) == text then
            return i
        end
    end
    for i = MAX_ACCOUNT_MACROS + 1, MAX_ACCOUNT_MACROS + character do
        if trim(GetMacroBody(i)) == text then
            return i
        end
    end
    return nil
end

local function PickupMacroByText(text)
    local index = GetMacroByText(text)
    if index then
        PickupMacro(index)
        return true
    end
    return false
end

local function PickupActionTable(actionData, flyouts, mountCache)
    if not actionData or not actionData.actionType then
        return true, nil
    end

    local success = true
    local failReason = nil

    if actionData.actionType == "macro" then
        if actionData.macroBody then
            if not PickupMacroByText(actionData.macroBody) then
                if actionData.macroName then
                    local macroId = GetMacroIndexByName(actionData.macroName)
                    if macroId and macroId > 0 then
                        PickupMacro(macroId)
                    else
                        success = false
                        failReason = "Macro does not exist"
                    end
                else
                    success = false
                    failReason = "Macro does not exist"
                end
            end
        else
            success = false
            failReason = "Macro has no body"
        end

    elseif actionData.actionType == "spell" then
        local spellId = actionData.spellID
        if spellId then
            if FindBaseSpellByID then
                spellId = FindBaseSpellByID(spellId) or spellId
            end

            if IsCovenantSignatureAbility(spellId) then
                local covenantId = GetCovenantSignatureAbility()
                if covenantId then
                    spellId = covenantId
                end
            end

            if C_Spell and C_Spell.PickupSpell then
                C_Spell.PickupSpell(spellId)
            else
                PickupSpell(spellId)
            end

            if not GetCursorInfo() then
                if actionData.spellName then
                    PickupSpell(actionData.spellName)
                end
            end

            if not GetCursorInfo() then
                success = false
                failReason = string.format("Spell not found (ID: %d)", spellId)
            end
        else
            success = false
            failReason = "Spell has no ID"
        end

    elseif actionData.actionType == "item" then
        if actionData.itemID then
            PickupItem(actionData.itemID)
            if not GetCursorInfo() then
                success = false
                failReason = "Item not in bags"
            end
        else
            success = false
            failReason = "Item has no ID"
        end

    elseif actionData.actionType == "companion" then
        local subType = actionData.subType or actionData.companionType
        if subType == "MOUNT" then
            local displayIndex = mountCache and mountCache[actionData.id]
            if displayIndex and C_MountJournal and C_MountJournal.Pickup then
                C_MountJournal.Pickup(displayIndex)
            elseif C_MountJournal and C_MountJournal.Pickup then
                C_MountJournal.Pickup(0)
            end
            if not GetCursorInfo() then
                success = false
                failReason = "Mount not collected"
            end
        elseif subType == "CRITTER" then
            if C_PetJournal and C_PetJournal.PickupPet then
                C_PetJournal.PickupPet(actionData.id, false)
                if not GetCursorInfo() then
                    C_PetJournal.PickupPet(actionData.id, true)
                end
            end
            if not GetCursorInfo() then
                success = false
                failReason = "Pet not collected"
            end
        else
            if C_Spell and C_Spell.PickupSpell then
                C_Spell.PickupSpell(actionData.id)
            else
                PickupSpell(actionData.id)
            end
            if not GetCursorInfo() then
                success = false
                failReason = "Companion not found"
            end
        end

    elseif actionData.actionType == "summonmount" then
        local displayIndex = mountCache and mountCache[actionData.id]
        if displayIndex and C_MountJournal and C_MountJournal.Pickup then
            C_MountJournal.Pickup(displayIndex)
        elseif C_MountJournal and C_MountJournal.Pickup then
            C_MountJournal.Pickup(0)
        end
        if not GetCursorInfo() then
            success = false
            failReason = "Mount not collected"
        end

    elseif actionData.actionType == "summonpet" then
        if C_PetJournal and C_PetJournal.PickupPet then
            C_PetJournal.PickupPet(actionData.id, false)
            if not GetCursorInfo() then
                C_PetJournal.PickupPet(actionData.id, true)
            end
        end
        if not GetCursorInfo() then
            success = false
            failReason = "Pet not collected"
        end

    elseif actionData.actionType == "equipmentset" then
        if C_EquipmentSet and C_EquipmentSet.PickupEquipmentSet then
            local setName = actionData.equipmentSetName or actionData.id
            local setID
            for _, checkID in ipairs(C_EquipmentSet.GetEquipmentSetIDs() or {}) do
                local setInfo = C_EquipmentSet.GetEquipmentSetInfo(checkID)
                if setInfo and setInfo.name == setName then
                    setID = checkID
                    break
                end
            end
            if setID then
                C_EquipmentSet.PickupEquipmentSet(setID)
            end
        end
        if not GetCursorInfo() then
            success = false
            failReason = "Equipment set not found"
        end

    elseif actionData.actionType == "flyout" then
        local flyoutID = actionData.flyoutID or actionData.id
        if flyoutID and flyouts then
            local flyout = flyouts[flyoutID]
            if flyout then
                if C_SpellBook and C_SpellBook.PickupSpellBookItem then
                    C_SpellBook.PickupSpellBookItem(flyout[1], flyout[2])
                else
                    PickupSpellBookItem(flyout[1], flyout[2])
                end
            end
        end
        if not GetCursorInfo() then
            success = false
            failReason = "Flyout not available"
        end

    else
        success = false
        failReason = "Unknown action type"
    end

    return success, failReason
end

function Module:RestoreActionSlot(slotID, actionData, flyouts, mountCache, spellOverride)
    if InCombatLockdown() then
        return false, "In combat"
    end

    if not actionData then
        return false, "No action data"
    end

    local success, failReason = PickupActionTable(actionData, flyouts, mountCache)

    if success and GetCursorInfo() then
        PlaceAction(slotID)
        ClearCursor()
        return true, nil
    else
        ClearCursor()
        return success, failReason
    end
end

function Module:RestorePetActionSlot(slotID, actionData)
    if InCombatLockdown() then
        return false, "In combat"
    end

    if not IsPetActive() then
        return false, "No pet summoned"
    end

    if not actionData then
        return false, "No action data"
    end

    if actionData.isToken and actionData.name then
        local success = false
        for i = 1, NUM_PET_ACTION_SLOTS do
            local name, _, isToken = GetPetActionInfo(i)
            if isToken and name == actionData.name then
                PickupPetAction(i)
                if GetCursorInfo() then
                    PickupPetAction(slotID)
                    ClearCursor()
                    success = true
                end
                break
            end
        end
        if not success then
            return false, "Pet action not found"
        end
        return success, nil
    elseif actionData.spellID then
        PickupPetSpell(actionData.spellID)
        if GetCursorInfo() then
            PickupPetAction(slotID)
            ClearCursor()
            return true, nil
        else
            return false, "Pet spell not found"
        end
    end

    ClearCursor()
    return false, "Unknown error"
end

function Module:FindOrCreateMacro(macroInfo, createMissing)
    if not macroInfo or not macroInfo.name or not macroInfo.body then
        return nil
    end

    local localIndex = GetMacroByText(macroInfo.body)
    if localIndex then
        return localIndex
    end

    if not createMissing then
        return nil
    end

    local numGlobal, numPerChar = GetNumMacros()
    local isCharMacro = macroInfo.id > MAX_ACCOUNT_MACROS
    local perChar = isCharMacro and 2 or 1

    local testAllow = bit.bor(
        (numGlobal < MAX_ACCOUNT_MACROS) and 1 or 0,
        (numPerChar < MAX_CHARACTER_MACROS) and 2 or 0
    )
    perChar = bit.band(perChar, testAllow)
    perChar = (perChar == 0) and testAllow or perChar

    if perChar ~= 0 then
        local icon = macroInfo.icon or "INV_Misc_QuestionMark"
        if macroInfo.body:sub(1, 12) == "#showtooltip" then
            icon = "INV_Misc_QuestionMark"
        end

        local newId = CreateMacro(macroInfo.name, icon, macroInfo.body, perChar >= 2)
        if newId then
            return newId
        end
    end

    return nil
end

function Module:RestoreKeybinds(charKey)
    local charData = self:GetCharacterData(charKey)
    return RestoreKeybindsGeneric(charData and charData.keybinds)
end

function Module:RestoreMacros(charKey, restoreType)
    local charData = self:GetCharacterData(charKey)
    return RestoreMacrosGeneric(charData and charData.macros, restoreType)
end

function Module:RestoreSingleActionBar(charKey, sourceBarNumber, targetBarNumber, specName)
    local specData = self:GetSpecData(charKey, specName)
    if not specData or not specData.bars then
        print("|cFFFFD100OneWoW|r AltTracker: No action bar data found")
        return false
    end
    return RestoreBars(self, specData.bars, nil, { singleBar = sourceBarNumber, targetBar = targetBarNumber })
end

function Module:RestoreAllActionBars(charKey, specName)
    local specData = self:GetSpecData(charKey, specName)
    if not specData or not specData.bars then
        print("|cFFFFD100OneWoW|r AltTracker: No action bar data found")
        return false
    end
    return RestoreBars(self, specData.bars, specData.petBar, nil)
end
