local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

OneWoW_Bags.BagsBar = {}
local BagsBar = OneWoW_Bags.BagsBar

local bagsBarFrame = nil
local bagButtons = {}
local eventFrame = nil
local trackerDialog = nil

local ROW1_HEIGHT = 32
local ROW2_HEIGHT = 26
local ROW1_TRACKER_MAX = 3
local MAX_ALT_DISPLAY = 10

local function ShowTrackerDialog()
    local L = OneWoW_Bags.L

    if not trackerDialog then
        local function doAdd()
            local id = tonumber(trackerDialog.editBox:GetText())
            if id and id > 0 then
                local db = OneWoW_Bags.db
                if not db.global.trackedCurrencies then
                    db.global.trackedCurrencies = {}
                end
                local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(id)
                local trackType = "item"
                if currencyInfo and currencyInfo.name and currencyInfo.name ~= "" then
                    trackType = "currency"
                end
                tinsert(db.global.trackedCurrencies, { type = trackType, id = id })
                BagsBar:UpdateTrackers()
            end
            trackerDialog.editBox:SetText("")
            trackerDialog.frame:Hide()
        end

        local dialog = OneWoW_GUI:CreateDialog({
            name = "OneWoW_BagsTrackerDialog",
            title = L["TRACKER_ADD"],
            width = 380,
            height = 170,
            strata = "DIALOG",
            movable = false,
            escClose = true,
            buttons = {
                { text = L["POPUP_ADD"], onClick = function() doAdd() end },
                { text = L["POPUP_CANCEL"], onClick = function(frame) frame:Hide() end },
            },
        })

        local content = dialog.contentFrame

        local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", content, "TOPLEFT", 12, -10)
        label:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, -10)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(true)
        label:SetText(L["TRACKER_ADD_ID"])
        label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local editBox = OneWoW_GUI:CreateEditBox(content, {
            name = "OneWoW_BagsTrackerInput",
            height = 22,
            maxLetters = 10,
        })
        editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
        editBox:SetPoint("TOPRIGHT", label, "BOTTOMRIGHT", 0, -8)
        editBox:SetNumeric(true)
        editBox:SetScript("OnEnterPressed", function() doAdd() end)

        dialog.editBox = editBox
        trackerDialog = dialog
    end

    trackerDialog.frame:Show()
    trackerDialog.editBox:SetText("")
    C_Timer.After(0, function()
        if trackerDialog and trackerDialog.editBox then
            trackerDialog.editBox:SetFocus()
        end
    end)
end

