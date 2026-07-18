local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

ns.Compose = {}
local Compose = ns.Compose

local ui = {}
local suggestionFrame
local acIndex = 0
local acList = {}
local sendMoneyMode = true -- true = Send Money, false = COD
local eventsWired = false

local SLOT_SIZE = 42 -- scaled ShipMission equipment atlases (native 78)
local SLOT_ICON_INSET = 7
local SLOT_GAP = 4
local MAX_SLOTS = ns.Constants.SEND_ATTACH_SLOTS
local MAX_SUGGESTIONS = 8
local SUGGEST_ROW_H = 22
local ATLAS_SLOT_BG = "ShipMission_ShipFollower-EquipmentBG"
local ATLAS_SLOT_FRAME = "ShipMission_ShipFollower-EquipmentFrame"

local function GetFieldText(box)
    if not box then
        return ""
    end
    if box.GetSearchText then
        return box:GetSearchText() or ""
    end
    return box:GetText() or ""
end

local function SetFieldText(box, text)
    if not box then
        return
    end
    text = text or ""
    box:SetText(text)
    if text ~= "" then
        box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    elseif box.RestorePlaceholder then
        box:RestorePlaceholder()
    end
end

local function HideSuggestions()
    if suggestionFrame then
        suggestionFrame:Hide()
    end
    acIndex = 0
    wipe(acList)
end

