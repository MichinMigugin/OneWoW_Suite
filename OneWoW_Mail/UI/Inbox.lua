local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

ns.Inbox = {}
local Inbox = ns.Inbox

local panel
local scrollChild
local rowPool = {}
local statusMail
local statusGold
local statusItems
local selectedBtn
local returnBtn
local deleteBtn
local cancelBtn
local expandedRow -- exclusive accordion
local expandRestoreKey -- survive Blizzard CheckInbox / MAIL_INBOX_UPDATE rebuilds

local ROW_H = ns.Constants.GUI.ROW_HEIGHT
local ROW_GAP = 2
local DETAIL_PAD = 8
local ATTACH_SIZE = 32
local ATTACH_GAP = 4
local MAX_RECV = ATTACHMENTS_MAX_RECEIVE or 16

local function ScrollGutter()
    return ns.Constants.GUI.SCROLLBAR_CONTENT_GUTTER
end

local function MailKey(sender, subject, money, attachments, CODAmount)
    return table.concat({
        tostring(sender or ""),
        tostring(subject or ""),
        tostring(money or 0),
        tostring(attachments or 0),
        tostring(CODAmount or 0),
    }, "\0")
end

local FILTERS = {
    { id = "all", labelKey = "FILTER_ALL", tipKey = "TT_FILTER_ALL" },
    { id = "gold", labelKey = "FILTER_GOLD", tipKey = "TT_FILTER_GOLD" },
    { id = "items", labelKey = "FILTER_ITEMS", tipKey = "TT_FILTER_ITEMS" },
    { id = "sold", labelKey = "FILTER_SOLD", tipKey = "TT_FILTER_SOLD" },
    { id = "bought", labelKey = "FILTER_BOUGHT", tipKey = "TT_FILTER_BOUGHT" },
    { id = "canceled", labelKey = "FILTER_CANCELED", tipKey = "TT_FILTER_CANCELED" },
    { id = "expired", labelKey = "FILTER_EXPIRED", tipKey = "TT_FILTER_EXPIRED" },
    { id = "other", labelKey = "FILTER_OTHER", tipKey = "TT_FILTER_OTHER" },
    { id = "selected", labelKey = "FILTER_SELECTED", tipKey = "TT_FILTER_SELECTED" },
}

local function AttachTooltip(btn, title, body)
    btn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_BOTTOM")
        GameTooltip:SetText(title, 1, 1, 1)
        if body and body ~= "" then
            GameTooltip:AddLine(body, 0.85, 0.85, 0.85, true)
        end
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", GameTooltip_Hide)
end

local function FormatCount(n, oneKey, manyKey)
    if n == 1 then
        return string.format(L[oneKey], n)
    end
    return string.format(L[manyKey], n)
end

-- Compact inbox expiry. Color threshold mirrors Blizzard InboxFrame_Update
-- (.wow_docs/mail/MailFrame.lua ~254-257): >= 1 day green, else red.
---@param daysLeft number|nil fractional days from GetInboxHeaderInfo
---@return string text
---@return boolean urgent true when under one day
local function FormatDaysLeft(daysLeft)
    daysLeft = tonumber(daysLeft) or 0
    if daysLeft >= 1 then
        return string.format("%dd", math.floor(daysLeft)), false
    end
    local secs = math.max(0, math.floor(daysLeft * 24 * 60 * 60))
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    if h > 0 and m > 0 then
        return string.format("%dh%dm", h, m), true
    elseif h > 0 then
        return string.format("%dh", h), true
    end
    return string.format("%dm", math.max(1, m)), true
end

---@param row table
---@param index number
---@param daysLeft number|nil
local function SetRowExpire(row, index, daysLeft)
    local text, urgent = FormatDaysLeft(daysLeft)
    row.expire:SetText(text)
    -- Blizzard MailFrame.lua ~254-257: GREEN_FONT_COLOR vs RED_FONT_COLOR.
    if urgent then
        row.expire:SetTextColor(RED_FONT_COLOR:GetRGB())
    else
        row.expire:SetTextColor(GREEN_FONT_COLOR:GetRGB())
    end
    row.expireHit.mailIndex = index
end

--- Label + gold amount on one line (Blizzard *_COLON globals already include ":").
---@param label string
---@param copper number
---@return string
local function InvoiceMoneyLine(label, copper)
    return label .. " " .. OneWoW.Format.FormatGold(copper)
end

