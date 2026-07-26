local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

ns.ActivityUI = {}
local ActivityUI = ns.ActivityUI

local panel
local pendingScroll, pendingChild
local logScroll, logChild
local processBtn, discardBtn, clearBtn, mirrorChatCb
local pendingLines = {}
local logRows = {} -- pooled expandable log rows
local expandedLogRow

local HEADER_H = 30
local PENDING_H = 170
local SECTION_GAP = 14
local LINE_H = 16
local LOG_ROW_H = 22
local LOG_DETAIL_H = 48
local LOG_ROW_GAP = 2

local function ScrollGutter()
    return ns.Constants.GUI.SCROLLBAR_CONTENT_GUTTER
end

local SEVERITY_COLOR = {
    error = "TEXT_FEATURES_DISABLED",
    warn = "TEXT_WARNING",
    info = "TEXT_SECONDARY",
}

local function AttachTooltip(frame, title, body)
    frame:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if body and body ~= "" then
            GameTooltip:AddLine(body, 0.85, 0.85, 0.85, true)
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
end

local function SetWidgetEnabled(widget, on)
    if on then
        widget:Enable()
        widget:SetAlpha(1)
    else
        widget:Disable()
        widget:SetAlpha(0.45)
    end
end

local function ResetPool(pool)
    for _, fs in ipairs(pool) do
        fs:Hide()
        fs:ClearAllPoints()
    end
end

local function AcquireLine(pool, parent)
    for _, fs in ipairs(pool) do
        if not fs:IsShown() then
            fs:Show()
            return fs
        end
    end
    local fs = OneWoW_GUI:CreateFS(parent, 11)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    tinsert(pool, fs)
    return fs
end

local function PlaceLine(pool, parent, y, indent)
    local fs = AcquireLine(pool, parent)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", indent or 0, -y)
    fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
    return fs
end

local function SyncChildWidth(scroll, child)
    -- CreateScrollFrame already syncs on size/show; keep a defensive refresh for rebuilds.
    local w = scroll:GetWidth() or 0
    if w > 0 then
        child:SetWidth(math.max(100, w - ScrollGutter()))
    end
end

local function EntryContext(e)
    if e.shipmentName and e.shipmentName ~= "" then
        local context = e.shipmentName
        if e.target and e.target ~= "" then
            context = context .. " >> " .. e.target
        end
        return context .. ": "
    elseif e.target and e.target ~= "" then
        return e.target .. ": "
    end
    return ""
end

local function EntryHasDetail(e)
    return (e.detail and e.detail ~= "" and e.detail ~= e.message)
        or (e.itemLink and e.itemLink ~= "")
        or (e.code and e.code ~= "")
end

local function CollapseLogRow(row)
    if not row then
        return
    end
    row.isExpanded = false
    if row.detail then
        row.detail:Hide()
    end
    if row.expandIcon then
        row.expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
    end
    if expandedLogRow == row then
        expandedLogRow = nil
    end
end

local function ExpandLogRow(row)
    if expandedLogRow and expandedLogRow ~= row then
        CollapseLogRow(expandedLogRow)
    end
    row.isExpanded = true
    if row.expandIcon then
        row.expandIcon:SetAtlas("Gamepad_Rev_Minus_64")
    end
    expandedLogRow = row
    local detail = row.detail
    detail:ClearAllPoints()
    detail:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -LOG_ROW_GAP)
    detail:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -LOG_ROW_GAP)
    detail:SetWidth(row:GetWidth() or logChild:GetWidth() or 1)
    detail:Show()
end

--- Inbox-style accordion: row stays fixed height; detail is a sibling under the row.
local function RelayoutLogRows()
    local y = 0
    for _, row in ipairs(logRows) do
        if row:IsShown() then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", logChild, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", logChild, "TOPRIGHT", 0, -y)
            y = y + LOG_ROW_H + LOG_ROW_GAP
            if row.isExpanded and row.detail and row.detail:IsShown() then
                row.detail:ClearAllPoints()
                row.detail:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -LOG_ROW_GAP)
                row.detail:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -LOG_ROW_GAP)
                y = y + (row.detail:GetHeight() or LOG_DETAIL_H) + LOG_ROW_GAP
            end
        end
    end
    logChild:SetHeight(math.max(1, y))
end

local function ToggleLogRow(row)
    if not row.canExpand then
        return
    end
    if row.isExpanded then
        CollapseLogRow(row)
    else
        ExpandLogRow(row)
    end
    RelayoutLogRows()
end

