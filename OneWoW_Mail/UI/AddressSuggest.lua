local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

-- ============================================================================
-- AddressSuggest — To-box autocomplete shared by Compose / Shipments.
-- ============================================================================

ns.AddressSuggest = {}
local AddressSuggest = ns.AddressSuggest

local MAX_SUGGESTIONS = 16
local SUGGEST_ROW_H = 22
local CHEVRON_W = 22

local function GetBoxText(box)
    if box.GetSearchText then
        return box:GetSearchText() or ""
    end
    return box:GetText() or ""
end

local function SetBoxText(box, text)
    text = text or ""
    box:SetText(text)
    if text ~= "" then
        box:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    elseif box.RestorePlaceholder then
        box:RestorePlaceholder()
    end
    if box.UpdateClearButton then
        box:UpdateClearButton()
    end
end

local function SetRowHighlight(btn, highlighted)
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

local function CreateRow(parent)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(SUGGEST_ROW_H - 2)
    btn:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    btn:Hide()

    btn.label = OneWoW_GUI:CreateFS(btn, 11)
    btn.label:SetPoint("LEFT", 6, 0)
    btn.label:SetPoint("RIGHT", -6, 0)
    btn.label:SetJustifyH("LEFT")
    btn.label:SetWordWrap(false)
    btn.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    return btn
end

