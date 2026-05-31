-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/vendorpanel/vendorpanel.lua
local addonName, ns = ...

local function GetDB()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db or not addon.db.global or not addon.db.global.modules then return nil end
    if not addon.db.global.modules["vendorpanel"] then
        addon.db.global.modules["vendorpanel"] = {}
    end
    return addon.db.global.modules["vendorpanel"]
end

local function GetSettings()
    local db = GetDB()
    if not db.settings then db.settings = {} end
    return db.settings
end

local function GetShowBlizzJunk()
    local db = GetDB()
    return db and db.toggles and db.toggles.show_blizz_junk or false
end

local function GetShowPanel()
    return ns.ModuleRegistry:GetToggleValue("vendorpanel", "show_panel")
end

ns.VPGetDB = GetDB
ns.VPGetSettings = GetSettings
ns.VPGetShowBlizzJunk = GetShowBlizzJunk
ns.VPGetShowPanel = GetShowPanel

-- ============================================================
-- Shared state (vendorpanel-ui.lua reads ns.VPState)
-- ============================================================
local state = {
    vendorButton = nil,
    junkPreviewPanel = nil,
    panelToggleTab = nil,
    _merchantSidebarIndex = nil,
    _merchantToggleHandler = nil,
    replacementSellButton = nil,
    filtersDialog = nil,
    neverSellDialog = nil,
    updateTicker = nil,
    currentVendorFilter = "Show All",
    showAllArmor = false,
    dimKnownItems = false,
    availableFilters = {},
    playerClass = nil,
    playerClassId = nil,
    oneTimeItems = { ilvlGear = {}, reagents = {} },
    collapsedCategories = { gray = false, marked = false, ilvlGear = false, reagents = false, noValueJunk = false },
    activeSellTicker = nil,
    activeSellConfirmTicker = nil,
    activeSellErrFrame = nil,
    vendorSellSeq = 0,
}
ns.VPState = state

local function GetItemStatus()
    return _G.OneWoW and _G.OneWoW.ItemStatus
end

-- ============================================================
-- Filter helpers (exposed in VPFilters for cross-file access)
-- ============================================================
local VPFilters = {}
ns.VPFilters = VPFilters

local function IsMount(itemLink)
    if not itemLink then return false end
    local itemType, itemSubType = select(6, C_Item.GetItemInfo(itemLink))
    return itemType == "Miscellaneous" and itemSubType == "Mount"
end

local function IsPet(itemLink)
    if not itemLink then return false end
    local itemID = C_Item.GetItemInfoInstant(itemLink)
    if itemID then
        local speciesID = C_PetJournal.GetPetInfoByItemID(itemID)
        return speciesID ~= nil
    end
    return false
end

local function IsToy(itemLink)
    if not itemLink then return false end
    local itemID = C_Item.GetItemInfoInstant(itemLink)
    if itemID then
        local toyName = C_ToyBox.GetToyInfo(itemID)
        return toyName ~= nil
    end
    return false
end

local function IsCosmetic(itemLink)
    if not itemLink then return false end
    local itemType, itemSubType = select(6, C_Item.GetItemInfo(itemLink))
    return itemType == "Armor" and itemSubType == "Cosmetic"
end

local function IsEnsemble(itemLink)
    if not itemLink then return false end
    if not _G["OneWoW_QoL_VendorEnsembleScanner"] then
        CreateFrame("GameTooltip", "OneWoW_QoL_VendorEnsembleScanner", nil, "GameTooltipTemplate")
    end
    local scanner = _G["OneWoW_QoL_VendorEnsembleScanner"]
    scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetHyperlink(itemLink)
    for i = 1, scanner:NumLines() do
        local line = _G["OneWoW_QoL_VendorEnsembleScannerTextLeft" .. i]
        if line and line:GetText() then
            local text = line:GetText()
            if text:find("Ensemble", 1, true) then return true end
            if text:find("Collect the appearances", 1, true) then return true end
        end
    end
    return false
end

local function IsAnyCosmetic(itemLink)
    if not itemLink then return false end
    return IsCosmetic(itemLink) or IsEnsemble(itemLink)
end

local function IsDecorItem(itemLink)
    if not itemLink then return false end
    if C_Item.IsDecorItem then
        return C_Item.IsDecorItem(itemLink)
    end
    return false
end

local function IsHousingItem(itemLink)
    if not itemLink then return false end
    local itemType = select(6, C_Item.GetItemInfo(itemLink))
    return itemType == "Housing"
end

local function IsConsumable(itemLink)
    if not itemLink then return false end
    local itemType = select(6, C_Item.GetItemInfo(itemLink))
    return itemType == "Consumable"
end

local function IsReagent(itemLink)
    if not itemLink then return false end
    local _, _, _, _, _, _, _, _, _, _, _, classID = select(6, C_Item.GetItemInfo(itemLink))
    local itemType = select(6, C_Item.GetItemInfo(itemLink))
    return itemType == "Reagent" or classID == Enum.ItemClass.Tradegoods
end

local function GetArmorTypeFromLink(itemLink)
    if not itemLink then return nil end
    local itemType, itemSubType = select(6, C_Item.GetItemInfo(itemLink))
    if itemType == "Armor" then return itemSubType end
    return nil
end

local CLASS_ARMOR = {
    WARRIOR = "Plate",
    PALADIN = "Plate",
    DEATHKNIGHT = "Plate",
    DEMONHUNTER = "Leather",
    ROGUE = "Leather",
    MONK = "Leather",
    DRUID = "Leather",
    HUNTER = "Mail",
    SHAMAN = "Mail",
    EVOKER = "Mail",
    MAGE = "Cloth",
    PRIEST = "Cloth",
    WARLOCK = "Cloth",
}

local ARMOR_TYPES = {
    ["Cloth"] = true,
    ["Leather"] = true,
    ["Mail"] = true,
    ["Plate"] = true,
}

local function GetPreferredArmor()
    return CLASS_ARMOR[state.playerClass]
end