local function ApplySuggestion(text)
    SetFieldText(ui.toBox, text)
    if ui.toBox then
        ui.toBox:SetCursorPosition(#text)
        ui.toBox:SetFocus()
    end
    HideSuggestions()
end

local function SetSuggestionRowHighlight(btn, highlighted)
    if highlighted then
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        btn.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    else
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        btn.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
end

local function HighlightSuggestion(index)
    if not suggestionFrame then
        return
    end
    if index < 1 or index > #acList then
        acIndex = 0
    else
        acIndex = index
    end
    for i, btn in ipairs(suggestionFrame.buttons) do
        if btn:IsShown() then
            SetSuggestionRowHighlight(btn, i == acIndex)
        end
    end
end

local function CreateSuggestionRow(parent)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(SUGGEST_ROW_H - 2)
    btn:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    btn:Hide()

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.label:SetPoint("LEFT", 6, 0)
    btn.label:SetPoint("RIGHT", -6, 0)
    btn.label:SetJustifyH("LEFT")
    btn.label:SetWordWrap(false)
    btn.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    btn:SetScript("OnEnter", function(myself)
        HighlightSuggestion(myself.suggestIndex or 0)
    end)
    btn:SetScript("OnLeave", function(myself)
        if acIndex ~= (myself.suggestIndex or 0) then
            SetSuggestionRowHighlight(myself, false)
        end
    end)
    return btn
end

local function ShowSuggestions(prefix)
    if not suggestionFrame or not ui.toBox then
        return
    end
    prefix = strtrim(prefix or "")
    -- Empty prefix would dump the entire address book (alts/friends/guild).
    if prefix == "" then
        HideSuggestions()
        return
    end

    local matches = ns.AddressBook:Autocomplete(prefix)
    wipe(acList)
    for i = 1, math.min(#matches, MAX_SUGGESTIONS) do
        acList[i] = matches[i]
    end
    if #acList == 0 then
        HideSuggestions()
        return
    end

    suggestionFrame:ClearAllPoints()
    suggestionFrame:SetPoint("TOPLEFT", ui.toBox, "BOTTOMLEFT", 0, -2)
    suggestionFrame:SetPoint("TOPRIGHT", ui.toBox, "BOTTOMRIGHT", 0, -2)
    suggestionFrame:SetHeight(6 + #acList * SUGGEST_ROW_H)
    suggestionFrame:Show()

    for _, btn in ipairs(suggestionFrame.buttons) do
        btn:Hide()
    end

    local frameW = math.max(120, suggestionFrame:GetWidth() or ui.toBox:GetWidth() or 320)
    for i, entry in ipairs(acList) do
        local btn = suggestionFrame.buttons[i]
        if not btn then
            btn = CreateSuggestionRow(suggestionFrame)
            suggestionFrame.buttons[i] = btn
        end
        btn.suggestIndex = i
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", suggestionFrame, "TOPLEFT", 4, -3 - (i - 1) * SUGGEST_ROW_H)
        btn:SetPoint("TOPRIGHT", suggestionFrame, "TOPRIGHT", -4, -3 - (i - 1) * SUGGEST_ROW_H)
        btn:SetWidth(frameW - 8)
        local src = L["SRC_" .. strupper(entry.source)] or entry.source
        btn.label:SetText(entry.text .. " (" .. src .. ")")
        local text = entry.text
        btn:SetScript("OnClick", function()
            ApplySuggestion(text)
        end)
        btn:Show()
    end
    -- No row selected until Down / mouse hover — typing stays in the edit box.
    HighlightSuggestion(0)
end

local function SyncAttachmentSlot(slot, slotIndex)
    local name, _, texture, count = GetSendMailItem(slotIndex)
    if name and texture then
        slot.Icon:SetTexture(texture)
        slot.Icon:Show()
        slot.itemLink = GetSendMailItemLink(slotIndex)
        if count and count > 1 then
            slot.Count:SetText(count)
            slot.Count:Show()
        else
            slot.Count:Hide()
        end
    else
        slot.Icon:Hide()
        slot.Count:Hide()
        slot.itemLink = nil
    end
end

local function RefreshAllSlots()
    if not ui.slots then
        return
    end
    for i = 1, MAX_SLOTS do
        local slot = ui.slots[i]
        if slot then
            SyncAttachmentSlot(slot, i)
        end
    end
end

local function UpdatePostage()
    if not ui.postage then
        return
    end
    local cost = GetSendMailPrice() or 0
    ui.postage:SetText(SEND_MAIL_COST .. " " .. OneWoW.Format.FormatGold(cost))
end

local function MoneyCopper()
    local g = tonumber(GetFieldText(ui.goldBox)) or 0
    local s = tonumber(GetFieldText(ui.silverBox)) or 0
    local c = tonumber(GetFieldText(ui.copperBox)) or 0
    return g * 10000 + s * 100 + c
end

local function SyncMoneyModeButtons()
    if not ui.sendMoneyBtn or not ui.codBtn then
        return
    end
    ui.sendMoneyBtn:SetActive(sendMoneyMode)
    ui.codBtn:SetActive(not sendMoneyMode)
end

--- Thin coin-tinted border so g/s/c fields read at a glance (survives CreateEditBox focus chrome).
local function StyleMoneyBox(box, color)
    local r, g, b = color[1], color[2], color[3]
    local function applyIdle()
        box:SetBackdropBorderColor(r, g, b, 0.85)
    end
    local function applyFocus()
        box:SetBackdropBorderColor(math.min(1, r + 0.12), math.min(1, g + 0.12), math.min(1, b + 0.12), 1)
    end
    applyIdle()
    box:HookScript("OnEditFocusGained", applyFocus)
    box:HookScript("OnEditFocusLost", applyIdle)
end

local function ClearFormFields()
    SetFieldText(ui.toBox, "")
    SetFieldText(ui.subjectBox, "")
    if ui.bodyBox then
        ui.bodyBox:SetText("")
    end
    SetFieldText(ui.goldBox, "")
    SetFieldText(ui.silverBox, "")
    SetFieldText(ui.copperBox, "")
    sendMoneyMode = true
    SyncMoneyModeButtons()
    HideSuggestions()
    RefreshAllSlots()
    UpdatePostage()
end

local function CreateAttachmentSlot(parent, slotIndex)
    local slot = CreateFrame("Button", nil, parent)
    slot:SetSize(SLOT_SIZE, SLOT_SIZE)
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:RegisterForDrag("LeftButton")
    slot.slotIndex = slotIndex

    slot.Bg = slot:CreateTexture(nil, "BACKGROUND")
    slot.Bg:SetAllPoints()
    slot.Bg:SetAtlas(ATLAS_SLOT_BG)

    slot.Icon = slot:CreateTexture(nil, "ARTWORK")
    slot.Icon:SetPoint("TOPLEFT", SLOT_ICON_INSET, -SLOT_ICON_INSET)
    slot.Icon:SetPoint("BOTTOMRIGHT", -SLOT_ICON_INSET, SLOT_ICON_INSET)
    slot.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.Icon:Hide()

    slot.Frame = slot:CreateTexture(nil, "OVERLAY")
    slot.Frame:SetAllPoints()
    slot.Frame:SetAtlas(ATLAS_SLOT_FRAME)

    slot.Count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    slot.Count:SetPoint("BOTTOMRIGHT", -SLOT_ICON_INSET + 1, SLOT_ICON_INSET - 1)
    slot.Count:SetJustifyH("RIGHT")
    slot.Count:Hide()

    slot:SetScript("OnEnter", function(myself)
        if myself.itemLink then
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(myself.itemLink)
            GameTooltip:Show()
        end
        myself.Frame:SetVertexColor(1.15, 1.15, 1.15)
    end)
    slot:SetScript("OnLeave", function(myself)
        GameTooltip_Hide()
        myself.Frame:SetVertexColor(1, 1, 1)
    end)
    slot:SetScript("OnReceiveDrag", function(myself)
        ClickSendMailItemButton(myself.slotIndex)
        C_Timer.After(0.05, function()
            SyncAttachmentSlot(myself, myself.slotIndex)
            UpdatePostage()
        end)
    end)
    slot:SetScript("OnClick", function(myself, button)
        local hasCursor = CursorHasItem and CursorHasItem()
        if button == "RightButton" then
            if hasCursor then
                ClickSendMailItemButton(myself.slotIndex)
            else
                ClickSendMailItemButton(myself.slotIndex, true)
            end
        else
            ClickSendMailItemButton(myself.slotIndex)
        end
        C_Timer.After(0.05, function()
            SyncAttachmentSlot(myself, myself.slotIndex)
            UpdatePostage()
        end)
    end)

    return slot
end

local function DoSend()
    local to = ns.AddressBook:NormalizeRecipient(GetFieldText(ui.toBox))
    local subject = GetFieldText(ui.subjectBox)
    local body = ui.bodyBox and ui.bodyBox:GetText() or ""

    if to == "" then
        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["ERR_NO_TARGET"])
        return
    end

    local isRoster = ns.AddressBook:IsSuiteAlt(to)
    if not isRoster then
        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["WARN_NON_ROSTER"])
    end

    ns.NativeSend:Activate("compose")

    local copper = MoneyCopper()
    if not sendMoneyMode then
        if copper <= 0 then
            print(L["ADDON_CHAT_PREFIX"] .. " " .. AMOUNT_TO_SEND)
            return
        end
        SetSendMailMoney(0)
        SetSendMailCOD(copper)
    else
        SetSendMailCOD(0)
        if copper > 0 then
            SetSendMailMoney(copper)
        else
            SetSendMailMoney(0)
        end
    end

    SendMail(to, subject, body)
end

local function WireEvents()
    if eventsWired then
        return
    end
    eventsWired = true
    local f = CreateFrame("Frame")
    f:RegisterEvent("MAIL_SEND_SUCCESS")
    f:RegisterEvent("MAIL_FAILED")
    f:RegisterEvent("MAIL_SEND_INFO_UPDATE")
    f:SetScript("OnEvent", function(_, event)
        if event == "MAIL_SEND_SUCCESS" then
            -- Fires for EVERY successful send, not just Compose's. Queue sends
            -- (SendQueue teardown is deferred, so IsRunning is still true here)
            -- must not wipe a half-typed draft or remember whatever happens to
            -- sit in the To box.
            if ns.SendQueue:IsRunning() then
                RefreshAllSlots()
                UpdatePostage()
                return
            end
            -- Blizzard MailFrame already runs SendMailFrame_Reset on this event.
            -- Calling ClearSendMail here re-enters the same path and overflows the stack.
            local to = ns.AddressBook:NormalizeRecipient(GetFieldText(ui.toBox))
            if to ~= "" then
                ns.AddressBook:RememberRecipient(to)
            end
            ClearFormFields()
            RefreshAllSlots()
            UpdatePostage()
            if ui.toBox then
                ui.toBox:ClearFocus()
            end
        elseif event == "MAIL_FAILED" then
            RefreshAllSlots()
            UpdatePostage()
        elseif event == "MAIL_SEND_INFO_UPDATE" then
            RefreshAllSlots()
            UpdatePostage()
        end
    end)
end

function Compose:Reset()
    wipe(ui)
    suggestionFrame = nil
    HideSuggestions()
end

function Compose:Create(parent)
    wipe(ui)

    local toLabel = OneWoW_GUI:CreateFS(parent, 12)
    toLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    toLabel:SetText(MAIL_TO_LABEL)
    toLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    ui.toBox = OneWoW_GUI:CreateEditBox(parent, {
        width = 320,
        height = 24,
        placeholderText = "",
    })
    ui.toBox:SetPoint("TOPLEFT", toLabel, "BOTTOMLEFT", 0, -4)
    -- Only user keystrokes — programmatic SetText (last recipient autofill) must not open the list.
    ui.toBox:HookScript("OnTextChanged", function(myself, userInput)
        if not userInput then
            return
        end
        ShowSuggestions(GetFieldText(myself))
    end)
    ui.toBox:HookScript("OnArrowPressed", function(_, key)
        if not suggestionFrame or not suggestionFrame:IsShown() or #acList == 0 then
            return
        end
        if key == "DOWN" then
            local next = acIndex + 1
            if next > #acList then
                next = 1
            end
            HighlightSuggestion(next)
        elseif key == "UP" then
            if acIndex <= 1 then
                HighlightSuggestion(0)
            else
                HighlightSuggestion(acIndex - 1)
            end
        end
    end)
    ui.toBox:HookScript("OnEnterPressed", function()
        if suggestionFrame and suggestionFrame:IsShown() and acIndex >= 1 and acList[acIndex] then
            ApplySuggestion(acList[acIndex].text)
            return
        end
        if ui.subjectBox then
            ui.subjectBox:SetFocus()
        end
    end)
    ui.toBox:HookScript("OnTabPressed", function()
        if suggestionFrame and suggestionFrame:IsShown() and acIndex >= 1 and acList[acIndex] then
            ApplySuggestion(acList[acIndex].text)
        else
            HideSuggestions()
        end
        if ui.subjectBox then
            ui.subjectBox:SetFocus()
        end
    end)
    ui.toBox:HookScript("OnEscapePressed", function()
        HideSuggestions()
    end)
    ui.toBox:HookScript("OnEditFocusLost", function()
        C_Timer.After(0.15, HideSuggestions)
    end)

    local subLabel = OneWoW_GUI:CreateFS(parent, 12)
    subLabel:SetPoint("TOPLEFT", ui.toBox, "BOTTOMLEFT", 0, -10)
    subLabel:SetText(MAIL_SUBJECT_LABEL)
    subLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    ui.subjectBox = OneWoW_GUI:CreateEditBox(parent, {
        width = 420,
        height = 24,
        placeholderText = "",
    })
    ui.subjectBox:SetPoint("TOPLEFT", subLabel, "BOTTOMLEFT", 0, -4)
    ui.subjectBox:HookScript("OnTabPressed", function()
        if ui.bodyBox then
            ui.bodyBox:SetFocus()
        end
    end)

    local bodyWrap = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bodyWrap:SetPoint("TOPLEFT", ui.subjectBox, "BOTTOMLEFT", 0, -10)
    bodyWrap:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    bodyWrap:SetHeight(120)
    bodyWrap:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    bodyWrap:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    bodyWrap:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local bodyScroll, bodyBox = OneWoW_GUI:CreateScrollEditBox(bodyWrap, {
        fontSize = 12,
        maxLetters = 500,
    })
    bodyScroll:ClearAllPoints()
    bodyScroll:SetPoint("TOPLEFT", bodyWrap, "TOPLEFT", 4, -4)
    bodyScroll:SetPoint("BOTTOMRIGHT", bodyWrap, "BOTTOMRIGHT", -4, 4)
    ui.bodyBox = bodyBox
    ui.bodyWrap = bodyWrap

    -- Attachments
    local attachLabel = OneWoW_GUI:CreateFS(parent, 12)
    attachLabel:SetPoint("TOPLEFT", bodyWrap, "BOTTOMLEFT", 0, -10)
    attachLabel:SetText(ATTACHMENT_TEXT)
    attachLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    ui.attachLabel = attachLabel

    local slotRow = CreateFrame("Frame", nil, parent)
    slotRow:SetPoint("TOPLEFT", attachLabel, "BOTTOMLEFT", 0, -6)
    slotRow:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    slotRow:SetHeight(SLOT_SIZE * 2 + SLOT_GAP)
    ui.slotRow = slotRow
    ui.slots = {}

    for i = 1, MAX_SLOTS do
        local slot = CreateAttachmentSlot(slotRow, i)
        local col = (i - 1) % 6
        local row = math.floor((i - 1) / 6)
        slot:SetPoint("TOPLEFT", slotRow, "TOPLEFT", col * (SLOT_SIZE + SLOT_GAP), -row * (SLOT_SIZE + SLOT_GAP))
        ui.slots[i] = slot
    end

    -- Money / COD
    ui.sendMoneyBtn = OneWoW_GUI:CreateFitTextButton(parent, {
        text = SEND_MONEY,
        height = 22,
        toggleable = true,
    })
    ui.sendMoneyBtn:SetPoint("TOPLEFT", slotRow, "BOTTOMLEFT", 0, -12)
    ui.sendMoneyBtn:SetScript("OnClick", function()
        sendMoneyMode = true
        SyncMoneyModeButtons()
    end)

    ui.codBtn = OneWoW_GUI:CreateFitTextButton(parent, {
        text = COD,
        height = 22,
        toggleable = true,
    })
    ui.codBtn:SetPoint("LEFT", ui.sendMoneyBtn, "RIGHT", 6, 0)
    ui.codBtn:SetScript("OnClick", function()
        sendMoneyMode = false
        SyncMoneyModeButtons()
    end)
    SyncMoneyModeButtons()

    local moneyColors = ns.Constants.MONEY_COLORS
    ui.goldBox = OneWoW_GUI:CreateEditBox(parent, { width = 56, height = 22, placeholderText = GOLD_AMOUNT_SYMBOL })
    ui.goldBox:SetPoint("LEFT", ui.codBtn, "RIGHT", 12, 0)
    ui.goldBox:SetNumeric(true)
    StyleMoneyBox(ui.goldBox, moneyColors.GOLD)

    ui.silverBox = OneWoW_GUI:CreateEditBox(parent, { width = 40, height = 22, placeholderText = SILVER_AMOUNT_SYMBOL })
    ui.silverBox:SetPoint("LEFT", ui.goldBox, "RIGHT", 6, 0)
    ui.silverBox:SetNumeric(true)
    StyleMoneyBox(ui.silverBox, moneyColors.SILVER)

    ui.copperBox = OneWoW_GUI:CreateEditBox(parent, { width = 40, height = 22, placeholderText = COPPER_AMOUNT_SYMBOL })
    ui.copperBox:SetPoint("LEFT", ui.silverBox, "RIGHT", 6, 0)
    ui.copperBox:SetNumeric(true)
    StyleMoneyBox(ui.copperBox, moneyColors.COPPER)

    ui.postage = OneWoW_GUI:CreateFS(parent, 12)
    ui.postage:SetPoint("TOPLEFT", ui.sendMoneyBtn, "BOTTOMLEFT", 0, -10)
    ui.postage:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    ui.sendBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = SEND_LABEL, height = 28 })
    ui.sendBtn:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    ui.sendBtn:SetScript("OnClick", DoSend)

    ui.clearBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = CLEAR_ALL, height = 28 })
    ui.clearBtn:SetPoint("RIGHT", ui.sendBtn, "LEFT", -6, 0)
    ui.clearBtn:SetScript("OnClick", function()
        ClearSendMail()
        ClearFormFields()
    end)

    suggestionFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    suggestionFrame:SetSize(320, 200)
    suggestionFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SOFT)
    do
        local r, g, b = OneWoW_GUI:GetThemeColor("BG_PRIMARY")
        suggestionFrame:SetBackdropColor(r, g, b, 1)
    end
    suggestionFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    suggestionFrame:SetFrameStrata("DIALOG")
    suggestionFrame:SetFrameLevel(parent:GetFrameLevel() + 20)
    if suggestionFrame.SetClipsChildren then
        suggestionFrame:SetClipsChildren(true)
    end
    suggestionFrame:Hide()
    suggestionFrame.buttons = {}

    WireEvents()
    UpdatePostage()
end

--- Compose tab selected or MAIL_SHOW while Compose is current.
function Compose:Activate()
    HideSuggestions()
    ns.NativeSend:Activate("compose")
    ns.NativeSend:ReassertPark()

    if ns.db.global.mail.autoFillLastRecipient and ns.db.global.mail.lastRecipient ~= "" then
        if GetFieldText(ui.toBox) == "" then
            SetFieldText(ui.toBox, ns.db.global.mail.lastRecipient)
        end
    end

    RefreshAllSlots()
    UpdatePostage()
end

--- Leave Compose tab (fields kept for this mailbox visit).
function Compose:Deactivate()
    HideSuggestions()
    ns.NativeSend:Deactivate("compose")
end

--- Mailbox closed — clear form + tear down native send.
function Compose:OnMailboxClosed()
    HideSuggestions()
    ClearFormFields()
    ns.NativeSend:DeactivateAll()
end

function Compose:OnShow()
    self:Activate()
end

function Compose:OnHide()
    self:Deactivate()
end

function Compose:Refresh()
    RefreshAllSlots()
    UpdatePostage()
end