--- Full AH invoice text for the expand panel (Blizzard OpenMail parity).
---@param index number
---@return string|nil text
---@return string|nil invoiceType
local function BuildInvoiceText(index)
    local invoiceType, itemName, playerName, bid, _, deposit, consignment, _, etaHour, etaMin, count, commerceAuction =
        GetInboxInvoiceInfo(index)
    if not invoiceType then
        return nil, nil
    end

    bid = bid or 0
    deposit = deposit or 0
    consignment = consignment or 0
    count = count or 1

    if playerName == nil then
        playerName = (invoiceType == "buyer") and AUCTION_HOUSE_MAIL_MULTIPLE_SELLERS
            or AUCTION_HOUSE_MAIL_MULTIPLE_BUYERS
    end

    local multipleSale = count > 1
    local displayItem = itemName or ""
    if multipleSale and itemName then
        displayItem = string.format(AUCTION_MAIL_ITEM_STACK, itemName, count)
    end

    local lines = {}

    if invoiceType == "buyer" then
        tinsert(lines, ITEM_PURCHASED_COLON .. " " .. displayItem)
        if not commerceAuction then
            tinsert(lines, SOLD_BY_COLON .. " " .. playerName)
        end
        tinsert(lines, InvoiceMoneyLine(AMOUNT_PAID_COLON, bid))
    elseif invoiceType == "seller" then
        tinsert(lines, ITEM_SOLD_COLON .. " " .. displayItem)
        if not commerceAuction then
            tinsert(lines, PURCHASED_BY_COLON .. " " .. playerName)
        end
        local saleCopper = multipleSale and math.floor(bid / count) or bid
        local saleLine = InvoiceMoneyLine(SALE_PRICE_COLON, saleCopper)
        if multipleSale then
            saleLine = saleLine .. "  " .. string.format(AUCTION_HOUSE_MAIL_FORMAT_COUNT, count)
        end
        tinsert(lines, saleLine)
        tinsert(lines, InvoiceMoneyLine(DEPOSIT_COLON, deposit))
        tinsert(lines, RED_FONT_COLOR:WrapTextInColorCode(
            InvoiceMoneyLine(AUCTION_HOUSE_CUT_COLON, consignment)))
        tinsert(lines, InvoiceMoneyLine(AMOUNT_RECEIVED_COLON, bid + deposit - consignment))
    elseif invoiceType == "seller_temp_invoice" then
        tinsert(lines, ITEM_SOLD_COLON .. " " .. displayItem)
        if not commerceAuction then
            tinsert(lines, PURCHASED_BY_COLON .. " " .. playerName)
        end
        tinsert(lines, InvoiceMoneyLine(AUCTION_INVOICE_PENDING_FUNDS_COLON, bid + deposit - consignment))
        tinsert(lines, AUCTION_INVOICE_FUNDS_NOT_YET_SENT)
        if etaHour ~= nil and etaMin ~= nil then
            tinsert(lines, string.format(AUCTION_INVOICE_FUNDS_DELAY, GameTime_GetFormattedTime(etaHour, etaMin, true)))
        end
    else
        return nil, nil
    end

    return table.concat(lines, "\n"), invoiceType
end

--- Whether the expand control should be clickable (button always visible).
local function MailCanExpand(index, attachments, CODAmount)
    if (attachments or 0) > 1 then
        return true
    end
    if (CODAmount or 0) > 0 then
        return true
    end
    local invoiceType = GetInboxInvoiceInfo(index)
    if invoiceType then
        return true
    end
    local _, _, _, _, _, _, _, _, wasRead, _, _, canReply = GetInboxHeaderInfo(index)
    if canReply then
        return true
    end
    -- Already-read mail: safe to peek body without changing unread state further.
    if wasRead then
        local body = GetInboxText(index)
        if body and strtrim(body) ~= "" then
            return true
        end
    end
    -- Single attachment still gets a detail strip with a proper item tooltip.
    if (attachments or 0) == 1 then
        return true
    end
    return false
end

local function CollapseRow(row)
    if not row then
        return
    end
    row.isExpanded = false
    if row.expandIcon then
        row.expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
    end
    if row.detail then
        row.detail:Hide()
    end
    if expandedRow == row then
        expandedRow = nil
    end
end

local function CaptureExpandKey()
    if expandedRow and expandedRow.mailKey then
        expandRestoreKey = expandedRow.mailKey
    end
end

local ExpandRow -- forward decl for RestoreExpandedRow

