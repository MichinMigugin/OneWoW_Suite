local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

ns.OtherUI = {}
local OtherUI = ns.OtherUI

local panel
local rakeCopper = 0
local rakeText
local bankSuggest

function OtherUI:Reset()
    panel = nil
    rakeText = nil
    bankSuggest = nil
end

function OtherUI:Create(parent)
    panel = parent

    local title = OneWoW_GUI:CreateFS(parent, 14)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    title:SetText(L["OTHER_TITLE"])

    local bankLabel = OneWoW_GUI:CreateFS(parent, 12)
    bankLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    bankLabel:SetText(L["OTHER_BANKER"])

    local bankBox = OneWoW_GUI:CreateEditBox(parent, {
        width = 280,
        height = 24,
        placeholderText = "",
    })
    bankBox:SetPoint("TOPLEFT", bankLabel, "BOTTOMLEFT", 0, -4)
    bankSuggest = ns.AddressSuggest:Attach(bankBox, {
        onCommit = function(text)
            ns.db.global.mail.bankerTarget = text
        end,
    })
    bankSuggest:SetText(ns.db.global.mail.bankerTarget or "")
    panel.bankBox = bankBox
    panel.bankSuggest = bankSuggest

    local keepLabel = OneWoW_GUI:CreateFS(parent, 12)
    keepLabel:SetPoint("TOPLEFT", bankBox, "BOTTOMLEFT", 0, -8)
    keepLabel:SetText(L["OTHER_KEEP_GOLD"])

    local keepBox = OneWoW_GUI:CreateEditBox(parent, {
        width = 100,
        height = 24,
        placeholderText = GOLD_AMOUNT_SYMBOL,
    })
    keepBox:SetPoint("TOPLEFT", keepLabel, "BOTTOMLEFT", 0, -4)
    keepBox:SetNumeric(true)
    do
        local r, g, b = 1.00, 0.82, 0.10
        local function applyIdle()
            keepBox:SetBackdropBorderColor(r, g, b, 0.85)
        end
        local function applyFocus()
            keepBox:SetBackdropBorderColor(math.min(1, r + 0.12), math.min(1, g + 0.12), math.min(1, b + 0.12), 1)
        end
        applyIdle()
        keepBox:HookScript("OnEditFocusGained", applyFocus)
        keepBox:HookScript("OnEditFocusLost", applyIdle)
    end
    local keepGold = math.floor((ns.db.global.mail.excessGoldKeepCopper or 0) / 10000)
    if keepGold > 0 then
        keepBox:SetText(tostring(keepGold))
        keepBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
    keepBox:HookScript("OnEditFocusLost", function(myself)
        local gold = tonumber(myself.GetSearchText and myself:GetSearchText() or myself:GetText()) or 0
        ns.db.global.mail.excessGoldKeepCopper = gold * 10000
    end)
    panel.keepBox = keepBox

    local sendGold = OneWoW_GUI:CreateFitTextButton(parent, { text = L["BTN_SEND_EXCESS_GOLD"], height = 26 })
    sendGold:SetPoint("TOPLEFT", keepBox, "BOTTOMLEFT", 0, -8)
    local goldSendPending = false
    sendGold:SetScript("OnClick", function()
        if goldSendPending then
            return
        end
        local target = bankSuggest:GetText()
        ns.db.global.mail.bankerTarget = target
        if target == "" then
            print(L["ADDON_CHAT_PREFIX"] .. " " .. L["ERR_NO_TARGET"])
            return
        end
        local keep = ns.db.global.mail.excessGoldKeepCopper or 0
        local have = GetMoney()
        local send = have - keep - (GetSendMailPrice() or 30)
        if send <= 0 then
            print(L["ADDON_CHAT_PREFIX"] .. " " .. L["ERR_NO_EXCESS_GOLD"])
            return
        end
        ns.NativeSend:Activate("other")
        ClearSendMail()
        local norm = ns.AddressBook:NormalizeRecipient(target)
        SetSendMailMoney(send)

        local function settle()
            goldSendPending = false
            ns.NativeSend:Deactivate("other")
            if ns.NativeSend:HasHolder("compose") and ns.Compose and ns.Compose.Refresh then
                ns.Compose:Refresh()
            end
        end
        goldSendPending = true
        -- Only report success (and pollute recents) once the server acks.
        ns.SendResult:Listen(function()
            ns.AddressBook:RememberRecipient(norm)
            print(L["ADDON_CHAT_PREFIX"] .. " " .. string.format(L["SENT_GOLD"], OneWoW.Format.FormatGold(send), norm))
            settle()
        end, function()
            print(L["ADDON_CHAT_PREFIX"] .. " " .. L["ERR_SEND_FAILED"])
            settle()
        end)
        SendMail(norm, ns.Constants.SUBJECT_PREFIX .. "gold", "")
    end)

    rakeText = OneWoW_GUI:CreateFS(parent, 12)
    rakeText:SetPoint("TOPLEFT", sendGold, "BOTTOMLEFT", 0, -24)
    rakeText:SetText(string.format(L["RAKE_SESSION"], OneWoW.Format.FormatGold(0)))
end

function OtherUI:Refresh()
    if rakeText then
        rakeText:SetText(string.format(L["RAKE_SESSION"], OneWoW.Format.FormatGold(rakeCopper)))
    end
    if bankSuggest then
        bankSuggest:SetText(ns.db.global.mail.bankerTarget or "")
    end
end

--- Count mail income only — called from the paths that actually take inbox
--- money (Collect, inbox shift-click), not from PLAYER_MONEY, which also
--- ticks for loot/vendoring while the mailbox happens to be open.
function OtherUI:AddRake(copper)
    if (copper or 0) > 0 then
        rakeCopper = rakeCopper + copper
        self:Refresh()
    end
end

function OtherUI:ResetRake()
    rakeCopper = 0
    self:Refresh()
end

function OtherUI:Initialize()
    if self._wired then
        return
    end
    self._wired = true
    local f = CreateFrame("Frame")
    f:RegisterEvent("MAIL_SHOW")
    f:SetScript("OnEvent", function()
        OtherUI:ResetRake()
    end)
end