function BagsBar:Create(parent)
    if bagsBarFrame then return bagsBarFrame end

    local Constants = OneWoW_Bags.Constants
    local L = OneWoW_Bags.L
    local C = Constants.GUI

    bagsBarFrame = CreateFrame("Frame", "OneWoW_BagsBar", parent, "BackdropTemplate")
    bagsBarFrame:SetHeight(C.BAGSBAR_HEIGHT)
    bagsBarFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bagsBarFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bagsBarFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    bagsBarFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    bagsBarFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    -- Row 1: bag icons | cleanup button + slots right
    local row1Frame = CreateFrame("Frame", nil, bagsBarFrame)
    row1Frame:SetPoint("TOPLEFT", bagsBarFrame, "TOPLEFT", 0, 0)
    row1Frame:SetPoint("TOPRIGHT", bagsBarFrame, "TOPRIGHT", 0, 0)
    row1Frame:SetHeight(ROW1_HEIGHT)
    bagsBarFrame.row1Frame = row1Frame

    -- Row 2: add tracker | trackers | gold right
    local row2Frame = CreateFrame("Frame", nil, bagsBarFrame, "BackdropTemplate")
    row2Frame:SetPoint("BOTTOMLEFT", bagsBarFrame, "BOTTOMLEFT", 0, 0)
    row2Frame:SetPoint("BOTTOMRIGHT", bagsBarFrame, "BOTTOMRIGHT", 0, 0)
    row2Frame:SetHeight(ROW2_HEIGHT)
    row2Frame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    row2Frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    row2Frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    bagsBarFrame.row2Frame = row2Frame

    -- Bag icon buttons (row 1, left)
    local BagTypes = OneWoW_Bags.BagTypes
    local xOffset = OneWoW_GUI:GetSpacing("SM")

    for i = 0, 4 do
        local bagSlot = BagsBar:CreateBagButton(row1Frame, i, xOffset)
        bagButtons[i] = bagSlot
        xOffset = xOffset + 30
    end

    if BagTypes and BagTypes.REAGENT_BAG then
        local sep = row1Frame:CreateTexture(nil, "ARTWORK")
        sep:SetSize(1, 20)
        sep:SetPoint("LEFT", row1Frame, "LEFT", xOffset + 2, 0)
        sep:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        xOffset = xOffset + 6

        local reagentSlot = BagsBar:CreateBagButton(row1Frame, 5, xOffset)
        bagButtons[5] = reagentSlot
    end

    -- Row 1 right: free slots then cleanup button
    local freeSlots = row1Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    freeSlots:SetPoint("RIGHT", row1Frame, "RIGHT", -OneWoW_GUI:GetSpacing("SM"), 0)
    freeSlots:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    bagsBarFrame.freeSlots = freeSlots

    local cleanupBtn = OneWoW_GUI:CreateFitTextButton(row1Frame, { text = L["CLEANUP"], height = 22 })
    cleanupBtn:SetPoint("RIGHT", freeSlots, "LEFT", -OneWoW_GUI:GetSpacing("SM"), 0)
    cleanupBtn:SetScript("OnClick", function()
        C_Container.SortBags()
    end)
    bagsBarFrame.cleanupBtn = cleanupBtn

    -- Row 2 left: add tracker button
    local addTrackerBtn = OneWoW_GUI:CreateButton(row2Frame, { text = "+", width = 20, height = 20 })
    addTrackerBtn:SetPoint("LEFT", row2Frame, "LEFT", OneWoW_GUI:GetSpacing("SM"), 0)
    addTrackerBtn:SetScript("OnClick", function()
        ShowTrackerDialog()
    end)
    addTrackerBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(OneWoW_Bags.L["TRACKER_ADD"], 1, 1, 1)
        GameTooltip:AddLine(OneWoW_Bags.L["TRACKER_ADD_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addTrackerBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    addTrackerBtn:RegisterForDrag("LeftButton")
    addTrackerBtn:SetScript("OnReceiveDrag", function(self)
        local cursorType, itemID = GetCursorInfo()
        if cursorType == "item" and itemID then
            local db = OneWoW_Bags.db
            if not db.global.trackedCurrencies then db.global.trackedCurrencies = {} end
            tinsert(db.global.trackedCurrencies, { type = "item", id = itemID })
            ClearCursor()
            BagsBar:UpdateTrackers()
        end
    end)
    bagsBarFrame.addTrackerBtn = addTrackerBtn

    local goldBtn = CreateFrame("Button", nil, row2Frame)
    goldBtn:SetHeight(20)
    goldBtn:SetPoint("RIGHT", row2Frame, "RIGHT", -OneWoW_GUI:GetSpacing("SM"), 0)

    local goldText = goldBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldText:SetPoint("RIGHT", goldBtn, "RIGHT", 0, 0)
    goldText:SetText(OneWoW_GUI:FormatGold(GetMoney()))
    bagsBarFrame.goldText = goldText

    goldBtn:SetWidth(math.max(goldText:GetStringWidth() + 4, 60))
    goldBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        BagsBar:ShowGoldTooltip()
        GameTooltip:Show()
    end)
    goldBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bagsBarFrame.goldBtn = goldBtn

    bagsBarFrame.trackerFrames = {}
    BagsBar:UpdateTrackers()

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_MONEY")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_MONEY" and bagsBarFrame and bagsBarFrame.goldText then
            bagsBarFrame.goldText:SetText(OneWoW_GUI:FormatGold(GetMoney()))
            if bagsBarFrame.goldBtn then
                bagsBarFrame.goldBtn:SetWidth(math.max(bagsBarFrame.goldText:GetStringWidth() + 4, 60))
            end
        end
    end)

    return bagsBarFrame