local function RestoreExpandedRow()
    if not expandRestoreKey then
        return
    end
    for _, row in ipairs(rowPool) do
        if row:IsShown() and row.mailKey == expandRestoreKey and row.canExpand then
            ExpandRow(row)
            return
        end
    end
    -- Mail gone (collected/deleted) — drop the restore target.
    expandRestoreKey = nil
end

local function RelayoutRows()
    if not scrollChild then
        return
    end
    local y = 0
    for _, row in ipairs(rowPool) do
        if row:IsShown() then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -y)
            y = y + ROW_H
            if row.isExpanded and row.detail and row.detail:IsShown() then
                row.detail:ClearAllPoints()
                row.detail:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -ROW_GAP)
                row.detail:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -ROW_GAP)
                y = y + ROW_GAP + (row.detail:GetHeight() or 0)
            end
            y = y + ROW_GAP
        end
    end
    scrollChild:SetHeight(math.max(1, y))
end

local function EnsureDetail(row)
    if row.detail then
        return row.detail
    end
    local detail = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    detail:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    detail:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    detail:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    detail:Hide()

    detail.moneyLine = OneWoW_GUI:CreateFS(detail, 11)
    detail.moneyLine:SetPoint("TOPLEFT", detail, "TOPLEFT", DETAIL_PAD, -DETAIL_PAD)
    detail.moneyLine:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -DETAIL_PAD, -DETAIL_PAD)
    detail.moneyLine:SetJustifyH("LEFT")
    detail.moneyLine:SetJustifyV("TOP")
    detail.moneyLine:SetWordWrap(true)
    detail.moneyLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    detail.bodyScroll, detail.bodyChild = OneWoW_GUI:CreateScrollFrame(detail, {})
    detail.bodyScroll:ClearAllPoints()
    detail.bodyScroll:SetPoint("TOPLEFT", detail.moneyLine, "BOTTOMLEFT", 0, -6)
    detail.bodyScroll:SetPoint("TOPRIGHT", detail.moneyLine, "BOTTOMRIGHT", 0, -6)
    detail.bodyScroll:SetHeight(72)

    detail.bodyText = OneWoW_GUI:CreateFS(detail.bodyChild, 11)
    detail.bodyText:SetPoint("TOPLEFT", detail.bodyChild, "TOPLEFT", 0, 0)
    detail.bodyText:SetJustifyH("LEFT")
    detail.bodyText:SetJustifyV("TOP")
    detail.bodyText:SetWordWrap(true)
    detail.bodyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    detail.attachRow = CreateFrame("Frame", nil, detail)
    detail.attachRow:SetPoint("TOPLEFT", detail.bodyScroll, "BOTTOMLEFT", 0, -8)
    detail.attachRow:SetPoint("TOPRIGHT", detail.bodyScroll, "BOTTOMRIGHT", 0, -8)
    detail.attachRow:SetHeight(ATTACH_SIZE)
    detail.slots = {}

    for i = 1, MAX_RECV do
        local slot = CreateFrame("Button", nil, detail.attachRow, "BackdropTemplate")
        slot:SetSize(ATTACH_SIZE, ATTACH_SIZE)
        slot:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
        slot:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        slot:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        slot:SetPoint("LEFT", detail.attachRow, "LEFT", (i - 1) * (ATTACH_SIZE + ATTACH_GAP), 0)
        slot:Hide()

        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetPoint("TOPLEFT", 2, -2)
        slot.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        slot.count = OneWoW_GUI:CreateFS(slot, 11)
        slot.count:SetPoint("BOTTOMRIGHT", -1, 1)
        slot.count:SetJustifyH("RIGHT")
        slot.count:Hide()

        slot:SetScript("OnEnter", function(myself)
            if not myself.mailIndex or not myself.attachIndex then
                return
            end
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetInboxItem(myself.mailIndex, myself.attachIndex)
            GameTooltip:Show()
        end)
        slot:SetScript("OnLeave", GameTooltip_Hide)
        slot:SetScript("OnClick", function(myself)
            if myself.mailIndex and myself.attachIndex then
                TakeInboxItem(myself.mailIndex, myself.attachIndex)
                C_Timer.After(0.2, function()
                    if ns.Inbox and ns.Inbox.Refresh then
                        ns.Inbox:Refresh()
                    end
                end)
            end
        end)

        detail.slots[i] = slot
    end

    row.detail = detail
    return detail
end

