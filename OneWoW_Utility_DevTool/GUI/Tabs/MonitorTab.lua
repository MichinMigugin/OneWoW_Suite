local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local L = Addon.L or {}

function Addon.UI:CreateMonitorTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local Monitor = Addon.MonitorTab

    if Monitor then
        Monitor:Initialize()
    end

    local DUm = Addon.Constants and Addon.Constants.DEVTOOL_UI or {}
    local ROW_HEIGHT = DUm.MONITOR_LIST_ROW_HEIGHT or 20
    local MAX_ROWS = DUm.MONITOR_MAX_ROWS or 60

    local playBtn = OneWoW_GUI:CreateButton(tab, { text = L["MON_BTN_PLAY"] or "Play", width = 80, height = 22 })
    playBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)

    local updateBtn = OneWoW_GUI:CreateButton(tab, { text = L["MON_BTN_UPDATE"] or "Update", width = 80, height = 22 })
    updateBtn:SetPoint("LEFT", playBtn, "RIGHT", 5, 0)

    local resetBtn = OneWoW_GUI:CreateButton(tab, { text = L["MON_BTN_RESET"] or "Reset", width = 80, height = 22 })
    resetBtn:SetPoint("LEFT", updateBtn, "RIGHT", 5, 0)

    local cpuCheck = OneWoW_GUI:CreateCheckbox(tab, { label = L["MON_LABEL_CPU_PROFILING"] or "CPU Profiling" })
    cpuCheck:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    cpuCheck:SetChecked(Monitor and Monitor:IsCPUProfilingEnabled() or false)

    local showOnLoadCheck = OneWoW_GUI:CreateCheckbox(tab, { label = L["MON_LABEL_SHOW_ON_LOAD"] or "Show on Load" })
    showOnLoadCheck:SetPoint("LEFT", cpuCheck.label, "RIGHT", 15, 0)
    showOnLoadCheck:SetChecked(Addon.db and Addon.db.monitor and Addon.db.monitor.showOnLoad or false)

    local filterLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("TOPLEFT", playBtn, "BOTTOMLEFT", 0, -8)
    filterLabel:SetText(L["MON_LABEL_FILTER"] or "Filter:")
    filterLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local filterBox = OneWoW_GUI:CreateEditBox(tab, {
        width = 150,
        height = 22,
        placeholderText = L["MON_LABEL_FILTER"] or "Filter...",
        onTextChanged = function(text)
            if Monitor then
                Monitor:SetFilter(text)
                Monitor:GetSortedList()
                tab:RefreshList()
            end
        end,
    })
    filterBox:SetPoint("LEFT", filterLabel, "RIGHT", 5, 0)

    local hasCPU = Monitor and Monitor:IsCPUProfilingEnabled() or false

    local headerFrame = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_SIMPLE, width = 100, height = 22 })
    headerFrame:ClearAllPoints()
    headerFrame:SetPoint("TOPLEFT", playBtn, "BOTTOMLEFT", 0, -35)
    headerFrame:SetPoint("RIGHT", tab, "RIGHT", -5, 0)
    headerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local nameHeader = CreateFrame("Button", nil, headerFrame)
    nameHeader:SetPoint("LEFT", headerFrame, "LEFT", 5, 0)
    nameHeader:SetHeight(22)
    nameHeader.text = nameHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameHeader.text:SetPoint("LEFT", 0, 0)
    nameHeader.text:SetText(L["MON_HEADER_NAME"] or "Addon")
    nameHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local memHeader = CreateFrame("Button", nil, headerFrame)
    memHeader:SetSize(90, 22)
    memHeader.text = memHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    memHeader.text:SetPoint("RIGHT", 0, 0)
    memHeader.text:SetText(L["MON_HEADER_MEMORY"] or "Memory (k)")
    memHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local memPctHeader = CreateFrame("Button", nil, headerFrame)
    memPctHeader:SetSize(55, 22)
    memPctHeader.text = memPctHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    memPctHeader.text:SetPoint("RIGHT", 0, 0)
    memPctHeader.text:SetText(L["MON_HEADER_MEM_PCT"] or "Mem %")
    memPctHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local cpuHeader = CreateFrame("Button", nil, headerFrame)
    cpuHeader:SetSize(90, 22)
    cpuHeader.text = cpuHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cpuHeader.text:SetPoint("RIGHT", 0, 0)
    cpuHeader.text:SetText(L["MON_HEADER_CPU"] or "CPU (ms/s)")
    cpuHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local cpuPctHeader = CreateFrame("Button", nil, headerFrame)
    cpuPctHeader:SetSize(55, 22)
    cpuPctHeader.text = cpuPctHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cpuPctHeader.text:SetPoint("RIGHT", -14, 0)
    cpuPctHeader.text:SetText(L["MON_HEADER_CPU_PCT"] or "CPU %")
    cpuPctHeader.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    if hasCPU then
        cpuPctHeader:SetPoint("RIGHT", headerFrame, "RIGHT", 0, 0)
        cpuHeader:SetPoint("RIGHT", cpuPctHeader, "LEFT", -5, 0)
        memPctHeader:SetPoint("RIGHT", cpuHeader, "LEFT", -5, 0)
        memHeader:SetPoint("RIGHT", memPctHeader, "LEFT", -5, 0)
    else
        cpuPctHeader:Hide()
        cpuHeader:Hide()
        memPctHeader:SetPoint("RIGHT", headerFrame, "RIGHT", -14, 0)
        memHeader:SetPoint("RIGHT", memPctHeader, "LEFT", -5, 0)
    end

    nameHeader:SetPoint("RIGHT", memHeader, "LEFT", -5, 0)

    nameHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(1); Monitor:GetSortedList(); tab:RefreshList() end
    end)
    memHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(2); Monitor:GetSortedList(); tab:RefreshList() end
    end)
    memPctHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(2); Monitor:GetSortedList(); tab:RefreshList() end
    end)
    cpuHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(3); Monitor:GetSortedList(); tab:RefreshList() end
    end)
    cpuPctHeader:SetScript("OnClick", function()
        if Monitor then Monitor:ToggleSort(3); Monitor:GetSortedList(); tab:RefreshList() end
    end)

    local listPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    listPanel:ClearAllPoints()
    listPanel:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
    listPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 35)
    self:StyleContentPanel(listPanel)

    local listScroll, listContent = OneWoW_GUI:CreateScrollFrame(listPanel, {})
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 0, 0)
    listScroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -14, 0)

    listScroll:HookScript("OnSizeChanged", function(self, w)
        listContent:SetWidth(w)
    end)

    tab.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, listContent)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", listContent, "RIGHT", 0, 0)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        row:SetScript("OnClick", function(self, button)
            if button == "RightButton" and self.addonInfo and Monitor then
                local info = self.addonInfo
                MenuUtil.CreateContextMenu(self, function(ownerRegion, rootDescription)
                    -- gsub returns (string, count); as sole arg, Lua passes both — 2nd is treated as title color by MenuUtil
                    local pinTitle = (L["MON_CTX_PIN_TITLE"] or "Pin: {title}"):gsub("{title}", tostring(info.title or ""))
                    rootDescription:CreateTitle(pinTitle)
                    rootDescription:CreateButton(L["MON_CTX_MONITOR_THIS"] or "Monitor This Addon", function()
                        Monitor:CreatePinnedPopup(info.name, info.title)
                        if Monitor:IsMonitoring() then
                            Monitor:ToggleMonitoring()
                            playBtn.text:SetText(L["MON_BTN_PLAY"] or "Play")
                        end
                    end)
                end)
            end
        end)

        row.stripe = row:CreateTexture(nil, "BACKGROUND")
        row.stripe:SetAllPoints()
        if i % 2 == 0 then
            row.stripe:SetColorTexture(1, 1, 1, 0.03)
        else
            row.stripe:SetColorTexture(0, 0, 0, 0)
        end

        row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        row.highlight:SetAlpha(0.15)

        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameText:SetPoint("LEFT", row, "LEFT", 5, 0)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        row.memText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.memText:SetJustifyH("RIGHT")
        row.memText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row.memPctText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.memPctText:SetJustifyH("RIGHT")
        row.memPctText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        row.cpuText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cpuText:SetJustifyH("RIGHT")
        row.cpuText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row.cpuPctText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cpuPctText:SetJustifyH("RIGHT")
        row.cpuPctText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        if hasCPU then
            row.cpuPctText:SetPoint("RIGHT", row, "RIGHT", -14, 0)
            row.cpuPctText:SetWidth(55)
            row.cpuText:SetPoint("RIGHT", row.cpuPctText, "LEFT", -5, 0)
            row.cpuText:SetWidth(90)
            row.memPctText:SetPoint("RIGHT", row.cpuText, "LEFT", -5, 0)
            row.memPctText:SetWidth(55)
            row.memText:SetPoint("RIGHT", row.memPctText, "LEFT", -5, 0)
            row.memText:SetWidth(90)
        else
            row.cpuText:Hide()
            row.cpuPctText:Hide()
            row.memPctText:SetPoint("RIGHT", row, "RIGHT", -14, 0)
            row.memPctText:SetWidth(55)
            row.memText:SetPoint("RIGHT", row.memPctText, "LEFT", -5, 0)
            row.memText:SetWidth(90)
        end

        row.nameText:SetPoint("RIGHT", row.memText, "LEFT", -5, 0)

        row:Hide()
        tab.rows[i] = row
    end

    local totalsBar = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_SIMPLE, width = 100, height = 25 })
    totalsBar:ClearAllPoints()
    totalsBar:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 5, 5)
    totalsBar:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)
    totalsBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    tab.totalsText = totalsBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.totalsText:SetPoint("LEFT", totalsBar, "LEFT", 10, 0)
    tab.totalsText:SetText("")
    tab.totalsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    tab.noDataText = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.noDataText:SetPoint("CENTER", listPanel, "CENTER", 0, 0)
    tab.noDataText:SetText(L["MON_MSG_NO_DATA"] or "Click 'Update' or 'Play' to begin monitoring")
    tab.noDataText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    function tab:RefreshList()
        if not Monitor then return end
        local list = Monitor:GetDisplayedList()
        local t = Monitor:GetTotals()

        if t.count == 0 then
            tab.noDataText:Show()
        else
            tab.noDataText:Hide()
        end

        for i = 1, MAX_ROWS do
            local row = tab.rows[i]
            local info = list[i]
            if info then
                row.addonInfo = info
                row.nameText:SetText(info.title)
                row.memText:SetText(Monitor:FormatMemory(info.memory))
                row.memPctText:SetText(Monitor:FormatPercent(info.memPercent))
                if hasCPU then
                    row.cpuText:SetText(Monitor:FormatCPU(info.cpuPerSec))
                    row.cpuPctText:SetText(Monitor:FormatPercent(info.cpuPercent))
                end
                row:Show()
            else
                row.addonInfo = nil
                row:Hide()
            end
        end

        local contentHeight = math.max(#list * ROW_HEIGHT + 5, listScroll:GetHeight())
        listContent:SetHeight(contentHeight)

        local cpuTotalPerSec = 0
        if t.duration > 0 then
            cpuTotalPerSec = t.cpu / t.duration
        end

        local totalsStr = (L["MON_TOTALS_ADDONS"] or "Addons:") .. " " .. t.count ..
            "    " .. (L["MON_TOTALS_MEMORY"] or "Memory:") .. " " .. Monitor:FormatMemory(t.memory) .. " k"
        if hasCPU then
            totalsStr = totalsStr .. "    " .. (L["MON_TOTALS_CPU"] or "CPU:") .. " " .. Monitor:FormatCPU(cpuTotalPerSec) .. " ms/s"
        end
        tab.totalsText:SetText(totalsStr)
    end

    local function DoUpdate()
        if Monitor then
            Monitor:GatherUsage()
            Monitor:GetSortedList()
            tab:RefreshList()
        end
    end

    playBtn:SetScript("OnClick", function()
        if not Monitor then return end
        Monitor:ToggleMonitoring()
        if Monitor:IsMonitoring() then
            playBtn.text:SetText(L["MON_BTN_PAUSE"] or "Pause")
            DoUpdate()
        else
            playBtn.text:SetText(L["MON_BTN_PLAY"] or "Play")
        end
    end)

    updateBtn:SetScript("OnClick", function()
        DoUpdate()
    end)

    resetBtn:SetScript("OnClick", function()
        if Monitor then
            Monitor:Reset()
            DoUpdate()
            Addon:Print(L["MON_MSG_RESET"] or "Memory collected and CPU usage reset")
        end
    end)

    cpuCheck:SetScript("OnClick", function()
        if Monitor then
            StaticPopupDialogs["ONEWOW_DEVTOOL_CPU_RELOAD"] = {
                text = L["MON_CPU_RELOAD_CONFIRM"] or "Changing CPU profiling requires a UI reload. Reload now?",
                button1 = YES,
                button2 = NO,
                OnAccept = function()
                    Monitor:ToggleCPUProfiling()
                end,
                OnCancel = function()
                    cpuCheck:SetChecked(Monitor:IsCPUProfilingEnabled())
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("ONEWOW_DEVTOOL_CPU_RELOAD")
        end
    end)

    showOnLoadCheck:SetScript("OnClick", function(self)
        if Addon.db and Addon.db.monitor then
            Addon.db.monitor.showOnLoad = self:GetChecked() and true or false
        end
    end)

    tab:SetScript("OnUpdate", function(self, elapsed)
        if Monitor then
            local wasMonitoring = Monitor:IsMonitoring()
            Monitor:OnUpdate(elapsed)
            if wasMonitoring then
                Monitor:GetSortedList()
            end
        end
    end)

    function tab:Teardown()
        self:SetScript("OnUpdate", nil)
        if Monitor then
            Monitor:StopMonitoring()
            Monitor:ClosePinnedPopup()
        end
        if Addon.MonitorTabUI == self then
            Addon.MonitorTabUI = nil
        end
    end

    Addon.MonitorTabUI = tab
    return tab
end
