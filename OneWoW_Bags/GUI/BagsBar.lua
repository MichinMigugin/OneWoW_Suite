local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BagsBar = {}
local BagsBar = OneWoW_Bags.BagsBar

local bagsBarFrame = nil
local bagButtons = {}
local eventFrame = nil

local ROW1_TRACKER_MAX = 2
local ROW2_HEIGHT = 28

StaticPopupDialogs["ONEWOW_BAGS_ADD_TRACKER"] = {
    text = "",
    button1 = "Add",
    button2 = "Cancel",
    hasEditBox = true,
    OnShow = function(self)
        self.Text:SetText(OneWoW_Bags.L["TRACKER_ADD_ID"])
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self)
        local id = tonumber(self.EditBox:GetText())
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
            table.insert(db.global.trackedCurrencies, { type = trackType, id = id })
            BagsBar:UpdateTrackers()
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["ONEWOW_BAGS_ADD_TRACKER"].OnAccept(parent)
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function FormatGold(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    if gold > 0 then
        return string.format("|cFFFFD100%dg|r |cFFC0C0C0%ds|r |cFFAD6A24%dc|r", gold, silver, cop)
    elseif silver > 0 then
        return string.format("|cFFC0C0C0%ds|r |cFFAD6A24%dc|r", silver, cop)
    else
        return string.format("|cFFAD6A24%dc|r", cop)
    end
end

function BagsBar:Create(parent)
    if bagsBarFrame then return bagsBarFrame end

    local Constants = OneWoW_Bags.Constants
    local GUI = OneWoW_Bags.GUI
    local L = OneWoW_Bags.L
    local C = Constants.GUI
    local T = GUI.GetThemeColor
    local S = GUI.GetSpacing

    bagsBarFrame = CreateFrame("Frame", "OneWoW_BagsBar", parent, "BackdropTemplate")
    bagsBarFrame:SetHeight(C.BAGSBAR_HEIGHT)
    bagsBarFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bagsBarFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bagsBarFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bagsBarFrame:SetBackdropColor(T("BG_TERTIARY"))
    bagsBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local row1Frame = CreateFrame("Frame", nil, bagsBarFrame)
    row1Frame:SetPoint("TOPLEFT", bagsBarFrame, "TOPLEFT", 0, 0)
    row1Frame:SetPoint("TOPRIGHT", bagsBarFrame, "TOPRIGHT", 0, 0)
    row1Frame:SetHeight(C.BAGSBAR_HEIGHT)
    bagsBarFrame.row1Frame = row1Frame

    local row2Frame = CreateFrame("Frame", nil, bagsBarFrame, "BackdropTemplate")
    row2Frame:SetPoint("BOTTOMLEFT", bagsBarFrame, "BOTTOMLEFT", 0, 0)
    row2Frame:SetPoint("BOTTOMRIGHT", bagsBarFrame, "BOTTOMRIGHT", 0, 0)
    row2Frame:SetHeight(ROW2_HEIGHT)
    row2Frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    row2Frame:SetBackdropColor(T("BG_SECONDARY"))
    row2Frame:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    row2Frame:Hide()
    bagsBarFrame.row2Frame = row2Frame

    local BagTypes = OneWoW_Bags.BagTypes
    local xOffset = S("SM")

    for i = 0, 4 do
        local bagSlot = BagsBar:CreateBagButton(row1Frame, i, xOffset)
        bagButtons[i] = bagSlot
        xOffset = xOffset + 30
    end

    if BagTypes and BagTypes.REAGENT_BAG then
        local sep = row1Frame:CreateTexture(nil, "ARTWORK")
        sep:SetSize(1, 20)
        sep:SetPoint("LEFT", row1Frame, "LEFT", xOffset + 2, 0)
        sep:SetColorTexture(T("BORDER_SUBTLE"))
        xOffset = xOffset + 6

        local reagentSlot = BagsBar:CreateBagButton(row1Frame, 5, xOffset)
        bagButtons[5] = reagentSlot
        xOffset = xOffset + 30
    end

    local sep2 = row1Frame:CreateTexture(nil, "ARTWORK")
    sep2:SetSize(1, 20)
    sep2:SetPoint("LEFT", row1Frame, "LEFT", xOffset + 2, 0)
    sep2:SetColorTexture(T("BORDER_SUBTLE"))

    local goldText = row1Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldText:SetPoint("LEFT", row1Frame, "LEFT", xOffset + 10, 0)
    goldText:SetText(FormatGold(GetMoney()))
    bagsBarFrame.goldText = goldText

    local sortBtn = GUI:CreateButton(nil, row1Frame, L["SORT"] or "Sort", 100, 22)
    sortBtn:AutoFit(12)
    sortBtn:SetPoint("RIGHT", row1Frame, "RIGHT", -S("SM"), 0)
    sortBtn:SetScript("OnClick", function()
        C_Container.SortBags()
    end)
    bagsBarFrame.sortBtn = sortBtn

    local freeSlots = row1Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    freeSlots:SetPoint("RIGHT", sortBtn, "LEFT", -S("SM"), 0)
    freeSlots:SetTextColor(T("TEXT_SECONDARY"))
    bagsBarFrame.freeSlots = freeSlots

    local addTrackerBtn = CreateFrame("Button", nil, row1Frame)
    addTrackerBtn:SetSize(20, 20)
    addTrackerBtn:SetPoint("RIGHT", freeSlots, "LEFT", -S("SM"), 0)
    addTrackerBtn:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
    addTrackerBtn:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
    addTrackerBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
    addTrackerBtn:SetScript("OnClick", function()
        StaticPopup_Show("ONEWOW_BAGS_ADD_TRACKER")
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
            table.insert(db.global.trackedCurrencies, { type = "item", id = itemID })
            ClearCursor()
            BagsBar:UpdateTrackers()
        end
    end)
    bagsBarFrame.addTrackerBtn = addTrackerBtn

    bagsBarFrame.trackerFrames = {}

    BagsBar:UpdateTrackers()

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_MONEY")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_MONEY" and bagsBarFrame and bagsBarFrame.goldText then
            bagsBarFrame.goldText:SetText(FormatGold(GetMoney()))
        end
    end)

    return bagsBarFrame
