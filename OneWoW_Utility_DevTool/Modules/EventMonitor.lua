local AddonName, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
local L = Addon.L or {}
if not OneWoW_GUI then return end

local function formatArgForDisplay(arg)
    if OneWoW_GUI:IsSecret(arg) then return "[secret]" end
    local s = tostring(arg)
    if #s > 30 then
        return s:sub(1, 27) .. "..."
    end
    return s
end

local function isUnitToken(s)
    if type(s) ~= "string" then return false end
    return s:match("^nameplate%d+$") or s == "player" or s == "target" or s == "pet" or s == "vehicle"
end

local function WrapEventViewerColor(text, colorKey)
    local val = Addon.Constants.EVENT_VIEWER_COLORS and Addon.Constants.EVENT_VIEWER_COLORS[colorKey]
    if type(val) == "string" then
        return OneWoW_GUI:WrapThemeColor(text, val)
    elseif type(val) == "table" then
        local r, g, b, a = unpack(val)
        return CreateColor(r or 1, g or 1, b or 1, a or 1):WrapTextInColorCode(text)
    end
    return text
end

local EventMonitor = {}
Addon.EventMonitor = EventMonitor

EventMonitor.events = {}
EventMonitor.monitoring = false
EventMonitor.firehose = false
EventMonitor.paused = false
EventMonitor.maxEvents = 500
EventMonitor.selectedEvents = {}
EventMonitor.selectedRegistryEvents = {}
EventMonitor.registryCallbackRegistered = {}
EventMonitor.allEventsRegistered = false

function EventMonitor:Initialize()
    if self.frame then return end

    self.frame = CreateFrame("Frame")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        EventMonitor:OnEvent(event, ...)
    end)

    self:RegisterAllPossibleEvents()
end

function EventMonitor:RegisterAllPossibleEvents()
    if self.allEventsRegistered then return end

    for _, event in ipairs(Addon.Constants.COMMON_EVENTS) do
        pcall(function() self.frame:RegisterEvent(event) end)
    end

    self.allEventsRegistered = true
end

function EventMonitor:Start()
    if self.monitoring then
        Addon:Print(L["MSG_MONITOR_ALREADY_RUNNING"] or "Event monitor already running")
        return
    end

    if self:GetEventCount() == 0 then
        self:RegisterCommonEvents()
        Addon:Print(L["MSG_AUTO_SELECTED_FIRST"] or "Auto-selected common events (first time)")
    end

    self:Initialize()
    self:RegisterAllPossibleEvents()
    for event in pairs(self.selectedEvents) do
        pcall(function() self.frame:RegisterEvent(event) end)
    end
    self.monitoring = true

    local count = self:GetEventCount()
    Addon:Print((L["MSG_MONITOR_STARTED"] or "Event monitoring started (%d events selected)"):format(count))
    self:UpdateUI()
end

function EventMonitor:Stop()
    if not self.monitoring then
        Addon:Print(L["MSG_MONITOR_NOT_RUNNING"] or "Event monitor not running")
        return
    end

    if self.firehose then
        self:FirehoseStop()
    end

    self.monitoring = false
    if self.frame then
        self.frame:UnregisterAllEvents()
        self.allEventsRegistered = false
    end
    Addon:Print(L["MSG_MONITOR_STOPPED"] or "Event monitoring stopped")
    self:UpdateUI()
end

function EventMonitor:Clear()
    self.events = {}
    self:UpdateUI()
    Addon:Print(L["MSG_EVENT_LOG_CLEARED"] or "Event log cleared")
end

function EventMonitor:SetPaused(paused)
    self.paused = paused
    self:UpdateUI()
end

function EventMonitor:IsPaused()
    return self.paused
end

function EventMonitor:TogglePause()
    self.paused = not self.paused
    Addon:Print(self.paused and (L["MSG_EVENT_DISPLAY_PAUSED"] or "Event display paused") or (L["MSG_EVENT_DISPLAY_RESUMED"] or "Event display resumed"))
    self:UpdateUI()
end

local function argsMatchVararg(lastDisplayArgs, nArgs, ...)
    if #lastDisplayArgs ~= nArgs then return false end
    for i = 1, nArgs do
        if lastDisplayArgs[i] ~= formatArgForDisplay((select(i, ...))) then
            return false
        end
    end
    return true
end

local function buildDisplayArgs(args)
    local display = {}
    for i = 1, #args do
        display[i] = formatArgForDisplay(args[i])
    end
    return display
end

function EventMonitor:ScheduleUIUpdate()
    if self.uiUpdatePending then return end
    self.uiUpdatePending = true
    C_Timer.After(0, function()
        self.uiUpdatePending = false
        self:UpdateUI()
    end)
end

