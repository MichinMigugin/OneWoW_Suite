local _, ns = ...

local AutoOpenModule, L = ns.ModuleRegistry:Current()
if not AutoOpenModule then return end

local Restriction = OneWoW.Restriction
local OneWoW_GUI = OneWoW_GUI
local PE = OneWoW.PredicateEngine
local Inventory = OneWoW.Inventory

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local AO = AutoOpenModule

-- #openable reads the bag tooltip; hasLoot/isLocked alone cannot detect lockpicking-locked lockboxes.
local OPEN_PREDICATE_EXPR = "#hasloot&!#locked& #openable"
local openPredicate = PE:Compile(OPEN_PREDICATE_EXPR)

local function GetBlacklist()
    local bucket = ns.ModuleRegistry:GetModuleBucket("autoopen")
    if not bucket.blacklist then bucket.blacklist = {} end
    return bucket.blacklist
end

function AutoOpenModule:IsBlacklisted(itemID)
    if self._tempBlacklist[itemID] then return true end
    local bl = GetBlacklist()
    return bl[itemID] == true
end

function AutoOpenModule:AddToBlacklist(itemID, permanent)
    if permanent then
        GetBlacklist()[itemID] = true
    else
        self._tempBlacklist[itemID] = true
    end
end

function AutoOpenModule:RemoveFromBlacklist(itemID)
    self._tempBlacklist[itemID] = nil
    GetBlacklist()[itemID] = nil
end

function AutoOpenModule:ClearBlacklist()
    wipe(self._tempBlacklist)
    wipe(GetBlacklist())
end

function AutoOpenModule:ScanAndOpen()
    -- Merchant and trade-skill state are read live from the core funnels
    -- (OneWoW.Merchant / OneWoW.ProfessionRecipe, the single event owners) rather
    -- than locally tracked _atMerchant / _atCrafting flags. Character bank open
    -- state comes from OneWoW.Inventory; guild/mail suppress stay local.
    if Inventory.IsBankOpen() or self._atGuildBank or self._atMail
        or OneWoW.Merchant.IsMerchantOpen()
        or OneWoW.ProfessionRecipe.IsTradeskillOpen() then
        return
    end
    if Restriction.IsProtectedActionBlocked() then return end

    local items = ns.AutoOpenItems
    if not items then return end

    Inventory.ForEachSlot("player", function(bag, slot, info)
        local itemID = info and info.itemID
        if not itemID or not items[itemID] or AO:IsBlacklisted(itemID) then
            return
        end
        if not openPredicate then return end
        local props = PE:BuildProps(itemID, bag, slot, info)
        if not PE:SafeEvaluate(openPredicate, props) then return end
        local itemLink = props.hyperlink or C_Container.GetContainerItemLink(bag, slot)
        if itemLink then
            print(string.format(L["AUTOOPEN_OPENING"], itemLink))
        end
        C_Container.UseContainerItem(bag, slot)
        return true
    end)
end

function AutoOpenModule:OnEnable()
    Inventory.RegisterDelayedCallback("QoL_autoopen", function()
        AO:ScanAndOpen()
    end)

    -- Guild bank + mail are not Inventory-owned yet; keep a thin local frame.
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_AutoOpen")
        self._frame:SetScript("OnEvent", function(_, event)
            if event == "GUILDBANKFRAME_OPENED" then
                AO._atGuildBank = true
            elseif event == "GUILDBANKFRAME_CLOSED" then
                AO._atGuildBank = false
            elseif event == "MAIL_SHOW" then
                AO._atMail = true
            elseif event == "MAIL_CLOSED" then
                AO._atMail = false
            end
        end)
    end
    OneWoW_QoL:RegisterEnteringWorldHandler("autoopen", function()
        C_Timer.After(2.5, function() AO:ScanAndOpen() end)
    end)
    self._frame:RegisterEvent("MAIL_SHOW")
    self._frame:RegisterEvent("MAIL_CLOSED")
    self._frame:RegisterEvent("GUILDBANKFRAME_OPENED")
    self._frame:RegisterEvent("GUILDBANKFRAME_CLOSED")
end

function AutoOpenModule:OnDisable()
    Inventory.UnregisterCallback("QoL_autoopen")
    if self._frame then
        self._frame:UnregisterAllEvents()
    end
    OneWoW_QoL:UnregisterEnteringWorldHandler("autoopen")
    self._atGuildBank = false
    self._atMail = false
end

function AutoOpenModule:OnToggle()
end

