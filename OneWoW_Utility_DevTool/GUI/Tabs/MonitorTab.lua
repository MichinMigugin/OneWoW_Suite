local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local L = Addon.L or {}

local function BindHeaderTooltip(btn, titleKey, bodyKey)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[titleKey] or titleKey, 1, 1, 1)
        GameTooltip:AddLine(L[bodyKey] or bodyKey, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
end

local function CreateTotalsBarSegment(parent, tooltipTitleKey, tooltipBodyKey, textColorR, textColorG, textColorB)
    local seg = CreateFrame("Frame", nil, parent)
    seg:SetHeight(22)
    seg:EnableMouse(true)
    local fs = seg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", seg, "LEFT", 0, 0)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(textColorR, textColorG, textColorB, 1)
    seg.fs = fs
    if tooltipTitleKey and tooltipBodyKey then
        seg:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText(L[tooltipTitleKey] or tooltipTitleKey, 1, 1, 1)
            GameTooltip:AddLine(L[tooltipBodyKey] or tooltipBodyKey, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        seg:SetScript("OnLeave", GameTooltip_Hide)
    end
    return seg
end

local function LayoutTotalsSegments(parent, segments, gap, topInset)
    topInset = topInset or -2
    local prev = nil
    for _, seg in ipairs(segments) do
        if seg:IsShown() then
            local w = seg.fs:GetStringWidth()
            if not w or w < 4 then w = 4 end
            seg:SetWidth(w)
            seg:ClearAllPoints()
            if prev then
                seg:SetPoint("TOPLEFT", prev, "TOPRIGHT", gap, 0)
            else
                seg:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, topInset)
            end
            prev = seg
        end
    end
end

function Addon.UI:CreateMonitorTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints(parent)
    tab:Hide()

    local Monitor = Addon.MonitorTab
    local Const = Addon.Constants or {}
    local MP = Const.MONITOR_PRESET
    if not MP or not MP.BALANCED then
        MP = {
            BALANCED = "balanced", MEMORY_DIG = "memory_dig", CPU_SPIKES = "cpu_spikes",
            MINIMAL = "minimal", ENGINE_PROFILER = "engine_profiler",
        }
    end
    local MS = {
        NAME = Const.MONITOR_SORT_NAME or 1,
        MEMORY = Const.MONITOR_SORT_MEMORY or 2,
        CPU_SESSION = Const.MONITOR_SORT_CPU_SESSION or 3,
        MEM_DELTA = Const.MONITOR_SORT_MEM_DELTA or 4,
        MEM_PEAK = Const.MONITOR_SORT_MEM_PEAK or 5,
        CPU_RECENT = Const.MONITOR_SORT_CPU_RECENT or 6,
        CPU_MS = Const.MONITOR_SORT_CPU_MS or 7,
        MEM_PCT = Const.MONITOR_SORT_MEM_PCT or 8,
        CPU_PCT = Const.MONITOR_SORT_CPU_PCT or 9,
        AP_SESSION = Const.MONITOR_SORT_AP_SESSION or 10,
        AP_RECENT = Const.MONITOR_SORT_AP_RECENT or 11,
        AP_PEAK = Const.MONITOR_SORT_AP_PEAK or 12,
        AP_OVER1 = Const.MONITOR_SORT_AP_OVER1 or 13,
        AP_OVER5 = Const.MONITOR_SORT_AP_OVER5 or 14,
        AP_OVER10 = Const.MONITOR_SORT_AP_OVER10 or 15,
        AP_OVER50 = Const.MONITOR_SORT_AP_OVER50 or 16,
        AP_OVER100 = Const.MONITOR_SORT_AP_OVER100 or 17,
        AP_OVER500 = Const.MONITOR_SORT_AP_OVER500 or 18,
        AP_OVER1000 = Const.MONITOR_SORT_AP_OVER1000 or 19,
        AP_SPIKE = Const.MONITOR_SORT_AP_SPIKE or 20,
    }

    if Monitor then
        Monitor:Initialize()
    end

    local DUm = Const.DEVTOOL_UI or {}
    local ROW_HEIGHT = DUm.MONITOR_LIST_ROW_HEIGHT or 20
    local MAX_ROWS = DUm.MONITOR_MAX_ROWS or 60

    local W_MEM = 76
    local W_MEMD = 64
    local W_PEAK = 76
    local W_PCT = 50
    local W_CPU = 78
    local W_CPUMS = 56
    local W_AP_N = DUm.MONITOR_COL_AP_NARROW or 40
    local W_AP_M = DUm.MONITOR_COL_AP_MED or 48
    local W_AP_S = 52
    local LIST_RIGHT_GUTTER = DUm.MONITOR_LIST_RIGHT_GUTTER or 14

    local playBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["MON_BTN_PLAY"], height = 22, minWidth = 64 })
    playBtn:SetPoint("TOPLEFT", tab, "TOPLEFT", 5, -5)

    local updateBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["MON_BTN_UPDATE"], height = 22, minWidth = 64 })
    updateBtn:SetPoint("LEFT", playBtn, "RIGHT", 5, 0)

    local resetBtn = OneWoW_GUI:CreateFitTextButton(tab, { text = L["MON_BTN_RESET"], height = 22, minWidth = 64 })
    resetBtn:SetPoint("LEFT", updateBtn, "RIGHT", 5, 0)

    local cpuCheck = OneWoW_GUI:CreateCheckbox(tab, { label = L["MON_LABEL_CPU_PROFILING"] })
    cpuCheck:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    cpuCheck:SetChecked(Monitor and Monitor:IsCPUProfilingEnabled() or false)

    local showOnLoadCheck = OneWoW_GUI:CreateCheckbox(tab, { label = L["MON_LABEL_SHOW_ON_LOAD"] })
    showOnLoadCheck:SetPoint("LEFT", cpuCheck.label, "RIGHT", 15, 0)
    showOnLoadCheck:SetChecked(Addon.db.global.monitor.showOnLoad)

    local filterLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("TOPLEFT", playBtn, "BOTTOMLEFT", 0, -14)
    filterLabel:SetText(L["MON_LABEL_FILTER"])
    filterLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local filterBox = OneWoW_GUI:CreateEditBox(tab, {
        width = 150,
        height = 22,
        placeholderText = L["MON_LABEL_FILTER"],
        onTextChanged = function(text)
            if Monitor then
                Monitor:SetFilter(text)
                Monitor:RefreshDisplayedList()
            end
        end,
    })
    filterBox:SetPoint("LEFT", filterLabel, "RIGHT", 5, 0)

    local function PresetDisplayName(id)
        if id == MP.BALANCED then return L["MON_PRESET_BALANCED"] end
        if id == MP.MEMORY_DIG then return L["MON_PRESET_MEMORY_DIG"] end
        if id == MP.CPU_SPIKES then return L["MON_PRESET_CPU_SPIKES"] end
        if id == MP.MINIMAL then return L["MON_PRESET_MINIMAL"] end
        if id == MP.ENGINE_PROFILER then return L["MON_PRESET_ENGINE_PROFILER"] end
        return L["MON_PRESET_BALANCED"]
    end

    local viewBtn = OneWoW_GUI:CreateFitTextButton(tab, {
        text = "",
        height = 22,
        minWidth = 100,
    })
    viewBtn:SetPoint("LEFT", filterBox, "RIGHT", 8, 0)

    local function UpdateViewButtonLabel()
        if not Monitor then return end
        local id = Monitor:GetViewPreset()
        local fmt = L["MON_VIEW_BUTTON"]
        viewBtn:SetFitText((fmt):gsub("%%s", PresetDisplayName(id)))
    end
    UpdateViewButtonLabel()

    viewBtn:SetScript("OnClick", function()
        if not Monitor then return end
        MenuUtil.CreateContextMenu(viewBtn, function(_, rootDescription)
            rootDescription:CreateTitle(L["MON_VIEW_MENU_TITLE"])
            rootDescription:CreateButton(L["MON_PRESET_BALANCED"], function()
                Monitor:SetViewPreset(MP.BALANCED or "balanced")
                UpdateViewButtonLabel()
                tab:ApplyMonitorColumnLayout()
                Monitor:RefreshDisplayedList()
            end)
            rootDescription:CreateButton(L["MON_PRESET_MEMORY_DIG"], function()
                Monitor:SetViewPreset(MP.MEMORY_DIG or "memory_dig")
                UpdateViewButtonLabel()
                tab:ApplyMonitorColumnLayout()
                Monitor:RefreshDisplayedList()
            end)
            rootDescription:CreateButton(L["MON_PRESET_CPU_SPIKES"], function()
                Monitor:SetViewPreset(MP.CPU_SPIKES or "cpu_spikes")
                UpdateViewButtonLabel()
                tab:ApplyMonitorColumnLayout()
                Monitor:RefreshDisplayedList()
            end)
            rootDescription:CreateButton(L["MON_PRESET_MINIMAL"], function()
                Monitor:SetViewPreset(MP.MINIMAL or "minimal")
                UpdateViewButtonLabel()
                tab:ApplyMonitorColumnLayout()
                Monitor:RefreshDisplayedList()
            end)
            rootDescription:CreateButton(L["MON_PRESET_ENGINE_PROFILER"], function()
                Monitor:SetViewPreset(MP.ENGINE_PROFILER or "engine_profiler")
                UpdateViewButtonLabel()
                tab:ApplyMonitorColumnLayout()
                Monitor:RefreshDisplayedList()
            end)
        end)
    end)

    local headerFrame = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_SIMPLE, width = 100, height = 22 })
    headerFrame:ClearAllPoints()
    headerFrame:SetPoint("TOPLEFT", playBtn, "BOTTOMLEFT", 0, -41)
    headerFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local function MakeHeader(parent, text, sortCol, titleKey, bodyKey, justifyH)
        justifyH = justifyH or "CENTER"
        local h = CreateFrame("Button", nil, parent)
        h:SetHeight(22)
        h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h.text:SetPoint("TOPLEFT", h, "TOPLEFT", 2, 0)
        h.text:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -2, 0)
        h.text:SetJustifyH(justifyH)
        h.text:SetJustifyV("MIDDLE")
        h.text:SetText(text)
        h.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        h.sortCol = sortCol
        h:SetScript("OnClick", function()
            if Monitor then Monitor:ToggleSort(sortCol); Monitor:RefreshDisplayedList() end
        end)
        if titleKey and bodyKey then
            BindHeaderTooltip(h, titleKey, bodyKey)
        end
        return h
    end

    local nameHeader = MakeHeader(headerFrame, L["MON_HEADER_NAME"], MS.NAME, "MON_TT_NAME_TITLE", "MON_TT_NAME_BODY", "LEFT")

    local memHeader = MakeHeader(headerFrame, L["MON_HEADER_MEMORY"], MS.MEMORY, "MON_TT_MEMORY_TITLE", "MON_TT_MEMORY_BODY", "RIGHT")
    local memDeltaHeader = MakeHeader(headerFrame, L["MON_HEADER_MEM_DELTA"], MS.MEM_DELTA, "MON_TT_MEM_DELTA_TITLE", "MON_TT_MEM_DELTA_BODY", "RIGHT")
    local memPeakHeader = MakeHeader(headerFrame, L["MON_HEADER_MEM_PEAK"], MS.MEM_PEAK, "MON_TT_MEM_PEAK_TITLE", "MON_TT_MEM_PEAK_BODY", "RIGHT")
    local memPctHeader = MakeHeader(headerFrame, L["MON_HEADER_MEM_PCT"], MS.MEM_PCT, "MON_TT_MEM_PCT_TITLE", "MON_TT_MEM_PCT_BODY", "RIGHT")
    local cpuSessionHeader = MakeHeader(headerFrame, L["MON_HEADER_CPU_SESSION"], MS.CPU_SESSION, "MON_TT_CPU_SESSION_TITLE", "MON_TT_CPU_SESSION_BODY", "RIGHT")
    local cpuRecentHeader = MakeHeader(headerFrame, L["MON_HEADER_CPU_RECENT"], MS.CPU_RECENT, "MON_TT_CPU_RECENT_TITLE", "MON_TT_CPU_RECENT_BODY", "RIGHT")
    local cpuMsHeader = MakeHeader(headerFrame, L["MON_HEADER_CPU_MS"], MS.CPU_MS, "MON_TT_CPU_MS_TITLE", "MON_TT_CPU_MS_BODY", "RIGHT")
    local cpuPctHeader = MakeHeader(headerFrame, L["MON_HEADER_CPU_PCT"], MS.CPU_PCT, "MON_TT_CPU_PCT_TITLE", "MON_TT_CPU_PCT_BODY", "RIGHT")

    local apSessionHeader = MakeHeader(headerFrame, L["MON_HEADER_AP_SESSION"], MS.AP_SESSION, "MON_TT_AP_SESSION_TITLE", "MON_TT_AP_SESSION_BODY", "RIGHT")
    local apRecentHeader = MakeHeader(headerFrame, L["MON_HEADER_AP_RECENT"], MS.AP_RECENT, "MON_TT_AP_RECENT_TITLE", "MON_TT_AP_RECENT_BODY", "RIGHT")
    local apPeakHeader = MakeHeader(headerFrame, L["MON_HEADER_AP_PEAK"], MS.AP_PEAK, "MON_TT_AP_PEAK_TITLE", "MON_TT_AP_PEAK_BODY", "RIGHT")
    local apOver1Header = MakeHeader(headerFrame, L["MON_HEADER_AP_OVER1"], MS.AP_OVER1, "MON_TT_AP_OVER1_TITLE", "MON_TT_AP_OVER1_BODY", "RIGHT")
    local apOver5Header = MakeHeader(headerFrame, L["MON_HEADER_AP_OVER5"], MS.AP_OVER5, "MON_TT_AP_OVER5_TITLE", "MON_TT_AP_OVER5_BODY", "RIGHT")
    local apOver10Header = MakeHeader(headerFrame, L["MON_HEADER_AP_OVER10"], MS.AP_OVER10, "MON_TT_AP_OVER10_TITLE", "MON_TT_AP_OVER10_BODY", "RIGHT")
    local apOver50Header = MakeHeader(headerFrame, L["MON_HEADER_AP_OVER50"], MS.AP_OVER50, "MON_TT_AP_OVER50_TITLE", "MON_TT_AP_OVER50_BODY", "RIGHT")
    local apOver100Header = MakeHeader(headerFrame, L["MON_HEADER_AP_OVER100"], MS.AP_OVER100, "MON_TT_AP_OVER100_TITLE", "MON_TT_AP_OVER100_BODY", "RIGHT")
    local apOver500Header = MakeHeader(headerFrame, L["MON_HEADER_AP_OVER500"], MS.AP_OVER500, "MON_TT_AP_OVER500_TITLE", "MON_TT_AP_OVER500_BODY", "RIGHT")
    local apOver1000Header = MakeHeader(headerFrame, L["MON_HEADER_AP_OVER1000"], MS.AP_OVER1000, "MON_TT_AP_OVER1000_TITLE", "MON_TT_AP_OVER1000_BODY", "RIGHT")
    local apSpikeHeader = MakeHeader(headerFrame, L["MON_HEADER_AP_SPIKE"], MS.AP_SPIKE, "MON_TT_AP_SPIKE_TITLE", "MON_TT_AP_SPIKE_BODY", "RIGHT")

    local allHeaders = {
        memHeader, memDeltaHeader, memPeakHeader, memPctHeader,
        cpuSessionHeader, cpuRecentHeader, cpuMsHeader, cpuPctHeader,
        apSessionHeader, apRecentHeader, apPeakHeader,
        apOver1Header, apOver5Header, apOver10Header, apOver50Header, apOver100Header, apOver500Header, apOver1000Header,
        apSpikeHeader,
    }

    function tab:ApplyMonitorColumnLayout()
        if not Monitor then return end
        local hasCPU = Monitor:IsCPUProfilingEnabled()
        local hasProfiler = Monitor:ProfilerEnabled()
        local preset = Monitor:GetViewPreset()
        for _, h in ipairs(allHeaders) do
            h:Hide()
        end

        local showMem = true
        local showMemD = false
        local showMemP = false
        local showMemPct = true
        local showCpuS = false
        local showCpuR = false
        local showCpuMs = false
        local showCpuPct = false
        local showApSession = false
        local showApRecent = false
        local showApPeak = false
        local showAp1 = false
        local showAp5 = false
        local showAp10 = false
        local showAp50 = false
        local showAp100 = false
        local showAp500 = false
        local showAp1000 = false
        local showApSpike = false

        if preset == MP.ENGINE_PROFILER then
            showMem = false
            showMemPct = false
            showApSession = true
            showApRecent = true
            showApPeak = true
            showAp1 = true
            showAp5 = true
            showAp10 = true
            showAp50 = true
            showAp100 = true
            showAp500 = true
            showAp1000 = true
            showApSpike = true
        elseif preset == MP.CPU_SPIKES then
            if hasCPU then
                showMem = false
                showMemPct = false
                showCpuS = true
                showCpuR = true
                showCpuMs = true
                showCpuPct = true
                if hasProfiler then
                    showApPeak = true
                    showAp50 = true
                    showApSpike = true
                end
            elseif hasProfiler then
                showMem = false
                showMemPct = false
                showApPeak = true
                showAp50 = true
                showApSpike = true
            else
                showMemD = false
                showMemP = false
                showMemPct = true
            end
        elseif preset == MP.MEMORY_DIG then
            showMemD = true
            showMemP = true
            showMemPct = true
        elseif preset == MP.MINIMAL then
            showMemD = false
            showMemP = false
            showMemPct = true
        else
            showCpuS = hasCPU
            showCpuPct = hasCPU
        end

        local chain = headerFrame
        local ox = -LIST_RIGHT_GUTTER

        local function attach(h, w)
            h:SetWidth(w)
            h:ClearAllPoints()
            if chain == headerFrame then
                h:SetPoint("RIGHT", headerFrame, "RIGHT", ox, 0)
            else
                h:SetPoint("RIGHT", chain, "LEFT", -5, 0)
            end
            chain = h
            h:Show()
        end

        if showApSpike then attach(apSpikeHeader, W_AP_S) end
        if showAp1000 then attach(apOver1000Header, W_AP_N) end
        if showAp500 then attach(apOver500Header, W_AP_N) end
        if showAp100 then attach(apOver100Header, W_AP_N) end
        if showAp50 then attach(apOver50Header, W_AP_N) end
        if showAp10 then attach(apOver10Header, W_AP_N) end
        if showAp5 then attach(apOver5Header, W_AP_N) end
        if showAp1 then attach(apOver1Header, W_AP_N) end
        if showApPeak then attach(apPeakHeader, W_AP_M) end
        if showApRecent then attach(apRecentHeader, W_AP_M) end
        if showApSession then attach(apSessionHeader, W_AP_M) end
        if showCpuPct then attach(cpuPctHeader, W_PCT) end
        if showCpuMs then attach(cpuMsHeader, W_CPUMS) end
        if showCpuR then attach(cpuRecentHeader, W_CPU) end
        if showCpuS then attach(cpuSessionHeader, W_CPU) end
        if showMemPct then attach(memPctHeader, W_PCT) end
        if showMemP then attach(memPeakHeader, W_PEAK) end
        if showMemD then attach(memDeltaHeader, W_MEMD) end
        if showMem then attach(memHeader, W_MEM) end

        nameHeader:ClearAllPoints()
        nameHeader:SetPoint("LEFT", headerFrame, "LEFT", 5, 0)
        nameHeader:SetPoint("RIGHT", chain, "LEFT", -5, 0)
        nameHeader:SetHeight(22)
        nameHeader:Show()

        for i = 1, MAX_ROWS do
            local row = tab.rows[i]
            if not row then break end
            row.memText:Hide()
            row.memDeltaText:Hide()
            row.memPeakText:Hide()
            row.memPctText:Hide()
            row.cpuSessionText:Hide()
            row.cpuRecentText:Hide()
            row.cpuMsText:Hide()
            row.cpuPctText:Hide()
            row.apSessionText:Hide()
            row.apRecentText:Hide()
            row.apPeakText:Hide()
            row.apOver1Text:Hide()
            row.apOver5Text:Hide()
            row.apOver10Text:Hide()
            row.apOver50Text:Hide()
            row.apOver100Text:Hide()
            row.apOver500Text:Hide()
            row.apOver1000Text:Hide()
            row.apSpikeText:Hide()
            local rchain = row
            local function rattach(fs, w)
                fs:SetWidth(w)
                fs:ClearAllPoints()
                if rchain == row then
                    fs:SetPoint("RIGHT", row, "RIGHT", -LIST_RIGHT_GUTTER, 0)
                else
                    fs:SetPoint("RIGHT", rchain, "LEFT", -5, 0)
                end
                rchain = fs
                fs:Show()
            end
            if showApSpike then rattach(row.apSpikeText, W_AP_S) end
            if showAp1000 then rattach(row.apOver1000Text, W_AP_N) end
            if showAp500 then rattach(row.apOver500Text, W_AP_N) end
            if showAp100 then rattach(row.apOver100Text, W_AP_N) end
            if showAp50 then rattach(row.apOver50Text, W_AP_N) end
            if showAp10 then rattach(row.apOver10Text, W_AP_N) end
            if showAp5 then rattach(row.apOver5Text, W_AP_N) end
            if showAp1 then rattach(row.apOver1Text, W_AP_N) end
            if showApPeak then rattach(row.apPeakText, W_AP_M) end
            if showApRecent then rattach(row.apRecentText, W_AP_M) end
            if showApSession then rattach(row.apSessionText, W_AP_M) end
            if showCpuPct then rattach(row.cpuPctText, W_PCT) end
            if showCpuMs then rattach(row.cpuMsText, W_CPUMS) end
            if showCpuR then rattach(row.cpuRecentText, W_CPU) end
            if showCpuS then rattach(row.cpuSessionText, W_CPU) end
            if showMemPct then rattach(row.memPctText, W_PCT) end
            if showMemP then rattach(row.memPeakText, W_PEAK) end
            if showMemD then rattach(row.memDeltaText, W_MEMD) end
            if showMem then rattach(row.memText, W_MEM) end
            row.nameText:ClearAllPoints()
            row.nameText:SetPoint("LEFT", row, "LEFT", 5, 0)
            row.nameText:SetPoint("RIGHT", rchain, "LEFT", -5, 0)
        end
    end

    local listPanel = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_INNER_NO_INSETS, width = 100, height = 100 })
    listPanel:ClearAllPoints()
    listPanel:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
    listPanel:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 35)
    self:StyleContentPanel(listPanel)

    local listScroll, listContent = OneWoW_GUI:CreateScrollFrame(listPanel, {})
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 0, 0)
    listScroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -LIST_RIGHT_GUTTER, 0)

    local TAB_PANEL_RIGHT_INSET = 5

    local function SyncMonitorHeaderToList()
        headerFrame:ClearAllPoints()
        headerFrame:SetPoint("TOPLEFT", playBtn, "BOTTOMLEFT", 0, -41)
        headerFrame:SetPoint("RIGHT", tab, "RIGHT", -TAB_PANEL_RIGHT_INSET - LIST_RIGHT_GUTTER, 0)
    end

    listScroll:HookScript("OnSizeChanged", function(self, w)
        listContent:SetWidth(w)
        tab:ApplyMonitorColumnLayout()
    end)

    SyncMonitorHeaderToList()

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
                    local pinTitle = (L["MON_CTX_PIN_TITLE"]):gsub("{title}", tostring(info.title or ""))
                    rootDescription:CreateTitle(pinTitle)
                    rootDescription:CreateButton(L["MON_CTX_MONITOR_THIS"], function()
                        Monitor:CreatePinnedPopup(info.name, info.title)
                        if Monitor:IsMonitoring() then
                            Monitor:ToggleMonitoring()
                            playBtn.text:SetText(L["MON_BTN_PLAY"])
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
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        row.memText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.memText:SetJustifyH("RIGHT")
        row.memText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row.memDeltaText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.memDeltaText:SetJustifyH("RIGHT")
        row.memDeltaText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row.memPeakText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.memPeakText:SetJustifyH("RIGHT")
        row.memPeakText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row.memPctText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.memPctText:SetJustifyH("RIGHT")
        row.memPctText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        row.cpuSessionText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cpuSessionText:SetJustifyH("RIGHT")
        row.cpuSessionText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row.cpuRecentText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cpuRecentText:SetJustifyH("RIGHT")
        row.cpuRecentText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row.cpuMsText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cpuMsText:SetJustifyH("RIGHT")
        row.cpuMsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row.cpuPctText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cpuPctText:SetJustifyH("RIGHT")
        row.cpuPctText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        row.apSessionText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.apSessionText:SetJustifyH("RIGHT")
        row.apSessionText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row.apRecentText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.apRecentText:SetJustifyH("RIGHT")
        row.apRecentText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row.apPeakText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.apPeakText:SetJustifyH("RIGHT")
        row.apPeakText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row.apOver1Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.apOver1Text:SetJustifyH("RIGHT")
        row.apOver1Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row.apOver5Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.apOver5Text:SetJustifyH("RIGHT")
        row.apOver5Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row.apOver10Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.apOver10Text:SetJustifyH("RIGHT")
        row.apOver10Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row.apOver50Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.apOver50Text:SetJustifyH("RIGHT")
        row.apOver50Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row.apOver100Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.apOver100Text:SetJustifyH("RIGHT")
        row.apOver100Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row.apOver500Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.apOver500Text:SetJustifyH("RIGHT")
        row.apOver500Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row.apOver1000Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.apOver1000Text:SetJustifyH("RIGHT")
        row.apOver1000Text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row.apSpikeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.apSpikeText:SetJustifyH("RIGHT")
        row.apSpikeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        row.memText:Hide()
        row.memDeltaText:Hide()
        row.memPeakText:Hide()
        row.memPctText:Hide()
        row.cpuSessionText:Hide()
        row.cpuRecentText:Hide()
        row.cpuMsText:Hide()
        row.cpuPctText:Hide()
        row.apSessionText:Hide()
        row.apRecentText:Hide()
        row.apPeakText:Hide()
        row.apOver1Text:Hide()
        row.apOver5Text:Hide()
        row.apOver10Text:Hide()
        row.apOver50Text:Hide()
        row.apOver100Text:Hide()
        row.apOver500Text:Hide()
        row.apOver1000Text:Hide()
        row.apSpikeText:Hide()

        row:Hide()
        tab.rows[i] = row
    end

    tab:ApplyMonitorColumnLayout()

    local totalsBar = OneWoW_GUI:CreateFrame(tab, { backdrop = BACKDROP_SIMPLE, width = 100, height = 25 })
    totalsBar:ClearAllPoints()
    totalsBar:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 5, 5)
    totalsBar:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -5, 5)
    totalsBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local tr, tg, tb = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
    tab.totalsSegAddons = CreateTotalsBarSegment(totalsBar, nil, nil, tr, tg, tb)
    tab.totalsSegMem = CreateTotalsBarSegment(totalsBar, "MON_TT_TOTALS_MEM_TITLE", "MON_TT_TOTALS_MEM_BODY", tr, tg, tb)
    tab.totalsSegFps = CreateTotalsBarSegment(totalsBar, nil, nil, tr, tg, tb)
    tab.totalsSegLua = CreateTotalsBarSegment(totalsBar, "MON_TT_TOTALS_LUA_TITLE", "MON_TT_TOTALS_LUA_BODY", tr, tg, tb)
    tab.totalsSegCpu = CreateTotalsBarSegment(totalsBar, "MON_TT_TOTALS_CPU_TITLE", "MON_TT_TOTALS_CPU_BODY", tr, tg, tb)
    tab.totalsSegDmem = CreateTotalsBarSegment(totalsBar, nil, nil, tr, tg, tb)
    tab._totalsSegGap = 12

    tab.noDataText = listPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tab.noDataText:SetPoint("CENTER", listPanel, "CENTER", 0, 0)
    tab.noDataText:SetText(L["MON_MSG_NO_DATA"])
    tab.noDataText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    function tab:RefreshList()
        if not Monitor then return end
        tab:ApplyMonitorColumnLayout()
        local list = Monitor:GetDisplayedList()
        local t = Monitor:GetTotals()
        local preset = Monitor:GetViewPreset()
        local hasCPU = Monitor:IsCPUProfilingEnabled()
        local profOk = Monitor:ProfilerEnabled()

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
                row.memDeltaText:SetText(Monitor:FormatMemoryDelta(info.memoryDelta))
                row.memPeakText:SetText(Monitor:FormatMemory(info.memoryPeak))
                row.memPctText:SetText(Monitor:FormatPercent(info.memPercent))
                row.cpuSessionText:SetText(Monitor:FormatCPU(info.cpuPerSec))
                row.cpuRecentText:SetText(Monitor:FormatCPU(info.cpuPerSecRecent))
                row.cpuMsText:SetText(Monitor:FormatCPUMs(info.cpu))
                row.cpuPctText:SetText(Monitor:FormatPercent(info.cpuPercent))
                if profOk then
                    row.apSessionText:SetText(Monitor:FormatAPMs(info.apSessionAvgMs))
                    row.apRecentText:SetText(Monitor:FormatAPMs(info.apRecentAvgMs))
                    row.apPeakText:SetText(Monitor:FormatAPMs(info.apPeakMs))
                    row.apOver1Text:SetText(Monitor:FormatAPCount(info.apOver1))
                    row.apOver5Text:SetText(Monitor:FormatAPCount(info.apOver5))
                    row.apOver10Text:SetText(Monitor:FormatAPCount(info.apOver10))
                    row.apOver50Text:SetText(Monitor:FormatAPCount(info.apOver50))
                    row.apOver100Text:SetText(Monitor:FormatAPCount(info.apOver100))
                    row.apOver500Text:SetText(Monitor:FormatAPCount(info.apOver500))
                    row.apOver1000Text:SetText(Monitor:FormatAPCount(info.apOver1000))
                    row.apSpikeText:SetText(Monitor:FormatAPCount(info.apSpikeScore))
                else
                    row.apSessionText:SetText("--")
                    row.apRecentText:SetText("--")
                    row.apPeakText:SetText("--")
                    row.apOver1Text:SetText("--")
                    row.apOver5Text:SetText("--")
                    row.apOver10Text:SetText("--")
                    row.apOver50Text:SetText("--")
                    row.apOver100Text:SetText("--")
                    row.apOver500Text:SetText("--")
                    row.apOver1000Text:SetText("--")
                    row.apSpikeText:SetText("--")
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

        local fps = GetFramerate()
        local luaKb = t.luaHeapKb or 0
        tab.totalsSegAddons.fs:SetText((L["MON_TOTALS_ADDONS"]) .. " " .. tostring(t.count))
        tab.totalsSegMem.fs:SetText((L["MON_TOTALS_MEMORY"]) .. " " .. Monitor:FormatMemory(t.memory) .. " " .. (L["MON_UNIT_K"]))
        tab.totalsSegFps.fs:SetText((L["MON_TOTALS_FPS"]) .. " " .. format("%.1f", fps))
        tab.totalsSegLua.fs:SetText((L["MON_TOTALS_LUA_HEAP"]) .. " " .. Monitor:FormatMemory(luaKb) .. " " .. (L["MON_UNIT_K"]))
        tab.totalsSegAddons:Show()
        tab.totalsSegMem:Show()
        tab.totalsSegFps:Show()
        tab.totalsSegLua:Show()
        local vis = { tab.totalsSegAddons, tab.totalsSegMem, tab.totalsSegFps, tab.totalsSegLua }
        if hasCPU then
            tab.totalsSegCpu.fs:SetText((L["MON_TOTALS_CPU"]) .. " " .. Monitor:FormatCPU(cpuTotalPerSec) .. " " .. (L["MON_TOTALS_CPU_UNIT"]))
            tab.totalsSegCpu:Show()
            vis[#vis + 1] = tab.totalsSegCpu
        else
            tab.totalsSegCpu:Hide()
        end
        if preset == MP.MEMORY_DIG then
            tab.totalsSegDmem.fs:SetText((L["MON_TOTALS_MEM_DELTA_SUM"]) .. " " .. Monitor:FormatMemoryDelta(t.sumMemDelta or 0) .. " " .. (L["MON_UNIT_K"]))
            tab.totalsSegDmem:Show()
            vis[#vis + 1] = tab.totalsSegDmem
        else
            tab.totalsSegDmem:Hide()
        end
        LayoutTotalsSegments(totalsBar, vis, tab._totalsSegGap or 12)
    end

    local function DoUpdate()
        if Monitor then
            Monitor:GatherUsage()
            Monitor:RefreshDisplayedList()
        end
    end

    playBtn:SetScript("OnClick", function()
        if not Monitor then return end
        Monitor:ToggleMonitoring()
        if Monitor:IsMonitoring() then
            playBtn.text:SetText(L["MON_BTN_PAUSE"])
            DoUpdate()
        else
            playBtn.text:SetText(L["MON_BTN_PLAY"])
        end
    end)

    updateBtn:SetScript("OnClick", function()
        DoUpdate()
    end)

    resetBtn:SetScript("OnClick", function()
        if Monitor then
            Monitor:Reset()
            DoUpdate()
            Addon:Print(L["MON_MSG_RESET"])
        end
    end)

    cpuCheck:SetScript("OnClick", function()
        if Monitor then
            StaticPopupDialogs["ONEWOW_DEVTOOL_CPU_RELOAD"] = {
                text = L["MON_CPU_RELOAD_CONFIRM"],
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
        Addon.db.global.monitor.showOnLoad = self:GetChecked() and true or false
    end)

    tab:SetScript("OnUpdate", function(self, elapsed)
        if Monitor then
            Monitor:OnUpdate(elapsed)
        end
    end)

    function tab:Teardown()
        self:SetScript("OnUpdate", nil)
        if Monitor then
            Monitor:StopMonitoring()
            Monitor:CloseAllPinnedPopouts()
        end
        if Addon.MonitorTabUI == self then
            Addon.MonitorTabUI = nil
        end
    end

    Addon.MonitorTabUI = tab
    return tab
end