function EventMonitor:OnEvent(event, ...)
    if not self.monitoring then return end

    if not self.firehose and not self.selectedEvents[event] and not self.selectedRegistryEvents[event] then return end

    local now = GetTime()
    local collapseWindow = Addon.Constants.EVENT_COLLAPSE_WINDOW or 0.2
    local nArgs = select("#", ...)

    local last = self.events[1]
    if last and last.event == event and (now - last.time) <= collapseWindow and argsMatchVararg(last.displayArgs, nArgs, ...) then
        last.count = (last.count or 1) + 1
        last.time = now
        if not self.paused then
            self:ScheduleUIUpdate()
        end
        return
    end

    local args = {...}
    local eventData = {
        event = event,
        args = args,
        displayArgs = buildDisplayArgs(args),
        timestamp = date("%H:%M:%S"),
        time = now,
        count = 1,
    }

    tinsert(self.events, 1, eventData)

    if #self.events > self.maxEvents then
        tremove(self.events, self.maxEvents + 1)
    end

    if not self.paused then
        self:ScheduleUIUpdate()
    end
end

function EventMonitor:UpdateUI()
    if not Addon.EventMonitorTab then return end

    local tab = Addon.EventMonitorTab

    if tab.startStopBtn then
        if self.monitoring then
            tab.startStopBtn.text:SetText(Addon.L and Addon.L["BTN_STOP"] or "Stop")
            tab.startStopBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            tab.startStopBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            tab.startStopBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            tab.startStopBtn.text:SetText(Addon.L and Addon.L["BTN_START"] or "Start")
            tab.startStopBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            tab.startStopBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            tab.startStopBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end

    if tab.pauseBtn then
        if self.monitoring then
            tab.pauseBtn:Enable()
            if self.paused then
                tab.pauseBtn.text:SetText(Addon.L and Addon.L["BTN_UNPAUSE"] or "Unpause")
                tab.pauseBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                tab.pauseBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                tab.pauseBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            else
                tab.pauseBtn.text:SetText(Addon.L and Addon.L["BTN_PAUSE"] or "Pause")
                tab.pauseBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                tab.pauseBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                tab.pauseBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        else
            tab.pauseBtn.text:SetText(Addon.L and Addon.L["BTN_PAUSE"] or "Pause")
            tab.pauseBtn:Disable()
            tab.pauseBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            tab.pauseBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            tab.pauseBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    if tab.firehoseBtn then
        if self.firehose then
            tab.firehoseBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            tab.firehoseBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            tab.firehoseBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            tab.firehoseBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            tab.firehoseBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
            tab.firehoseBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end

    local rowPool = tab.rowPool
    local emptyStateText = tab.emptyStateText
    local content = tab.content
    local ROW_HEIGHT = tab.ROW_HEIGHT or 14

    if not rowPool or not content then return end

    if #self.events == 0 then
        tab.maxRowWidth = 0
        if emptyStateText then
            emptyStateText:Show()
            emptyStateText:SetText(self.monitoring and (L["MSG_MONITORING_EVENTS"] or "Monitoring events... (%d captured)"):format(0) or
                (L["MSG_CLICK_START"] or "Click 'Start' to begin monitoring (auto-selects common events)\nOr click 'Select Events' to customize"))
        end
        for i = 1, #rowPool do
            rowPool[i]:Hide()
        end
        content:SetHeight(math.max(100, tab.scroll and tab.scroll:GetHeight() or 100))
        content:SetWidth(tab.scroll and tab.scroll:GetWidth() or 200)
    else
        local filterText = tab.filterBox and tab.filterBox:GetSearchText() or ""
        local filter = filterText ~= "" and filterText:upper() or nil
        local argNames = Addon.Constants.EVENT_ARG_NAMES
        local displayCount = 0
        local maxRowWidth = 0

        for _, data in ipairs(self.events) do
            if not filter or string.find(data.event:upper(), filter, 1, true) then
                local argsText = ""
                if #data.args > 0 then
                    local argStrings = {}
                    local names = argNames and argNames[data.event]
                    for i, arg in ipairs(data.args) do
                        if i > 5 then
                            tinsert(argStrings, "...")
                            break
                        end
                        local disp = formatArgForDisplay(arg)
                        local colorKey = "ARG_DEFAULT"
                        if disp == "[secret]" then
                            colorKey = "SECRET"
                        elseif isUnitToken(disp) then
                            colorKey = "UNIT"
                        end
                        local label = (names and names[i]) and (WrapEventViewerColor(names[i] .. "=", "TIMESTAMP")) or ""
                        tinsert(argStrings, label .. WrapEventViewerColor(disp, colorKey))
                    end
                    argsText = table.concat(argStrings, ", ")
                end

                local countText = (data.count and data.count > 1) and WrapEventViewerColor(string.format("(x%d)", data.count), "TIMESTAMP") or ""

                displayCount = displayCount + 1
                local row = rowPool[displayCount]
                if row then
                    row.eventCol:SetText(WrapEventViewerColor("[" .. data.timestamp .. "]", "TIMESTAMP") ..
                        " " .. WrapEventViewerColor(data.event, "EVENT_NAME"))
                    row.argsCol:SetText(argsText)
                    row.countCol:SetText(countText)
                    local colEvent = tab.COL_EVENT or 280
                    local colArgs = tab.COL_ARGS or 260
                    local rowWidth = colEvent + colArgs + row.countCol:GetStringWidth()
                    maxRowWidth = math.max(maxRowWidth, rowWidth)
                    row:SetHeight(ROW_HEIGHT)
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -(displayCount - 1) * ROW_HEIGHT)
                    row:SetPoint("RIGHT", content, "RIGHT", -2, 0)
                    row:Show()
                end

                if displayCount >= 200 then
                    displayCount = displayCount + 1
                    local row = rowPool[displayCount]
                    if row then
                        row.eventCol:SetText(WrapEventViewerColor("...", "TIMESTAMP"))
                        row.argsCol:SetText(L["MSG_SHOWING_FIRST_200_EVENTS"] or "(showing first 200 events)")
                        row.countCol:SetText("")
                        row:SetHeight(ROW_HEIGHT)
                        row:ClearAllPoints()
                        row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -(displayCount - 1) * ROW_HEIGHT)
                        row:SetPoint("RIGHT", content, "RIGHT", -2, 0)
                        row:Show()
                    end
                    break
                end
            end
        end

        if emptyStateText then
            if filter and displayCount == 0 then
                emptyStateText:Show()
                emptyStateText:SetText((L["MSG_NO_EVENTS_MATCHING"] or "No events matching '%s' (total: %d)"):format(filterText, #self.events))
            else
                emptyStateText:Hide()
            end
        end

        for i = displayCount + 1, #rowPool do
            rowPool[i]:Hide()
        end

        local totalRows = (filter and displayCount == 0) and 1 or displayCount
        content:SetHeight(math.max(totalRows * ROW_HEIGHT + 10, tab.scroll and tab.scroll:GetHeight() or 100))
        tab.maxRowWidth = maxRowWidth + 8
        local scrollW = tab.scroll and tab.scroll:GetWidth() or 200
        content:SetWidth(math.max(scrollW, tab.maxRowWidth))
    end
end

function EventMonitor:ToggleEvent(event)
    if self.selectedEvents[event] then
        self.selectedEvents[event] = nil
        return false
    else
        self.selectedEvents[event] = true
        return true
    end
end

function EventMonitor:IsEventRegistered(event)
    return self.selectedEvents[event] == true
end

function EventMonitor:GetEventCount()
    local count = 0
    for _ in pairs(self.selectedEvents) do
        count = count + 1
    end
    return count
end

function EventMonitor:RegisterRegistryEvent(eventId)
    if self.registryCallbackRegistered[eventId] then return end

    pcall(function()
        EventRegistry:RegisterCallback(eventId, function(owner, ...)
            EventMonitor:OnEvent(eventId, ...)
        end, EventMonitor)
    end)

    self.registryCallbackRegistered[eventId] = true
end

function EventMonitor:ImportEvents(text)
    local count = 0

    for line in text:gmatch("[^\n]+") do
        line = line:match("^%s*(.-)%s*$")

        if line ~= "" then
            local eventId = line:match("^event%s+Event[%.%s]+(.-)%s*%->") or
                            line:match("^event%s+Event[%.%s]+(.-)%s*$")

            if eventId then
                eventId = eventId:gsub("%s+", "")
                if eventId ~= "" then
                    self.selectedRegistryEvents[eventId] = true
                    self:Initialize()
                    self:RegisterRegistryEvent(eventId)
                    count = count + 1
                end
            else
                local plainEvent = line:match("^([A-Z][A-Z_]+[A-Z])%s*$")
                if plainEvent then
                    self.selectedEvents[plainEvent] = true
                    self:Initialize()
                    pcall(function() self.frame:RegisterEvent(plainEvent) end)
                    count = count + 1
                end
            end
        end
    end

    return count
end

function EventMonitor:FirehoseStart()
    self:Initialize()
    self.frame:RegisterAllEvents()
    self.firehose = true
    self.monitoring = true
    Addon:Print(L["MSG_FIREHOSE_ON"] or "Firehose mode ON - capturing ALL events")
    self:UpdateUI()
end

function EventMonitor:FirehoseStop()
    self.frame:UnregisterAllEvents()
    self.firehose = false
    self.allEventsRegistered = false
    self:RegisterAllPossibleEvents()
    for event in pairs(self.selectedEvents) do
        pcall(function() self.frame:RegisterEvent(event) end)
    end
    Addon:Print(L["MSG_FIREHOSE_OFF"] or "Firehose mode OFF")
    self:UpdateUI()
end

function EventMonitor:FirehoseToggle()
    if self.firehose then
        self:FirehoseStop()
    else
        self:FirehoseStart()
    end
end

function EventMonitor:RegisterCommonEvents()
    for _, event in ipairs(Addon.Constants.COMMON_EVENTS) do
        self.selectedEvents[event] = true
    end
end

function EventMonitor:GetCommonEvents()
    return Addon.Constants.COMMON_EVENTS
end