function AutoOpenModule:CreateCustomDetail(detailScrollChild, yOffset, _, registerRefresh)

    local blHeader = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blHeader:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    blHeader:SetText(L["BLACKLIST"])
    blHeader:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - blHeader:GetStringHeight() - 8

    local blDivider = detailScrollChild:CreateTexture(nil, "ARTWORK")
    blDivider:SetHeight(1)
    blDivider:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    blDivider:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    blDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOffset = yOffset - 8

    local blDesc = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    blDesc:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    blDesc:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    blDesc:SetJustifyH("LEFT")
    blDesc:SetWordWrap(true)
    blDesc:SetText(L["AUTOOPEN_BLACKLIST_DESC"])
    yOffset = yOffset - blDesc:GetStringHeight() - 10

    local addLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLabel:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    addLabel:SetText(L["AUTOOPEN_BLACKLIST_ADD"])

    local idBox = CreateFrame("EditBox", nil, detailScrollChild, "BackdropTemplate")
    idBox:SetPoint("LEFT", addLabel, "RIGHT", 8, 0)
    idBox:SetSize(80, 22)
    idBox:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    idBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    idBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    idBox:SetFontObject(GameFontHighlight)
    idBox:SetTextInsets(6, 6, 0, 0)
    idBox:SetAutoFocus(false)
    idBox:SetMaxLetters(10)
    idBox:SetNumeric(true)
    idBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    idBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)
    idBox:SetScript("OnEditFocusGained", function(eb)
        eb:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
    end)
    idBox:SetScript("OnEditFocusLost", function(eb)
        eb:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    local addBtn = OneWoW_GUI:CreateFitTextButton(detailScrollChild, { text = ADD, height = 22 })
    addBtn:SetPoint("LEFT", idBox, "RIGHT", 6, 0)

    local dropZone = CreateFrame("Frame", nil, detailScrollChild, "BackdropTemplate")
    dropZone:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
    dropZone:SetSize(110, 22)
    dropZone:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    dropZone:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    dropZone:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    dropZone:EnableMouse(true)

    local dropText = dropZone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropText:SetPoint("CENTER")
    dropText:SetText(L["DRAG_ITEM_HERE"])

    local function AddItemToBlacklist(itemID)
        if not itemID or itemID <= 0 then return end
        AO:AddToBlacklist(itemID, true)
        local itemName = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
        print(string.format("|cFFFFD700OneWoW QoL:|r " .. (L["AUTOOPEN_BLACKLIST_ADDED"]), itemName))
    end

    addBtn:SetScript("OnClick", function()
        local itemID = tonumber(idBox:GetText())
        if itemID and itemID > 0 then
            AddItemToBlacklist(itemID)
            idBox:SetText("")
            idBox:ClearFocus()
        end
    end)

    idBox:SetScript("OnEnterPressed", function(eb)
        local itemID = tonumber(eb:GetText())
        if itemID and itemID > 0 then
            AddItemToBlacklist(itemID)
            eb:SetText("")
        end
        eb:ClearFocus()
    end)

    dropZone:SetScript("OnEnter", function(dz)
        dz:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        dz:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
    end)
    dropZone:SetScript("OnLeave", function(dz)
        dz:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        dz:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)
    dropZone:SetScript("OnReceiveDrag", function()
        local infoType, itemID = GetCursorInfo()
        if infoType == "item" and itemID then
            ClearCursor()
            AddItemToBlacklist(itemID)
        end
    end)
    dropZone:SetScript("OnMouseUp", function()
        local infoType, itemID = GetCursorInfo()
        if infoType == "item" and itemID then
            ClearCursor()
            AddItemToBlacklist(itemID)
        end
    end)

    yOffset = yOffset - 28 - 10

    local listFrame = CreateFrame("Frame", nil, detailScrollChild, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    listFrame:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    listFrame:SetHeight(120)
    listFrame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    listFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    listFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local blacklist = GetBlacklist()
    local listY = -5
    local hasItems = false
    local removeBtns = {}

    for itemID, _ in pairs(blacklist) do
        hasItems = true
        local itemName = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
        local _, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(itemID)

        local row = CreateFrame("Frame", nil, listFrame)
        row:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 8, listY)
        row:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -8, listY)
        row:SetHeight(20)

        if icon then
            local rowIcon = row:CreateTexture(nil, "ARTWORK")
            rowIcon:SetSize(16, 16)
            rowIcon:SetPoint("LEFT", row, "LEFT", 0, 0)
            rowIcon:SetTexture(icon)
        end

        local rowText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rowText:SetPoint("LEFT", row, "LEFT", 20, 0)
        rowText:SetText(itemName)
        rowText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local removeBtn = CreateFrame("Button", nil, row)
        removeBtn:SetSize(16, 16)
        removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        removeBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
        local capturedID = itemID
        removeBtn:SetScript("OnClick", function()
            AO:RemoveFromBlacklist(capturedID)
            local rName = C_Item.GetItemNameByID(capturedID) or ("Item " .. capturedID)
            print(string.format("|cFFFFD700OneWoW QoL:|r " .. (L["AUTOOPEN_BLACKLIST_REMOVED"]), rName))
        end)
        tinsert(removeBtns, removeBtn)

        listY = listY - 22
    end

    if not hasItems then
        local emptyText = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        emptyText:SetPoint("CENTER", listFrame, "CENTER", 0, 0)
        emptyText:SetText(L["AUTOOPEN_BLACKLIST_EMPTY"])
        emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    local neededHeight = math.max(60, math.abs(listY) + 10)
    listFrame:SetHeight(neededHeight)

    yOffset = yOffset - neededHeight - 8

    local clearBtn = OneWoW_GUI:CreateFitTextButton(detailScrollChild, { text = CLEAR_ALL, height = 22 })
    clearBtn:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    clearBtn:SetScript("OnClick", function()
        AO:ClearBlacklist()
        print("|cFFFFD700OneWoW QoL:|r " .. (L["AUTOOPEN_BLACKLIST_CLEARED"]))
    end)
    yOffset = yOffset - 30

    local function UpdateBlacklist()
        local isEnabledNow = ns.ModuleRegistry:IsEnabled("autoopen")
        if isEnabledNow then
            blDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            addLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            dropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            idBox:EnableKeyboard(true)
        else
            blDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            addLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            dropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            idBox:ClearFocus()
            idBox:EnableKeyboard(false)
        end
        idBox:EnableMouse(isEnabledNow)
        addBtn:EnableMouse(isEnabledNow)
        dropZone:EnableMouse(isEnabledNow)
        for _, btn in ipairs(removeBtns) do
            btn:EnableMouse(isEnabledNow)
        end
        clearBtn:EnableMouse(isEnabledNow)
        if isEnabledNow then
            clearBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            clearBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    if registerRefresh then registerRefresh(UpdateBlacklist) end
    UpdateBlacklist()

    return yOffset
end
