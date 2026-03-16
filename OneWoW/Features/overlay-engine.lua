local ADDON_NAME, OneWoW = ...

OneWoW.OverlayEngine = {}
local Engine = OneWoW.OverlayEngine

local PositionOffsets = {
    TOPLEFT     = {1, -1},
    TOPRIGHT    = {-1, -1},
    BOTTOMLEFT  = {1,  1},
    BOTTOMRIGHT = {-1,  1},
    BOTTOM      = {0,  1},
    TOP         = {0, -1},
    LEFT        = {1,  0},
    RIGHT       = {-1,  0},
    CENTER      = {0,  0},
}

local OVERLAY_ORDER = {
    "protected",
    "junk",
    "consumables",
    "housingdecor",
    "knownitems",
    "unknownitems",
    "mounts",
    "pets",
    "quest",
    "reagents",
    "recipe",
    "soulbound",
    "toys",
    "warbound",
}

local bagThrottle        = {}
local bankThrottle       = false
local trackedBankButtons = {}
local vendorPending      = false
local initialized   = false

Engine.integrationRefreshCallbacks = {}

function Engine:RegisterIntegration(fn)
    table.insert(self.integrationRefreshCallbacks, fn)
end

local function GetDB()
    return OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings and OneWoW.db.global.settings.overlays
end

local function IsGlobalEnabled()
    local db = GetDB()
    if not db then return false end
    return db.general and db.general.enabled ~= false
end

local function GetOverlayCfg(overlayId)
    local db = GetDB()
    if not db then return nil end
    return db[overlayId]
end

local function IsOverlayEnabled(overlayId)
    if not IsGlobalEnabled() then return false end
    local cfg = GetOverlayCfg(overlayId)
    return cfg and cfg.enabled == true
end

local function AnyVendorOverlayEnabled()
    for _, id in ipairs(OVERLAY_ORDER) do
        local cfg = GetOverlayCfg(id)
        if cfg and cfg.enabled and cfg.applyToVendorItems then
            return true
        end
    end
    local ilvlCfg = GetOverlayCfg("itemlevel")
    if ilvlCfg and ilvlCfg.enabled and ilvlCfg.applyToVendorItems then
        return true
    end
    return false
end

local function AnyAHOverlayEnabled()
    for _, id in ipairs(OVERLAY_ORDER) do
        local cfg = GetOverlayCfg(id)
        if cfg and cfg.enabled and cfg.applyToAuctionHouse then
            return true
        end
    end
    local ilvlCfg = GetOverlayCfg("itemlevel")
    if ilvlCfg and ilvlCfg.enabled and ilvlCfg.applyToAuctionHouse then
        return true
    end
    return false
end

local function GetOrCreateContainer(button)
    if not button.onewow_overlayContainer then
        local c = CreateFrame("Frame", nil, button)
        c:SetAllPoints(button)
        c:EnableMouse(false)
        c:Hide()
        button.onewow_overlayContainer = c
    end
    return button.onewow_overlayContainer
end

local function CleanButton(button)
    if not button then return end
    if button.onewow_overlayContainer then
        button.onewow_overlayContainer:Hide()
    end
    if button.onewow_overlayPool then
        for _, entry in ipairs(button.onewow_overlayPool) do
            if entry.frame then
                entry.frame:ClearAllPoints()
                entry.frame:Hide()
            end
        end
    end
    if button.onewow_ilvl then
        button.onewow_ilvl:Hide()
    end
end

local function PreparePool(button)
    if not button.onewow_overlayPool then
        button.onewow_overlayPool = {}
    end
end

local function GetOrCreatePoolEntry(button, index)
    PreparePool(button)
    if not button.onewow_overlayPool[index] then
        local container = GetOrCreateContainer(button)
        local f = CreateFrame("Frame", nil, container)
        f:SetFrameLevel(button:GetFrameLevel() + 3)
        f:EnableMouse(false)
        local t = f:CreateTexture(nil, "OVERLAY", nil, 3)
        t:SetAllPoints(f)
        button.onewow_overlayPool[index] = { frame = f, texture = t }
    end
    return button.onewow_overlayPool[index]
end

local function ApplyItemLevelToButton(button, item, itemLink, classID, itemLocation)
    local cfg = GetOverlayCfg("itemlevel")
    if not cfg or not cfg.enabled then return end

    local isContainer = (classID == Enum.ItemClass.Container)
    if not isContainer then
        local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemLink)
        if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP"
            or equipLoc == "INVTYPE_NON_EQUIP_IGNORE" then
            return
        end
    end

    local ilvl
    if itemLocation and C_Item.DoesItemExist(itemLocation) then
        ilvl = C_Item.GetCurrentItemLevel(itemLocation)
    end
    if not ilvl or ilvl == 0 then
        ilvl = C_Item.GetDetailedItemLevelInfo(itemLink)
    end
    if not ilvl or ilvl == 0 then return end

    if not button.onewow_ilvl then
        local container = GetOrCreateContainer(button)
        button.onewow_ilvl = container:CreateFontString(nil, "OVERLAY")
    end
    local _guiLib = LibStub("OneWoW_GUI-1.0", true)
    local fontPath = (_guiLib and _guiLib.GetFont and _guiLib:GetFont()) or "Fonts\\FRIZQT__.TTF"
    local fontName = cfg.fontFamily
    if fontName then
        local LSM = LibStub("LibSharedMedia-3.0", true)
        if LSM then
            local path = LSM:Fetch("font", fontName)
            if path then
                fontPath = path
            end
        end
    end
    button.onewow_ilvl:SetFont(fontPath, cfg.fontSize or 10, cfg.fontOutline or "OUTLINE")

    local position  = cfg.position or "TOPRIGHT"
    local offsets   = PositionOffsets[position] or {0, 0}
    local container = GetOrCreateContainer(button)
    button.onewow_ilvl:ClearAllPoints()
    button.onewow_ilvl:SetPoint(position, container, position, offsets[1], offsets[2])

    if cfg.useQualityColors then
        local quality = item and item:GetItemQuality() or select(3, C_Item.GetItemInfo(itemLink)) or 1
        local r, g, b = C_Item.GetItemQualityColor(quality)
        button.onewow_ilvl:SetTextColor(r, g, b)
    else
        button.onewow_ilvl:SetTextColor(1, 0.82, 0)
    end

    button.onewow_ilvl:SetText(tostring(ilvl))
    button.onewow_ilvl:Show()