end

function BagsBar:ShowGoldTooltip()
    local L = OneWoW_Bags.L
    local personalCopper = GetMoney()

    if not _G.OneWoW_AltTracker_Character_API then
        GameTooltip:SetText(L["GOLD_TOOLTIP_PERSONAL"], 1, 0.82, 0)
        GameTooltip:AddLine(OneWoW_GUI:FormatGold(personalCopper), 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["GOLD_TOOLTIP_NO_ALTTRACKER"], 0.5, 0.5, 0.5, true)
        return
    end

    local allChars = OneWoW_AltTracker_Character_API.GetAllCharacters()
    local currentKey = OneWoW_AltTracker_Character_API.GetCurrentCharacterKey()
    local warbandGold = (_G.StorageAPI and _G.StorageAPI.GetWarbandBankGold) and _G.StorageAPI.GetWarbandBankGold() or 0

    local altList = {}
    local totalGold = 0
    for _, entry in ipairs(allChars) do
        local money = entry.data.money or 0
        totalGold = totalGold + money
        if entry.key ~= currentKey then
            tinsert(altList, { name = entry.key:match("^([^%-]+)") or entry.key, money = money })
        end
    end
    totalGold = totalGold + warbandGold

    sort(altList, function(a, b) return a.money > b.money end)

    GameTooltip:SetText(L["GOLD_TOOLTIP_PERSONAL"] .. " - " .. OneWoW_GUI:FormatGold(personalCopper), 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["GOLD_TOOLTIP_TOTAL"] .. " - " .. OneWoW_GUI:FormatGold(totalGold), 0.2, 1, 0.2)
    GameTooltip:AddLine(" ")

    if warbandGold > 0 then
        GameTooltip:AddLine(L["GOLD_TOOLTIP_WARBAND"] .. " - " .. OneWoW_GUI:FormatGold(warbandGold), 0.6, 0.8, 1)
    end

    local displayCount = math.min(#altList, MAX_ALT_DISPLAY)
    local othersCount = #altList - displayCount
    local othersGold = 0

    for i = 1, #altList do
        if i <= displayCount then
            GameTooltip:AddLine(altList[i].name .. " - " .. OneWoW_GUI:FormatGold(altList[i].money), 0.8, 0.8, 0.8)
        else
            othersGold = othersGold + altList[i].money
        end
    end

    if othersCount > 0 then
        GameTooltip:AddLine(string.format(L["GOLD_TOOLTIP_OTHERS"], othersCount) .. " - " .. OneWoW_GUI:FormatGold(othersGold), 0.5, 0.5, 0.5)
    end
end

function BagsBar:CreateTrackerFrame(parentFrame, index, entry)
    local L = OneWoW_Bags.L
    local db = OneWoW_Bags.db

    local tf = CreateFrame("Button", nil, parentFrame)
    tf:SetSize(65, 22)

    local iconTexture
    local countValue = 0
    if entry.type == "item" then
        countValue = C_Item.GetItemCount(entry.id, true)
        iconTexture = C_Item.GetItemIconByID(entry.id)
    elseif entry.type == "currency" then
        local info = C_CurrencyInfo.GetCurrencyInfo(entry.id)
        if info then
            iconTexture = info.iconFileID
            countValue = info.quantity
        end
    end

    local iconFrame = OneWoW_GUI:CreateSkinnedIcon(tf, {
        size = 16,
        preset = "clean",
        iconTexture = iconTexture,
    })
    iconFrame:SetPoint("LEFT", tf, "LEFT", 2, 0)
    tf.iconFrame = iconFrame

    local countText = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("LEFT", iconFrame, "RIGHT", 3, 0)
    countText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    countText:SetText("x" .. countValue)
    tf.countText = countText

    local capturedIdx = index
    local removeBtn = OneWoW_GUI:CreateButton(tf, { text = "X", width = 14, height = 14 })
    removeBtn:SetPoint("CENTER", tf.iconFrame, "CENTER", 0, 0)
    removeBtn:SetFrameLevel(tf:GetFrameLevel() + 5)
    removeBtn:Hide()
    removeBtn:SetScript("OnClick", function()
        tremove(db.global.trackedCurrencies, capturedIdx)
        BagsBar:UpdateTrackers()
    end)
    removeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["TRACKER_REMOVE"], 1, 1, 1)
        GameTooltip:Show()
    end)
    removeBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        removeBtn:Hide()
    end)
    tf.removeBtn = removeBtn

    if entry.type == "item" then
        tf:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetItemByID(entry.id)
            GameTooltip:Show()
            if self.removeBtn then self.removeBtn:Show() end
        end)
        tf:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            if self.removeBtn and not self.removeBtn:IsMouseOver() then
                self.removeBtn:Hide()
            end
        end)
    elseif entry.type == "currency" then
        tf:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetCurrencyByID(entry.id)
            GameTooltip:Show()
            if self.removeBtn then self.removeBtn:Show() end
        end)
        tf:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            if self.removeBtn and not self.removeBtn:IsMouseOver() then
                self.removeBtn:Hide()
            end
        end)
    end

    return tf
