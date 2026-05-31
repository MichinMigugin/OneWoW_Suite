-- ============================================================================
-- OneWoW_AltTracker/UI/MailDetail.lua
--   Per-character mail detail popup. Opened by clicking the Summary tab's
--   mail icon. Built from OneWoW_GUI helpers (CreateDialog +
--   showScrollFrame); each row is a small horizontal layout of FontStrings.
--
--   Data source: StorageAPI.GetMail(charKey) -> reads OneWoW_AltTracker_Storage
--   directly (no new collectors). Expiry is computed live from the stored
--   `daysLeft` + `collectedAt` fields.
-- ============================================================================
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.UI = ns.UI or {}

local SECONDS_PER_DAY = 86400
local ROW_HEIGHT = 30
local DIALOG_WIDTH = 660
local DIALOG_HEIGHT = 480

local dialogResult -- single reused dialog instance
local rowPool = {}

local function ComputeRemaining(mail)
    if not mail or not mail.daysLeft or not mail.collectedAt then return nil end
    return (mail.daysLeft * SECONDS_PER_DAY) - (time() - mail.collectedAt)
end

local function FormatExpiry(seconds)
    if not seconds then return L["FMT_NEVER"], { 0.6, 0.6, 0.6 } end
    if seconds <= 0 then return L["FMT_LESS_THAN_MINUTE"], { 1, 0.3, 0.3 } end
    local days = math.floor(seconds / SECONDS_PER_DAY)
    local hours = math.floor((seconds % SECONDS_PER_DAY) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local text
    if days > 0 then
        text = string.format("%d%s %d%s", days, L["FMT_DAY_SHORT"], hours, L["FMT_HOUR_SHORT"])
    elseif hours > 0 then
        text = string.format("%d%s %d%s", hours, L["FMT_HOUR_SHORT"], minutes, L["FMT_MINUTE_SHORT"])
    else
        text = string.format("%d%s", math.max(minutes, 1), L["FMT_MINUTE_SHORT"])
    end
    local daysFloat = seconds / SECONDS_PER_DAY
    local color
    if daysFloat < 1 then color = { 1, 0.3, 0.3 }
    elseif daysFloat < 5 then color = { 1, 0.8, 0.2 }
    else color = { 0.5, 1, 0.5 } end
    return text, color
end

local function FormatAgo(epoch)
    if not epoch or epoch <= 0 then return L["FMT_NEVER"] end
    local diff = time() - epoch
    if diff < 60 then return L["FMT_NOW"] end
    local days = math.floor(diff / SECONDS_PER_DAY)
    local hours = math.floor((diff % SECONDS_PER_DAY) / 3600)
    local minutes = math.floor((diff % 3600) / 60)
    if days > 0 then return string.format("%d%s", days, L["FMT_DAY_SHORT"]) end
    if hours > 0 then return string.format("%d%s", hours, L["FMT_HOUR_SHORT"]) end
    return string.format("%d%s", math.max(minutes, 1), L["FMT_MINUTE_SHORT"])
end

local function ContentsLabel(mail)
    local parts = {}
    if mail.CODAmount and mail.CODAmount > 0 then
        parts[#parts + 1] = string.format(L["MAIL_DETAIL_COD_PREFIX"], OneWoW_GUI:FormatGold(mail.CODAmount))
    elseif mail.money and mail.money > 0 then
        parts[#parts + 1] = string.format(L["MAIL_DETAIL_GOLD_PREFIX"], OneWoW_GUI:FormatGold(mail.money))
    end
    if mail.items then
        local n = 0
        for _ in pairs(mail.items) do n = n + 1 end
        if n > 0 then
            local label = n == 1 and L["MAIL_DETAIL_ITEM_COUNT"] or L["MAIL_DETAIL_ITEM_COUNT_PLURAL"]
            parts[#parts + 1] = string.format(label, n)
        end
    end
    if #parts == 0 then return "-" end
    return table.concat(parts, "  ")
end

local function AcquireRow(parent)
    for _, row in ipairs(rowPool) do
        if not row:IsShown() then
            row:Show()
            return row
        end
    end

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))

    row.sender = OneWoW_GUI:CreateFS(row, 12)
    row.sender:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.sender:SetWidth(140)
    row.sender:SetJustifyH("LEFT")

    row.subject = OneWoW_GUI:CreateFS(row, 12)
    row.subject:SetPoint("LEFT", row.sender, "RIGHT", 8, 0)
    row.subject:SetWidth(220)
    row.subject:SetJustifyH("LEFT")
    row.subject:SetWordWrap(false)

    row.contents = OneWoW_GUI:CreateFS(row, 12)
    row.contents:SetPoint("LEFT", row.subject, "RIGHT", 8, 0)
    row.contents:SetWidth(170)
    row.contents:SetJustifyH("LEFT")

    row.expires = OneWoW_GUI:CreateFS(row, 12)
    row.expires:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.expires:SetWidth(80)
    row.expires:SetJustifyH("RIGHT")

    rowPool[#rowPool + 1] = row
    return row
end

local function ReleaseAllRows()
    for _, row in ipairs(rowPool) do
        row:Hide()
        row:ClearAllPoints()
        row:SetParent(nil)
    end
end

local function BuildHeader(scrollContent)
    local header = CreateFrame("Frame", nil, scrollContent)
    header:SetHeight(24)
    header:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, 0)

    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(header)
    bg:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local sender = OneWoW_GUI:CreateFS(header, 12)
    sender:SetPoint("LEFT", header, "LEFT", 8, 0)
    sender:SetWidth(140); sender:SetJustifyH("LEFT")
    sender:SetText(L["MAIL_DETAIL_COL_SENDER"])
    sender:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    local subject = OneWoW_GUI:CreateFS(header, 12)
    subject:SetPoint("LEFT", sender, "RIGHT", 8, 0)
    subject:SetWidth(220); subject:SetJustifyH("LEFT")
    subject:SetText(L["MAIL_DETAIL_COL_SUBJECT"])
    subject:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    local contents = OneWoW_GUI:CreateFS(header, 12)
    contents:SetPoint("LEFT", subject, "RIGHT", 8, 0)
    contents:SetWidth(170); contents:SetJustifyH("LEFT")
    contents:SetText(L["MAIL_DETAIL_COL_CONTENTS"])
    contents:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    local expires = OneWoW_GUI:CreateFS(header, 12)
    expires:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    expires:SetWidth(80); expires:SetJustifyH("RIGHT")
    expires:SetText(L["MAIL_DETAIL_COL_EXPIRES"])
    expires:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    return header
end

local function EnsureDialog()
    if dialogResult and dialogResult.frame then return dialogResult end

    dialogResult = OneWoW_GUI:CreateDialog({
        name = "OneWoW_AltTrackerMailDetailDialog",
        title = L["MAIL_DETAIL_TITLE"]:gsub("%%s", ""),
        width = DIALOG_WIDTH,
        height = DIALOG_HEIGHT,
        showScrollFrame = true,
        escClose = true,
        buttons = {
            { text = L["MAIL_DETAIL_CLOSE"], onClick = function(dialog) dialog:Hide() end },
        },
    })

    local subtitle = OneWoW_GUI:CreateFS(dialogResult.contentFrame, 12)
    subtitle:SetPoint("TOPLEFT", dialogResult.contentFrame, "TOPLEFT", 12, -8)
    subtitle:SetPoint("TOPRIGHT", dialogResult.contentFrame, "TOPRIGHT", -12, -8)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    dialogResult._subtitle = subtitle

    return dialogResult
end

function ns.UI.ShowMailDetail(charKey)
    if not charKey then return end
    local dialog = EnsureDialog()

    local charData = OneWoW_AltTracker_Character_DB
        and OneWoW_AltTracker_Character_DB.characters
        and OneWoW_AltTracker_Character_DB.characters[charKey]
    local charName = (charData and charData.name) or charKey
    dialog.titleBar._titleText:SetText(string.format(L["MAIL_DETAIL_TITLE"], charName))

    local summary = ns.UI.GetMailSummaryForChar and ns.UI.GetMailSummaryForChar(charKey)
    local lastScanText = summary and summary.lastScan and FormatAgo(summary.lastScan) or L["FMT_NEVER"]
    if summary and summary.count > 0 then
        local oldestText = summary.oldestExpirySeconds and (select(1, FormatExpiry(summary.oldestExpirySeconds))) or "-"
        dialog._subtitle:SetText(string.format(L["MAIL_DETAIL_SUBTITLE"], summary.count, oldestText, lastScanText))
    else
        dialog._subtitle:SetText(L["MAIL_DETAIL_SUBTITLE_EMPTY"])
    end

    ReleaseAllRows()
    OneWoW_GUI:ClearFrame(dialog.scrollContent)

    local scrollContent = dialog.scrollContent
    scrollContent:SetPoint("TOPLEFT", dialog.contentFrame, "TOPLEFT", 0, -32)

    local mailData = StorageAPI and StorageAPI.GetMail and StorageAPI.GetMail(charKey)
    if not mailData or not mailData.mails or not next(mailData.mails) then
        local empty = OneWoW_GUI:CreateFS(scrollContent, 13)
        empty:SetPoint("TOP", scrollContent, "TOP", 0, -20)
        empty:SetText(L["MAIL_DETAIL_NEVER_SCANNED"])
        empty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        dialog.frame:Show()
        return
    end

    BuildHeader(scrollContent)

    local rows = {}
    for mailID, mail in pairs(mailData.mails) do
        local remaining = ComputeRemaining(mail)
        if not remaining or remaining > 0 then
            rows[#rows + 1] = { mailID = mailID, mail = mail, remaining = remaining or math.huge }
        end
    end

    table.sort(rows, function(a, b) return a.remaining < b.remaining end)

    local yOffset = -28
    for _, entry in ipairs(rows) do
        local row = AcquireRow(scrollContent)
        row:SetParent(scrollContent)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
        row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)

        local senderText = entry.mail.sender or "?"
        if entry.mail.wasReturned then
            senderText = senderText .. L["MAIL_DETAIL_RETURNED_FLAG"]
        end
        row.sender:SetText(senderText)
        row.sender:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        row.subject:SetText(entry.mail.subject or "")
        row.subject:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        row.contents:SetText(ContentsLabel(entry.mail))
        row.contents:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local expiryText, color = FormatExpiry(entry.remaining ~= math.huge and entry.remaining or nil)
        row.expires:SetText(expiryText)
        row.expires:SetTextColor(color[1], color[2], color[3])

        yOffset = yOffset - (ROW_HEIGHT + 1)
    end

    scrollContent:SetHeight(math.max(1, -yOffset))
    dialog.frame:Show()
end