local function IsAlreadyKnown(itemLink)
    if not itemLink then return false end

    local itemID = tonumber(itemLink:match("item:(%d+)"))
    if itemID then
        local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
        if classID == Enum.ItemClass.Recipe then
            local Util = OneWoW_RecipeKnownUtil
            if Util then
                local result = Util:IsRecipeKnown(itemID, itemLink)
                if result ~= nil then return result end
            end
        end
    end

    if not _G["OneWoW_QoL_VendorKnownScanner"] then
        CreateFrame("GameTooltip", "OneWoW_QoL_VendorKnownScanner", nil, "GameTooltipTemplate")
    end
    local scanner = _G["OneWoW_QoL_VendorKnownScanner"]
    scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetHyperlink(itemLink)
    for i = 1, scanner:NumLines() do
        local line = _G["OneWoW_QoL_VendorKnownScannerTextLeft" .. i]
        if line and line:GetText() then
            local text = line:GetText()
            local lower = text:lower()
            if text == ITEM_SPELL_KNOWN then return true end
            if lower:find("already known") then return true end
            if IsDecorItem(itemLink) then
                if text:find("Owned", 1, true) then return true end
            end
            local currentCount, maxCount = text:match("^Collected %((%d+)/(%d+)%)$")
            if currentCount and maxCount then
                currentCount = tonumber(currentCount)
                return currentCount and currentCount > 0
            end
        end
    end
    return false
end

local function GetProfessionFromTooltip(itemLink)
    if not itemLink then return nil end
    if not _G["OneWoW_QoL_VendorProfScanner"] then
        CreateFrame("GameTooltip", "OneWoW_QoL_VendorProfScanner", nil, "GameTooltipTemplate")
    end
    local scanner = _G["OneWoW_QoL_VendorProfScanner"]
    scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanner:SetHyperlink(itemLink)
    for i = 1, scanner:NumLines() do
        local line = _G["OneWoW_QoL_VendorProfScannerTextLeft" .. i]
        if line and line:GetText() then
            local text = line:GetText()
            if text:find("Alchemy", 1, true) then return "Alchemy" end
            if text:find("Blacksmithing", 1, true) then return "Blacksmithing" end
            if text:find("Cooking", 1, true) then return "Cooking" end
            if text:find("Enchanting", 1, true) then return "Enchanting" end
            if text:find("Engineering", 1, true) then return "Engineering" end
            if text:find("Inscription", 1, true) then return "Inscription" end
            if text:find("Jewelcrafting", 1, true) then return "Jewelcrafting" end
            if text:find("Leatherworking", 1, true) then return "Leatherworking" end
            if text:find("Tailoring", 1, true) then return "Tailoring" end
        end
    end
    return nil
end

local professionList = {
    ["Alchemy"] = true, ["Blacksmithing"] = true, ["Cooking"] = true,
    ["Enchanting"] = true, ["Engineering"] = true, ["Inscription"] = true,
    ["Jewelcrafting"] = true, ["Leatherworking"] = true, ["Tailoring"] = true,
}

local slotFilterMap = {
    ["Head"] = "INVTYPE_HEAD", ["Neck"] = "INVTYPE_NECK", ["Shoulder"] = "INVTYPE_SHOULDER",
    ["Back"] = "INVTYPE_CLOAK", ["Chest"] = "INVTYPE_CHEST", ["Waist"] = "INVTYPE_WAIST",
    ["Legs"] = "INVTYPE_LEGS", ["Feet"] = "INVTYPE_FEET", ["Wrist"] = "INVTYPE_WRIST",
    ["Hands"] = "INVTYPE_HAND", ["Rings"] = "INVTYPE_FINGER", ["Trinkets"] = "INVTYPE_TRINKET",
}

local weaponSlots = {
    INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true, INVTYPE_RANGED = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true,
}

function VPFilters.CheckVendorItemFilter(itemLink, filterType)
    if not itemLink then return false end

    local matches = true

    if filterType == "Show All" then
        matches = true
    elseif filterType == "Mounts" then
        matches = IsMount(itemLink)
    elseif filterType == "Pets" then
        matches = IsPet(itemLink)
    elseif filterType == "Toys" then
        matches = IsToy(itemLink)
    elseif filterType == "Cosmetic Items" then
        matches = IsAnyCosmetic(itemLink)
    elseif filterType == "Decor" then
        matches = IsDecorItem(itemLink)
    elseif filterType == "Housing" then
        matches = IsHousingItem(itemLink)
    elseif filterType == "Consumables" then
        matches = IsConsumable(itemLink)
    elseif filterType == "Reagents" then
        matches = IsReagent(itemLink)
    elseif filterType == "Equipable" then
        local equipSlot = select(9, C_Item.GetItemInfo(itemLink))
        matches = equipSlot and equipSlot ~= "" and equipSlot ~= "INVTYPE_NON_EQUIP_IGNORE"
    elseif filterType == "Weapons" then
        local equipSlot = select(9, C_Item.GetItemInfo(itemLink))
        matches = weaponSlots[equipSlot] or false
    elseif filterType == "Patterns" or filterType == "All Patterns" then
        local itemType = select(6, C_Item.GetItemInfo(itemLink))
        matches = itemType == "Recipe"
    elseif professionList[filterType] then
        local profession = GetProfessionFromTooltip(itemLink)
        matches = (profession == filterType)
    elseif slotFilterMap[filterType] then
        local equipSlot = select(9, C_Item.GetItemInfo(itemLink))
        matches = (equipSlot == slotFilterMap[filterType])
    end

    return matches
end

function VPFilters.ScanVendor()
    wipe(state.availableFilters)
    local nonEquipSlots = {
        ["INVTYPE_NON_EQUIP_IGNORE"] = true, ["INVTYPE_BAG"] = true,
        ["INVTYPE_TABARD"] = true, ["INVTYPE_RELIC"] = true,
    }
    local slotLabels = {
        ["INVTYPE_HEAD"] = "Head", ["INVTYPE_NECK"] = "Neck", ["INVTYPE_SHOULDER"] = "Shoulder",
        ["INVTYPE_CLOAK"] = "Back", ["INVTYPE_CHEST"] = "Chest", ["INVTYPE_WAIST"] = "Waist",
        ["INVTYPE_LEGS"] = "Legs", ["INVTYPE_FEET"] = "Feet", ["INVTYPE_WRIST"] = "Wrist",
        ["INVTYPE_HAND"] = "Hands", ["INVTYPE_FINGER"] = "Rings", ["INVTYPE_TRINKET"] = "Trinkets",
        ["INVTYPE_WEAPON"] = "Weapons", ["INVTYPE_2HWEAPON"] = "Weapons",
        ["INVTYPE_WEAPONMAINHAND"] = "Weapons", ["INVTYPE_WEAPONOFFHAND"] = "Weapons",
        ["INVTYPE_RANGED"] = "Weapons", ["INVTYPE_SHIELD"] = "Weapons", ["INVTYPE_HOLDABLE"] = "Weapons",
    }
    for i = 1, GetMerchantNumItems() do
        local itemLink = GetMerchantItemLink(i)
        if itemLink then
            local itemType, itemSubType, _, equipSlot = select(6, C_Item.GetItemInfo(itemLink))
            local armorType = GetArmorTypeFromLink(itemLink)
            if armorType then state.availableFilters[armorType] = true end
            local label = slotLabels[equipSlot]
            if equipSlot and not nonEquipSlots[equipSlot] and label then
                state.availableFilters["Equipable"] = true
                state.availableFilters[label] = true
            elseif IsMount(itemLink) then state.availableFilters["Mounts"] = true
            elseif itemType == "Recipe" then
                state.availableFilters["Patterns"] = true
                local profession = GetProfessionFromTooltip(itemLink)
                if profession then state.availableFilters[profession] = true end
            elseif IsPet(itemLink) then state.availableFilters["Pets"] = true
            elseif IsToy(itemLink) then state.availableFilters["Toys"] = true
            elseif IsAnyCosmetic(itemLink) then state.availableFilters["Cosmetic Items"] = true
            elseif IsDecorItem(itemLink) then state.availableFilters["Decor"] = true
            elseif IsHousingItem(itemLink) then state.availableFilters["Housing"] = true
            elseif IsConsumable(itemLink) then state.availableFilters["Consumables"] = true
            elseif IsReagent(itemLink) then state.availableFilters["Reagents"] = true
            end
        end
    end
