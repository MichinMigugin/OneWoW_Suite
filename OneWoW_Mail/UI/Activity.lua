local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

ns.ActivityUI = {}
local ActivityUI = ns.ActivityUI

local panel
local pendingScroll, pendingChild
local logScroll, logChild
local processBtn, discardBtn, clearBtn, mirrorChatCb
local pendingRows = {} -- pooled expandable pending groups
local logRows = {} -- pooled expandable log rows
local expandedPendingRow
local expandedLogRow
local expandedPendingKey -- survive refresh

local HEADER_H = 30
local PENDING_H = 170
local SECTION_GAP = 14
local LINE_H = 16
local LOG_ROW_H = 22
local LOG_DETAIL_H = 48
local LOG_ROW_GAP = 2
local PENDING_ROW_H = 24
local PENDING_ROW_GAP = 2
local PENDING_ICON = 20

local ATLAS_PROCESS = "common-icon-rotateleft"
local ATLAS_PROCESS_OFF = "common-icon-rotateleft-disable"
local ATLAS_DISCARD = "common-icon-delete"
local ATLAS_DISCARD_OFF = "common-icon-delete-disable"

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

--- Atlas mirrored to a forward-facing arrow (H + V flip of rotateleft).
--- H alone points right with the curve on the bottom; V puts the curve on top.
local function SetMirroredAtlas(tex, atlas)
    local info = C_Texture.GetAtlasInfo(atlas)
    local file = info and (info.file or info.filename)
    if file and info.leftTexCoord then
        tex:SetTexture(file)
        tex:SetTexCoord(
            info.rightTexCoord, info.leftTexCoord,
            info.bottomTexCoord, info.topTexCoord
        )
        return
    end
    tex:SetAtlas(atlas)
end

local function SetProcessIcon(btn, enabled)
    if enabled then
        SetMirroredAtlas(btn.icon, ATLAS_PROCESS)
        btn:Enable()
        btn:SetAlpha(1)
    else
        SetMirroredAtlas(btn.icon, ATLAS_PROCESS_OFF)
        btn:Disable()
        btn:SetAlpha(0.45)
    end
end

local function SetDiscardIcon(btn, enabled)
    if enabled then
        btn.icon:SetAtlas(ATLAS_DISCARD)
        btn:Enable()
        btn:SetAlpha(1)
    else
        btn.icon:SetAtlas(ATLAS_DISCARD_OFF)
        btn:Disable()
        btn:SetAlpha(0.45)
    end
end

local function PendingGroupKey(group)
    return tostring(group.shipmentId or "") .. "\0" .. tostring(group.target or "")
end

local function FormatIntentLine(intent)
    local name
    if intent.money then
        name = OneWoW.Format.FormatGold(intent.money)
    else
        name = ns.ItemLabel.ResolveLabel(intent.itemID, intent.link)
        ns.ItemLabel.RequestLoadIfNeeded(intent.itemID, intent.link)
    end
    if intent.quantity then
        return name .. " x" .. intent.quantity
    end
    return name
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

-- ---------------------------------------------------------------------------
-- Pending review accordion (per shipment+target group)
-- ---------------------------------------------------------------------------

local function CollapsePendingRow(row)
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
    if expandedPendingRow == row then
        expandedPendingRow = nil
    end
end

local function ExpandPendingRow(row)
    if expandedPendingRow and expandedPendingRow ~= row then
        CollapsePendingRow(expandedPendingRow)
    end
    row.isExpanded = true
    if row.expandIcon then
        row.expandIcon:SetAtlas("Gamepad_Rev_Minus_64")
    end
    expandedPendingRow = row
    expandedPendingKey = row.groupKey
    local detail = row.detail
    detail:ClearAllPoints()
    detail:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -PENDING_ROW_GAP)
    detail:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -PENDING_ROW_GAP)
    detail:SetWidth(row:GetWidth() or pendingChild:GetWidth() or 1)
    detail:Show()
end

local function RelayoutPendingRows()
    local y = 0
    for _, row in ipairs(pendingRows) do
        if row:IsShown() then
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", pendingChild, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", pendingChild, "TOPRIGHT", 0, -y)
            y = y + PENDING_ROW_H + PENDING_ROW_GAP
            if row.isExpanded and row.detail and row.detail:IsShown() then
                row.detail:ClearAllPoints()
                row.detail:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -PENDING_ROW_GAP)
                row.detail:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -PENDING_ROW_GAP)
                y = y + (row.detail:GetHeight() or 12) + PENDING_ROW_GAP
            end
        end
    end
    pendingChild:SetHeight(math.max(1, y))
end

local function TogglePendingRow(row)
    if row.isExpanded then
        CollapsePendingRow(row)
        expandedPendingKey = nil
    else
        ExpandPendingRow(row)
    end
    RelayoutPendingRows()
end

