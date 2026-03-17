local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BagsBar = {}
local BagsBar = OneWoW_Bags.BagsBar

local bagsBarFrame = nil
local bagButtons = {}
local eventFrame = nil
local OneWoW_GUI = OneWoW_Bags.GUILib

local ROW1_TRACKER_MAX = 2
local ROW2_HEIGHT = 28

local function T(key)
    return OneWoW_GUI:GetThemeColor(key)
end

local function S(key)
    return OneWoW_GUI:GetSpacing(key)
end

StaticPopupDialogs["ONEWOW_BAGS_ADD_TRACKER"] = {
    text = "",
    button1 = OneWoW_Bags.L["POPUP_ADD"] or "Add",
    button2 = OneWoW_Bags.L["POPUP_CANCEL"] or "Cancel",
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

local function FormatNumber(n)
    local s = tostring(n)
    local pos = #s % 3
    if pos == 0 then pos = 3 end
    local parts = { s:sub(1, pos) }
    for i = pos + 1, #s, 3 do
        parts[#parts + 1] = s:sub(i, i + 2)
    end
    return table.concat(parts, ",")
end

local function FormatGold(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    if gold > 0 then
        return string.format("|cFFFFD100%sg|r |cFFC0C0C0%ds|r |cFFAD6A24%dc|r", FormatNumber(gold), silver, cop)
    elseif silver > 0 then
        return string.format("|cFFC0C0C0%ds|r |cFFAD6A24%dc|r", silver, cop)
    else
        return string.format("|cFFAD6A24%dc|r", cop)
    end
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
    row2Frame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
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

    local goldBtn = CreateFrame("Button", nil, row1Frame)
    goldBtn:SetPoint("LEFT", row1Frame, "LEFT", xOffset + 10, 0)
    goldBtn:SetHeight(22)

    local goldText = goldBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldText:SetPoint("LEFT", goldBtn, "LEFT", 0, 0)
    goldText:SetText(FormatGold(GetMoney()))
    bagsBarFrame.goldText = goldText

    goldBtn:SetWidth(math.max(goldText:GetStringWidth() + 4, 60))

    goldBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        BagsBar:ShowGoldTooltip()
        GameTooltip:Show()
    end)
    goldBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bagsBarFrame.goldBtn = goldBtn

    local sortBtn = OneWoW_GUI:CreateFitTextButton(row1Frame, { text = L["SORT"], height = 22 })
    sortBtn:SetPoint("RIGHT", row1Frame, "RIGHT", -S("SM"), 0)
    sortBtn:SetScript("OnClick", function()
        C_Container.SortBags()
    end)
    bagsBarFrame.sortBtn = sortBtn

    local freeSlots = row1Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    freeSlots:SetPoint("RIGHT", sortBtn, "LEFT", -S("SM"), 0)
    freeSlots:SetTextColor(T("TEXT_SECONDARY"))
    bagsBarFrame.freeSlots = freeSlots

    local addTrackerBtn = OneWoW_GUI:CreateButton(row1Frame, { text = "+", width = 20, height = 20 })
    addTrackerBtn:SetPoint("RIGHT", freeSlots, "LEFT", -S("SM"), 0)
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
            if bagsBarFrame.goldBtn then
                bagsBarFrame.goldBtn:SetWidth(math.max(bagsBarFrame.goldText:GetStringWidth() + 4, 60))
            end
        end
    end)

    return bagsBarFrame
end

local MAX_ALT_DISPLAY = 10

function BagsBar:ShowGoldTooltip()
    local L = OneWoW_Bags.L
    local personalCopper = GetMoney()

    if not _G.OneWoW_AltTracker_Character_API then
        GameTooltip:SetText(L["GOLD_TOOLTIP_PERSONAL"], 1, 0.82, 0)
        GameTooltip:AddLine(FormatGold(personalCopper), 1, 1, 1)
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
            table.insert(altList, { name = entry.key:match("^([^%-]+)") or entry.key, money = money })
        end
    end
    totalGold = totalGold + warbandGold

    table.sort(altList, function(a, b) return a.money > b.money end)

    GameTooltip:SetText(L["GOLD_TOOLTIP_PERSONAL"] .. " - " .. FormatGold(personalCopper), 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["GOLD_TOOLTIP_TOTAL"] .. " - " .. FormatGold(totalGold), 0.2, 1, 0.2)
    GameTooltip:AddLine(" ")

    if warbandGold > 0 then
        GameTooltip:AddLine(L["GOLD_TOOLTIP_WARBAND"] .. " - " .. FormatGold(warbandGold), 0.6, 0.8, 1)
    end

    local displayCount = math.min(#altList, MAX_ALT_DISPLAY)
    local othersCount = #altList - displayCount
    local othersGold = 0

    for i = 1, #altList do
        if i <= displayCount then
            GameTooltip:AddLine(altList[i].name .. " - " .. FormatGold(altList[i].money), 0.8, 0.8, 0.8)
        else
            othersGold = othersGold + altList[i].money
        end
    end

    if othersCount > 0 then
        GameTooltip:AddLine(string.format(L["GOLD_TOOLTIP_OTHERS"], othersCount) .. " - " .. FormatGold(othersGold), 0.5, 0.5, 0.5)
    end
end

function BagsBar:CreateTrackerFrame(parentFrame, index, entry)
    local L = OneWoW_Bags.L
    local db = OneWoW_Bags.db

    local tf = CreateFrame("Button", nil, parentFrame)
    tf:SetSize(65, 24)

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
        size = 18,
        preset = "clean",
        iconTexture = iconTexture,
    })
    iconFrame:SetPoint("LEFT", tf, "LEFT", 2, 0)
    tf.iconFrame = iconFrame

    local countText = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("LEFT", iconFrame, "RIGHT", 3, 0)
    countText:SetTextColor(T("TEXT_PRIMARY"))
    countText:SetText("x" .. countValue)
    tf.countText = countText

    local capturedIdx = index
    local removeBtn = OneWoW_GUI:CreateButton(tf, { text = "X", width = 12, height = 12 })
    removeBtn:SetPoint("TOPRIGHT", tf, "TOPRIGHT", 0, 0)
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
        tf:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetItemByID(entry.id)
            GameTooltip:Show()
        end)
        tf:SetScript("OnLeave", function() GameTooltip:Hide() end)
    elseif entry.type == "currency" then
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
    local db = OneWoW_Bags.db
    local selected = db and db.global.selectedBag
    for idx, btn in pairs(bagButtons) do
        if btn._skinBorder then
            if selected ~= nil and selected == idx then
                btn._skinBorder:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
            else
                btn._skinBorder:SetBackdropBorderColor(T("BORDER_DEFAULT"))
            end
        elseif btn.border then
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
    local L = OneWoW_Bags.L
    local text = string.format(L["FREE_SLOTS_FORMAT"], free, total)
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
        if bagsBarFrame.hoverZone then
            bagsBarFrame.hoverZone:Hide()
            bagsBarFrame.hoverZone:SetParent(UIParent)
        end
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