end

function VPFilters.FormatMoney(amount)
    if amount <= 0 then return "0c" end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    local formatted = ""
    if gold > 0 then formatted = formatted .. gold .. "g" end
    if silver > 0 then formatted = formatted .. (formatted ~= "" and " " or "") .. silver .. "s" end
    if copper > 0 or formatted == "" then formatted = formatted .. (formatted ~= "" and " " or "") .. copper .. "c" end
    return formatted
end

-- ============================================================
-- VendorPanel
-- ============================================================
local VendorPanel = {}
ns.VendorPanel = VendorPanel

function VendorPanel:IsItemInNeverSellList(itemID)
    return GetItemStatus():IsItemProtected(itemID)
end

function VendorPanel:AddToNeverSellList(itemID, itemLink)
    if not itemID then return end
    if GetItemStatus():IsItemJunk(itemID) then GetItemStatus():RemoveItemStatus(itemID) end
    GetItemStatus():MarkAsProtected(itemID, itemLink)
    print("OneWoW QoL: " .. ns.L["VENDOR_ITEM_PROTECTED"])
    C_Timer.After(0.1, function()
        VendorPanel:UpdatePreviewPanel()
        VendorPanel:UpdateButton()
        if state.neverSellDialog and state.neverSellDialog:IsShown() then
            VendorPanel:UpdateNeverSellDialog()
        end
        if state.filtersDialog and state.filtersDialog:IsShown() and state.filtersDialog.neverSellBtnText then
            VendorPanel:UpdateNeverSellButtonCount()
        end
    end)
end

function VendorPanel:RemoveFromNeverSellList(itemID)
    if not itemID then return end
    GetItemStatus():RemoveItemStatus(itemID)
    print("OneWoW QoL: " .. ns.L["VENDOR_PROTECTION_REMOVED"])
    C_Timer.After(0.1, function()
        VendorPanel:UpdatePreviewPanel()
        VendorPanel:UpdateButton()
        if state.filtersDialog and state.filtersDialog:IsShown() and state.filtersDialog.neverSellBtnText then
            VendorPanel:UpdateNeverSellButtonCount()
        end
    end)
end

function VendorPanel:GetNeverSellList()
    local protectedItems = {}
    local allStatuses = GetItemStatus():GetAllStatuses()
    for itemID, statusData in pairs(allStatuses) do
        if statusData.status == "Protected" then
            protectedItems[itemID] = statusData.link or true
        end
    end
    return protectedItems
end

function VendorPanel:UpdateNeverSellButtonCount()
    if not state.filtersDialog or not state.filtersDialog.neverSellBtnText then return end
    local count = 0
    for _ in pairs(self:GetNeverSellList()) do count = count + 1 end
    state.filtersDialog.neverSellBtnText:SetText(string.format(ns.L["VENDOR_PROTECTED_ITEMS"] .. " (%d)", count))
end

function VendorPanel:GetOneTimeItems()
    return state.oneTimeItems
end