end

function BagsBar:CreateTrackerFrame(parentFrame, index, entry)
    local T = OneWoW_Bags.GUI.GetThemeColor
    local L = OneWoW_Bags.L
    local db = OneWoW_Bags.db

    local tf = CreateFrame("Button", nil, parentFrame)
    tf:SetSize(65, 24)

    local icon = tf:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", tf, "LEFT", 2, 0)
    tf.icon = icon

    local countText = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("LEFT", icon, "RIGHT", 3, 0)
    countText:SetTextColor(T("TEXT_PRIMARY"))
    tf.countText = countText

    local removeBtn = CreateFrame("Button", nil, tf)
    removeBtn:SetSize(12, 12)
    removeBtn:SetPoint("TOPRIGHT", tf, "TOPRIGHT", 0, 0)
    removeBtn:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
    local capturedIdx = index
    removeBtn:SetScript("OnClick", function()
        table.remove(db.global.trackedCurrencies, capturedIdx)
        BagsBar:UpdateTrackers()
    end)
    removeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["TRACKER_REMOVE"], 1, 1, 1)
        GameTooltip:Show()
    end)
    removeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if entry.type == "item" then
        local count = C_Item.GetItemCount(entry.id, true)
        local iconTex = C_Item.GetItemIconByID(entry.id)
        if iconTex then icon:SetTexture(iconTex) end
        countText:SetText("x" .. count)
        tf:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetItemByID(entry.id)
            GameTooltip:Show()
        end)
        tf:SetScript("OnLeave", function() GameTooltip:Hide() end)
    elseif entry.type == "currency" then
        local info = C_CurrencyInfo.GetCurrencyInfo(entry.id)
        if info then
            icon:SetTexture(info.iconFileID)
            countText:SetText("x" .. info.quantity)
        end
        tf:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetCurrencyByID(entry.id)
            GameTooltip:Show()
        end)
        tf:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
    local row1Frame = bagsBarFrame.row1Frame
    local row2Frame = bagsBarFrame.row2Frame

    local needRow2 = count > ROW1_TRACKER_MAX
    row2Frame:SetShown(needRow2)
    bagsBarFrame:SetHeight(C.BAGSBAR_HEIGHT + (needRow2 and ROW2_HEIGHT or 0))

    local row1Count = math.min(count, ROW1_TRACKER_MAX)
    local anchorRight = bagsBarFrame.addTrackerBtn
    for i = row1Count, 1, -1 do
        local tf = BagsBar:CreateTrackerFrame(row1Frame, i, trackers[i])
        tf:SetPoint("RIGHT", anchorRight, "LEFT", -4, 0)
        anchorRight = tf
        table.insert(bagsBarFrame.trackerFrames, tf)
        tf:Show()
    end

    if needRow2 then
        local xOff = 8
        for i = ROW1_TRACKER_MAX + 1, count do
            local tf = BagsBar:CreateTrackerFrame(row2Frame, i, trackers[i])
            tf:SetPoint("LEFT", row2Frame, "LEFT", xOff, 0)
            xOff = xOff + 69
            table.insert(bagsBarFrame.trackerFrames, tf)
            tf:Show()
        end
    end