end

function BagsBar:UpdateTrackers()
    if not bagsBarFrame then return end

    local db = OneWoW_Bags.db
    local C = OneWoW_Bags.Constants.GUI

    if not db.global.trackedCurrencies then
        db.global.trackedCurrencies = {}
    end

    for _, tf in ipairs(bagsBarFrame.trackerFrames) do
        tf:Hide()
        tf:ClearAllPoints()
        tf:SetParent(UIParent)
    end
    bagsBarFrame.trackerFrames = {}

    local trackers = db.global.trackedCurrencies
    local count = #trackers
    local row2Frame = bagsBarFrame.row2Frame

    local needExtraRow = count > ROW1_TRACKER_MAX
    if needExtraRow then
        bagsBarFrame:SetHeight(C.BAGSBAR_HEIGHT + ROW2_HEIGHT)
    else
        bagsBarFrame:SetHeight(C.BAGSBAR_HEIGHT)
    end

    local row2Count = math.min(count, ROW1_TRACKER_MAX)
    local anchorLeft = bagsBarFrame.addTrackerBtn
    for i = 1, row2Count do
        local tf = BagsBar:CreateTrackerFrame(row2Frame, i, trackers[i])
        tf:SetPoint("LEFT", anchorLeft, "RIGHT", 4, 0)
        anchorLeft = tf
        tinsert(bagsBarFrame.trackerFrames, tf)
        tf:Show()
    end

    if needExtraRow then
        local extraRow = bagsBarFrame.extraRow
        if not extraRow then
            extraRow = CreateFrame("Frame", nil, bagsBarFrame, "BackdropTemplate")
            extraRow:SetPoint("BOTTOMLEFT", bagsBarFrame, "BOTTOMLEFT", 0, 0)
            extraRow:SetPoint("BOTTOMRIGHT", bagsBarFrame, "BOTTOMRIGHT", 0, 0)
            extraRow:SetHeight(ROW2_HEIGHT)
            extraRow:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
            extraRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            extraRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            bagsBarFrame.extraRow = extraRow
        end
        extraRow:Show()
        row2Frame:ClearAllPoints()
        row2Frame:SetPoint("BOTTOMLEFT", extraRow, "TOPLEFT", 0, 0)
        row2Frame:SetPoint("BOTTOMRIGHT", extraRow, "TOPRIGHT", 0, 0)

        local xOff = 8
        for i = ROW1_TRACKER_MAX + 1, count do
            local tf = BagsBar:CreateTrackerFrame(extraRow, i, trackers[i])
            tf:SetPoint("LEFT", extraRow, "LEFT", xOff, 0)
            xOff = xOff + 69
            tinsert(bagsBarFrame.trackerFrames, tf)
            tf:Show()
        end
    else
        if bagsBarFrame.extraRow then
            bagsBarFrame.extraRow:Hide()
        end
        row2Frame:ClearAllPoints()
        row2Frame:SetPoint("BOTTOMLEFT", bagsBarFrame, "BOTTOMLEFT", 0, 0)
        row2Frame:SetPoint("BOTTOMRIGHT", bagsBarFrame, "BOTTOMRIGHT", 0, 0)
    end