end

local function GetButtonVisualSize(button)
    local container = button.onewow_overlayContainer
    if container then
        local cw, ch = container:GetSize()
        if cw and cw > 1 and ch and ch > 1 then
            return cw, ch
        end
    end
    return button:GetSize()
end

local function PresetContainerOnIcon(button, iconFrame, inset)
    if button.onewow_overlayContainer then return end
    inset = inset or 0
    local c = CreateFrame("Frame", nil, button)
    c:SetPoint("TOPLEFT",     iconFrame, "TOPLEFT",      inset, -inset)
    c:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -inset,  inset)
    c:EnableMouse(false)
    c:SetFrameStrata("HIGH")
    c:Hide()
    button.onewow_overlayContainer = c
end

local function PresetContainerFixed(button, parent, w, h, anchorPoint, anchorTo, ox, oy)
    if button.onewow_overlayContainer then return end
    local c = CreateFrame("Frame", nil, parent)
    c:SetSize(w, h)
    c:SetPoint(anchorPoint, anchorTo, anchorPoint, ox, oy)
    c:EnableMouse(false)
    c:SetFrameStrata("HIGH")
    c:Hide()
    button.onewow_overlayContainer = c
end

local function SyncQuestAlpha(button)
    if not button or not button.onewow_questEntry then return end
    local entry = button.onewow_questEntry
    if not entry.frame or not entry.frame:IsShown() then return end
    local questAlpha = 1.0
    if button.IconOverlay and button.IconOverlay:IsShown() then
        local a = button.IconOverlay:GetAlpha()
        if a and a < 1.0 then questAlpha = a end
    end
    entry.texture:SetAlpha(questAlpha)
end

local function SyncSearchDim(button)
    if not button then return end
    local isDimmed = (button.ItemContextOverlay and button.ItemContextOverlay:IsShown())
        or (button:GetAlpha() < 0.9)
    if button.onewow_overlayPool then
        for _, entry in ipairs(button.onewow_overlayPool) do
            if entry.frame and entry.frame:IsShown() then
                if isDimmed then
                    entry.texture:SetAlpha(0.2)
                else
                    entry.texture:SetAlpha(entry.configAlpha or 1.0)
                end
            end
        end
    end
    if button.onewow_ilvl and button.onewow_ilvl:IsShown() then
        button.onewow_ilvl:SetAlpha(isDimmed and 0.2 or 1.0)
    end
end

local function ApplyOverlayToButton(button, overlayId, positionIndex)
    local cfg = GetOverlayCfg(overlayId)
    if not cfg then return end

    local container = GetOrCreateContainer(button)
    local entry = GetOrCreatePoolEntry(button, positionIndex)

    if overlayId == "quest" then
        local bw, bh = GetButtonVisualSize(button)
        entry.frame:ClearAllPoints()
        entry.frame:SetPoint("CENTER", container, "CENTER", 0, 0)
        entry.frame:SetSize(bw, bh)
        entry.texture:SetTexture(TEXTURE_ITEM_QUEST_BANG)
        local questAlpha = 1.0
        if button.IconOverlay and button.IconOverlay:IsShown() then
            local a = button.IconOverlay:GetAlpha()
            if a and a < 1.0 then questAlpha = a end
        end
        entry.texture:SetAlpha(questAlpha)
        entry.configAlpha = questAlpha
        button.onewow_questEntry = entry
        entry.frame:Show()
        return
    end

    local iconName  = cfg.icon or "VignetteEvent-SuperTracked"
    local position  = cfg.position or "TOPRIGHT"
    local scale     = cfg.scale or 1.0
    local alpha     = math.min(cfg.alpha or 1.0, 1.0)
    local offsets   = PositionOffsets[position] or {0, 0}
    local bw, bh    = GetButtonVisualSize(button)
    local baseSize  = math.min(bw or 37, bh or 37) * 0.54
    local finalSize = baseSize * scale

    entry.frame:ClearAllPoints()
    entry.frame:SetPoint(position, container, position, offsets[1], offsets[2])
    entry.frame:SetSize(finalSize, finalSize)
    OneWoW.OverlayIcons:ApplyToTexture(entry.texture, iconName)
    entry.texture:SetAlpha(alpha)
    entry.configAlpha = alpha
    entry.frame:Show()
end