function VendorPanel:SellJunkItems()
    if state.activeSellTicker then
        state.activeSellTicker:Cancel()
        state.activeSellTicker = nil
    end
    if state.activeSellConfirmTicker then
        state.activeSellConfirmTicker:Cancel()
        state.activeSellConfirmTicker = nil
    end
    state.vendorSellSeq = (state.vendorSellSeq or 0) + 1
    local sellSeq = state.vendorSellSeq

    local oneTime = state.oneTimeItems
    local itemsToSell = {}

    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, itemLink, quality, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemInfo.itemID)
                    if itemName and sellPrice and sellPrice > 0 then
                        local itemLevel, actualQuality = 0, quality
                        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                        if itemLocation and C_Item.DoesItemExist(itemLocation) then
                            local item = Item:CreateFromItemLocation(itemLocation)
                            if item and item:IsItemDataCached() then
                                itemLevel = item:GetCurrentItemLevel() or 0
                                actualQuality = item:GetItemQuality() or quality
                            end
                        end
                        local isGray = quality == 0
                        local isMarked = GetItemStatus():IsItemJunk(itemInfo.itemID)
                        local isIlvlGear = oneTime.ilvlGear and oneTime.ilvlGear[itemInfo.itemID]
                        local isReagent = oneTime.reagents and oneTime.reagents[itemInfo.itemID]
                        local isJunkItem = isGray or isMarked or isIlvlGear or isReagent
                        if GetItemStatus():IsItemProtected(itemInfo.itemID) then isJunkItem = false end
                        if isJunkItem and not itemInfo.hasNoValue and sellPrice and sellPrice > 0 then
                            table.insert(itemsToSell, {
                                bag = bag, slot = slot, itemID = itemInfo.itemID,
                                name = itemName, sellPrice = sellPrice * (itemInfo.stackCount or 1),
                                isGray = isGray, isMarked = isMarked, isIlvlGear = isIlvlGear, isReagent = isReagent
                            })
                        end
                    end
                end
            end
        end
    end

    if #itemsToSell == 0 then
        print("OneWoW QoL: " .. ns.L["VENDOR_NO_JUNK"])
        return
    end

    local vendorRefused = false
    local sellDone = false
    local pendingSells = {}
    local actualSoldCount = 0
    local actualGold = 0
    local grayCount, markedCount, ilvlGearCount, reagentsCount = 0, 0, 0, 0
    local confirmTicker, sellTicker
    local summaryPrinted = false

    if not state.activeSellErrFrame then
        state.activeSellErrFrame = CreateFrame("Frame")
    end
    local errFrame = state.activeSellErrFrame
    errFrame:RegisterEvent("UI_ERROR_MESSAGE")
    errFrame:SetScript("OnEvent", function(self, event, _, msg)
        if msg == ERR_VENDOR_DOESNT_BUY then
            vendorRefused = true
            errFrame:UnregisterEvent("UI_ERROR_MESSAGE")
            wipe(pendingSells)
            if sellTicker then sellTicker:Cancel() end
            if confirmTicker then confirmTicker:Cancel() end
            if state.vendorSellSeq == sellSeq then
                state.activeSellTicker = nil
                state.activeSellConfirmTicker = nil
            end
            print("OneWoW QoL: " .. ns.L["VENDOR_DOES_NOT_BUY"])
        end
    end)

    confirmTicker = C_Timer.NewTicker(0, function()
        if state.vendorSellSeq ~= sellSeq then
            if confirmTicker then confirmTicker:Cancel() end
            return
        end
        if vendorRefused then
            if confirmTicker then confirmTicker:Cancel() end
            if state.vendorSellSeq == sellSeq then
                state.activeSellConfirmTicker = nil
            end
            return
        end

        for i = #pendingSells, 1, -1 do
            local item = pendingSells[i]
            if C_Container.GetContainerItemID(item.bag, item.slot) ~= item.itemID then
                actualSoldCount = actualSoldCount + 1
                actualGold = actualGold + item.sellPrice
                if item.isGray then grayCount = grayCount + 1
                elseif item.isMarked then markedCount = markedCount + 1
                elseif item.isIlvlGear then ilvlGearCount = ilvlGearCount + 1
                elseif item.isReagent then reagentsCount = reagentsCount + 1
                end
                table.remove(pendingSells, i)
            end
        end

        if sellDone and #pendingSells == 0 then
            if summaryPrinted then return end
            summaryPrinted = true
            errFrame:UnregisterEvent("UI_ERROR_MESSAGE")
            if confirmTicker then confirmTicker:Cancel() end
            if state.vendorSellSeq == sellSeq then
                state.activeSellConfirmTicker = nil
            end
            if actualSoldCount > 0 then
                local moneyStr = VPFilters.FormatMoney(actualGold)
                local categoryParts = {}
                if grayCount > 0 then table.insert(categoryParts, grayCount .. " " .. ns.L["VENDOR_SOLD_GRAY"]) end
                if markedCount > 0 then table.insert(categoryParts, markedCount .. " " .. ns.L["VENDOR_SOLD_MARKED"]) end
                if ilvlGearCount > 0 then table.insert(categoryParts, ilvlGearCount .. " " .. ns.L["VENDOR_SOLD_ILVL"]) end
                if reagentsCount > 0 then table.insert(categoryParts, reagentsCount .. " " .. ns.L["VENDOR_SOLD_REAGENT"]) end
                local categoryStr = table.concat(categoryParts, ", ")
                print("OneWoW QoL: " .. string.format(ns.L["VENDOR_SOLD"], actualSoldCount, categoryStr, moneyStr))
            end
        end
    end)
    state.activeSellConfirmTicker = confirmTicker

    local currentIndex = 1
    sellTicker = C_Timer.NewTicker(0.3, function()
        if state.vendorSellSeq ~= sellSeq then
            if sellTicker then sellTicker:Cancel() end
            return
        end
        if vendorRefused then
            if sellTicker then sellTicker:Cancel() end
            if state.vendorSellSeq == sellSeq then
                state.activeSellTicker = nil
            end
            return
        end
        if currentIndex > #itemsToSell then
            if sellTicker then sellTicker:Cancel() end
            if state.vendorSellSeq == sellSeq then
                state.activeSellTicker = nil
            end
            sellDone = true
            return
        end
        local item = itemsToSell[currentIndex]
        table.insert(pendingSells, item)
        ClearCursor()
        C_Container.PickupContainerItem(item.bag, item.slot)
        SellCursorItem()
        currentIndex = currentIndex + 1
    end)
    state.activeSellTicker = sellTicker
end

function VendorPanel:GetJunkItemCount()
    local count = 0
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local _, _, quality, _, _, _, _, _, _, _, sellPrice, classID, subclassID = C_Item.GetItemInfo(itemInfo.itemID)
                    local itemLevel, actualQuality = 0, quality
                    local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                    if itemLocation and C_Item.DoesItemExist(itemLocation) then
                        local item = Item:CreateFromItemLocation(itemLocation)
                        if item and item:IsItemDataCached() then
                            itemLevel = item:GetCurrentItemLevel() or 0
                            actualQuality = item:GetItemQuality() or quality
                        end
                    end
                    if not self:IsItemInNeverSellList(itemInfo.itemID) and
                       not (GetItemStatus():IsItemProtected(itemInfo.itemID)) then
                        local isUserMarked = GetItemStatus():IsItemJunk(itemInfo.itemID)
                        local isGray = quality and quality == 0
                        local isGameJunk = (classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.Junk)
                        local isIlvlGear = state.oneTimeItems.ilvlGear[itemInfo.itemID]
                        local isReagent = state.oneTimeItems.reagents[itemInfo.itemID]
                        local isJunkItem = false
                        if isUserMarked then isJunkItem = true
                        elseif isIlvlGear or isReagent then isJunkItem = true
                        elseif (isGray or isGameJunk) and GetShowBlizzJunk() then isJunkItem = true
                        end
                        if isJunkItem and not itemInfo.hasNoValue and sellPrice and sellPrice > 0 then
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
    return count
end

function VendorPanel:GetDestroyableItemCount()
    local count = 0
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local _, _, quality, _, _, _, _, _, _, _, sellPrice, classID, subclassID = C_Item.GetItemInfo(itemInfo.itemID)
                    local itemLevel, actualQuality = 0, quality
                    local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                    if itemLocation and C_Item.DoesItemExist(itemLocation) then
                        local item = Item:CreateFromItemLocation(itemLocation)
                        if item and item:IsItemDataCached() then
                            itemLevel = item:GetCurrentItemLevel() or 0
                            actualQuality = item:GetItemQuality() or quality
                        end
                    end
                    if not self:IsItemInNeverSellList(itemInfo.itemID) and
                       not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                        local isUserMarked = GetItemStatus():IsItemJunk(itemInfo.itemID)
                        local isGray = quality and quality == 0
                        local isGameJunk = (classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.Junk)
                        local isIlvlGear = state.oneTimeItems.ilvlGear[itemInfo.itemID]
                        local isReagent = state.oneTimeItems.reagents[itemInfo.itemID]
                        local isJunkItem = false
                        if isUserMarked then isJunkItem = true
                        elseif isIlvlGear or isReagent then isJunkItem = true
                        elseif (isGray or isGameJunk) and GetShowBlizzJunk() then isJunkItem = true
                        end
                        if isJunkItem and (itemInfo.hasNoValue or not sellPrice or sellPrice == 0) then
                            count = count + 1
                        end
                    end
                end
            end
        end
    end
    return count