end

function BagsBar:CreateBagButton(parent, bagIndex, xOffset)
    local L = OneWoW_Bags.L

    local iconTexture
    if bagIndex == 0 then
        iconTexture = "Interface\\Buttons\\Button-Backpack-Up"
    else
        local invSlotID = C_Container.ContainerIDToInventoryID(bagIndex)
        if invSlotID then
            iconTexture = GetInventoryItemTexture("player", invSlotID) or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
        else
            iconTexture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
        end
    end

    local btn = CreateFrame("Button", "OneWoW_BagSlot" .. bagIndex, parent)
    btn:SetSize(26, 26)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(iconTexture)
    btn.icon = icon
    btn._skinnedIcon = icon
    OneWoW_GUI:SkinIconFrame(btn, { preset = "clean" })

    btn:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    btn.bagIndex = bagIndex

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local db = OneWoW_Bags.db
        local selected = db and db.global.selectedBag
        if self.bagIndex == 0 then
            GameTooltip:SetText(BACKPACK_TOOLTIP or "Backpack")
        else
            local invID = C_Container.ContainerIDToInventoryID(self.bagIndex)
            if invID then
                GameTooltip:SetInventoryItem("player", invID)
            end
        end
        if selected == self.bagIndex then
            GameTooltip:AddLine(L["BAG_FILTER_ACTIVE"]:format(L["BAG_" .. self.bagIndex] or ("Bag " .. self.bagIndex)), 0.5, 1, 0.5, true)
            GameTooltip:AddLine(L["BAG_SHOW_ALL"], 0.7, 0.7, 0.7, true)
        else
            GameTooltip:AddLine(L["BAG_SHOW_ONLY"], 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function(self)
        local db = OneWoW_Bags.db
        if not db then return end
        if db.global.selectedBag == self.bagIndex then
            db.global.selectedBag = nil
        else
            db.global.selectedBag = self.bagIndex
            db.global.viewMode = "bag"
            if OneWoW_Bags.InfoBar then
                OneWoW_Bags.InfoBar:UpdateViewButtons()
            end
        end
        BagsBar:UpdateBagHighlights()
        if OneWoW_Bags.GUI and OneWoW_Bags.GUI.RefreshLayout then
            OneWoW_Bags.GUI:RefreshLayout()
        end
    end)

    return btn
end

function BagsBar:UpdateBagHighlights()
    local db = OneWoW_Bags.db
    local selected = db and db.global.selectedBag
    for idx, btn in pairs(bagButtons) do
        if btn._skinBorder then
            if selected ~= nil and selected == idx then
                btn._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                btn._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            end
        elseif btn.border then
            if selected ~= nil and selected == idx then
                btn.border:SetVertexColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                btn.border:SetVertexColor(OneWoW_GUI:GetThemeColor("ACCENT_MUTED"))
            end
        end
    end
end