local function AcquirePendingRow()
    for _, row in ipairs(pendingRows) do
        if not row:IsShown() then
            row:Show()
            return row
        end
    end

    local row = CreateFrame("Button", nil, pendingChild, "BackdropTemplate")
    row:SetHeight(PENDING_ROW_H)
    row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    row.isExpanded = false

    row.expandBtn = CreateFrame("Button", nil, row)
    row.expandBtn:SetSize(20, PENDING_ROW_H)
    row.expandBtn:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.expandIcon = row.expandBtn:CreateTexture(nil, "ARTWORK")
    row.expandIcon:SetSize(12, 12)
    row.expandIcon:SetPoint("CENTER")
    row.expandIcon:SetAtlas("Gamepad_Rev_Plus_64")
    row.expandBtn:SetScript("OnClick", function()
        TogglePendingRow(row)
    end)

    row.discardBtn = OneWoW_GUI:CreateAtlasIconButton(row, {
        atlas = ATLAS_DISCARD,
        width = PENDING_ICON,
        height = PENDING_ICON,
        iconInset = 2,
    })
    row.discardBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    AttachTooltip(row.discardBtn, L["DISCARD"], L["TT_BTN_DISCARD_SHIPMENT"])
    row.discardBtn:SetScript("OnClick", function()
        if not row.shipmentId then
            return
        end
        ns.AutoRun:Discard({ shipmentId = row.shipmentId, target = row.target })
    end)

    row.processBtn = OneWoW_GUI:CreateAtlasIconButton(row, {
        atlas = ATLAS_PROCESS,
        width = PENDING_ICON,
        height = PENDING_ICON,
        iconInset = 2,
    })
    SetMirroredAtlas(row.processBtn.icon, ATLAS_PROCESS)
    row.processBtn:SetPoint("RIGHT", row.discardBtn, "LEFT", -4, 0)
    AttachTooltip(row.processBtn, L["BTN_PROCESS"], L["TT_BTN_PROCESS_SHIPMENT"])
    row.processBtn:SetScript("OnClick", function()
        if not row.shipmentId then
            return
        end
        ns.AutoRun:Process(nil, { shipmentId = row.shipmentId, target = row.target })
    end)

    row.summary = OneWoW_GUI:CreateFS(row, 11)
    row.summary:SetPoint("LEFT", row.expandBtn, "RIGHT", 4, 0)
    row.summary:SetPoint("RIGHT", row.processBtn, "LEFT", -6, 0)
    row.summary:SetJustifyH("LEFT")
    row.summary:SetWordWrap(false)
    row.summary:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    row.detail = CreateFrame("Frame", nil, pendingChild, "BackdropTemplate")
    row.detail:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    row.detail:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    row.detail:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    row.detail:Hide()

    row.detailText = OneWoW_GUI:CreateFS(row.detail, 11)
    row.detailText:SetPoint("TOPLEFT", row.detail, "TOPLEFT", 8, -6)
    row.detailText:SetPoint("TOPRIGHT", row.detail, "TOPRIGHT", -8, -6)
    row.detailText:SetJustifyH("LEFT")
    row.detailText:SetJustifyV("TOP")
    row.detailText:SetWordWrap(true)
    row.detailText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    row:SetScript("OnClick", function()
        TogglePendingRow(row)
    end)

    tinsert(pendingRows, row)
    return row
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
    for _, row in ipairs(pendingRows) do
        if row ~= expandedPendingRow then
            CollapsePendingRow(row)
        end
        row:Hide()
        row:ClearAllPoints()
        if row.detail then
            row.detail:Hide()
        end
    end
    SyncChildWidth(pendingScroll, pendingChild)

    local groups = ns.AutoRun:GetPendingGroups()
    local busy = ns.SendQueue:IsRunning() or ns.AutoRun:IsProcessing()
    local y = 0

    if #groups == 0 then
        expandedPendingRow = nil
        expandedPendingKey = nil
        if not pendingChild.emptyFs then
            pendingChild.emptyFs = OneWoW_GUI:CreateFS(pendingChild, 11)
        end
        local fs = pendingChild.emptyFs
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", pendingChild, "TOPLEFT", 0, 0)
        fs:SetText(L["ACTIVITY_EMPTY"])
        fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        fs:Show()
        y = LINE_H
    else
        if pendingChild.emptyFs then
            pendingChild.emptyFs:Hide()
        end
        for _, group in ipairs(groups) do
            local row = AcquirePendingRow()
            local key = PendingGroupKey(group)
            row.groupKey = key
            row.shipmentId = group.shipmentId
            row.target = group.target
            row.summary:SetText((group.shipmentName or group.shipmentId or "?")
                .. " >> " .. (group.target or "?"))

            local lines = {}
            for _, intent in ipairs(group.intents) do
                tinsert(lines, FormatIntentLine(intent))
            end
            row.detailText:SetText(table.concat(lines, "\n"))
            local detailH = math.max(28, 12 + (#lines * LINE_H))
            row.detail:SetHeight(detailH)
            local scrollW = math.max(100, (pendingChild:GetWidth() or 100) - 16)
            row.detailText:SetWidth(scrollW)

            SetProcessIcon(row.processBtn, not busy)
            SetDiscardIcon(row.discardBtn, true)

            local keepExpanded = expandedPendingKey == key
            if keepExpanded then
                ExpandPendingRow(row)
            else
                CollapsePendingRow(row)
            end

            row:SetPoint("TOPLEFT", pendingChild, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", pendingChild, "TOPRIGHT", 0, -y)
            y = y + PENDING_ROW_H + PENDING_ROW_GAP
            if keepExpanded then
                y = y + detailH + PENDING_ROW_GAP
            end
        end
    end
    pendingChild:SetHeight(math.max(1, y))

    local canAct = #groups > 0
    SetWidgetEnabled(processBtn, canAct and not busy)
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
        if ns.Shell and ns.Shell.UpdateActivityBadge then
            ns.Shell:UpdateActivityBadge()
        end
        return
    end
    RefreshPending()
    RefreshLog()
    if ns.Shell and ns.Shell.UpdateActivityBadge then
        ns.Shell:UpdateActivityBadge()
    end
end

function ActivityUI:Reset()
    panel = nil
    pendingScroll, pendingChild = nil, nil
    logScroll, logChild = nil, nil
    processBtn, discardBtn, clearBtn, mirrorChatCb = nil, nil, nil, nil
    expandedPendingRow = nil
    expandedLogRow = nil
    expandedPendingKey = nil
    wipe(pendingRows)
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