-- Returns: true = collectible AND already known/collected
--          false = collectible AND not yet known/collected
--          nil = not a collectible type (no overlay either way)
local function CheckCollectionStatus(itemID, itemLink, classID, subclassID)
    if not itemID or not itemLink or not classID then return nil end

    local isMisc = (classID == Enum.ItemClass.Miscellaneous)

    -- Toys: fast API, no tooltip needed
    if C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(itemID) then
        return PlayerHasToy(itemID) == true
    end

    -- Caged battle pets
    if classID == Enum.ItemClass.Battlepet or itemID == 82800 then
        local speciesID = tonumber(itemLink:match("|Hbattlepet:(%d+):"))
        if speciesID then
            local numCollected = C_PetJournal.GetNumCollectedInfo(speciesID)
            return numCollected ~= nil and numCollected > 0
        end
        return nil
    end

    -- Mounts
    if isMisc and subclassID == Enum.ItemMiscellaneousSubclass.Mount then
        if C_MountJournal and C_MountJournal.GetMountFromItem then
            local mountID = C_MountJournal.GetMountFromItem(itemID)
            if mountID then
                local _, _, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
                return isCollected == true
            end
        end
        -- fallback: tooltip scan
        local td = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(itemLink)
        if td and td.lines then
            for _, line in ipairs(td.lines) do
                if line.leftText and line.leftText == ITEM_SPELL_KNOWN then return true end
            end
        end
        return false
    end

    -- Companion pets
    if isMisc and subclassID == Enum.ItemMiscellaneousSubclass.CompanionPet then
        local td = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(itemLink)
        if td and td.lines then
            for _, line in ipairs(td.lines) do
                if line.leftText then
                    if line.leftText == ITEM_SPELL_KNOWN or line.leftText:match("Collected") then
                        return true
                    end
                end
            end
        end
        return false
    end

    -- Recipes: only real teachable ones (have ItemSpellTriggerLearn line)
    if classID == Enum.ItemClass.Recipe then
        local td = C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(itemLink)
        if not td or not td.lines then return nil end
        local isTeachable = false
        local isKnown     = false
        for _, line in ipairs(td.lines) do
            if line.type == Enum.TooltipDataLineType.ItemSpellTriggerLearn then
                isTeachable = true
            end
            if line.leftText and line.leftText == ITEM_SPELL_KNOWN then
                isKnown = true
            end
        end
        if not isTeachable then return nil end
        return isKnown
    end

    -- Transmog appearances (weapons and armor)
    -- Trinkets, rings, necks have no transmog — skip them entirely
    if classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor then
        local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemLink)
        if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP"
            or equipLoc == "INVTYPE_TRINKET" or equipLoc == "INVTYPE_FINGER"
            or equipLoc == "INVTYPE_NECK" then
            return nil
        end
        if not C_TransmogCollection then return nil end
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
                        local otherInfo = C_TransmogCollection.GetSourceInfo(otherID)
                        if otherInfo and otherInfo.isCollected
                            and otherInfo.categoryID == sourceInfo.categoryID then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    return nil
end

