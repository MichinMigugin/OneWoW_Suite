local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

local format = string.format

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local function getErrorDB()
    return ns.db.global.errorDB
end

local function soundChoiceLabel(value)
    if value == "devtools_error" then
        return L["ERR_SOUND_DEVTOOL"]
    end
    if value == "raid_warning" then
        return L["ERR_SOUND_RAID_WARNING"]
    end
    if value == "tell_message" then
        return L["ERR_SOUND_TELL"]
    end
    if value == "map_ping" then
        return L["ERR_SOUND_MAP_PING"]
    end
    return OFF
end

local function copyFormatLabel(value)
    if value == "curseforge" then
        return L["ERR_COPY_FMT_CURSEFORGE"]
    end
    if value == "discord" then
        return L["DISCORD"]
    end
    return L["ERR_COPY_FMT_PLAIN"]
end

local function normalizeKeepSessions(n)
    n = tonumber(n) or 10
    if n < 1 then
        return 1
    end
    if n > 20 then
        return 20
    end
    return n
end

local function keepSessionsDropdownText(n)
    n = normalizeKeepSessions(n)
    local fmt = L["ERR_KEEP_SESSIONS_VALUE"]
    return format(fmt, n)
end

local function refreshDropdownLabels(tab)
    local db = getErrorDB()
    if not db then
        return
    end
    if tab.soundDropdown and tab.soundDropdown._text then
        tab.soundDropdown._text:SetText(soundChoiceLabel(db.soundChoice or "off"))
        tab.soundDropdown._activeValue = db.soundChoice
    end
    if tab.copyFormatDropdown and tab.copyFormatDropdown._text then
        tab.copyFormatDropdown._text:SetText(copyFormatLabel(db.copyFormat or "plain"))
        tab.copyFormatDropdown._activeValue = db.copyFormat
    end
    if tab.keepSessionsDropdown and tab.keepSessionsDropdown._text then
        tab.keepSessionsDropdown._text:SetText(keepSessionsDropdownText(db.keepLastSessions))
        tab.keepSessionsDropdown._activeValue = normalizeKeepSessions(db.keepLastSessions)
    end
end