function BagsBar:UpdateIcons()
    for bagIndex, btn in pairs(bagButtons) do
        if bagIndex > 0 then
            local invSlotID = C_Container.ContainerIDToInventoryID(bagIndex)
            if invSlotID then
                local texID = GetInventoryItemTexture("player", invSlotID) or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
                OneWoW_GUI:UpdateIconTexture(btn, texID)
            end
        end
    end
end

function BagsBar:UpdateFreeSlots(free, total)
    if not bagsBarFrame or not bagsBarFrame.freeSlots then return end
    bagsBarFrame.freeSlots:SetText(string.format("%d/%d", free, total))
end

function BagsBar:GetFrame()
    return bagsBarFrame
end

function BagsBar:SetShown(show)
    if bagsBarFrame then
        bagsBarFrame:SetShown(show)
    end
end

function BagsBar:UpdateRowVisibility()
    if not bagsBarFrame then return end
    local db = OneWoW_Bags.db
    if not db or not db.global then return end

    local altShow = OneWoW_Bags.GUI and OneWoW_Bags.GUI.IsAltShowActive and OneWoW_Bags.GUI:IsAltShowActive()
    local showBags = db.global.showBagsBar ~= false
    local showMoney = db.global.showMoneyBar ~= false
    if altShow then showBags = true; showMoney = true end

    local trackers = db.global.trackedCurrencies or {}
    local hasTrackers = #trackers > 0
    local showRow2 = showMoney or hasTrackers
    local needExtraRow = showRow2 and #trackers > ROW1_TRACKER_MAX

    if bagsBarFrame.row1Frame then
        bagsBarFrame.row1Frame:SetShown(showBags)
    end

    if bagsBarFrame.goldBtn then
        bagsBarFrame.goldBtn:SetShown(showMoney)
    end

    if bagsBarFrame.row2Frame then
        bagsBarFrame.row2Frame:SetShown(showRow2)
    end

    if bagsBarFrame.extraRow then
        bagsBarFrame.extraRow:SetShown(needExtraRow)
    end

    if not showBags and not showRow2 then
        bagsBarFrame:Hide()
        return
    end

    bagsBarFrame:Show()

    local baseHeight = 0
    if showBags then baseHeight = baseHeight + ROW1_HEIGHT end
    if showRow2 then baseHeight = baseHeight + ROW2_HEIGHT end
    if needExtraRow then baseHeight = baseHeight + ROW2_HEIGHT end

    bagsBarFrame:SetHeight(baseHeight)

    if showRow2 then
        bagsBarFrame.row2Frame:ClearAllPoints()
        if needExtraRow and bagsBarFrame.extraRow then
            bagsBarFrame.row2Frame:SetPoint("BOTTOMLEFT", bagsBarFrame.extraRow, "TOPLEFT", 0, 0)
            bagsBarFrame.row2Frame:SetPoint("BOTTOMRIGHT", bagsBarFrame.extraRow, "TOPRIGHT", 0, 0)
        else
            bagsBarFrame.row2Frame:SetPoint("BOTTOMLEFT", bagsBarFrame, "BOTTOMLEFT", 0, 0)
            bagsBarFrame.row2Frame:SetPoint("BOTTOMRIGHT", bagsBarFrame, "BOTTOMRIGHT", 0, 0)
        end
    end

    if showBags then
        bagsBarFrame.row1Frame:ClearAllPoints()
        bagsBarFrame.row1Frame:SetPoint("TOPLEFT", bagsBarFrame, "TOPLEFT", 0, 0)
        bagsBarFrame.row1Frame:SetPoint("TOPRIGHT", bagsBarFrame, "TOPRIGHT", 0, 0)
    end
end

function BagsBar:Reset()
    if trackerDialog then
        trackerDialog.frame:Hide()
    end
    if bagsBarFrame then
        bagsBarFrame:Hide()
        bagsBarFrame:SetParent(UIParent)
    end
    bagsBarFrame = nil
    bagButtons = {}
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame = nil
    end
end