local function AcquireLogRow()
    for _, row in ipairs(logRows) do
        if not row:IsShown() then
            row:Show()
            return row
        end
    end

    local row = CreateFrame("Button", nil, logChild, "BackdropTemplate")
    row:SetHeight(LOG_ROW_H)
    row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    row.isExpanded = false
    row.canExpand = false

    row.expandBtn = CreateFrame("Button", nil, row)
    row.expandBtn:SetSize(20, LOG_ROW_H)
    row.expandBtn:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.expandIcon = row.expandBtn:CreateTexture(nil, "ARTWORK")
    row.expandIcon:SetSize(12, 12)
    row.expandIcon:SetPoint("CENTER")
    row.expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
    row.expandBtn:SetScript("OnClick", function()
        ToggleLogRow(row)
    end)

    row.summary = OneWoW_GUI:CreateFS(row, 11)
    row.summary:SetPoint("LEFT", row.expandBtn, "RIGHT", 4, 0)
    row.summary:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.summary:SetJustifyH("LEFT")
    row.summary:SetWordWrap(false)

    -- Sibling of the row (parented to scroll child), same as Inbox expand — keeps the
    -- summary vertically centered on the short header when the detail opens.
    row.detail = CreateFrame("Frame", nil, logChild, "BackdropTemplate")
    row.detail:SetHeight(LOG_DETAIL_H)
    row.detail:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    row.detail:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    row.detail:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    row.detail:Hide()

    row.detailText = OneWoW_GUI:CreateFS(row.detail, 11)
    row.detailText:SetPoint("TOPLEFT", row.detail, "TOPLEFT", 8, -8)
    row.detailText:SetPoint("BOTTOMRIGHT", row.detail, "BOTTOMRIGHT", -8, 8)
    row.detailText:SetJustifyH("LEFT")
    row.detailText:SetJustifyV("TOP")
    row.detailText:SetWordWrap(true)
    row.detailText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    row:SetScript("OnClick", function()
        ToggleLogRow(row)
    end)

    tinsert(logRows, row)
    return row
end

local function RefreshPending()
    ResetPool(pendingLines)
    SyncChildWidth(pendingScroll, pendingChild)
    local intents = ns.AutoRun:GetPendingIntents()
    local y = 0
    if #intents == 0 then
        local fs = PlaceLine(pendingLines, pendingChild, y)
        fs:SetText(L["ACTIVITY_EMPTY"])
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        y = y + LINE_H
    else
        local lastShipment
        for _, intent in ipairs(intents) do
            if intent.shipmentId ~= lastShipment then
                lastShipment = intent.shipmentId
                if y > 0 then
                    y = y + 4
                end
                local fs = PlaceLine(pendingLines, pendingChild, y)
                fs:SetText(intent.shipmentName .. " >> " .. (intent.target or "?"))
                fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                y = y + LINE_H + 2
            end
            local fs = PlaceLine(pendingLines, pendingChild, y, 12)
            local name
            if intent.money then
                name = OneWoW.Format.FormatGold(intent.money)
            else
                name = intent.link or C_Item.GetItemNameByID(intent.itemID) or tostring(intent.itemID or "?")
            end
            if intent.quantity then
                fs:SetText(name .. " ×" .. intent.quantity)
            else
                fs:SetText(name)
            end
            fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            y = y + LINE_H
        end
    end
    pendingChild:SetHeight(math.max(1, y))

    local canAct = #intents > 0
    SetWidgetEnabled(processBtn, canAct and not ns.SendQueue:IsRunning() and not ns.AutoRun:IsProcessing())
    SetWidgetEnabled(discardBtn, canAct)
end