function ns.UI:CreateErrorsTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()


    local bugGrabberNotice = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bugGrabberNotice:SetWordWrap(true)
    bugGrabberNotice:SetJustifyH("LEFT")
    bugGrabberNotice:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    bugGrabberNotice:Hide()

    tab.bugGrabberNotice = bugGrabberNotice

    local clearBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["BTN_CLEAR"],
        height = 22,
        minWidth = 72,
    })
    clearBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
    tab.luaClearBtn = clearBtn
    clearBtn:SetScript("OnClick", function()
        if ns.ErrorLogger then
            ns.ErrorLogger:ClearErrors()
        end
    end)

    local countLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    countLabel:SetPoint("LEFT", clearBtn, "RIGHT", 12, 0)
    countLabel:SetText((L["LABEL_ERRORS"]) .. " 0")
    countLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    -- Checkbox hit box is only CHECKBOX_SIZE wide; label is cb.label — do not anchor siblings to cb:RIGHT or they overlap the label text.
    local clearReloadCheck = OneWoW_GUI:CreateCheckbox(tab, {
        label = L["ERR_CLEAR_ON_RELOAD"],
    })
    clearReloadCheck:SetChecked(getErrorDB() and getErrorDB().clearOnReload or false)
    clearReloadCheck:SetScript("OnClick", function(myself)
        local db = getErrorDB()
        if db then
            db.clearOnReload = myself:GetChecked() and true or false
        end
    end)

    local soundDrop = OneWoW_GUI:CreateDropdown(tab, { width = 160, height = 24, text = "" })
    soundDrop:SetPoint("TOPLEFT", clearBtn, "BOTTOMLEFT", 0, -8)

    local copyDrop = OneWoW_GUI:CreateDropdown(tab, { width = 160, height = 24, text = "" })

    OneWoW_GUI:AttachFilterMenu(soundDrop, {
        searchable = false,
        menuHeight = 200,
        getActiveValue = function()
            return getErrorDB() and getErrorDB().soundChoice or "off"
        end,
        buildItems = function()
            return {
                { value = "off", text = OFF },
                { value = "devtools_error", text = L["ERR_SOUND_DEVTOOL"] },
                { value = "raid_warning", text = L["ERR_SOUND_RAID_WARNING"] },
                { value = "tell_message", text = L["ERR_SOUND_TELL"] },
                { value = "map_ping", text = L["ERR_SOUND_MAP_PING"] },
            }
        end,
        onSelect = function(value)
            local db = getErrorDB()
            if db then
                db.soundChoice = value
            end
            refreshDropdownLabels(tab)
            if ns.ErrorLogger and ns.ErrorLogger.PreviewSoundChoice then
                ns.ErrorLogger:PreviewSoundChoice(value)
            end
        end,
    })

    OneWoW_GUI:AttachFilterMenu(copyDrop, {
        searchable = false,
        menuHeight = 140,
        getActiveValue = function()
            return getErrorDB() and getErrorDB().copyFormat or "plain"
        end,
        buildItems = function()
            return {
                { value = "plain", text = L["ERR_COPY_FMT_PLAIN"] },
                { value = "curseforge", text = L["ERR_COPY_FMT_CURSEFORGE"] },
                { value = "discord", text = L["DISCORD"] },
            }
        end,
        onSelect = function(value)
            local db = getErrorDB()
            if db then
                db.copyFormat = value
            end
            refreshDropdownLabels(tab)
        end,
    })

    tab.soundDropdown = soundDrop
    tab.copyFormatDropdown = copyDrop

    local keepLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    keepLabel:SetText(L["ERR_KEEP_SESSIONS_LABEL"])
    keepLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local keepSessionsDrop = OneWoW_GUI:CreateDropdown(tab, { width = 56, height = 24, text = "" })

    OneWoW_GUI:AttachFilterMenu(keepSessionsDrop, {
        searchable = false,
        menuHeight = 320,
        getActiveValue = function()
            return normalizeKeepSessions(getErrorDB() and getErrorDB().keepLastSessions)
        end,
        buildItems = function()
            local fmt = L["ERR_KEEP_SESSIONS_VALUE"]
            local items = {}
            for i = 1, 20 do
                tinsert(items, { value = i, text = format(fmt, i) })
            end
            return items
        end,
        onSelect = function(value)
            local db = getErrorDB()
            if db then
                db.keepLastSessions = normalizeKeepSessions(value)
            end
            refreshDropdownLabels(tab)
        end,
    })

    tab.keepSessionsDropdown = keepSessionsDrop

    keepLabel:SetPoint("LEFT", soundDrop, "RIGHT", 16, 3)
    keepSessionsDrop:SetPoint("LEFT", keepLabel, "RIGHT", 10, 0)
    keepSessionsDrop:SetPoint("TOP", soundDrop, "TOP", 0, 0)

    local function setDevModeFlashEnabled(on)
        local flash = tab.devModeFlashCheck
        if on then
            flash:Enable()
            flash.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            flash:Disable()
            flash.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end
    tab.SetDevModeFlashEnabled = setDevModeFlashEnabled

    local devModeCheck = OneWoW_GUI:CreateCheckbox(tab, {
        label = L["ERR_DEVMODE"],
    })
    devModeCheck:SetPoint("TOPLEFT", soundDrop, "BOTTOMLEFT", 0, -8)
    devModeCheck:SetChecked(getErrorDB().devMode)
    tab.devModeCheck = devModeCheck

    local flashCheck = OneWoW_GUI:CreateCheckbox(tab, {
        label = L["ERR_DEVMODE_FLASH"],
    })
    flashCheck:SetPoint("LEFT", devModeCheck.label, "RIGHT", 16, 0)
    flashCheck:SetChecked(getErrorDB().devModeFlash)
    tab.devModeFlashCheck = flashCheck
    setDevModeFlashEnabled(getErrorDB().devMode)

    devModeCheck:SetScript("OnClick", function(myself)
        local db = getErrorDB()
        db.devMode = myself:GetChecked() and true or false
        setDevModeFlashEnabled(db.devMode)
        if db.devMode then
            ns.ErrorFloat:ShowNow()
        else
            ns.ErrorFloat:Hide()
        end
    end)
    flashCheck:SetScript("OnClick", function(myself)
        local db = getErrorDB()
        db.devModeFlash = myself:GetChecked() and true or false
    end)

    local function layoutLuaErrorRowAnchors()
        local cb = clearReloadCheck
        local cl = countLabel
        local btn = clearBtn
        if not cb or not cl or not btn then
            return
        end
        local offsetX = (cl:GetRight() + 16 + cb:GetWidth() / 2) - (btn:GetLeft() + btn:GetWidth() / 2)
        cb:ClearAllPoints()
        cb:SetPoint("CENTER", btn, "CENTER", offsetX, 0)
    end

    tab.LayoutErrorRowAnchors = layoutLuaErrorRowAnchors

    -- Full-width invisible line under the DEVMODE row so list top (TOPLEFT + TOPRIGHT) shares one Y (avoids shearing vs tab TOP).
    local belowRetention = CreateFrame("Frame", nil, tab)
    belowRetention:SetPoint("LEFT", tab, "LEFT", 5, 0)
    belowRetention:SetPoint("RIGHT", tab, "RIGHT", -5, 0)
    belowRetention:SetPoint("TOP", devModeCheck, "BOTTOM", 0, 0)
    belowRetention:SetHeight(1)

    local listPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 150 })
    listPanel:ClearAllPoints()
    listPanel:SetPoint("TOPLEFT", belowRetention, "BOTTOMLEFT", 0, -12)
    listPanel:SetPoint("TOPRIGHT", belowRetention, "BOTTOMRIGHT", 0, -12)
    listPanel:SetHeight(130)
    self:StyleContentPanel(listPanel)

    local listScroll, listContent = OneWoW_GUI:CreateScrollFrame(listPanel, {})
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -14, 4)

    listScroll:HookScript("OnSizeChanged", function(_, w)
        listContent:SetWidth(w)
    end)

    tab.errorButtons = {}
    for i = 1, 100 do
        local btn = OneWoW_GUI:CreateListRowBasic(listContent, {
            height = 20,
            label = "",
            onClick = function(myself)
                if ns.ErrorLogger and myself.errorData then
                    ns.ErrorLogger:ShowErrorDetails(myself.errorData)
                end
            end,
        })
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", listContent, "TOPLEFT", 2, -(i - 1) * 20 - 2)
        btn:SetPoint("RIGHT", listContent, "RIGHT", 0, 0)
        btn.label:SetFontObject(GameFontNormalSmall)

        tab.errorButtons[i] = btn
    end

    local analysisPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 150 })
    analysisPanel:ClearAllPoints()
    analysisPanel:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 5, 35)
    analysisPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 35)
    analysisPanel:SetHeight(150)
    self:StyleContentPanel(analysisPanel)

    local analysisScroll, analysisContent = OneWoW_GUI:CreateScrollFrame(analysisPanel, {})
    analysisScroll:ClearAllPoints()
    analysisScroll:SetPoint("TOPLEFT", analysisPanel, "TOPLEFT", 4, -4)
    analysisScroll:SetPoint("BOTTOMRIGHT", analysisPanel, "BOTTOMRIGHT", -14, 4)

    analysisScroll:HookScript("OnSizeChanged", function(_, w)
        analysisContent:SetWidth(w)
    end)

    tab.analysisText = analysisContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.analysisText:SetPoint("TOPLEFT", 2, -2)
    tab.analysisText:SetPoint("RIGHT", analysisContent, "RIGHT", -2, 0)
    tab.analysisText:SetJustifyH("LEFT")
    tab.analysisText:SetWordWrap(true)
    tab.analysisText:SetText(L["ERR_ANALYSIS_NONE"])
    tab.analysisText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    tab.analysisPanel = analysisPanel
    tab.analysisScroll = analysisScroll

    local detailsPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    detailsPanel:ClearAllPoints()
    detailsPanel:SetPoint("TOPLEFT", listPanel, "BOTTOMLEFT", 0, -5)
    detailsPanel:SetPoint("TOPRIGHT", listPanel, "BOTTOMRIGHT", 0, -5)
    detailsPanel:SetPoint("BOTTOMLEFT", analysisPanel, "TOPLEFT", 0, -5)
    detailsPanel:SetPoint("BOTTOMRIGHT", analysisPanel, "TOPRIGHT", 0, -5)
    self:StyleContentPanel(detailsPanel)

    local detailsScroll = CreateFrame("ScrollFrame", nil, detailsPanel, "UIPanelScrollFrameTemplate")
    detailsScroll:ClearAllPoints()
    detailsScroll:SetPoint("TOPLEFT", detailsPanel, "TOPLEFT", 4, -4)
    detailsScroll:SetPoint("BOTTOMRIGHT", detailsPanel, "BOTTOMRIGHT", -14, 4)
    detailsScroll:EnableMouse(true)
    detailsScroll:EnableMouseWheel(true)
    OneWoW_GUI:ApplyScrollBarStyle(detailsScroll.ScrollBar, detailsPanel, -2)

    local detailsEditBox = CreateFrame("EditBox", nil, detailsScroll)
    detailsEditBox:SetMultiLine(true)
    detailsEditBox:SetAutoFocus(false)
    detailsEditBox:SetFontObject(GameFontNormalSmall)
    detailsEditBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    detailsEditBox:SetHeight(1)
    detailsEditBox:SetTextInsets(2, 2, 2, 2)
    detailsEditBox:SetText(L["LABEL_NO_ERROR"])
    detailsScroll:SetScrollChild(detailsEditBox)

    detailsScroll:HookScript("OnSizeChanged", function(_, w)
        detailsEditBox:SetWidth(math.max(1, w))
    end)
    detailsScroll:HookScript("OnMouseDown", function()
        detailsEditBox:SetFocus()
    end)

    detailsEditBox:SetScript("OnEscapePressed", function(myself) myself:ClearFocus() end)
    detailsEditBox:SetScript("OnTextChanged", function(myself, userInput)
        if userInput and not myself._swappingForCopy then
            myself:SetText(myself._lastSetText or "")
        end
    end)
    detailsEditBox:SetScript("OnKeyDown", function(myself, key)
        if IsControlKeyDown() and key == "C" then
            local err = ns.ErrorLogger and ns.ErrorLogger.currentError
            if err then
                local plainText = ns.ErrorExport.BuildPlainText(err, L, false)
                local colorized = myself._lastSetText
                myself._swappingForCopy = true
                myself:SetText(plainText)
                myself:HighlightText()
                myself:SetPropagateKeyboardInput(false)
                C_Timer.After(0, function()
                    myself._swappingForCopy = nil
                    if colorized then
                        myself:SetText(colorized)
                    end
                end)
            else
                myself:SetPropagateKeyboardInput(true)
            end
            return
        end
        if IsControlKeyDown() and key == "A" then
            myself:SetPropagateKeyboardInput(false)
            myself:HighlightText()
            return
        end
        myself:SetPropagateKeyboardInput(true)
    end)

    detailsEditBox._lastSetText = L["LABEL_NO_ERROR"]
    tab.detailsText = detailsEditBox

    tab.detailsPanel = detailsPanel

    local function setAnalysisVisible(visible)
        if visible then
            analysisPanel:Show()
            detailsPanel:ClearAllPoints()
            detailsPanel:SetPoint("TOPLEFT", listPanel, "BOTTOMLEFT", 0, -5)
            detailsPanel:SetPoint("TOPRIGHT", listPanel, "BOTTOMRIGHT", 0, -5)
            detailsPanel:SetPoint("BOTTOMLEFT", analysisPanel, "TOPLEFT", 0, -5)
            detailsPanel:SetPoint("BOTTOMRIGHT", analysisPanel, "TOPRIGHT", 0, -5)
        else
            analysisPanel:Hide()
            detailsPanel:ClearAllPoints()
            detailsPanel:SetPoint("TOPLEFT", listPanel, "BOTTOMLEFT", 0, -5)
            detailsPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 35)
        end
    end

    local copyBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["BTN_COPY_ERROR"],
        height = 25,
        minWidth = 96,
    })
    copyBtn:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 5, 5)
    copyBtn:SetScript("OnClick", function()
        if ns.ErrorLogger then
            ns.ErrorLogger:CopyCurrentError()
        end
    end)

    local copyAllBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["BTN_COPY_DETAILS"],
        height = 25,
        minWidth = 80,
    })
    copyAllBtn:SetPoint("BOTTOMLEFT", copyBtn, "BOTTOMRIGHT", 8, 0)
    copyAllBtn:SetScript("OnClick", function()
        if ns.ErrorLogger then
            ns.ErrorLogger:CopyAllErrors()
        end
    end)
    tab.copyAllBtn = copyAllBtn

    copyDrop:SetPoint("BOTTOMLEFT", copyAllBtn, "BOTTOMRIGHT", 10, 0)

    local analysisToggleBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = L["BTN_TOGGLE_ANALYSIS"],
        height = 25,
        minWidth = 80,
    })
    analysisToggleBtn:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)
    analysisToggleBtn:SetScript("OnClick", function()
        local db = getErrorDB()
        local newState = not analysisPanel:IsShown()
        if db then
            db.showAnalysis = newState
        end
        setAnalysisVisible(newState)
    end)

    tab.analysisToggleBtn = analysisToggleBtn

    local db = getErrorDB()
    local showAnalysis = (db and db.showAnalysis ~= false) and true or false
    setAnalysisVisible(showAnalysis)

    tab.listScroll = listScroll
    tab.detailsScroll = detailsScroll
    tab.countLabel = countLabel
    tab.clearReloadCheck = clearReloadCheck

    tab:SetScript("OnShow", function()
        local showDB = getErrorDB()
        if tab.clearReloadCheck and showDB then
            tab.clearReloadCheck:SetChecked(showDB.clearOnReload and true or false)
        end
        refreshDropdownLabels(tab)
        if tab.devModeCheck and showDB then
            tab.devModeCheck:SetChecked(showDB.devMode)
        end
        if tab.devModeFlashCheck and showDB then
            tab.devModeFlashCheck:SetChecked(showDB.devModeFlash)
        end
        if tab.SetDevModeFlashEnabled and showDB then
            tab.SetDevModeFlashEnabled(showDB.devMode)
        end
        local vis = (showDB and showDB.showAnalysis ~= false) and true or false
        setAnalysisVisible(vis)
        if ns.ErrorLogger then
            ns.ErrorLogger:UpdateLuaTabBugGrabberNotice()
            ns.ErrorLogger:UpdateUI()
        elseif tab.LayoutErrorRowAnchors then
            tab.LayoutErrorRowAnchors()
        end
        if showDB and showDB.devMode then
            ns.ErrorFloat:ShowSessionErrors()
        end
    end)

    ns.LuaConsoleTab = tab
    refreshDropdownLabels(tab)
    if ns.ErrorLogger and ns.ErrorLogger.UpdateLuaTabBugGrabberNotice then
        ns.ErrorLogger:UpdateLuaTabBugGrabberNotice()
    end
    C_Timer.After(0, function()
        if tab.LayoutErrorRowAnchors then
            tab.LayoutErrorRowAnchors()
        end
    end)
    return tab
end
