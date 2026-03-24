local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local L = Addon.L or {}

function Addon.UI:CreateEventMonitorTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local startStopBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["BTN_START"] or "Start", height = 22, minWidth = 60 })
    startStopBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)
    startStopBtn:SetScript("OnClick", function()
        if Addon.EventMonitor then
            if Addon.EventMonitor.monitoring then
                Addon.EventMonitor:Stop()
            else
                Addon.EventMonitor:Start()
            end
        end
    end)

    local pauseBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["BTN_PAUSE"] or "Pause", height = 22, minWidth = 70 })
    pauseBtn:SetPoint("LEFT", startStopBtn, "RIGHT", 5, 0)
    pauseBtn:SetScript("OnClick", function()
        if Addon.EventMonitor then
            Addon.EventMonitor:TogglePause()
        end
    end)

    local clearBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["BTN_CLEAR"] or "Clear", height = 22, minWidth = 50 })
    clearBtn:SetPoint("LEFT", pauseBtn, "RIGHT", 5, 0)
    clearBtn:SetScript("OnClick", function()
        if Addon.EventMonitor then
            Addon.EventMonitor:Clear()
        end
    end)

    local configBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["BTN_SELECT_EVENTS"] or "Select Events", height = 22, minWidth = 80 })
    configBtn:SetPoint("LEFT", clearBtn, "RIGHT", 5, 0)
    configBtn:SetScript("OnClick", function()
        Addon.UI:ShowEventSelector()
    end)

    local importBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["BTN_IMPORT_EVENTS"] or "Import Events", height = 22, minWidth = 80 })
    importBtn:SetPoint("LEFT", configBtn, "RIGHT", 5, 0)
    importBtn:SetScript("OnClick", function()
        Addon.UI:ShowEventImportDialog()
    end)

    local firehoseBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["BTN_FIREHOSE"] or "Firehose", height = 22, minWidth = 60 })
    firehoseBtn:SetPoint("LEFT", importBtn, "RIGHT", 5, 0)
    firehoseBtn:SetScript("OnClick", function()
        if Addon.EventMonitor then
            Addon.EventMonitor:FirehoseToggle()
        end
    end)

    local filterLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("TOPLEFT", startStopBtn, "BOTTOMLEFT", 0, -8)
    filterLabel:SetText(Addon.L and Addon.L["LABEL_FILTER"] or "Filter:")
    filterLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local filterBox = OneWoW_GUI:CreateEditBox(tab, {
        width = 150,
        height = 22,
        placeholderText = Addon.L and Addon.L["LABEL_FILTER"] or "Filter...",
        onTextChanged = function()
            if Addon.EventMonitor then
                Addon.EventMonitor:UpdateUI()
            end
        end,
    })
    filterBox:SetPoint("LEFT", filterLabel, "RIGHT", 5, 0)

    local panel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", startStopBtn, "BOTTOMLEFT", 0, -35)
    panel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)
    self:StyleContentPanel(panel)

    local scroll, content = OneWoW_GUI:CreateScrollFrame(panel, {})
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 4)

    tab.maxRowWidth = 0
    scroll:HookScript("OnSizeChanged", function(self, w)
        content:SetWidth(math.max(w, tab.maxRowWidth or 0))
    end)

    local ROW_HEIGHT = Addon.Constants and Addon.Constants.EVENT_VIEWER_ROW_HEIGHT or 14
    local COL_EVENT = Addon.Constants and Addon.Constants.EVENT_VIEWER_COL_EVENT or 280
    local COL_ARGS = Addon.Constants and Addon.Constants.EVENT_VIEWER_COL_ARGS or 260
    local MAX_EVENT_ROWS = (Addon.Constants and Addon.Constants.DEVTOOL_UI and Addon.Constants.DEVTOOL_UI.EVENT_MONITOR_MAX_ROWS) or 201

    tab.emptyStateText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.emptyStateText:SetPoint("CENTER", content, "CENTER", 0, 0)
    tab.emptyStateText:SetJustifyH("CENTER")
    tab.emptyStateText:SetText(L["MSG_CLICK_START"] or "Click 'Start' to begin monitoring (auto-selects common events)\nOr click 'Select Events' to customize")
    tab.emptyStateText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    tab.rowPool = {}
    for i = 1, MAX_EVENT_ROWS do
        local row = CreateFrame("Frame", nil, content)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", content, "RIGHT", -2, 0)

        row.eventCol = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.eventCol:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.eventCol:SetJustifyH("LEFT")
        row.eventCol:SetWordWrap(false)

        row.argsCol = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.argsCol:SetPoint("LEFT", row, "LEFT", COL_EVENT, 0)
        row.argsCol:SetJustifyH("LEFT")
        row.argsCol:SetWordWrap(false)

        row.countCol = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.countCol:SetPoint("LEFT", row, "LEFT", COL_EVENT + COL_ARGS, 0)
        row.countCol:SetJustifyH("LEFT")
        row.countCol:SetWordWrap(false)

        row:Hide()
        tab.rowPool[i] = row
    end

    tab.content = content
    tab.ROW_HEIGHT = ROW_HEIGHT
    tab.COL_EVENT = COL_EVENT
    tab.COL_ARGS = COL_ARGS

    -- CreateScrollFrame sets content height to 1; set minimum so empty state is visible
    content:SetHeight(math.max(100, panel:GetHeight() or 100))

    tab.startStopBtn = startStopBtn
    tab.pauseBtn = pauseBtn
    tab.firehoseBtn = firehoseBtn
    tab.filterBox = filterBox
    tab.scroll = scroll

    pauseBtn:Disable()

    -- Hook OnLeave so correct styling persists: CreateButton's OnLeave always sets BTN_NORMAL,
    -- which overwrites our active state. Re-apply state-based styling.
    startStopBtn:HookScript("OnLeave", function(self)
        if Addon.EventMonitor and Addon.EventMonitor.monitoring then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end)
    pauseBtn:HookScript("OnLeave", function(self)
        if Addon.EventMonitor and Addon.EventMonitor.monitoring then
            if Addon.EventMonitor.paused then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            else
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end
    end)

    function tab:Teardown()
        if Addon.EventMonitor and Addon.EventMonitor.monitoring then
            Addon.EventMonitor:Stop()
        end
        if Addon.EventMonitorTab == self then
            Addon.EventMonitorTab = nil
        end
    end

    Addon.EventMonitorTab = tab
    return tab
