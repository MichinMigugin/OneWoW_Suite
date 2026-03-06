-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/autoopen/autoopen.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local AutoOpenModule = {
    id          = "autoopen",
    title       = "AUTOOPEN_TITLE",
    category    = "AUTOMATION",
    description = "AUTOOPEN_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles     = {},
    _frame      = nil,
    _atBank     = false,
    _atMail     = false,
    _atMerchant = false,
    _tempBlacklist = {},
}
local AO = AutoOpenModule

local function GetBlacklist()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then return {} end
    local mods = addon.db.global.modules
    if not mods["autoopen"] then mods["autoopen"] = {} end
    if not mods["autoopen"].blacklist then mods["autoopen"].blacklist = {} end
    return mods["autoopen"].blacklist
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
    if self._atBank or self._atMail or self._atMerchant then return end

    local items = ns.AutoOpenItems
    if not items then return end

    for bag = 0, 4 do
        for slot = 0, C_Container.GetContainerNumSlots(bag) do
            local itemID = C_Container.GetContainerItemID(bag, slot)
            if itemID and items[itemID] and not self:IsBlacklisted(itemID) then
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.hasLoot and not info.isLocked then
                    local itemLink = C_Container.GetContainerItemLink(bag, slot)
                    if itemLink then
                        print(string.format(ns.L["AUTOOPEN_OPENING"] or "Auto-opening: %s", itemLink))
                    end
                    C_Container.UseContainerItem(bag, slot)
                    return
                end
            end
        end
    end
end

function AutoOpenModule:OnEnable()
    if not self._frame then
        self._frame = CreateFrame("Frame", "OneWoW_QoL_AutoOpen")
        self._frame:SetScript("OnEvent", function(frame, event, ...)
            if event == "BAG_UPDATE_DELAYED" then
                AO:ScanAndOpen()
            elseif event == "PLAYER_ENTERING_WORLD" then
                C_Timer.After(2.5, function() AO:ScanAndOpen() end)
            elseif event == "BANKFRAME_OPENED" or event == "GUILDBANKFRAME_OPENED" then
                AO._atBank = true
            elseif event == "BANKFRAME_CLOSED" or event == "GUILDBANKFRAME_CLOSED" then
                AO._atBank = false
            elseif event == "MAIL_SHOW" then
                AO._atMail = true
            elseif event == "MAIL_CLOSED" then
                AO._atMail = false
            elseif event == "MERCHANT_SHOW" then
                AO._atMerchant = true
            elseif event == "MERCHANT_CLOSED" then
                AO._atMerchant = false
            end
        end)
    end
    self._frame:RegisterEvent("BAG_UPDATE_DELAYED")
    self._frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self._frame:RegisterEvent("BANKFRAME_OPENED")
    self._frame:RegisterEvent("BANKFRAME_CLOSED")
    self._frame:RegisterEvent("MAIL_SHOW")
    self._frame:RegisterEvent("MAIL_CLOSED")
    self._frame:RegisterEvent("MERCHANT_SHOW")
    self._frame:RegisterEvent("MERCHANT_CLOSED")
    self._frame:RegisterEvent("GUILDBANKFRAME_OPENED")
    self._frame:RegisterEvent("GUILDBANKFRAME_CLOSED")
end

function AutoOpenModule:OnDisable()
    if self._frame then
        self._frame:UnregisterAllEvents()
    end
    self._atBank    = false
    self._atMail    = false
    self._atMerchant = false
end

function AutoOpenModule:OnToggle(toggleId, value)
end

function AutoOpenModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled)
    local L = ns.L
    local T = ns.T

    local blHeader = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    blHeader:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    blHeader:SetText(L["AUTOOPEN_BLACKLIST"])
    blHeader:SetTextColor(T("ACCENT_SECONDARY"))
    yOffset = yOffset - blHeader:GetStringHeight() - 8

    local blDivider = detailScrollChild:CreateTexture(nil, "ARTWORK")
    blDivider:SetHeight(1)
    blDivider:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    blDivider:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    blDivider:SetColorTexture(T("BORDER_SUBTLE"))
    yOffset = yOffset - 8

    local blDesc = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    blDesc:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    blDesc:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    blDesc:SetJustifyH("LEFT")
    blDesc:SetWordWrap(true)
    blDesc:SetText(L["AUTOOPEN_BLACKLIST_DESC"])
    if isEnabled then
        blDesc:SetTextColor(T("TEXT_SECONDARY"))
    else
        blDesc:SetTextColor(T("TEXT_MUTED"))
    end
    yOffset = yOffset - blDesc:GetStringHeight() - 10

    local addLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addLabel:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    addLabel:SetText(L["AUTOOPEN_BLACKLIST_ADD"])
    if isEnabled then
        addLabel:SetTextColor(T("TEXT_PRIMARY"))
    else
        addLabel:SetTextColor(T("TEXT_MUTED"))
    end

    local idBox = CreateFrame("EditBox", nil, detailScrollChild, "BackdropTemplate")
    idBox:SetPoint("LEFT", addLabel, "RIGHT", 8, 0)
    idBox:SetSize(80, 22)
    idBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    idBox:SetBackdropColor(T("BG_SECONDARY"))
    idBox:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    idBox:SetFontObject(GameFontHighlight)
    idBox:SetTextInsets(6, 6, 0, 0)
    idBox:SetAutoFocus(false)
    idBox:SetMaxLetters(10)
    idBox:SetNumeric(true)
    idBox:SetTextColor(T("TEXT_PRIMARY"))
    idBox:SetScript("OnEscapePressed", function(eb) eb:ClearFocus() end)
    idBox:SetScript("OnEditFocusGained", function(eb)
        eb:SetBackdropBorderColor(T("BORDER_ACCENT"))
    end)
    idBox:SetScript("OnEditFocusLost", function(eb)
        eb:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

    local addBtn = ns.UI.CreateButton(nil, detailScrollChild, L["AUTOOPEN_ADD"], 50, 22)
    addBtn:SetPoint("LEFT", idBox, "RIGHT", 6, 0)

    local dropZone = CreateFrame("Frame", nil, detailScrollChild, "BackdropTemplate")
    dropZone:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
    dropZone:SetSize(110, 22)
    dropZone:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropZone:SetBackdropColor(T("BG_SECONDARY"))
    dropZone:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    dropZone:EnableMouse(true)

    local dropText = dropZone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropText:SetPoint("CENTER")
    dropText:SetText(L["AUTOOPEN_BLACKLIST_DRAG"])
    dropText:SetTextColor(T("TEXT_MUTED"))

    local function AddItemToBlacklist(itemID)
        if not itemID or itemID <= 0 then return end
        AO:AddToBlacklist(itemID, true)
        local itemName = C_Item.GetItemNameByID(itemID) or ("Item " .. itemID)
        print(string.format("|cFFFFD700OneWoW QoL:|r " .. (L["AUTOOPEN_BLACKLIST_ADDED"] or "Added to blacklist: %s"), itemName))
    end

    if isEnabled then
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
            dz:SetBackdropColor(T("BTN_HOVER"))
            dz:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
        end)
        dropZone:SetScript("OnLeave", function(dz)
            dz:SetBackdropColor(T("BG_SECONDARY"))
            dz:SetBackdropBorderColor(T("BORDER_SUBTLE"))
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
    else
        addBtn:EnableMouse(false)
        idBox:EnableMouse(false)
        dropZone:EnableMouse(false)
        addLabel:SetTextColor(T("TEXT_MUTED"))
        dropText:SetTextColor(T("TEXT_MUTED"))
    end

    yOffset = yOffset - 28 - 10

    local listFrame = CreateFrame("Frame", nil, detailScrollChild, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    listFrame:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    listFrame:SetHeight(120)
    listFrame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    listFrame:SetBackdropColor(T("BG_SECONDARY"))
    listFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local blacklist = GetBlacklist()
    local listY = -5
    local hasItems = false

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
        rowText:SetTextColor(T("TEXT_PRIMARY"))

        if isEnabled then
            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(16, 16)
            removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            removeBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
            removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
            local capturedID = itemID
            removeBtn:SetScript("OnClick", function()
                AO:RemoveFromBlacklist(capturedID)
                local rName = C_Item.GetItemNameByID(capturedID) or ("Item " .. capturedID)
                print(string.format("|cFFFFD700OneWoW QoL:|r " .. (ns.L["AUTOOPEN_BLACKLIST_REMOVED"] or "Removed from blacklist: %s"), rName))
            end)
        end

        listY = listY - 22
    end

    if not hasItems then
        local emptyText = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        emptyText:SetPoint("CENTER", listFrame, "CENTER", 0, 0)
        emptyText:SetText(L["AUTOOPEN_BLACKLIST_EMPTY"])
        emptyText:SetTextColor(T("TEXT_MUTED"))
    end

    local neededHeight = math.max(60, math.abs(listY) + 10)
    listFrame:SetHeight(neededHeight)

    yOffset = yOffset - neededHeight - 8

    if isEnabled then
        local clearBtn = ns.UI.CreateButton(nil, detailScrollChild, L["AUTOOPEN_BLACKLIST_CLEAR"], 100, 22)
        clearBtn:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
        clearBtn:SetScript("OnClick", function()
            AO:ClearBlacklist()
            print("|cFFFFD700OneWoW QoL:|r " .. (ns.L["AUTOOPEN_BLACKLIST_CLEARED"] or "Blacklist cleared."))
        end)
        yOffset = yOffset - 30
    end

    return yOffset
end

ns.AutoOpenModule = AutoOpenModule