end

function VendorPanel:DestroyNextJunkItem()
    if InCombatLockdown() then
        print("OneWoW QoL: Cannot destroy items while in combat.")
        return
    end
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, itemLink, quality, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemInfo.itemID)
                    local itemLevel, actualQuality = 0, quality
                    local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                    if itemLocation and C_Item.DoesItemExist(itemLocation) then
                        local item = Item:CreateFromItemLocation(itemLocation)
                        if item and item:IsItemDataCached() then
                            itemLevel = item:GetCurrentItemLevel() or 0
                            actualQuality = item:GetItemQuality() or quality
                        end
                    end
                    if not self:IsItemInNeverSellList(itemInfo.itemID) and
                       not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                        local isUserMarked = GetItemStatus():IsItemJunk(itemInfo.itemID)
                        local isGray = quality and quality == 0
                        local classID, subclassID = select(12, C_Item.GetItemInfo(itemInfo.itemID))
                        local isGameJunk = (classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.Junk)
                        local isIlvlGear = state.oneTimeItems.ilvlGear[itemInfo.itemID]
                        local isReagent = state.oneTimeItems.reagents[itemInfo.itemID]
                        local isJunkItem = isUserMarked or isGray or isGameJunk or isIlvlGear or isReagent
                        if isJunkItem and (itemInfo.hasNoValue or not sellPrice or sellPrice == 0) then
                            local shouldDestroy = false
                            if isUserMarked or isIlvlGear or isReagent then shouldDestroy = true
                            elseif (isGray or isGameJunk) and GetShowBlizzJunk() then shouldDestroy = true
                            end
                            if shouldDestroy then
                                ClearCursor()
                                C_Container.PickupContainerItem(bag, slot)
                                DeleteCursorItem()
                                print("OneWoW QoL: Destroyed " .. (itemLink or itemName or "item") .. ".")
                                C_Timer.After(0.2, function()
                                    VendorPanel:UpdatePreviewPanel()
                                    VendorPanel:UpdateButton()
                                end)
                                return
                            end
                        end
                    end
                end
            end
        end
    end
    print("OneWoW QoL: No junk items to destroy.")
end