local function PopulateDetail(row)
    local detail = EnsureDetail(row)
    local index = row.mailIndex
    local _, _, _, _, money, CODAmount = GetInboxHeaderInfo(index)
    money = money or 0
    CODAmount = CODAmount or 0

    local invoiceText = BuildInvoiceText(index)
    local parts = {}
    if invoiceText then
        tinsert(parts, invoiceText)
        -- Invoice already includes amount received / paid; skip generic Gold line.
    elseif money > 0 then
        tinsert(parts, string.format(L["INBOX_STAT_GOLD"], OneWoW.Format.FormatGold(money)))
    end
    if CODAmount > 0 then
        tinsert(parts, COD .. ": " .. OneWoW.Format.FormatGold(CODAmount))
    end

    local contentW = math.max(100, (detail:GetWidth() or 600) - DETAIL_PAD * 2)
    local moneyH = 0
    if #parts > 0 then
        detail.moneyLine:SetWidth(contentW)
        detail.moneyLine:SetText(table.concat(parts, "\n"))
        detail.moneyLine:Show()
        moneyH = detail.moneyLine:GetStringHeight() or 12
    else
        detail.moneyLine:SetText("")
        detail.moneyLine:Hide()
    end

    local body = GetInboxText(index)
    body = body and strtrim(body) or ""
    -- Invoice-first: skip empty-body placeholder when the breakdown is shown.
    local showBody = body ~= "" or not invoiceText
    local bodyScrollH = 0
    if showBody then
        if body == "" then
            detail.bodyText:SetText(L["INBOX_NO_BODY"])
            detail.bodyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        else
            detail.bodyText:SetText(body)
            detail.bodyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        local scrollW = math.max(100, (detail.bodyChild:GetWidth() or 0))
        if scrollW <= 1 then
            scrollW = math.max(100, contentW - ScrollGutter())
            detail.bodyChild:SetWidth(scrollW)
        end
        detail.bodyText:SetWidth(scrollW)
        local bodyH = detail.bodyText:GetStringHeight() or 12
        detail.bodyChild:SetHeight(math.max(bodyH, 12))
        bodyScrollH = math.min(96, math.max(36, bodyH + 4))
        detail.bodyScroll:SetHeight(bodyScrollH)
        detail.bodyScroll:Show()

        detail.bodyScroll:ClearAllPoints()
        if detail.moneyLine:IsShown() then
            detail.bodyScroll:SetPoint("TOPLEFT", detail.moneyLine, "BOTTOMLEFT", 0, -6)
            detail.bodyScroll:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -DETAIL_PAD, -(DETAIL_PAD + moneyH + 6))
        else
            detail.bodyScroll:SetPoint("TOPLEFT", detail, "TOPLEFT", DETAIL_PAD, -DETAIL_PAD)
            detail.bodyScroll:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -DETAIL_PAD, -DETAIL_PAD)
        end
    else
        detail.bodyScroll:Hide()
        detail.bodyScroll:SetHeight(1)
    end

    local shown = 0
    for i = 1, MAX_RECV do
        local slot = detail.slots[i]
        local name, _, texture, count = GetInboxItem(index, i)
        if name and texture then
            slot.mailIndex = index
            slot.attachIndex = i
            slot.icon:SetTexture(texture)
            if count and count > 1 then
                slot.count:SetText(count)
                slot.count:Show()
            else
                slot.count:Hide()
            end
            slot:Show()
            shown = shown + 1
        else
            slot.mailIndex = nil
            slot.attachIndex = nil
            slot:Hide()
        end
    end

    detail.attachRow:ClearAllPoints()
    if showBody then
        detail.attachRow:SetPoint("TOPLEFT", detail.bodyScroll, "BOTTOMLEFT", 0, -8)
        detail.attachRow:SetPoint("TOPRIGHT", detail.bodyScroll, "BOTTOMRIGHT", 0, -8)
    elseif detail.moneyLine:IsShown() then
        detail.attachRow:SetPoint("TOPLEFT", detail.moneyLine, "BOTTOMLEFT", 0, -8)
        detail.attachRow:SetPoint("TOPRIGHT", detail.moneyLine, "BOTTOMRIGHT", 0, -8)
    else
        detail.attachRow:SetPoint("TOPLEFT", detail, "TOPLEFT", DETAIL_PAD, -DETAIL_PAD)
        detail.attachRow:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -DETAIL_PAD, -DETAIL_PAD)
    end

    local height = DETAIL_PAD
    if detail.moneyLine:IsShown() then
        height = height + moneyH + (showBody and 6 or 0)
    end
    if showBody then
        height = height + bodyScrollH
    end
    if shown > 0 then
        detail.attachRow:Show()
        detail.attachRow:SetHeight(ATTACH_SIZE)
        height = height + 8 + ATTACH_SIZE + DETAIL_PAD
    else
        detail.attachRow:Hide()
        detail.attachRow:SetHeight(1)
        height = height + DETAIL_PAD
    end
    detail:SetHeight(height)

    detail:Show()