local function DetectOverlays(classID, subclassID, itemID, itemLink, itemLocation)
    local hits = {}

    if IsOverlayEnabled("protected") and OneWoW.ItemStatus and OneWoW.ItemStatus:IsItemProtected(itemID) then
        hits[#hits + 1] = "protected"
    end

    if IsOverlayEnabled("junk") then
        local isJunk = OneWoW.ItemStatus and OneWoW.ItemStatus:IsItemJunk(itemID)
        if not isJunk and GetOverlayCfg("junk") and GetOverlayCfg("junk").includeGreyItems then
            local quality = select(3, C_Item.GetItemInfo(itemLink))
            if quality and quality == 0 then
                isJunk = true
            end
        end
        if isJunk then
            hits[#hits + 1] = "junk"
        end
    end

    local isMisc = (classID == Enum.ItemClass.Miscellaneous)

    if IsOverlayEnabled("consumables") then
        if classID == Enum.ItemClass.Consumable then
            hits[#hits + 1] = "consumables"
        end
    end

    if IsOverlayEnabled("housingdecor") then
        local isDecor = false
        if Enum.ItemClass.Housing and classID == Enum.ItemClass.Housing then
            isDecor = true
        elseif C_HousingDecor and C_HousingDecor.IsDecorItem then
            isDecor = C_HousingDecor.IsDecorItem(itemID) or false
        end
        if isDecor then
            hits[#hits + 1] = "housingdecor"
        end
    end

    local needCollectionCheck = IsOverlayEnabled("knownitems") or IsOverlayEnabled("unknownitems")
    if needCollectionCheck then
        local status = CheckCollectionStatus(itemID, itemLink, classID, subclassID)
        if status == true and IsOverlayEnabled("knownitems") then
            hits[#hits + 1] = "knownitems"
        elseif status == false and IsOverlayEnabled("unknownitems") then
            hits[#hits + 1] = "unknownitems"
        end
    end

    if IsOverlayEnabled("mounts") then
        if isMisc and subclassID == Enum.ItemMiscellaneousSubclass.Mount then
            hits[#hits + 1] = "mounts"
        end
    end

    if IsOverlayEnabled("pets") then
        local isPet = (classID == Enum.ItemClass.Battlepet)
        if not isPet and isMisc then
            isPet = (subclassID == Enum.ItemMiscellaneousSubclass.CompanionPet)
        end
        if isPet then
            hits[#hits + 1] = "pets"
        end
    end

    if IsOverlayEnabled("quest") then
        if classID == Enum.ItemClass.Questitem then
            hits[#hits + 1] = "quest"
        end
    end

    if IsOverlayEnabled("reagents") then
        if classID == Enum.ItemClass.Tradegoods then
            hits[#hits + 1] = "reagents"
        end
    end

    if IsOverlayEnabled("recipe") then
        if classID == Enum.ItemClass.Recipe then
            local isTeachable = false
            local tooltipData = C_TooltipInfo and C_TooltipInfo.GetItemByID and C_TooltipInfo.GetItemByID(itemID)
            if tooltipData and tooltipData.lines then
                for _, line in ipairs(tooltipData.lines) do
                    if line.type == Enum.TooltipDataLineType.ItemSpellTriggerLearn then
                        isTeachable = true
                        break
                    end
                end
            end
            if isTeachable then
                hits[#hits + 1] = "recipe"
            end
        end
    end

    if IsOverlayEnabled("toys") then
        if C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(itemID) then
            hits[#hits + 1] = "toys"
        end
    end

    local isBound              = false
    local isWarbound           = false
    local isWarboundUntilEquip = false

    if C_Item.IsItemBindToAccountUntilEquip and itemLink then
        isWarboundUntilEquip = C_Item.IsItemBindToAccountUntilEquip(itemLink) or false
    end

    if itemLocation then
        if C_Item.IsBound then
            isBound = C_Item.IsBound(itemLocation) or false
        end
        if isBound and C_Bank and C_Bank.IsItemAllowedInBankType then
            isWarbound = C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, itemLocation) or false
        end
    end

    if IsOverlayEnabled("warbound") then
        if isWarbound or isWarboundUntilEquip then
            hits[#hits + 1] = "warbound"
        end
    end

    if IsOverlayEnabled("soulbound") then
        if isBound and not isWarbound and not isWarboundUntilEquip then
            hits[#hits + 1] = "soulbound"
        end
    end

    return hits
end

local function FilterHitsByContext(hits, context)
    if context ~= "auctionhouse" then return hits end
    local filtered = {}
    for _, id in ipairs(hits) do
        local cfg = GetOverlayCfg(id)
        if cfg and cfg.applyToAuctionHouse then
            filtered[#filtered + 1] = id
        end
    end
    return filtered
end

local function BuildOverlaysForButton(button, itemLink, itemLocation, context)
    if not button or not itemLink then
        CleanButton(button)
        return
    end

    if not IsGlobalEnabled() then
        CleanButton(button)
        return
    end

    local itemID = C_Item.GetItemInfoInstant(itemLink)
    if not itemID then
        CleanButton(button)
        return
    end

    CleanButton(button)

    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemLink)
    if classID then
        local hits = DetectOverlays(classID, subclassID, itemID, itemLink, itemLocation)
        hits = FilterHitsByContext(hits, context)
        for i, overlayId in ipairs(hits) do
            ApplyOverlayToButton(button, overlayId, i)
        end

        if C_Item.IsItemDataCachedByID(itemID) then
            local item = Item:CreateFromItemID(itemID)
            local ilvlCfg = GetOverlayCfg("itemlevel")
            if context ~= "auctionhouse" or (ilvlCfg and ilvlCfg.applyToAuctionHouse) then
                ApplyItemLevelToButton(button, item, itemLink, classID, itemLocation)
            end
        end

        if button.onewow_overlayContainer then
            button.onewow_overlayContainer:Show()
        end

        SyncSearchDim(button)
    else
        C_Item.RequestLoadItemDataByID(itemID)
        local item = Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            if not IsGlobalEnabled() then return end
            local _, _, _, _, _, cID, scID = C_Item.GetItemInfoInstant(itemLink)
            if not cID then return end

            local hits = DetectOverlays(cID, scID, itemID, itemLink, itemLocation)
            hits = FilterHitsByContext(hits, context)
            for i, overlayId in ipairs(hits) do
                ApplyOverlayToButton(button, overlayId, i)
            end

            local ilvlCfg = GetOverlayCfg("itemlevel")
            if context ~= "auctionhouse" or (ilvlCfg and ilvlCfg.applyToAuctionHouse) then
                ApplyItemLevelToButton(button, item, itemLink, cID, itemLocation)
            end

            if button.onewow_overlayContainer then
                button.onewow_overlayContainer:Show()
            end

            SyncSearchDim(button)
        end)
    end
end

local function ProcessBagContainer(container)
    if not container then return end

    local key = tostring(container)
    if bagThrottle[key] then
        bagThrottle[key] = "pending"
        return
    end

    bagThrottle[key] = "running"

    local function runPass()
        if not container.Items then return end
        for _, itemButton in ipairs(container.Items) do
            if itemButton and itemButton:IsVisible() then
                local bagID  = itemButton.GetBagID and itemButton:GetBagID()
                local slotID = itemButton.GetID and itemButton:GetID()
                if bagID and slotID then
                    local loc    = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
                    local exists = C_Item.DoesItemExist(loc)
                    if exists then
                        local link = C_Item.GetItemLink(loc)
                        if link then
                            BuildOverlaysForButton(itemButton, link, loc)
                        else
                            CleanButton(itemButton)
                        end
                    else
                        CleanButton(itemButton)
                    end
                end
            end
        end
    end

    runPass()

    C_Timer.After(0.1, function()
        if bagThrottle[key] == "pending" then
            bagThrottle[key] = nil
            ProcessBagContainer(container)
        else
            bagThrottle[key] = nil
        end
    end)
end

local function RefreshBags()
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsVisible() then
        ProcessBagContainer(ContainerFrameCombinedBags)
    end

    if ContainerFrameContainer then
        for _, cf in ipairs(ContainerFrameContainer.ContainerFrames or {}) do
            if cf and cf:IsVisible() then
                ProcessBagContainer(cf)
            end
        end
    end

    for i = 1, 13 do
        local cf = _G["ContainerFrame" .. i]
        if cf and cf:IsVisible() then
            ProcessBagContainer(cf)
        end
    end
end

local function RefreshBank()
    if bankThrottle then return end
    bankThrottle = true
    C_Timer.After(0.1, function()
        bankThrottle = false

        for btn in pairs(trackedBankButtons) do
            CleanButton(btn)
        end
        trackedBankButtons = {}

        if _G.BankPanel and BankPanel:IsVisible() then
            for i = 1, 98 do
                local btn = BankPanel.FindItemButtonByContainerSlotID and BankPanel:FindItemButtonByContainerSlotID(i)
                if btn then
                    trackedBankButtons[btn] = true
                    if BankPanel.selectedTabID then
                        local loc    = ItemLocation:CreateFromBagAndSlot(BankPanel.selectedTabID, i)
                        local exists = C_Item.DoesItemExist(loc)
                        if exists then
                            local link = C_Item.GetItemLink(loc)
                            if link then BuildOverlaysForButton(btn, link, loc) else CleanButton(btn) end
                        else
                            CleanButton(btn)
                        end
                    end
                end
            end
        end

        if _G.AccountBankPanel and AccountBankPanel:IsVisible() then
            for itemButton in AccountBankPanel:EnumerateValidItems() do
                if itemButton and itemButton:IsVisible() then
                    trackedBankButtons[itemButton] = true
                    local tabID  = itemButton.GetBankTabID and itemButton:GetBankTabID()
                    local slotID = itemButton.GetContainerSlotID and itemButton:GetContainerSlotID()
                    if tabID and slotID then
                        local loc    = ItemLocation:CreateFromBagAndSlot(tabID, slotID)
                        local exists = C_Item.DoesItemExist(loc)
                        if exists then
                            local link = C_Item.GetItemLink(loc)
                            if link then BuildOverlaysForButton(itemButton, link, loc) else CleanButton(itemButton) end
                        else
                            CleanButton(itemButton)
                        end
                    end
                end
            end
        end
    end)
end

local function RefreshVendor()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    if vendorPending then return end
    vendorPending = true
    C_Timer.After(0.05, function()
        vendorPending = false
        if not MerchantFrame or not MerchantFrame:IsShown() then return end

        if not IsGlobalEnabled() then
            for i = 1, MERCHANT_ITEMS_PER_PAGE do
                local btn = _G["MerchantItem" .. i]
                if btn then CleanButton(btn.ItemButton or btn) end
            end
            return
        end

        if not AnyVendorOverlayEnabled() then
            for i = 1, MERCHANT_ITEMS_PER_PAGE do
                local btn = _G["MerchantItem" .. i]
                if btn then CleanButton(btn.ItemButton or btn) end
            end
            return
        end

        for i = 1, MERCHANT_ITEMS_PER_PAGE do
            local btn = _G["MerchantItem" .. i]
            if btn then
                local index   = i + (MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE
                local link    = GetMerchantItemLink(index)
                local itemBtn = btn.ItemButton or btn
                if link then
                    BuildOverlaysForButton(itemBtn, link, nil)
                else
                    CleanButton(itemBtn)
                end
            end
        end
    end)
end

local function RefreshSearchDim()
    local function syncContainer(container)
        if not container or not container.Items then return end
        for _, itemButton in ipairs(container.Items) do
            SyncSearchDim(itemButton)
        end
    end

    if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsVisible() then
        syncContainer(ContainerFrameCombinedBags)
    end

    if ContainerFrameContainer then
        for _, cf in ipairs(ContainerFrameContainer.ContainerFrames or {}) do
            if cf and cf:IsVisible() then
                syncContainer(cf)
            end
        end
    end

    for i = 1, 13 do
        local cf = _G["ContainerFrame" .. i]
        if cf and cf:IsVisible() then
            syncContainer(cf)
        end
    end

    if _G.BankPanel and BankPanel:IsVisible() then
        if BankPanel.FindItemButtonByContainerSlotID then
            for i = 1, 98 do
                local btn = BankPanel:FindItemButtonByContainerSlotID(i)
                if btn then SyncSearchDim(btn) end
            end
        end
    end

    if _G.AccountBankPanel and AccountBankPanel:IsVisible() then
        for itemButton in AccountBankPanel:EnumerateValidItems() do
            SyncSearchDim(itemButton)
        end
    end
end

local function RefreshAll()
    RefreshBags()
    RefreshBank()
    RefreshVendor()
    for _, fn in ipairs(Engine.integrationRefreshCallbacks) do
        fn()
    end
end

function Engine:Refresh()
    RefreshAll()
end

function Engine:RefreshBags()
    RefreshBags()
end

function Engine:RefreshBank()
    RefreshBank()
end

function Engine:RefreshVendor()
    RefreshVendor()
end

function Engine:ProcessButton(button, link, location)
    BuildOverlaysForButton(button, link, location)
end

function Engine:CleanButton(button)
    CleanButton(button)
end

local surfacesInitialized = false

local function RefreshGuildBank()
    if not _G.GuildBankFrame or not GuildBankFrame:IsShown() then return end
    for tab = 1, 7 do
        if GuildBankFrame.Columns and GuildBankFrame.Columns[tab] then
            for slot = 1, 14 do
                local btn = GuildBankFrame.Columns[tab].Buttons and GuildBankFrame.Columns[tab].Buttons[slot]
                if btn then
                    local link = GetGuildBankItemLink(tab, slot)
                    if link then
                        BuildOverlaysForButton(btn, link, nil)
                    else
                        CleanButton(btn)
                    end
                end
            end
        end
    end
end

local selectedMailIndex = nil

local function RefreshMailbox()
    for i = 1, 7 do
        local btn = _G["MailItem"..i.."Button"]
        if btn then
            if btn.hasItem == 1 then
                local _, itemID = GetInboxItem(i, 1)
                if itemID then
                    local _, link = C_Item.GetItemInfo(itemID)
                    if link then
                        BuildOverlaysForButton(btn, link, nil)
                    else
                        CleanButton(btn)
                    end
                else
                    CleanButton(btn)
                end
            else
                CleanButton(btn)
            end
        end
    end

    for i = 1, ATTACHMENTS_MAX_RECEIVE do
        local btn = _G["OpenMailAttachmentButton"..i]
        if btn and selectedMailIndex then
            local link = GetInboxItemLink(selectedMailIndex, i)
            if link then
                BuildOverlaysForButton(btn, link, nil)
            else
                CleanButton(btn)
            end
        end
    end
end

local function RefreshGroupLoot()
    for i = 1, 4 do
        local frame = _G["GroupLootFrame"..i]
        if frame and frame:IsShown() and frame.rollID and frame.IconFrame then
            local link = GetLootRollItemLink(frame.rollID)
            if link then
                BuildOverlaysForButton(frame.IconFrame, link, nil)
            else
                CleanButton(frame.IconFrame)
            end
        end
    end
end

local function RefreshLootFrame()
    if not _G.LootFrame or not LootFrame:IsShown() then return end
    if LootFrame.ScrollBox and LootFrame.ScrollBox.view and LootFrame.ScrollBox.view.frames then
        for _, frame in next, LootFrame.ScrollBox.view.frames do
            if frame and frame.Item then
                local slotIndex = frame.GetSlotIndex and frame:GetSlotIndex()
                if slotIndex then
                    local link = GetLootSlotLink(slotIndex)
                    if link then
                        BuildOverlaysForButton(frame.Item, link, nil)
                    else
                        CleanButton(frame.Item)
                    end
                end
            end
        end
    end
end

local function RefreshGreatVault()
    if not _G.WeeklyRewardsFrame or not WeeklyRewardsFrame:IsShown() then return end
    local children = { WeeklyRewardsFrame:GetChildren() }
    for _, v in pairs(children) do
        if v and v.hasRewards and v.ItemFrame and v.info and v.info.rewards and v.info.rewards[1] then
            local icon = v.ItemFrame.Icon
            if icon then
                local link = C_WeeklyRewards.GetItemHyperlink(v.info.rewards[1].itemDBID)
                if link then
                    BuildOverlaysForButton(icon, link, nil)
                else
                    CleanButton(icon)
                end
            end
        end
    end
end

local function RefreshWorldQuestPins()
    if not _G.WorldMapFrame then return end
    C_Timer.After(0.1, function()
        for pin in WorldMapFrame:EnumeratePinsByTemplate("WorldMap_WorldQuestPinTemplate") do
            if pin and pin.questID then
                if not pin.onewow_overlayContainer and pin.GetButton then
                    local btn = pin:GetButton()
                    if btn then
                        PresetContainerOnIcon(pin, btn, 0)
                        if pin.onewow_overlayContainer then
                            pin.onewow_overlayContainer:SetScale(0.8)
                        end
                    end
                end
                if pin.onewow_overlayContainer then
                    pin.onewow_overlayContainer:Hide()
                end
                local bestIdx, bestType = QuestUtils_GetBestQualityItemRewardIndex(pin.questID)
                if bestIdx and bestType then
                    local link = GetQuestLogItemLink(bestType, bestIdx, pin.questID)
                    if link then
                        BuildOverlaysForButton(pin, link, nil)
                    end
                end
            end
        end
    end)
end

local function InitializeSurfaces()
    if surfacesInitialized then return end
    surfacesInitialized = true

    if _G.LootFrame and LootFrame.HookScript then
        LootFrame:HookScript("OnShow", RefreshLootFrame)
    end

    if _G.GuildBankFrame then
        if GuildBankFrame.Update then
            hooksecurefunc(GuildBankFrame, "Update", RefreshGuildBank)
        end
        GuildBankFrame:HookScript("OnShow", RefreshGuildBank)
    end

    if _G.InboxPrevPageButton then
        InboxPrevPageButton:HookScript("OnClick", RefreshMailbox)
    end
    if _G.InboxNextPageButton then
        InboxNextPageButton:HookScript("OnClick", RefreshMailbox)
    end
    for i = 1, 7 do
        local btn = _G["MailItem"..i.."Button"]
        if btn then
            btn:HookScript("OnClick", function()
                selectedMailIndex = btn.index
                RefreshMailbox()
            end)
        end
    end

    local function ProcessQuestRewardFrame(rewardsFrame, mode)
        if not rewardsFrame or not rewardsFrame.RewardButtons then return end
        for k, v in pairs(rewardsFrame.RewardButtons) do
            local btn = QuestInfo_GetRewardButton(rewardsFrame, k)
            if btn then
                if v.objectType == "currency" or not v.type then
                    CleanButton(btn)
                else
                    local link
                    if mode == "turnin" then
                        if GetQuestID() then
                            C_QuestLog.SetSelectedQuest(GetQuestID())
                        end
                        link = GetQuestLogItemLink(v.type, k)
                    elseif rewardsFrame == _G.MapQuestInfoRewardsFrame then
                        link = GetQuestLogItemLink(v.type, k)
                    else
                        link = GetQuestItemLink(v.type, k)
                    end
                    if link then
                        if btn.IconBorder and not btn.onewow_overlayContainer then
                            PresetContainerOnIcon(btn, btn.IconBorder, 0)
                        end
                        BuildOverlaysForButton(btn, link, nil)
                    else
                        CleanButton(btn)
                    end
                end
            end
        end
    end

    local function RefreshQuestRewards(mode)
        if _G.QuestInfoRewardsFrame and not (_G.WorldMapFrame and WorldMapFrame:IsShown()) then
            ProcessQuestRewardFrame(QuestInfoRewardsFrame, mode)
            C_Timer.After(1, function() ProcessQuestRewardFrame(QuestInfoRewardsFrame, mode) end)
        end
        if _G.MapQuestInfoRewardsFrame and _G.WorldMapFrame and WorldMapFrame:IsShown() then
            ProcessQuestRewardFrame(MapQuestInfoRewardsFrame, mode)
        end
    end

    if _G.QuestFrameRewardPanel then
        QuestFrameRewardPanel:HookScript("OnShow", function() RefreshQuestRewards() end)
    end
    if _G.QuestInfoRewardsFrame then
        QuestInfoRewardsFrame:HookScript("OnShow", function() RefreshQuestRewards() end)
    end
    if _G.QuestInfo_Display then
        hooksecurefunc("QuestInfo_Display", function() RefreshQuestRewards() end)
    end
    if _G.QuestMapFrame_ShowQuestDetails then
        hooksecurefunc("QuestMapFrame_ShowQuestDetails", function()
            RefreshQuestRewards()
            C_Timer.After(0.1, function() RefreshQuestRewards() end)
        end)
    end

    local ejHooked = false
    local function RegisterEJHook()
        if ejHooked then return end
        if not _G.EncounterJournalEncounterFrameInfo then return end
        if not EncounterJournalEncounterFrameInfo.LootContainer then return end
        if not EncounterJournalEncounterFrameInfo.LootContainer.ScrollBox then return end
        EncounterJournalEncounterFrameInfo.LootContainer.ScrollBox:RegisterCallback("OnAcquiredFrame", function(_, v)
            RunNextFrame(function()
                if not v then return end
                if v.icon and not v.onewow_overlayContainer then
                    local c = CreateFrame("Frame", nil, v)
                    c:SetPoint("TOPLEFT",     v.icon, "TOPLEFT",      4, -4)
                    c:SetPoint("BOTTOMRIGHT", v.icon, "BOTTOMRIGHT", -4,  4)
                    c:EnableMouse(false)
                    c:SetFrameStrata("HIGH")
                    c:Hide()
                    v.onewow_overlayContainer = c
                end
                if v.link then
                    BuildOverlaysForButton(v, v.link, nil)
                else
                    CleanButton(v)
                end
            end)
        end)
        ejHooked = true
    end
    if _G.EncounterJournal then
        EncounterJournal:HookScript("OnShow", RegisterEJHook)
    end
    local surfaceEventFrame_EJ = CreateFrame("Frame")
    surfaceEventFrame_EJ:RegisterEvent("UPDATE_INSTANCE_INFO")
    surfaceEventFrame_EJ:SetScript("OnEvent", function()
        if _G.EncounterJournal and EncounterJournal:IsShown() then
            RegisterEJHook()
        end
    end)


    local ahHooked = false
    local function RegisterAHHook()
        if ahHooked then return end
        if not _G.AuctionHouseFrame then return end
        if not AuctionHouseFrame.BrowseResultsFrame then return end
        if not AuctionHouseFrame.BrowseResultsFrame.ItemList then return end
        if not AuctionHouseFrame.BrowseResultsFrame.ItemList.ScrollBox then return end
        AuctionHouseFrame.BrowseResultsFrame.ItemList.ScrollBox:RegisterCallback("OnAcquiredFrame", function(_, v)
            C_Timer.After(0.1, function()
                if not v then return end
                if not AnyAHOverlayEnabled() then
                    CleanButton(v)
                    return
                end
                PresetContainerFixed(v, v, 36, 36, "LEFT", v, 4, 0)
                local rowData = v.rowData
                if rowData and rowData.itemKey then
                    local itemID = rowData.itemKey.itemID
                    if itemID then
                        local _, link = C_Item.GetItemInfo(itemID)
                        if link then
                            BuildOverlaysForButton(v, link, nil, "auctionhouse")
                        else
                            CleanButton(v)
                        end
                    end
                else
                    CleanButton(v)
                end
            end)
        end)
        ahHooked = true
    end

    local bmHooked = false
    local function RegisterBMHook()
        if bmHooked then return end
        if not _G.BlackMarketFrame then return end
        if not BlackMarketFrame.ScrollBox then return end
        BlackMarketFrame.ScrollBox:RegisterCallback("OnAcquiredFrame", function(_, v, data)
            C_Timer.After(0.1, function()
                if not v then return end
                if v.Item and not v.onewow_overlayContainer then
                    PresetContainerOnIcon(v, v.Item, 0)
                end
                local link = data and data.link
                if link then
                    BuildOverlaysForButton(v, link, nil)
                else
                    CleanButton(v)
                end
            end)
        end)
        bmHooked = true
    end
    if _G.BlackMarketFrame then
        BlackMarketFrame:HookScript("OnShow", RegisterBMHook)
    end

    if _G.WeeklyRewardsFrame then
        WeeklyRewardsFrame:HookScript("OnShow", function()
            RefreshGreatVault()
            C_Timer.After(1, RefreshGreatVault)
        end)
    end

    if _G.WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", RefreshWorldQuestPins)
        if EventRegistry then
            EventRegistry:RegisterCallback("MapCanvas.MapSet", RefreshWorldQuestPins)
        end
    end

    local surfaceEventFrame = CreateFrame("Frame")
    surfaceEventFrame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
    surfaceEventFrame:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
    surfaceEventFrame:RegisterEvent("NEW_RECIPE_LEARNED")
    surfaceEventFrame:RegisterEvent("MAIL_SHOW")
    surfaceEventFrame:RegisterEvent("MAIL_INBOX_UPDATE")
    surfaceEventFrame:RegisterEvent("QUEST_DETAIL")
    surfaceEventFrame:RegisterEvent("QUEST_COMPLETE")
    surfaceEventFrame:RegisterEvent("START_LOOT_ROLL")
    surfaceEventFrame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
    surfaceEventFrame:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
    surfaceEventFrame:SetScript("OnEvent", function(_, event)
        if event == "GUILDBANKBAGSLOTS_CHANGED" then
            RefreshGuildBank()
        elseif event == "TRANSMOG_COLLECTION_UPDATED" then
            C_Timer.After(0.1, RefreshAll)
            C_Timer.After(0.1, RefreshGuildBank)
        elseif event == "NEW_RECIPE_LEARNED" then
            C_Timer.After(0.1, RefreshAll)
        elseif event == "MAIL_SHOW" or event == "MAIL_INBOX_UPDATE" then
            C_Timer.After(0.1, RefreshMailbox)
        elseif event == "QUEST_DETAIL" then
            RefreshQuestRewards()
        elseif event == "QUEST_COMPLETE" then
            RefreshQuestRewards("turnin")
        elseif event == "START_LOOT_ROLL" then
            RunNextFrame(RefreshGroupLoot)
        elseif event == "WEEKLY_REWARDS_UPDATE" then
            RefreshGreatVault()
            C_Timer.After(1, RefreshGreatVault)
        elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
            RegisterAHHook()
        end
    end)
end

function Engine:Initialize()
    if initialized then return end
    initialized = true

    if ContainerFrameCombinedBags then
        hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", function(container)
            ProcessBagContainer(container)
        end)
    end

    if ContainerFrameContainer then
        for _, cf in ipairs(ContainerFrameContainer.ContainerFrames or {}) do
            if cf then
                hooksecurefunc(cf, "UpdateItems", function(container)
                    ProcessBagContainer(container)
                end)
            end
        end
    end

    for i = 1, 6 do
        local cf = _G["ContainerFrame" .. i]
        if cf and cf.UpdateItems then
            hooksecurefunc(cf, "UpdateItems", function(container)
                ProcessBagContainer(container)
            end)
        end
    end

    if _G.BankPanel then
        if BankPanel.RefreshBankPanel then
            hooksecurefunc(BankPanel, "RefreshBankPanel", function() RefreshBank() end)
        end
        if BankPanel.GenerateItemSlotsForSelectedTab then
            hooksecurefunc(BankPanel, "GenerateItemSlotsForSelectedTab", function() RefreshBank() end)
        end
        if BankPanel.RefreshAllItemsForSelectedTab then
            hooksecurefunc(BankPanel, "RefreshAllItemsForSelectedTab", function() RefreshBank() end)
        end
    end

    if _G.AccountBankPanel then
        if AccountBankPanel.GenerateItemSlotsForSelectedTab then
            hooksecurefunc(AccountBankPanel, "GenerateItemSlotsForSelectedTab", function() RefreshBank() end)
        end
        if AccountBankPanel.RefreshAllItemsForSelectedTab then
            hooksecurefunc(AccountBankPanel, "RefreshAllItemsForSelectedTab", function() RefreshBank() end)
        end
    end

    if _G.MerchantFrame_Update then
        hooksecurefunc("MerchantFrame_Update", RefreshVendor)
    end

    if SetItemButtonOverlay then
        hooksecurefunc("SetItemButtonOverlay", function(button)
            SyncQuestAlpha(button)
        end)
    end
    if ClearItemButtonOverlay then
        hooksecurefunc("ClearItemButtonOverlay", function(button)
            SyncQuestAlpha(button)
        end)
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("BANKFRAME_OPENED")
    eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED")
    eventFrame:RegisterEvent("MERCHANT_UPDATE")
    eventFrame:RegisterEvent("MERCHANT_SHOW")
    eventFrame:RegisterEvent("INVENTORY_SEARCH_UPDATE")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "BAG_UPDATE_DELAYED" then
            RefreshBags()
            for _, fn in ipairs(Engine.integrationRefreshCallbacks) do fn() end
        elseif event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED" or event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" then
            RefreshBank()
        elseif event == "MERCHANT_UPDATE" or event == "MERCHANT_SHOW" then
            RefreshVendor()
        elseif event == "INVENTORY_SEARCH_UPDATE" then
            C_Timer.After(0, RefreshSearchDim)
        end
    end)

    InitializeSurfaces()
end