local function RefreshLog()
    for _, row in ipairs(logRows) do
        if row ~= expandedLogRow then
            CollapseLogRow(row)
        end
        row:Hide()
        row:ClearAllPoints()
        if row.detail then
            row.detail:Hide()
        end
    end
    SyncChildWidth(logScroll, logChild)
    local entries = ns.RunLog:GetAll()
    local y = 0
    if #entries == 0 then
        expandedLogRow = nil
        -- reuse a plain line for empty state
        if not logChild.emptyFs then
            logChild.emptyFs = OneWoW_GUI:CreateFS(logChild, 11)
        end
        local fs = logChild.emptyFs
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", logChild, "TOPLEFT", 0, 0)
        fs:SetText(L["ACTIVITY_LOG_EMPTY"])
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        fs:Show()
        y = LINE_H
    else
        if logChild.emptyFs then
            logChild.emptyFs:Hide()
        end
        for i = #entries, 1, -1 do
            local e = entries[i]
            local row = AcquireLogRow()
            local canExpand = EntryHasDetail(e)
            row.canExpand = canExpand
            row.expandBtn:SetAlpha(canExpand and 1 or 0.25)
            row.expandBtn:EnableMouse(canExpand)

            local summary = date("%H:%M ", e.time) .. EntryContext(e) .. e.message
            row.summary:SetText(summary)
            row.summary:SetTextColor(OneWoW_GUI:GetThemeColor(SEVERITY_COLOR[e.severity] or "TEXT_SECONDARY"))

            local detailParts = {}
            if e.detail and e.detail ~= "" and e.detail ~= e.message then
                tinsert(detailParts, e.detail)
            end
            if e.itemLink and e.itemLink ~= "" then
                tinsert(detailParts, e.itemLink)
            end
            if e.code and e.code ~= "" then
                tinsert(detailParts, string.format(L["LOG_FAIL_CODE"], e.code))
            end
            -- If structured extras collapsed to nothing, still show the message in the panel.
            if #detailParts == 0 and e.message and e.message ~= "" then
                tinsert(detailParts, e.message)
            end
            row.detailText:SetText(table.concat(detailParts, "\n"))

            local keepExpanded = row.isExpanded and canExpand
            if not keepExpanded then
                CollapseLogRow(row)
            end

            row:SetPoint("TOPLEFT", logChild, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", logChild, "TOPRIGHT", 0, -y)
            y = y + LOG_ROW_H + LOG_ROW_GAP
            if keepExpanded then
                ExpandLogRow(row)
                y = y + LOG_DETAIL_H + LOG_ROW_GAP
            end
        end
    end
    logChild:SetHeight(math.max(1, y))
    SetWidgetEnabled(clearBtn, #entries > 0)
end

function ActivityUI:Refresh()
    if not panel then
        return
    end
    RefreshPending()
    RefreshLog()
end

function ActivityUI:Reset()
    panel = nil
    pendingScroll, pendingChild = nil, nil
    logScroll, logChild = nil, nil
    processBtn, discardBtn, clearBtn, mirrorChatCb = nil, nil, nil, nil
    expandedLogRow = nil
    wipe(pendingLines)
    wipe(logRows)
end

local function CreateSectionScroll(parent)
    local scroll, child = OneWoW_GUI:CreateScrollFrame(parent, {})
    scroll:ClearAllPoints()
    return scroll, child
end

function ActivityUI:Create(parent)
    panel = parent
    local gutter = ScrollGutter()
    local btnH = ns.Constants.GUI.BUTTON_HEIGHT

    local pendingHeader = OneWoW_GUI:CreateFS(parent, 13)
    pendingHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -6)
    pendingHeader:SetText(L["ACTIVITY_PENDING_HEADER"])
    pendingHeader:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    discardBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = L["DISCARD"], height = btnH })
    discardBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -gutter, 0)
    discardBtn:SetScript("OnClick", function()
        ns.AutoRun:Discard()
    end)
    AttachTooltip(discardBtn, L["DISCARD"], L["TT_BTN_DISCARD"])

    processBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = L["BTN_PROCESS"], height = btnH })
    processBtn:SetPoint("RIGHT", discardBtn, "LEFT", -6, 0)
    processBtn:SetScript("OnClick", function()
        ns.AutoRun:Process()
    end)
    AttachTooltip(processBtn, L["BTN_PROCESS"], L["TT_BTN_PROCESS"])

    pendingScroll, pendingChild = CreateSectionScroll(parent)
    pendingScroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -HEADER_H)
    pendingScroll:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -HEADER_H)
    pendingScroll:SetHeight(PENDING_H)

    local logHeader = OneWoW_GUI:CreateFS(parent, 13)
    logHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(HEADER_H + PENDING_H + SECTION_GAP + 6))
    logHeader:SetText(L["ACTIVITY_LOG_HEADER"])
    logHeader:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    clearBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = CLEAR_ALL, height = btnH })
    clearBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -gutter, -(HEADER_H + PENDING_H + SECTION_GAP))
    clearBtn:SetScript("OnClick", function()
        ns.RunLog:Clear()
    end)

    mirrorChatCb = OneWoW_GUI:CreateCheckbox(parent, {
        label = L["LOG_MIRROR_CHAT"],
        checked = ns.db.global.mail.mirrorLogToChat,
        onClick = function(myself)
            ns.db.global.mail.mirrorLogToChat = myself:GetChecked() and true or false
        end,
    })
    local mirrorInset = 8 + (mirrorChatCb._labelGap or 0) + mirrorChatCb:GetLabelStringWidth()
    mirrorChatCb:SetPoint("RIGHT", clearBtn, "LEFT", -mirrorInset, 0)
    AttachTooltip(mirrorChatCb, L["LOG_MIRROR_CHAT"], L["TT_LOG_MIRROR_CHAT"])

    logScroll, logChild = CreateSectionScroll(parent)
    logScroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(HEADER_H + PENDING_H + SECTION_GAP + HEADER_H))
    logScroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    ns.RunLog:SetOnChanged(function()
        ActivityUI:Refresh()
    end)
end