end

ExpandRow = function(row)
    if not row.canExpand then
        return
    end
    if expandedRow and expandedRow ~= row then
        CollapseRow(expandedRow)
    end
    row.isExpanded = true
    if row.expandIcon then
        row.expandIcon:SetAtlas("Gamepad_Rev_Minus_64")
    end
    expandedRow = row
    expandRestoreKey = row.mailKey
    local detail = EnsureDetail(row)
    detail:ClearAllPoints()
    detail:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -ROW_GAP)
    detail:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -ROW_GAP)
    detail:SetWidth(row:GetWidth() or scrollChild:GetWidth() or 1)
    PopulateDetail(row)
    RelayoutRows()
end

local function ToggleRow(row)
    if not row.canExpand then
        return
    end
    if row.isExpanded then
        CollapseRow(row)
        expandRestoreKey = nil
        RelayoutRows()
    else
        ExpandRow(row)
    end
end

local function SetExpandEnabled(row, enabled)
    row.canExpand = enabled and true or false
    local btn = row.expandBtn
    if not btn then
        return
    end
    -- Keep the button "enabled" so tooltips still fire; gate clicks via canExpand.
    btn:Enable()
    if enabled then
        btn:SetAlpha(1)
        row.expandIcon:SetDesaturated(false)
        btn.tooltipBody = L["TT_INBOX_EXPAND"]
    else
        btn:SetAlpha(0.45)
        row.expandIcon:SetDesaturated(true)
        btn.tooltipBody = L["TT_INBOX_EXPAND_DISABLED"]
        if row.isExpanded then
            CollapseRow(row)
        end
    end
end