end

function BagsBar:CreateBagButton(parent, bagIndex, xOffset)
    local T = OneWoW_Bags.GUI.GetThemeColor
    local L = OneWoW_Bags.L

    local btn = CreateFrame("Button", "OneWoW_BagSlot" .. bagIndex, parent)
    btn:SetSize(26, 26)
    btn:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    btn.bagIndex = bagIndex

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(30, 30)
    border:SetPoint("CENTER")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetTexCoord(0.218, 0.718, 0.234, 0.781)
    border:SetBlendMode("ADD")
    border:SetVertexColor(T("ACCENT_MUTED"))
    btn.border = border

    if bagIndex == 0 then
        icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
    else
        local invSlotID = C_Container.ContainerIDToInventoryID(bagIndex)
        if invSlotID then
            local texID = GetInventoryItemTexture("player", invSlotID)
            if texID then
                icon:SetTexture(texID)
            else
                icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
            end
        else
            icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
        end
    end

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
            GameTooltip:AddLine("Click to show all bags", 0.7, 0.7, 0.7, true)
        else
            GameTooltip:AddLine("Click to show only this bag", 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

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
    local T = OneWoW_Bags.GUI.GetThemeColor
    local db = OneWoW_Bags.db
    local selected = db and db.global.selectedBag
    for idx, btn in pairs(bagButtons) do
        if btn.border then
            if selected ~= nil and selected == idx then
                btn.border:SetVertexColor(T("ACCENT_PRIMARY"))
            else
                btn.border:SetVertexColor(T("ACCENT_MUTED"))
            end
        end
    end
end

function BagsBar:UpdateIcons()
    for bagIndex, btn in pairs(bagButtons) do
        if bagIndex > 0 and btn.icon then
            local invSlotID = C_Container.ContainerIDToInventoryID(bagIndex)
            if invSlotID then
                local texID = GetInventoryItemTexture("player", invSlotID)
                if texID then
                    btn.icon:SetTexture(texID)
                else
                    btn.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
                end
            end
        end
    end
end

function BagsBar:UpdateFreeSlots(free, total)
    if not bagsBarFrame or not bagsBarFrame.freeSlots then return end
    local L = OneWoW_Bags.L
    local text = string.format(L["FREE_SLOTS_FORMAT"] or "%d/%d", free, total)
    bagsBarFrame.freeSlots:SetText(text)
end

function BagsBar:GetFrame()
    return bagsBarFrame
end

function BagsBar:SetShown(show)
    if bagsBarFrame then
        bagsBarFrame:SetShown(show)
    end
end

function BagsBar:Reset()
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