--- Attach autocomplete + arrow/enter selection to a OneWoW CreateEditBox (or EditBox).
--- Browse-on-focus: empty text shows alts-first AddressBook list. Optional chevron opens the same list.
---@param box EditBox
---@param options table|nil { onCommit?: fun(text: string), onAdvance?: fun(), width?: number, showChevron?: boolean }
---@return table handle { SetText, GetText, Hide, Show, box, chevron? }
function AddressSuggest:Attach(box, options)
    options = options or {}
    local parent = box:GetParent()
    local state = {
        acIndex = 0,
        acList = {},
        box = box,
        onCommit = options.onCommit,
        onAdvance = options.onAdvance,
        suppressFocusShow = false,
    }

    local suggestionFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    suggestionFrame:SetSize(options.width or box:GetWidth() or 320, 200)
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
    state.frame = suggestionFrame

    local function Hide()
        suggestionFrame:Hide()
        state.acIndex = 0
        wipe(state.acList)
    end

    local function Highlight(index)
        if index < 1 or index > #state.acList then
            state.acIndex = 0
        else
            state.acIndex = index
        end
        for i, btn in ipairs(suggestionFrame.buttons) do
            if btn:IsShown() then
                SetRowHighlight(btn, i == state.acIndex)
            end
        end
    end

    local function Apply(text)
        state.suppressFocusShow = true
        SetBoxText(box, text)
        box:SetCursorPosition(#text)
        box:SetFocus()
        Hide()
        state.suppressFocusShow = false
        if state.onCommit then
            state.onCommit(ns.AddressBook:NormalizeRecipient(text))
        end
    end

    local function Show(prefix)
        prefix = strtrim(prefix or "")
        local matches = ns.AddressBook:Autocomplete(prefix)
        wipe(state.acList)
        for i = 1, math.min(#matches, MAX_SUGGESTIONS) do
            state.acList[i] = matches[i]
        end
        if #state.acList == 0 then
            Hide()
            return
        end

        local anchorRight = state.chevron or box
        suggestionFrame:ClearAllPoints()
        suggestionFrame:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
        suggestionFrame:SetPoint("TOPRIGHT", anchorRight, "BOTTOMRIGHT", 0, -2)
        suggestionFrame:SetHeight(6 + #state.acList * SUGGEST_ROW_H)
        suggestionFrame:Show()

        for _, btn in ipairs(suggestionFrame.buttons) do
            btn:Hide()
        end

        local frameW = math.max(120, suggestionFrame:GetWidth() or box:GetWidth() or 320)
        for i, entry in ipairs(state.acList) do
            local btn = suggestionFrame.buttons[i]
            if not btn then
                btn = CreateRow(suggestionFrame)
                suggestionFrame.buttons[i] = btn
                btn:SetScript("OnEnter", function(myself)
                    Highlight(myself.suggestIndex or 0)
                end)
                btn:SetScript("OnLeave", function(myself)
                    if state.acIndex ~= (myself.suggestIndex or 0) then
                        SetRowHighlight(myself, false)
                    end
                end)
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
                Apply(text)
            end)
            btn:Show()
        end
        Highlight(0)
    end

    local chevron
    if options.showChevron ~= false then
        chevron = CreateFrame("Button", nil, parent, "BackdropTemplate")
        chevron:SetSize(CHEVRON_W, box:GetHeight() or 24)
        chevron:SetPoint("LEFT", box, "RIGHT", 2, 0)
        chevron:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
        chevron:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        chevron:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local arrow = chevron:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(12, 12)
        arrow:SetPoint("CENTER")
        arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

        chevron:SetScript("OnEnter", function(myself)
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["TT_ADDRESS_BROWSE"], 1, 1, 1)
            GameTooltip:Show()
        end)
        chevron:SetScript("OnLeave", function(myself)
            myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            GameTooltip:Hide()
        end)
        chevron:SetScript("OnClick", function()
            if suggestionFrame:IsShown() then
                Hide()
                return
            end
            state.suppressFocusShow = true
            box:SetFocus()
            -- Chevron always browses the full alts-first list (ignore typed filter).
            Show("")
            state.suppressFocusShow = false
        end)
        state.chevron = chevron
    end

    box:HookScript("OnTextChanged", function(myself, userInput)
        if not userInput then
            return
        end
        Show(GetBoxText(myself))
    end)
    box:HookScript("OnEditFocusGained", function()
        if state.suppressFocusShow then
            return
        end
        -- User focus opens browse list; programmatic autofill must not call SetFocus.
        Show(GetBoxText(box))
    end)
    box:HookScript("OnArrowPressed", function(_, key)
        if not suggestionFrame:IsShown() or #state.acList == 0 then
            return
        end
        if key == "DOWN" then
            local next = state.acIndex + 1
            if next > #state.acList then
                next = 1
            end
            Highlight(next)
        elseif key == "UP" then
            if state.acIndex <= 1 then
                Highlight(0)
            else
                Highlight(state.acIndex - 1)
            end
        end
    end)
    local function CommitAndAdvance()
        local text = ns.AddressBook:NormalizeRecipient(GetBoxText(box))
        SetBoxText(box, text)
        Hide()
        if state.onCommit then
            state.onCommit(text)
        end
        if state.onAdvance then
            state.onAdvance()
        else
            box:ClearFocus()
        end
    end

    box:HookScript("OnEnterPressed", function()
        if suggestionFrame:IsShown() and state.acIndex >= 1 and state.acList[state.acIndex] then
            Apply(state.acList[state.acIndex].text)
            return
        end
        CommitAndAdvance()
    end)
    box:HookScript("OnTabPressed", function()
        if suggestionFrame:IsShown() and state.acIndex >= 1 and state.acList[state.acIndex] then
            Apply(state.acList[state.acIndex].text)
            return
        end
        CommitAndAdvance()
    end)
    box:HookScript("OnEscapePressed", function()
        Hide()
    end)
    box:HookScript("OnEditFocusLost", function()
        C_Timer.After(0.15, function()
            Hide()
            local text = ns.AddressBook:NormalizeRecipient(GetBoxText(box))
            SetBoxText(box, text)
            if state.onCommit then
                state.onCommit(text)
            end
        end)
    end)

    if box.clearButton then
        box.clearButton:HookScript("OnClick", function()
            Hide()
            if state.onCommit then
                state.onCommit("")
            end
        end)
    end

    return {
        SetText = function(_, text)
            SetBoxText(box, text)
        end,
        GetText = function()
            return ns.AddressBook:NormalizeRecipient(GetBoxText(box))
        end,
        Hide = Hide,
        Show = function(_, prefix)
            Show(prefix or GetBoxText(box))
        end,
        box = box,
        chevron = chevron,
    }
end