end

function Addon.UI:ShowEventSelector()
    if not self.eventSelector then
        local frame = OneWoW_GUI:CreateFrame(UIParent, {
            width = (Addon.Constants and Addon.Constants.DEVTOOL_UI and Addon.Constants.DEVTOOL_UI.EVENT_SELECTOR_WIDTH) or 600,
            height = (Addon.Constants and Addon.Constants.DEVTOOL_UI and Addon.Constants.DEVTOOL_UI.EVENT_SELECTOR_HEIGHT) or 500,
            backdrop = BACKDROP_INNER_NO_INSETS,
        })
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.title:SetPoint("TOP", 0, -5)
        frame.title:SetText(Addon.L and Addon.L["DIALOG_TITLE_SELECT_EVENTS"] or "Event Monitor - Select Events")
        frame.title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local commonBtn = OneWoW_GUI:CreateButton(frame, { text = Addon.L and Addon.L["BTN_COMMON_EVENTS"] or "Common Events", width = 110, height = 25 })
        commonBtn:SetPoint("TOPLEFT", 10, -30)
        commonBtn:SetScript("OnClick", function()
            Addon.EventMonitor:RegisterCommonEvents()
            Addon.UI:UpdateEventSelector()
            Addon:Print((Addon.L and Addon.L["MSG_ADDED_COMMON_EVENTS"] or "Added common events ({count} total)"):gsub("{count}", Addon.EventMonitor:GetEventCount()))
        end)

        local selectAllBtn = OneWoW_GUI:CreateButton(frame, { text = Addon.L and Addon.L["BTN_SELECT_ALL"] or "Select All", width = 80, height = 25 })
        selectAllBtn:SetPoint("LEFT", commonBtn, "RIGHT", 5, 0)
        selectAllBtn:SetScript("OnClick", function()
            Addon.UI:SelectAllEvents()
            Addon:Print((Addon.L and Addon.L["MSG_SELECTED_ALL_EVENTS"] or "Selected all events ({count} total)"):gsub("{count}", Addon.EventMonitor:GetEventCount()))
        end)

        local clearAllBtn = OneWoW_GUI:CreateButton(frame, { text = Addon.L and Addon.L["BTN_CLEAR_ALL"] or "Clear All", width = 80, height = 25 })
        clearAllBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 5, 0)
        clearAllBtn:SetScript("OnClick", function()
            Addon.EventMonitor.selectedEvents = {}
            Addon.UI:UpdateEventSelector()
            Addon:Print(Addon.L and Addon.L["MSG_CLEARED_ALL_EVENTS"] or "Cleared all events")
        end)

        local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        searchLabel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -215, -37)
        searchLabel:SetText((Addon.L and Addon.L["LABEL_FILTER"] or "Search:"))
        searchLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local searchBox = OneWoW_GUI:CreateEditBox(frame, {
            width = 180,
            height = 25,
            placeholderText = Addon.L and Addon.L["LABEL_FILTER"] or "Filter...",
            onTextChanged = function()
                Addon.UI:UpdateEventSelector()
            end,
        })
        searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 5, 0)

        local eventCount = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        eventCount:SetPoint("TOPLEFT", commonBtn, "BOTTOMLEFT", 0, -8)
        eventCount:SetText((Addon.L and Addon.L["LABEL_SELECTED"] or "Selected:") .. " 0")
        eventCount:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local leftPanel = OneWoW_GUI:CreateFrame(frame, { backdrop = BACKDROP_INNER_NO_INSETS, width = 280, height = 100 })
        leftPanel:ClearAllPoints()
        leftPanel:SetPoint("TOPLEFT", eventCount, "BOTTOMLEFT", 0, -8)
        leftPanel:SetPoint("BOTTOM", frame, "BOTTOM", 0, 40)
        leftPanel:SetWidth(280)
        self:StyleContentPanel(leftPanel)

        local leftTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        leftTitle:SetPoint("TOP", 0, -5)
        leftTitle:SetText(Addon.L and Addon.L["LABEL_EVENT_LIST"] or "Event List")
        leftTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local leftScroll, leftContent = OneWoW_GUI:CreateScrollFrame(leftPanel, {})
        leftScroll:ClearAllPoints()
        leftScroll:SetPoint("TOPLEFT", 4, -25)
        leftScroll:SetPoint("BOTTOMRIGHT", -14, 4)

        leftScroll:HookScript("OnSizeChanged", function(self, w)
            leftContent:SetWidth(w)
        end)

        frame.eventButtons = {}
        frame.eventRowHeight = 26
        local commonCount = #Addon.EventMonitor:GetCommonEvents()
        local poolSize = commonCount + (Addon.Constants.EVENT_SELECTOR_CUSTOM_BUFFER or 100)
        for i = 1, poolSize do
            local btn = OneWoW_GUI:CreateCheckbox(leftContent, { label = "" })
            btn:SetPoint("TOPLEFT", 5, -(i-1) * frame.eventRowHeight - 5)

            btn:SetScript("OnClick", function(btnSelf)
                if btnSelf.eventName then
                    Addon.EventMonitor:ToggleEvent(btnSelf.eventName)
                    Addon.UI:UpdateEventSelector()
                end
            end)

            frame.eventButtons[i] = btn
        end

        local rightPanel = OneWoW_GUI:CreateFrame(frame, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
        rightPanel:ClearAllPoints()
        rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 5, 0)
        rightPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 40)
        self:StyleContentPanel(rightPanel)

        local rightTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rightTitle:SetPoint("TOP", 0, -5)
        rightTitle:SetText(Addon.L and Addon.L["LABEL_CUSTOM_ATLAS"] or "Custom Event")
        rightTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local customLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        customLabel:SetPoint("TOPLEFT", 10, -30)
        customLabel:SetText(Addon.L and Addon.L["LABEL_ENTER_EVENT"] or "Enter event name:")
        customLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local customBox = OneWoW_GUI:CreateEditBox(rightPanel, {
            width = 180,
            height = 25,
            placeholderText = Addon.L and Addon.L["LABEL_ENTER_EVENT"] or "Event name...",
        })
        customBox:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 0, -5)

        local addBtn = OneWoW_GUI:CreateFitTextButton(rightPanel, { text = Addon.L and Addon.L["BTN_ADD_EVENT"] or "Add", height = 25 })
        addBtn:SetPoint("LEFT", customBox, "RIGHT", 5, 0)
        addBtn:SetScript("OnClick", function()
            local eventName = customBox:GetSearchText()
            if eventName and eventName ~= "" then
                Addon.EventMonitor:ToggleEvent(eventName:upper())
                customBox:SetText(customBox.placeholderText or "")
                customBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                Addon.UI:UpdateEventSelector()
                Addon:Print((Addon.L and Addon.L["MSG_ADDED_EVENT"] or "Added event: {event}"):gsub("{event}", eventName:upper()))
            end
        end)

        local helpText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        helpText:SetPoint("TOPLEFT", customLabel, "BOTTOMLEFT", 0, -40)
        helpText:SetPoint("RIGHT", rightPanel, "RIGHT", -10, 0)
        helpText:SetJustifyH("LEFT")
        helpText:SetText(Addon.L and Addon.L["HELP_TEXT_EVENTS"] or "Enter any WoW event name to monitor.\n\nCommon events:\nPLAYER_ENTERING_WORLD\nZONE_CHANGED\nPLAYER_REGEN_DISABLED\nPLAYER_REGEN_ENABLED\nBAG_UPDATE\nUNIT_HEALTH\nCHAT_MSG_SAY\nADDON_LOADED\n\nYou can find more events on:\nwarcraft.wiki.gg")
        helpText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local closeBtn = OneWoW_GUI:CreateButton(frame, { text = Addon.L and Addon.L["BTN_CLOSE"] or "Close", width = 80, height = 25 })
        closeBtn:SetPoint("BOTTOM", 0, 10)
        closeBtn:SetScript("OnClick", function()
            frame:Hide()
        end)

        frame.leftScroll = leftScroll
        frame.searchBox = searchBox
        frame.eventCount = eventCount

        self.eventSelector = frame

        Addon.EventMonitor:RegisterCommonEvents()
    end

    self:UpdateEventSelector()
    self.eventSelector:Show()