local function AcquireRow(parent)
    for _, row in ipairs(rowPool) do
        if not row:IsShown() then
            row:SetParent(parent)
            CollapseRow(row)
            row:Show()
            return row
        end
    end

    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(ROW_H)
    row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    row.isExpanded = false
    row.canExpand = false

    row.expandBtn = CreateFrame("Button", nil, row)
    row.expandBtn:SetSize(22, ROW_H)
    row.expandBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.expandIcon = row.expandBtn:CreateTexture(nil, "ARTWORK")
    row.expandIcon:SetSize(14, 14)
    row.expandIcon:SetPoint("CENTER")
    row.expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
    row.expandBtn:SetScript("OnClick", function()
        ToggleRow(row)
    end)
    row.expandBtn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_LEFT")
        GameTooltip:SetText(L["INBOX_EXPAND"], 1, 1, 1)
        GameTooltip:AddLine(myself.tooltipBody or L["TT_INBOX_EXPAND"], 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    row.expandBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Expire hit + label: expand | expire | money | badge
    row.expireHit = CreateFrame("Button", nil, row)
    row.expireHit:SetSize(44, ROW_H)
    row.expireHit:SetPoint("RIGHT", row.expandBtn, "LEFT", -2, 0)
    row.expireHit:SetScript("OnEnter", function(myself)
        if not myself.mailIndex then
            return
        end
        GameTooltip:SetOwner(myself, "ANCHOR_LEFT")
        if InboxItemCanDelete(myself.mailIndex) then
            GameTooltip:SetText(TIME_UNTIL_DELETED, 1, 1, 1)
        else
            GameTooltip:SetText(TIME_UNTIL_RETURNED, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    row.expireHit:SetScript("OnLeave", GameTooltip_Hide)

    row.expire = OneWoW_GUI:CreateFS(row.expireHit, 11)
    row.expire:SetAllPoints()
    row.expire:SetJustifyH("RIGHT")
    row.expire:SetJustifyV("MIDDLE")

    row.check = OneWoW_GUI:CreateCheckbox(row, { label = "" })
    row.check:SetSize(OneWoW_GUI.Constants.GUI.CHECKBOX_SIZE, OneWoW_GUI.Constants.GUI.CHECKBOX_SIZE)
    row.check:SetPoint("LEFT", row, "LEFT", 6, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)

    row.iconHit = CreateFrame("Button", nil, row)
    row.iconHit:SetAllPoints(row.icon)
    row.iconHit:SetScript("OnEnter", function(myself)
        if myself.mailIndex and myself.attachIndex then
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetInboxItem(myself.mailIndex, myself.attachIndex)
            GameTooltip:Show()
        end
    end)
    row.iconHit:SetScript("OnLeave", GameTooltip_Hide)

    row.sender = OneWoW_GUI:CreateFS(row, 12)
    row.sender:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
    row.sender:SetPoint("TOPRIGHT", row.expireHit, "TOPLEFT", -8, -2)
    row.sender:SetJustifyH("LEFT")
    row.sender:SetWordWrap(false)

    row.subject = OneWoW_GUI:CreateFS(row, 11)
    row.subject:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 2)
    row.subject:SetPoint("BOTTOMRIGHT", row.expireHit, "BOTTOMLEFT", -8, 2)
    row.subject:SetJustifyH("LEFT")
    row.subject:SetWordWrap(false)
    row.subject:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    row.money = OneWoW_GUI:CreateFS(row, 12)
    row.money:SetPoint("RIGHT", row.expireHit, "LEFT", -8, 0)
    row.money:SetJustifyH("RIGHT")

    row.badge = OneWoW_GUI:CreateFS(row, 10)
    row.badge:SetPoint("RIGHT", row.money, "LEFT", -8, 0)

    rowPool[#rowPool + 1] = row
    return row
end

local function ReleaseRows()
    if expandedRow then
        CollapseRow(expandedRow)
    end
    for _, row in ipairs(rowPool) do
        CollapseRow(row)
        row:Hide()
        row:ClearAllPoints()
        if row.detail then
            row.detail:Hide()
            row.detail:ClearAllPoints()
        end
    end
end

function Inbox:Reset()
    panel = nil
    scrollChild = nil
    wipe(rowPool)
    statusMail = nil
    statusGold = nil
    statusItems = nil
    selectedBtn = nil
    returnBtn = nil
    deleteBtn = nil
    cancelBtn = nil
    expandedRow = nil
    expandRestoreKey = nil
end

local function HasSelection()
    local selected = ns.Shell:GetSelected()
    for _, on in pairs(selected) do
        if on then
            return true
        end
    end
    return false
end

--- Keep mouse/tooltips; gate clicks + dim when inactive (same pattern as expand).
local function SetActionInteractive(btn, interactive)
    if not btn then
        return
    end
    btn._interactive = interactive and true or false
    btn:Enable()
    btn:SetAlpha(interactive and 1 or 0.45)
end

function Inbox:SyncActionButtons()
    local hasSel = HasSelection()
    SetActionInteractive(selectedBtn, hasSel)
    SetActionInteractive(returnBtn, hasSel)
    SetActionInteractive(deleteBtn, hasSel)
    -- Cancel stops an in-flight collect; not tied to checkboxes.
    SetActionInteractive(cancelBtn, ns.Collect:IsRunning())
end

function Inbox:Create(parent)
    panel = parent
    local btnH = ns.Constants.GUI.BUTTON_HEIGHT

    local btnBar = CreateFrame("Frame", nil, parent)
    btnBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    btnBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    btnBar:SetHeight(56)

    local prev
    for _, def in ipairs(FILTERS) do
        local btn = OneWoW_GUI:CreateFitTextButton(btnBar, {
            text = L[def.labelKey],
            height = btnH,
        })
        if not prev then
            btn:SetPoint("TOPLEFT", btnBar, "TOPLEFT", 0, 0)
        else
            btn:SetPoint("LEFT", prev, "RIGHT", 3, 0)
        end
        local filterId = def.id
        if filterId == "selected" then
            selectedBtn = btn
            btn:SetScript("OnClick", function(myself)
                if not myself._interactive then
                    return
                end
                ns.Collect:Start(filterId, ns.Shell:GetSelected())
            end)
        else
            btn:SetScript("OnClick", function()
                ns.Collect:Start(filterId, ns.Shell:GetSelected())
            end)
        end
        AttachTooltip(btn, L[def.labelKey], L[def.tipKey])
        prev = btn
    end

    returnBtn = OneWoW_GUI:CreateFitTextButton(btnBar, { text = L["BTN_RETURN"], height = btnH })
    returnBtn:SetPoint("TOPLEFT", btnBar, "TOPLEFT", 0, -28)
    returnBtn:SetScript("OnClick", function(myself)
        if not myself._interactive then
            return
        end
        ns.Collect:ReturnSelected(ns.Shell:GetSelected())
    end)
    AttachTooltip(returnBtn, L["BTN_RETURN"], L["TT_BTN_RETURN"])

    deleteBtn = OneWoW_GUI:CreateFitTextButton(btnBar, { text = DELETE, height = btnH })
    deleteBtn:SetPoint("LEFT", returnBtn, "RIGHT", 4, 0)
    deleteBtn:SetScript("OnClick", function(myself)
        if not myself._interactive then
            return
        end
        ns.Collect:DeleteSelected(ns.Shell:GetSelected())
    end)
    AttachTooltip(deleteBtn, DELETE, L["TT_BTN_DELETE"])

    cancelBtn = OneWoW_GUI:CreateFitTextButton(btnBar, { text = CANCEL, height = btnH })
    cancelBtn:SetPoint("LEFT", deleteBtn, "RIGHT", 4, 0)
    cancelBtn:SetScript("OnClick", function(myself)
        if not myself._interactive then
            return
        end
        ns.Collect:Cancel()
    end)
    AttachTooltip(cancelBtn, CANCEL, L["TT_BTN_CANCEL"])

    -- Auto-collect: [] Gold [] Items — right-aligned on the action row.
    local autoItems = OneWoW_GUI:CreateCheckbox(btnBar, {
        label = L["FILTER_ITEMS"],
        checked = ns.db.global.mail.autoCollectItems,
        onClick = function(myself)
            ns.db.global.mail.autoCollectItems = myself:GetChecked() and true or false
        end,
    })
    local itemsInset = (autoItems._labelGap or 0) + autoItems:GetLabelStringWidth()
    autoItems:SetPoint("TOPRIGHT", btnBar, "TOPRIGHT", -itemsInset, -26)
    AttachTooltip(autoItems, L["FILTER_ITEMS"], L["TT_AUTO_COLLECT_ITEMS"])

    local autoGold = OneWoW_GUI:CreateCheckbox(btnBar, {
        label = L["FILTER_GOLD"],
        checked = ns.db.global.mail.autoCollectGold,
        onClick = function(myself)
            ns.db.global.mail.autoCollectGold = myself:GetChecked() and true or false
        end,
    })
    local goldInset = 8 + (autoGold._labelGap or 0) + autoGold:GetLabelStringWidth()
    autoGold:SetPoint("TOPRIGHT", autoItems, "TOPLEFT", -goldInset, 0)
    AttachTooltip(autoGold, L["FILTER_GOLD"], L["TT_AUTO_COLLECT_GOLD"])

    local autoLabel = OneWoW_GUI:CreateFS(btnBar, 11)
    autoLabel:SetText(L["AUTO_COLLECT"])
    autoLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    autoLabel:SetPoint("RIGHT", autoGold, "LEFT", -6, 0)

    -- Expiry sort — left of Auto-collect cluster; same TOP row as Gold/Items.
    local sortExpiry = OneWoW_GUI:CreateCheckbox(btnBar, {
        label = L["SORT_BY_EXPIRY"],
        checked = ns.db.global.mail.sortByExpiry,
        onClick = function(myself)
            ns.db.global.mail.sortByExpiry = myself:GetChecked() and true or false
            Inbox:Refresh()
        end,
    })
    local sortInset = 12
        + (sortExpiry._labelGap or 0) + sortExpiry:GetLabelStringWidth()
        + 6 + (autoLabel:GetStringWidth() or 0) + 6
    sortExpiry:SetPoint("TOPRIGHT", autoGold, "TOPLEFT", -sortInset, 0)
    AttachTooltip(sortExpiry, L["SORT_BY_EXPIRY"], L["TT_SORT_BY_EXPIRY"])

    local hint = OneWoW_GUI:CreateFS(parent, 11)
    hint:SetPoint("TOPLEFT", btnBar, "BOTTOMLEFT", 0, -6)
    hint:SetPoint("TOPRIGHT", btnBar, "BOTTOMRIGHT", 0, -6)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["INBOX_ROW_HINT"])
    hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local statusBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    statusBar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    statusBar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    statusBar:SetHeight(26)
    statusBar:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    statusBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    statusBar:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    statusMail = OneWoW_GUI:CreateFS(statusBar, 11)
    statusMail:SetPoint("LEFT", statusBar, "LEFT", 10, 0)
    statusMail:SetJustifyH("LEFT")
    statusMail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    statusGold = OneWoW_GUI:CreateFS(statusBar, 11)
    statusGold:SetPoint("CENTER", statusBar, "CENTER", 0, 0)
    statusGold:SetJustifyH("CENTER")
    statusGold:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    statusItems = OneWoW_GUI:CreateFS(statusBar, 11)
    statusItems:SetPoint("RIGHT", statusBar, "RIGHT", -10, 0)
    statusItems:SetJustifyH("RIGHT")
    statusItems:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local scroll, child = OneWoW_GUI:CreateScrollFrame(parent, {})
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", statusBar, "TOPRIGHT", 0, -4)
    scrollChild = child
    panel.scroll = scroll
    panel.statusBar = statusBar

    self:SyncActionButtons()
end

function Inbox:Refresh()
    if not scrollChild then
        return
    end
    CaptureExpandKey()
    ReleaseRows()
    local selected = ns.Shell:GetSelected()
    local num = GetInboxNumItems() or 0
    local totalGold = 0
    local totalItems = 0

    local order = {}
    for i = 1, num do
        local daysLeft = select(7, GetInboxHeaderInfo(i)) or 0
        order[#order + 1] = { index = i, daysLeft = daysLeft }
    end
    if ns.db.global.mail.sortByExpiry then
        sort(order, function(a, b)
            if a.daysLeft ~= b.daysLeft then
                return a.daysLeft < b.daysLeft
            end
            return a.index < b.index
        end)
    end

    for _, entry in ipairs(order) do
        local i = entry.index
        local _, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead = GetInboxHeaderInfo(i)
        local category, hasCOD, isGM = ns.MailClassify:Classify(i)
        money = money or 0
        local attachments = tonumber(itemCount) or 0
        totalGold = totalGold + money
        totalItems = totalItems + attachments

        local row = AcquireRow(scrollChild)
        row.mailIndex = i
        row.mailKey = MailKey(sender, subject, money, attachments, CODAmount)

        row.check:SetChecked(selected[i] == true)
        local index = i
        row.check:SetScript("OnClick", function(myself)
            if myself:GetChecked() then
                selected[index] = true
            else
                selected[index] = nil
            end
            Inbox:SyncActionButtons()
        end)

        local tex
        if attachments > 0 then
            local _, _, texture = GetInboxItem(i, 1)
            tex = texture
            row.iconHit.mailIndex = i
            row.iconHit.attachIndex = 1
        else
            row.iconHit.mailIndex = nil
            row.iconHit.attachIndex = nil
        end
        row.icon:SetTexture(tex or stationeryIcon or "Interface\\Icons\\INV_Letter_02")

        local senderText = sender or "?"
        if isGM then
            senderText = senderText .. " [GM]"
        end
        if hasCOD then
            senderText = senderText .. " [COD]"
        end
        row.sender:SetText(senderText)
        if wasRead == false then
            row.sender:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            row.sender:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        row.subject:SetText(subject or "")
        row.badge:SetText(L["CAT_" .. strupper(category)] or category)
        if money > 0 then
            row.money:SetText(OneWoW.Format.FormatGold(money))
        else
            row.money:SetText("")
        end
        SetRowExpire(row, i, daysLeft or entry.daysLeft)

        SetExpandEnabled(row, MailCanExpand(i, attachments, CODAmount))

        row:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                return
            end
            if IsShiftKeyDown() and (CODAmount or 0) == 0 and not isGM then
                -- Mark read so the minimap mail icon clears (Collect does the same;
                -- Blizzard's modified click opens the letter, which also marks read).
                GetInboxText(index)
                AutoLootMailItem(index)
                if ns.InTransit then
                    ns.InTransit:ClearMatching(nil, subject)
                end
            elseif IsControlKeyDown() then
                local _, _, _, _, _, cod, _, _, _, wasReturned, _, canReply = GetInboxHeaderInfo(index)
                if canReply and not wasReturned and (cod or 0) == 0 then
                    ReturnInboxItem(index)
                end
            end
        end)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end

    RelayoutRows()
    RestoreExpandedRow()

    if statusMail then
        statusMail:SetText(FormatCount(num, "INBOX_MAIL_ONE", "INBOX_MAIL_MANY"))
    end
    if statusGold then
        statusGold:SetText(string.format(L["INBOX_STAT_GOLD"], OneWoW.Format.FormatGold(totalGold)))
    end
    if statusItems then
        statusItems:SetText(FormatCount(totalItems, "INBOX_ITEMS_ONE", "INBOX_ITEMS_MANY"))
    end
    self:SyncActionButtons()
end