function VendorPanel:DeleteAllNoValueJunk()
    if InCombatLockdown() then
        print("OneWoW QoL: Cannot delete items while in combat.")
        return
    end
    local itemsToDelete = {}
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, itemLink, quality, _, _, _, _, _, _, _, sellPrice, classID, subclassID = C_Item.GetItemInfo(itemInfo.itemID)
                    local itemLevel, actualQuality = 0, quality
                    local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                    if itemLocation and C_Item.DoesItemExist(itemLocation) then
                        local item = Item:CreateFromItemLocation(itemLocation)
                        if item and item:IsItemDataCached() then
                            itemLevel = item:GetCurrentItemLevel() or 0
                            actualQuality = item:GetItemQuality() or quality
                        end
                    end
                    if not self:IsItemInNeverSellList(itemInfo.itemID) and
                       not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                        local isUserMarked = GetItemStatus():IsItemJunk(itemInfo.itemID)
                        local isGray = quality and quality == 0
                        local isGameJunk = (classID == Enum.ItemClass.Miscellaneous and subclassID == Enum.ItemMiscellaneousSubclass.Junk)
                        local isIlvlGear = state.oneTimeItems.ilvlGear[itemInfo.itemID]
                        local isReagent = state.oneTimeItems.reagents[itemInfo.itemID]
                        local shouldDelete = false
                        if isUserMarked or isIlvlGear or isReagent then shouldDelete = true
                        elseif (isGray or isGameJunk) and GetShowBlizzJunk() then shouldDelete = true
                        end
                        if shouldDelete and (itemInfo.hasNoValue or not sellPrice or sellPrice == 0) then
                            table.insert(itemsToDelete, { bag = bag, slot = slot, link = itemLink, name = itemName })
                        end
                    end
                end
            end
        end
    end
    if #itemsToDelete == 0 then
        print("OneWoW QoL: No no-value junk items to delete.")
        return
    end
    print("OneWoW QoL: Deleting " .. #itemsToDelete .. " no-value junk items...")
    local currentIndex = 1
    local deleteTicker
    deleteTicker = C_Timer.NewTicker(0.2, function()
        if currentIndex > #itemsToDelete then
            deleteTicker:Cancel()
            print("OneWoW QoL: Deleted " .. #itemsToDelete .. " no-value junk items.")
            C_Timer.After(0.2, function()
                VendorPanel:UpdatePreviewPanel()
                VendorPanel:UpdateButton()
            end)
            return
        end
        local item = itemsToDelete[currentIndex]
        ClearCursor()
        C_Container.PickupContainerItem(item.bag, item.slot)
        DeleteCursorItem()
        currentIndex = currentIndex + 1
    end)
end

function VendorPanel:AddNonSoulboundReagents()
    local count = 0
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, _, quality, _, _, _, _, _, _, _, sellPrice, classID = C_Item.GetItemInfo(itemInfo.itemID)
                    if itemName and sellPrice and sellPrice > 0 then
                        local itemLevel, actualQuality = 0, quality
                        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                        if itemLocation and C_Item.DoesItemExist(itemLocation) then
                            local item = Item:CreateFromItemLocation(itemLocation)
                            if item and item:IsItemDataCached() then
                                itemLevel = item:GetCurrentItemLevel() or 0
                                actualQuality = item:GetItemQuality() or quality
                            end
                        end
                        if not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                            local alreadyJunk = GetItemStatus():IsItemJunk(itemInfo.itemID)
                            if quality ~= 0 and not alreadyJunk then
                                local isReagent = (classID == Enum.ItemClass.Reagent or classID == Enum.ItemClass.Tradegoods)
                                if isReagent then
                                    local isSoulbound = itemLocation and C_Item.IsBound(itemLocation)
                                    if not isSoulbound then
                                        state.oneTimeItems.reagents[itemInfo.itemID] = true
                                        count = count + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if count > 0 then
        print("OneWoW QoL: Added " .. count .. " non-soulbound reagents/tradeskill items to sell list.")
        self:UpdatePreviewPanel()
        self:UpdateButton()
    else
        print("OneWoW QoL: No non-soulbound reagents or tradeskill items found.")
    end
end

function VendorPanel:AddConsumables()
    local count = 0
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, _, quality, _, _, _, _, _, _, _, sellPrice, classID = C_Item.GetItemInfo(itemInfo.itemID)
                    if itemName and sellPrice and sellPrice > 0 then
                        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                        if not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                            local alreadyJunk = GetItemStatus():IsItemJunk(itemInfo.itemID)
                            if quality ~= 0 and not alreadyJunk and classID == Enum.ItemClass.Consumable then
                                local isSoulbound = itemLocation and C_Item.IsBound(itemLocation)
                                if not isSoulbound then
                                    state.oneTimeItems.reagents[itemInfo.itemID] = true
                                    count = count + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if count > 0 then
        print("OneWoW QoL: Added " .. count .. " non-soulbound consumables to sell list.")
        self:UpdatePreviewPanel()
        self:UpdateButton()
    else
        print("OneWoW QoL: No non-soulbound consumables found.")
    end
end

function VendorPanel:AddWhiteQuality()
    local count = 0
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, _, quality, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemInfo.itemID)
                    if itemName and sellPrice and sellPrice > 0 then
                        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                        if not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                            local alreadyJunk = GetItemStatus():IsItemJunk(itemInfo.itemID)
                            if quality == 1 and not alreadyJunk then
                                local isSoulbound = itemLocation and C_Item.IsBound(itemLocation)
                                if not isSoulbound then
                                    state.oneTimeItems.reagents[itemInfo.itemID] = true
                                    count = count + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if count > 0 then
        print("OneWoW QoL: Added " .. count .. " white quality items to sell list.")
        self:UpdatePreviewPanel()
        self:UpdateButton()
    else
        print("OneWoW QoL: No white quality items found.")
    end
end

function VendorPanel:AddGearBelowIlvl(targetIlvl)
    local count = 0
    local excludeIlvl1 = true
    if state.filtersDialog and state.filtersDialog.excludeIlvl1 then
        excludeIlvl1 = state.filtersDialog.excludeIlvl1:GetChecked()
    end
    for bag = 0, NUM_BAG_SLOTS + 1 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
                if itemInfo and itemInfo.itemID then
                    local itemName, _, quality, _, _, _, _, _, _, _, sellPrice, classID = C_Item.GetItemInfo(itemInfo.itemID)
                    if itemName and sellPrice and sellPrice > 0 then
                        local itemLevel, actualQuality = 0, quality
                        local itemLocation = ItemLocation:CreateFromBagAndSlot(bag, slot)
                        if itemLocation and C_Item.DoesItemExist(itemLocation) then
                            local item = Item:CreateFromItemLocation(itemLocation)
                            if item and item:IsItemDataCached() then
                                itemLevel = item:GetCurrentItemLevel() or 0
                                actualQuality = item:GetItemQuality() or quality
                            end
                        end
                        if not GetItemStatus():IsItemProtected(itemInfo.itemID) then
                            local alreadyJunk = GetItemStatus():IsItemJunk(itemInfo.itemID)
                            if quality ~= 0 and not alreadyJunk then
                                local isEquipment = (classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor)
                                if isEquipment and itemLevel and itemLevel < targetIlvl then
                                    if not (excludeIlvl1 and itemLevel == 1) then
                                        state.oneTimeItems.ilvlGear[itemInfo.itemID] = true
                                        count = count + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if count > 0 then
        print("OneWoW QoL: Added " .. count .. " items below iLvl " .. targetIlvl .. " to sell list.")
        self:UpdatePreviewPanel()
        self:UpdateButton()
    else
        print("OneWoW QoL: No gear found below iLvl " .. targetIlvl .. ".")
    end
end

function VendorPanel:UpdateButton()
    if not state.vendorButton then return end
    local junkCount = self:GetJunkItemCount()
    local destroyCount = self:GetDestroyableItemCount()
    if junkCount > 0 or destroyCount > 0 then
        state.vendorButton:SetText(string.format(ns.L["VENDOR_SELL_COUNTS"], junkCount, destroyCount))
        state.vendorButton:Enable()
        state.vendorButton:SetAlpha(1.0)
    else
        state.vendorButton:SetText(string.format(ns.L["VENDOR_SELL_COUNTS"], 0, 0))
        state.vendorButton:Disable()
        state.vendorButton:SetAlpha(0.6)
    end
end

function VendorPanel:UpdatePanelToggleButton()
    if not state.panelToggleTab then return end
    local panelShown = state.junkPreviewPanel and state.junkPreviewPanel:IsShown()
    state.panelToggleTab:SetChecked(panelShown)
    local gui = LibStub("OneWoW_GUI-1.0", true)
    if gui then
        local theme = (gui.GetSetting and gui:GetSetting("minimap.theme")) or "horde"
        state.panelToggleTab.Icon:SetTexture(gui:GetBrandIcon(theme))
    end
    state.panelToggleTab.Icon:SetSize(24, 24)
end

function VendorPanel:ManageBlizzardSellButton(hideIt)
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    local blizzButton = _G["MerchantSellAllJunkButton"]
    if not blizzButton then return end
    if hideIt then
        blizzButton:Hide()
        if not state.replacementSellButton then self:CreateReplacementSellButton() end
        if state.replacementSellButton then state.replacementSellButton:Show() end
    else
        blizzButton:Show()
        if state.replacementSellButton then state.replacementSellButton:Hide() end
    end
end

function VendorPanel:TogglePreviewPanel()
    if state._merchantToggleHandler then
        state._merchantToggleHandler()
        return
    end

    if not state.junkPreviewPanel then self:CreatePreviewPanel() end
    if state.junkPreviewPanel:IsShown() then
        state.junkPreviewPanel.manuallyHidden = true
        state.junkPreviewPanel:Hide()
        if state.filtersDialog then state.filtersDialog:Hide() end
        self:ManageBlizzardSellButton(false)
    else
        state.junkPreviewPanel.manuallyHidden = false
        state.junkPreviewPanel:Show()
        self:UpdatePreviewPanel()
        self:ManageBlizzardSellButton(true)
    end
    self:UpdatePanelToggleButton()
end

function VendorPanel:ToggleFiltersDialog()
    if not state.filtersDialog then self:CreateFiltersDialog() end
    if state.filtersDialog:IsShown() then
        state.filtersDialog:Hide()
        return
    end
    if not state.junkPreviewPanel or not state.junkPreviewPanel:IsShown() then return end
    local neverSellCount = 0
    for _ in pairs(self:GetNeverSellList()) do neverSellCount = neverSellCount + 1 end
    if state.filtersDialog.neverSellBtnText then
        state.filtersDialog.neverSellBtnText:SetText(string.format(ns.L["VENDOR_PROTECTED_ITEMS"] .. " (%d)", neverSellCount))
    end
    local screenWidth = GetScreenWidth() * UIParent:GetEffectiveScale()
    local panelRight = state.junkPreviewPanel:GetRight()
    local spaceOnRight = screenWidth - panelRight
    state.filtersDialog:ClearAllPoints()
    if spaceOnRight >= 210 then
        state.filtersDialog:SetPoint("TOPLEFT", state.junkPreviewPanel, "TOPRIGHT", 5, 0)
    else
        state.filtersDialog:SetPoint("CENTER", state.junkPreviewPanel, "CENTER", 0, 0)
    end
    state.filtersDialog:Show()
end

function VendorPanel:ToggleNeverSellDialog()
    if not state.neverSellDialog then self:CreateNeverSellDialog() end
    if state.neverSellDialog:IsShown() then
        state.neverSellDialog:Hide()
    else
        self:UpdateNeverSellDialog()
        state.neverSellDialog:ClearAllPoints()
        state.neverSellDialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        state.neverSellDialog:Show()
    end
end

function VendorPanel:StartUpdates()
    if state.updateTicker then return end
    state.updateTicker = C_Timer.NewTicker(5.0, function()
        if InCombatLockdown() or IsInInstance() then return end
        VendorPanel:UpdateButton()
        VendorPanel:UpdatePreviewPanel()
    end)
end

function VendorPanel:StopUpdates()
    if state.updateTicker then
        state.updateTicker:Cancel()
        state.updateTicker = nil
    end
end

function VendorPanel:OnMerchantShow()
    state.currentVendorFilter = "Show All"
    local settings = GetSettings()
    state.showAllArmor = settings.showAllArmor or false
    state.dimKnownItems = settings.dimKnownItems or false

    if not state.vendorButton then
        self:CreateVendorButton()
    end
    state.vendorButton:Show()
    self:UpdateButton()

    if not state.panelToggleTab then self:CreatePanelToggleButton() end

    if GetShowPanel() then
        if not state.junkPreviewPanel then self:CreatePreviewPanel() end
        C_Timer.After(0.25, function()
            VPFilters.ScanVendor()
            if state.junkPreviewPanel and state.junkPreviewPanel.vendorDropdown and state.junkPreviewPanel.vendorDropdown.RefreshFilters then
                state.junkPreviewPanel.vendorDropdown:RefreshFilters()
            end
        end)
        self:UpdatePreviewPanel()
        if state.junkPreviewPanel and state.junkPreviewPanel:IsShown() then
            self:ManageBlizzardSellButton(true)
            if state.panelToggleTab then
                state.panelToggleTab:SetChecked(true)
                local gui = LibStub("OneWoW_GUI-1.0", true)
                if gui then
                    local theme = (gui.GetSetting and gui:GetSetting("minimap.theme")) or "horde"
                    state.panelToggleTab.Icon:SetTexture(gui:GetBrandIcon(theme))
                end
                state.panelToggleTab.Icon:SetSize(24, 24)
                if MerchantFrameTabSideBar then
                    MerchantFrameTabSideBar.selTab = state._merchantSidebarIndex or 0
                end
            end
            if VendorPanel.RepositionMerchantSidebar then
                VendorPanel:RepositionMerchantSidebar()
            end
        end
    end

    C_Timer.After(0, function() VendorPanel:UpdatePanelToggleButton() end)
end

function VendorPanel:OnMerchantClosed()
    self:StopUpdates()
    if state.activeSellTicker then state.activeSellTicker:Cancel(); state.activeSellTicker = nil end
    if state.activeSellConfirmTicker then state.activeSellConfirmTicker:Cancel(); state.activeSellConfirmTicker = nil end
    state.vendorSellSeq = (state.vendorSellSeq or 0) + 1
    if state.activeSellErrFrame then state.activeSellErrFrame:UnregisterEvent("UI_ERROR_MESSAGE") end
    if state.vendorButton then state.vendorButton:Hide() end
    if state.panelToggleTab then state.panelToggleTab:SetChecked(false) end
    if state.junkPreviewPanel then state.junkPreviewPanel:Hide() end
    self:ManageBlizzardSellButton(false)
    if state.filtersDialog then state.filtersDialog:Hide() end
    if state.neverSellDialog then state.neverSellDialog:Hide() end
    state.currentVendorFilter = "Show All"
    wipe(state.availableFilters)
    state.oneTimeItems.ilvlGear = {}
    state.oneTimeItems.reagents = {}
end

-- ============================================================
-- Module
-- ============================================================
local VendorPanelModule = {}
ns.VendorPanelModule = VendorPanelModule

VendorPanelModule.id = "vendorpanel"
VendorPanelModule.title = "VENDORPANEL_TITLE"
VendorPanelModule.category = "ECONOMY"
VendorPanelModule.description = "VENDORPANEL_DESC"
VendorPanelModule.version = "1.0"
VendorPanelModule.author = "MichinMuggin / Ricky"
VendorPanelModule.contact = "https://wow2.xyz/"
VendorPanelModule.link = "https://wow2.xyz/"
VendorPanelModule.toggles = {
    { id = "show_panel", label = "VENDORPANEL_SHOW_PANEL", description = "VENDORPANEL_SHOW_PANEL_DESC", default = true },
    { id = "show_blizz_junk", label = "VENDORPANEL_SHOW_BLIZZ_JUNK", description = "VENDORPANEL_SHOW_BLIZZ_JUNK_DESC", default = false },
}
VendorPanelModule.preview = true
VendorPanelModule.defaultEnabled = true

function VendorPanelModule:OnEnable()
    local db = GetDB()
    if not db then return end
    if not db.settings then db.settings = {} end
    if not db.settings.panelWidth then db.settings.panelWidth = 320 end

    local coreIS = GetItemStatus()
    if coreIS and (db.itemStatus or db.charItemStatus) then
        local coreDB = _G.OneWoW and _G.OneWoW.db and _G.OneWoW.db.global and _G.OneWoW.db.global.itemStatus
        if coreDB then
            local migrated = 0
            if db.itemStatus then
                for itemID, statusData in pairs(db.itemStatus) do
                    if not coreDB[tonumber(itemID)] then
                        coreDB[tonumber(itemID)] = statusData
                        migrated = migrated + 1
                    end
                end
            end
            if db.charItemStatus then
                for itemID, statusData in pairs(db.charItemStatus) do
                    if not coreDB[tonumber(itemID)] then
                        coreDB[tonumber(itemID)] = statusData
                        migrated = migrated + 1
                    end
                end
            end
            if migrated > 0 then
                print("|cFF00FF00OneWoW QoL|r: Migrated " .. migrated .. " item statuses to OneWoW Core")
            end
            db.itemStatus = nil
            db.charItemStatus = nil
        end
    end

    if coreIS and coreIS.RegisterCallback then
        coreIS:RegisterCallback("vendorpanel", function()
            if MerchantFrame and MerchantFrame:IsShown() then
                VendorPanel:UpdatePreviewPanel()
                VendorPanel:UpdateButton()
            end
            if state.neverSellDialog and state.neverSellDialog:IsShown() then
                VendorPanel:UpdateNeverSellDialog()
            end
        end)
    end

    if not state.playerClass then
        local _, classFilename, classId = UnitClass("player")
        state.playerClass = classFilename
        state.playerClassId = classId
    end

    if not self._eventFrame then
        local frame = CreateFrame("Frame", "OneWoW_QoL_VendorPanelEvents")
        self._eventFrame = frame
        frame:SetScript("OnEvent", function(f, event)
            if event == "MERCHANT_SHOW" then
                VendorPanel:OnMerchantShow()
            elseif event == "MERCHANT_CLOSED" then
                VendorPanel:OnMerchantClosed()
            elseif event == "BAG_UPDATE" then
                VendorPanel:UpdateButton()
                VendorPanel:UpdatePreviewPanel()
            end
        end)
    end
    self._eventFrame:RegisterEvent("MERCHANT_SHOW")
    self._eventFrame:RegisterEvent("MERCHANT_CLOSED")
    self._eventFrame:RegisterEvent("BAG_UPDATE")

    local GUI = LibStub("OneWoW_GUI-1.0", true)
    if GUI and not self._guiCallbacksRegistered then
        self._guiCallbacksRegistered = true
        local function onSettingsChanged()
            VendorPanel:OnMerchantClosed()
            state.vendorButton = nil
            state.panelToggleTab = nil
            state._merchantSidebarIndex = nil
            state._merchantToggleHandler = nil
            state.junkPreviewPanel = nil
            state.replacementSellButton = nil
            state.filtersDialog = nil
            state.neverSellDialog = nil
        end
        GUI:RegisterSettingsCallback("OnThemeChanged", self, onSettingsChanged)
        GUI:RegisterSettingsCallback("OnLanguageChanged", self, onSettingsChanged)
        GUI:RegisterSettingsCallback("OnIconThemeChanged", self, onSettingsChanged)
    end

    if not self._hookDone and _G.MerchantFrame_Update then
        self._hookDone = true
        hooksecurefunc("MerchantFrame_Update", function()
            C_Timer.After(0.05, function()
                if not MerchantFrame or not MerchantFrame:IsShown() then return end
                local isBuyMode = (MerchantFrame.selectedTab == 1)
                if not isBuyMode then
                    for i = 1, MERCHANT_ITEMS_PER_PAGE do
                        local button = _G["MerchantItem" .. i]
                        if button then button:Show(); button:SetAlpha(1) end
                    end
                    if state.replacementSellButton then state.replacementSellButton:Hide() end
                    return
                end
                local panelShown = state.junkPreviewPanel and state.junkPreviewPanel:IsShown()
                VendorPanel:ManageBlizzardSellButton(panelShown and true or false)
                if not panelShown then
                    for i = 1, MERCHANT_ITEMS_PER_PAGE do
                        local button = _G["MerchantItem"..i]
                        if button then button:SetAlpha(1.0); if button.icon then button.icon:SetDesaturated(false) end end
                    end
                    return
                end
                local preferredArmor = GetPreferredArmor()
                local knownAlpha = 0.2
                local filteredAlpha = 0.4
                for i = 1, MERCHANT_ITEMS_PER_PAGE do
                    local button = _G["MerchantItem"..i]
                    local index = i + (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE
                    local itemLink = GetMerchantItemLink(index)
                    if button and itemLink then
                        local _, itemSubType, _, equipSlot = select(6, C_Item.GetItemInfo(itemLink))
                        local matches = VPFilters.CheckVendorItemFilter(itemLink, state.currentVendorFilter)
                        if state.currentVendorFilter == "Show All" then
                            -- no armor override when showing all
                        elseif state.showAllArmor then
                            -- keep matches as is
                        elseif itemSubType == preferredArmor then
                            -- keep matches as is
                        elseif equipSlot == "INVTYPE_CLOAK" then
                            -- keep matches as is
                        elseif ARMOR_TYPES[itemSubType] then
                            matches = false
                        end
                        button:Show()
                        if matches then
                            local known = state.dimKnownItems and IsAlreadyKnown(itemLink)
                            if known then
                                button:SetAlpha(knownAlpha)
                            else
                                button:SetAlpha(1.0)
                            end
                            if button.icon then button.icon:SetDesaturated(known and true or false) end
                        else
                            button:SetAlpha(filteredAlpha)
                            if button.icon then button.icon:SetDesaturated(true) end
                        end
                    end
                end
            end)
        end)
    end
end

function VendorPanelModule:OnDisable()
    if self._eventFrame then
        self._eventFrame:UnregisterEvent("MERCHANT_SHOW")
        self._eventFrame:UnregisterEvent("MERCHANT_CLOSED")
        self._eventFrame:UnregisterEvent("BAG_UPDATE")
    end
    VendorPanel:OnMerchantClosed()
end

function VendorPanelModule:OnToggle(toggleId, value)
    if toggleId == "show_panel" then
        if not value and state.junkPreviewPanel and state.junkPreviewPanel:IsShown() then
            state.junkPreviewPanel:Hide()
        end
    elseif toggleId == "show_blizz_junk" then
        if state.junkPreviewPanel and state.junkPreviewPanel:IsShown() then
            VendorPanel:UpdatePreviewPanel()
        end
        if state.filtersDialog and state.filtersDialog.showBlizzJunk then
            state.filtersDialog.showBlizzJunk:SetChecked(value)
        end
    end
end