end

function Addon.UI:SelectAllEvents()
    for _, event in ipairs(Addon.EventMonitor:GetCommonEvents()) do
        Addon.EventMonitor.selectedEvents[event] = true
    end

    self:UpdateEventSelector()
end

function Addon.UI:UpdateEventSelector()
    if not self.eventSelector then return end

    local frame = self.eventSelector
    local searchText = (frame.searchBox:GetSearchText() or ""):upper()

    local allEvents = {}
    for _, event in ipairs(Addon.EventMonitor:GetCommonEvents()) do
        tinsert(allEvents, event)
    end

    for event in pairs(Addon.EventMonitor.selectedEvents) do
        local exists = false
        for _, e in ipairs(allEvents) do
            if e == event then
                exists = true
                break
            end
        end
        if not exists then
            tinsert(allEvents, event)
        end
    end

    sort(allEvents)

    local filteredEvents = {}
    for _, event in ipairs(allEvents) do
        if searchText == "" or string.find(event, searchText, 1, true) then
            tinsert(filteredEvents, event)
        end
    end

    local rowHeight = frame.eventRowHeight or 26
    for i, btn in ipairs(frame.eventButtons) do
        local event = filteredEvents[i]
        if event then
            btn.eventName = event
            btn.label:SetText(event)
            btn:SetChecked(Addon.EventMonitor:IsEventRegistered(event))
            btn:Show()
        else
            btn:Hide()
        end
    end

    local height = math.max(#filteredEvents * rowHeight + 10, frame.leftScroll:GetHeight())
    frame.leftScroll:GetScrollChild():SetHeight(height)

    frame.eventCount:SetText((Addon.L and Addon.L["LABEL_SELECTED"] or "Selected:") .. " " .. Addon.EventMonitor:GetEventCount())
end

function Addon.UI:ShowEventImportDialog()
    if not self.importDialog then
        local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        local _DU = Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
        frame:SetSize(_DU.EVENT_IMPORT_WIDTH or 650, _DU.EVENT_IMPORT_HEIGHT or 480)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -8)
        title:SetText(L["EVENT_IMPORT_TITLE"] or "Import Events to Monitor")
        title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local instrLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        instrLabel:SetPoint("TOPLEFT", 10, -28)
        instrLabel:SetText(L["EVENT_IMPORT_INSTRUCTIONS"] or "Paste event search output below, then click Import:")
        instrLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local panel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        panel:SetPoint("TOPLEFT", 10, -48)
        panel:SetPoint("BOTTOMRIGHT", -10, 58)
        self:StyleContentPanel(panel)

        local editScroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
        editScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
        editScroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 4)
        OneWoW_GUI:StyleScrollBar(editScroll, { container = panel })

        local editBox = CreateFrame("EditBox", nil, editScroll)
        editBox:SetMultiLine(true)
        editBox:SetAutoFocus(false)
        editBox:SetFontObject(GameFontNormalSmall)
        editBox:SetHeight(400)
        editBox:SetMaxLetters(0)
        editBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        editScroll:SetScrollChild(editBox)

        editScroll:HookScript("OnSizeChanged", function(self, w)
            editBox:SetWidth(w)
        end)

        local statusLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        statusLabel:SetPoint("BOTTOMLEFT", 10, 33)
        statusLabel:SetText("")
        statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

        local importBtn = OneWoW_GUI:CreateButton(frame, { text = L["EVENT_IMPORT_BTN_IMPORT"] or "Import Events", width = 120, height = 26 })
        importBtn:SetPoint("BOTTOMRIGHT", -100, 8)
        importBtn:SetScript("OnClick", function()
            local text = editBox:GetText()
            if not text or text == "" then
                statusLabel:SetText(L["EVENT_IMPORT_NOTHING"] or "Nothing to import - paste event output first")
                return
            end
            local count = Addon.EventMonitor:ImportEvents(text)
            if count == 0 then
                statusLabel:SetText(L["EVENT_IMPORT_NONE_FOUND"] or "No events found in pasted text")
            else
                statusLabel:SetText((L["EVENT_IMPORT_SUCCESS"] or "Imported {count} event(s) - now monitoring"):gsub("{count}", tostring(count)))
                if not Addon.EventMonitor.monitoring then
                    Addon.EventMonitor:Start()
                end
            end
        end)

        local cancelBtn = OneWoW_GUI:CreateButton(frame, { text = L["BTN_CLOSE"] or "Close", width = 80, height = 26 })
        cancelBtn:SetPoint("BOTTOMRIGHT", -10, 8)
        cancelBtn:SetScript("OnClick", function()
            frame:Hide()
        end)

        frame.editBox = editBox
        frame.statusLabel = statusLabel
        self.importDialog = frame
    end

    self.importDialog.editBox:SetText("")
    self.importDialog.statusLabel:SetText("")
    self.importDialog:Show()
    self.importDialog.editBox:SetFocus()
end
