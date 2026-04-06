local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

local MonitorTab = {}
Addon.MonitorTab = MonitorTab

local addonInfo = {}
local displayedList = {}
local totals = { memory = 0, cpu = 0, count = 0, startTime = 0, duration = 0, sumMemDelta = 0, luaHeapKb = 0 }
local profilingCPU = false
local updateTimer = 0
local updateFrequency = 1.0
local monitoring = false
local filterText = ""

local prevAddonMemory = {}
local prevAddonCpu = {}
local memoryPeakByIndex = {}
local lastGatherTime = 0

local function ProfilerNamespaceAvailable()
    return C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric and Enum and Enum.AddOnProfilerMetric
end

function MonitorTab:ProfilerEnabled()
    if not ProfilerNamespaceAvailable() then return false end
    local ok, enabled = pcall(function()
        return C_AddOnProfiler.IsEnabled()
    end)
    return ok and enabled == true
end

local function safeGetAddOnMetric(addonName, metric)
    local ok, v = pcall(C_AddOnProfiler.GetAddOnMetric, addonName, metric)
    if ok and type(v) == "number" then return v end
    return 0
end

local function gatherAddOnProfilerFields(addonName)
    local E = Enum.AddOnProfilerMetric
    local o1 = safeGetAddOnMetric(addonName, E.CountTimeOver1Ms)
    local o5 = safeGetAddOnMetric(addonName, E.CountTimeOver5Ms)
    local o10 = safeGetAddOnMetric(addonName, E.CountTimeOver10Ms)
    local o50 = safeGetAddOnMetric(addonName, E.CountTimeOver50Ms)
    local o100 = safeGetAddOnMetric(addonName, E.CountTimeOver100Ms)
    local weights = (Addon.Constants and Addon.Constants.MONITOR_AP_SPIKE_WEIGHTS) or { 1, 5, 10, 50, 100 }
    local spikeScore = (weights[1] or 0) * o1 + (weights[2] or 0) * o5 + (weights[3] or 0) * o10
        + (weights[4] or 0) * o50 + (weights[5] or 0) * o100
    return {
        apSessionAvgMs = safeGetAddOnMetric(addonName, E.SessionAverageTime),
        apRecentAvgMs = safeGetAddOnMetric(addonName, E.RecentAverageTime),
        apPeakMs = safeGetAddOnMetric(addonName, E.PeakTime),
        apOver1 = o1,
        apOver5 = o5,
        apOver10 = o10,
        apOver50 = o50,
        apOver100 = o100,
        apOver500 = safeGetAddOnMetric(addonName, E.CountTimeOver500Ms),
        apOver1000 = safeGetAddOnMetric(addonName, E.CountTimeOver1000Ms),
        apSpikeScore = spikeScore,
    }
end

function MonitorTab:GetProfilerMetricsForAddon(addonName)
    if not self:ProfilerEnabled() then return nil end
    return gatherAddOnProfilerFields(addonName)
end

local function StripColorCodes(text)
    if not text then return "" end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|T.-|t", "")
    return text:trim()
end

local function FormatNumber(number, decimals)
    if not number then return "0" end
    decimals = decimals or 1
    local formatted = string.format("%." .. decimals .. "f", number)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

function MonitorTab:RegisterPinnedRestoreEvents()
    if self._pinnedRestoreFrame then return end
    local f = CreateFrame("Frame")
    self._pinnedRestoreFrame = f
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function()
        MonitorTab:RestorePinnedMonitorsPending()
    end)
end

function MonitorTab:Initialize()
    profilingCPU = GetCVar("scriptProfile") == "1"
    totals.startTime = GetTime()
    totals.duration = 0
    self:RegisterPinnedRestoreEvents()
end

function MonitorTab:GatherUsage()
    local numAddons = C_AddOns.GetNumAddOns()
    local now = GetTime()
    local wallDelta = (lastGatherTime > 0) and (now - lastGatherTime) or 0
    lastGatherTime = now

    addonInfo = {}
    totals.memory = 0
    totals.cpu = 0
    totals.count = 0
    totals.sumMemDelta = 0
    totals.duration = now - totals.startTime
    totals.luaHeapKb = collectgarbage("count")

    UpdateAddOnMemoryUsage()
    if profilingCPU then
        UpdateAddOnCPUUsage()
    end

    local profEnabled = self:ProfilerEnabled()

    for i = 1, numAddons do
        local loaded = C_AddOns.IsAddOnLoaded(i)
        if loaded then
            local name, title = C_AddOns.GetAddOnInfo(i)
            local displayTitle = StripColorCodes(title or name)

            local mem = 0
            local ok, result = pcall(GetAddOnMemoryUsage, i)
            if ok then mem = result or 0 end

            local prevMem = prevAddonMemory[i]
            local memDelta = (prevMem ~= nil) and (mem - prevMem) or 0
            totals.sumMemDelta = totals.sumMemDelta + memDelta

            local peak = memoryPeakByIndex[i]
            if not peak or mem > peak then
                peak = mem
                memoryPeakByIndex[i] = mem
            end

            local cpu = 0
            if profilingCPU then
                local cpuOk, cpuResult = pcall(GetAddOnCPUUsage, i)
                if cpuOk then cpu = cpuResult or 0 end
            end

            local prevCpu = prevAddonCpu[i]
            local cpuPerSec = 0
            local cpuPerSecRecent = 0
            if profilingCPU then
                if totals.duration > 0 then
                    cpuPerSec = cpu / totals.duration
                end
                if wallDelta > 0 and prevCpu ~= nil then
                    cpuPerSecRecent = (cpu - prevCpu) / wallDelta
                end
            end

            local row = {
                index = i,
                name = name,
                title = displayTitle,
                memory = mem,
                memoryDelta = memDelta,
                memoryPeak = peak,
                cpu = cpu,
                cpuPerSec = cpuPerSec,
                cpuPerSecRecent = cpuPerSecRecent,
            }
            if profEnabled then
                local ap = gatherAddOnProfilerFields(name)
                row.apSessionAvgMs = ap.apSessionAvgMs
                row.apRecentAvgMs = ap.apRecentAvgMs
                row.apPeakMs = ap.apPeakMs
                row.apOver1 = ap.apOver1
                row.apOver5 = ap.apOver5
                row.apOver10 = ap.apOver10
                row.apOver50 = ap.apOver50
                row.apOver100 = ap.apOver100
                row.apOver500 = ap.apOver500
                row.apOver1000 = ap.apOver1000
                row.apSpikeScore = ap.apSpikeScore
            else
                row.apSessionAvgMs = 0
                row.apRecentAvgMs = 0
                row.apPeakMs = 0
                row.apOver1 = 0
                row.apOver5 = 0
                row.apOver10 = 0
                row.apOver50 = 0
                row.apOver100 = 0
                row.apOver500 = 0
                row.apOver1000 = 0
                row.apSpikeScore = 0
            end
            tinsert(addonInfo, row)

            totals.memory = totals.memory + mem
            totals.cpu = totals.cpu + cpu
            totals.count = totals.count + 1

            prevAddonMemory[i] = mem
            if profilingCPU then
                prevAddonCpu[i] = cpu
            end
        end
    end

    for _, info in ipairs(addonInfo) do
        info.memPercent = totals.memory > 0 and (info.memory / totals.memory * 100) or 0
        info.cpuPercent = totals.cpu > 0 and (info.cpu / totals.cpu * 100) or 0
    end
end

function MonitorTab:GetSortedList()
    local sortOrder = Addon.db.global.monitor.sortOrder
    local absOrder = math.abs(sortOrder)
    local ascending = sortOrder > 0

    displayedList = {}
    local lowerFilter = filterText:lower()

    for _, info in ipairs(addonInfo) do
        local matchesFilter = lowerFilter == "" or info.title:lower():find(lowerFilter, 1, true) or info.name:lower():find(lowerFilter, 1, true)
        if matchesFilter then
            tinsert(displayedList, info)
        end
    end

    sort(displayedList, function(a, b)
        local valA, valB
        if absOrder == 1 then
            valA, valB = a.title:lower(), b.title:lower()
        elseif absOrder == 2 then
            valA, valB = a.memory, b.memory
        elseif absOrder == 3 then
            valA, valB = a.cpuPerSec, b.cpuPerSec
        elseif absOrder == 4 then
            valA, valB = a.memoryDelta, b.memoryDelta
        elseif absOrder == 5 then
            valA, valB = a.memoryPeak, b.memoryPeak
        elseif absOrder == 6 then
            valA, valB = a.cpuPerSecRecent, b.cpuPerSecRecent
        elseif absOrder == 7 then
            valA, valB = a.cpu, b.cpu
        elseif absOrder == 8 then
            valA, valB = a.memPercent, b.memPercent
        elseif absOrder == 9 then
            valA, valB = a.cpuPercent, b.cpuPercent
        elseif absOrder == 10 then
            valA, valB = a.apSessionAvgMs or 0, b.apSessionAvgMs or 0
        elseif absOrder == 11 then
            valA, valB = a.apRecentAvgMs or 0, b.apRecentAvgMs or 0
        elseif absOrder == 12 then
            valA, valB = a.apPeakMs or 0, b.apPeakMs or 0
        elseif absOrder == 13 then
            valA, valB = a.apOver1 or 0, b.apOver1 or 0
        elseif absOrder == 14 then
            valA, valB = a.apOver5 or 0, b.apOver5 or 0
        elseif absOrder == 15 then
            valA, valB = a.apOver10 or 0, b.apOver10 or 0
        elseif absOrder == 16 then
            valA, valB = a.apOver50 or 0, b.apOver50 or 0
        elseif absOrder == 17 then
            valA, valB = a.apOver100 or 0, b.apOver100 or 0
        elseif absOrder == 18 then
            valA, valB = a.apOver500 or 0, b.apOver500 or 0
        elseif absOrder == 19 then
            valA, valB = a.apOver1000 or 0, b.apOver1000 or 0
        elseif absOrder == 20 then
            valA, valB = a.apSpikeScore or 0, b.apSpikeScore or 0
        else
            valA, valB = a.memory, b.memory
        end
        if ascending then
            return valA < valB
        else
            return valA > valB
        end
    end)

    return displayedList
end

function MonitorTab:RefreshDisplayedList()
    self:GetSortedList()
    self:UpdateUI()
end

function MonitorTab:SetFilter(text)
    filterText = text or ""
end

function MonitorTab:GetFilter()
    return filterText
end

function MonitorTab:ToggleSort(column)
    local db = Addon.db.global.monitor

    local current = db.sortOrder
    local absOrder = math.abs(current)

    if absOrder == column then
        db.sortOrder = -current
    else
        db.sortOrder = -column
    end
end

function MonitorTab:Reset()
    collectgarbage()
    UpdateAddOnMemoryUsage()
    if profilingCPU and ResetCPUUsage then
        ResetCPUUsage()
    end
    totals.startTime = GetTime()
    totals.duration = 0
    wipe(prevAddonMemory)
    wipe(prevAddonCpu)
    wipe(memoryPeakByIndex)
    lastGatherTime = 0
end

function MonitorTab:IsMonitoring()
    return monitoring
end

function MonitorTab:StartMonitoring()
    monitoring = true
end

function MonitorTab:StopMonitoring()
    monitoring = false
end

function MonitorTab:ToggleMonitoring()
    monitoring = not monitoring
end

function MonitorTab:OnUpdate(elapsed)
    if not monitoring then return end
    updateTimer = updateTimer + elapsed
    if updateTimer >= updateFrequency then
        updateTimer = 0
        self:GatherUsage()
        self:RefreshDisplayedList()
    end
end

function MonitorTab:IsCPUProfilingEnabled()
    return profilingCPU
end

function MonitorTab:ToggleCPUProfiling()
    if profilingCPU then
        SetCVar("scriptProfile", "0")
        Addon:Print(Addon.L["MON_MSG_CPU_DISABLED"])
    else
        SetCVar("scriptProfile", "1")
        Addon:Print(Addon.L["MON_MSG_CPU_ENABLED"])
    end
    ReloadUI()
end

function MonitorTab:GetTotals()
    return totals
end

function MonitorTab:GetDisplayedList()
    return displayedList
end

function MonitorTab:FormatMemory(value)
    return FormatNumber(value, 1)
end

function MonitorTab:FormatCPU(value)
    return FormatNumber(value, 2)
end

function MonitorTab:FormatPercent(value)
    return FormatNumber(value, 1) .. "%"
end

function MonitorTab:FormatMemoryDelta(value)
    if not value or value == 0 then
        return "0"
    end
    local sign = value > 0 and "+" or "-"
    return sign .. FormatNumber(math.abs(value), 1)
end

function MonitorTab:FormatCPUMs(value)
    return FormatNumber(value or 0, 0)
end

function MonitorTab:FormatAPMs(value)
    return FormatNumber(value or 0, 2)
end

function MonitorTab:FormatAPCount(value)
    return FormatNumber(value or 0, 0)
end

function MonitorTab:GetViewPreset()
    local C = Addon.Constants and Addon.Constants.MONITOR_PRESET
    local defaultId = C and C.BALANCED or "balanced"
    local db = Addon.db.global.monitor
    local id = db.viewPreset or defaultId
    if not C then return id end
    if id ~= C.BALANCED and id ~= C.MEMORY_DIG and id ~= C.CPU_SPIKES and id ~= C.MINIMAL and id ~= C.ENGINE_PROFILER then
        return defaultId
    end
    return id
end

function MonitorTab:SetViewPreset(presetId)
    local db = Addon.db.global.monitor
    local Const = Addon.Constants
    local C = Const and Const.MONITOR_PRESET
    local DS = Const and Const.MONITOR_PRESET_DEFAULT_SORT
    if not C then return end
    if presetId ~= C.BALANCED and presetId ~= C.MEMORY_DIG and presetId ~= C.CPU_SPIKES and presetId ~= C.MINIMAL and presetId ~= C.ENGINE_PROFILER then
        return
    end
    db.viewPreset = presetId
    if not DS then
        DS = { balanced = -2, memory_dig = -4, cpu_spikes = -6, minimal = -2, engine_profiler = -20 }
    end
    local so = DS[presetId]
    if presetId == C.CPU_SPIKES then
        if GetCVar("scriptProfile") ~= "1" then
            so = -(Const.MONITOR_SORT_AP_SPIKE or 20)
        end
    end
    if so then
        db.sortOrder = so
    end
end

function MonitorTab:UpdateUI()
    local tab = Addon.MonitorTabUI
    if not tab then return end
    tab:RefreshList()
end

local pinnedSlots = {}
local pinnedMasterTicker = nil
local GROWTH_SAMPLE_MAX = 30

local function getMaxPinnedPopouts()
    local c = Addon.Constants and Addon.Constants.MONITOR_MAX_PINNED_POPOUTS
    return (type(c) == "number" and c > 0) and c or 4
end

local function FormatKB(value)
    if not value then return "0 k" end
    return FormatNumber(math.floor(value), 0) .. " k"
end

local function FindAddonIndexByName(name)
    local numAddons = C_AddOns.GetNumAddOns()
    for i = 1, numAddons do
        local addonName = C_AddOns.GetAddOnInfo(i)
        if addonName == name then return i end
    end
    return nil
end

local function ensurePinnedMonitorsArray(db)
    if type(db.pinnedMonitors) ~= "table" then
        db.pinnedMonitors = {}
    end
end

local function findPinnedDbEntry(monitors, addonName)
    if type(monitors) ~= "table" then return nil end
    local list = Addon.GetPinnedMonitorEntriesInOrder and Addon:GetPinnedMonitorEntriesInOrder(monitors) or {}
    for _, e in ipairs(list) do
        if e.addon == addonName then
            return e
        end
    end
    return nil
end

local function removePinnedDbEntryByAddon(db, addonName)
    local arr = db.pinnedMonitors
    if type(arr) ~= "table" then return end
    local list = Addon.GetPinnedMonitorEntriesInOrder and Addon:GetPinnedMonitorEntriesInOrder(arr) or {}
    local newArr = {}
    for _, e in ipairs(list) do
        if e.addon ~= addonName then tinsert(newArr, e) end
    end
    db.pinnedMonitors = newArr
end

local function findPinnedSlotByAddon(addonName)
    for i = 1, #pinnedSlots do
        local s = pinnedSlots[i]
        if s.addonName == addonName then
            return s, i
        end
    end
    return nil, nil
end

local function cancelPinnedMasterTickerIfEmpty()
    if #pinnedSlots == 0 and pinnedMasterTicker then
        pinnedMasterTicker:Cancel()
        pinnedMasterTicker = nil
    end
end

local function ensurePinnedMasterTicker()
    if #pinnedSlots == 0 then return end
    if pinnedMasterTicker then return end
    pinnedMasterTicker = C_Timer.NewTicker(1.0, function()
        for i = 1, #pinnedSlots do
            MonitorTab:UpdatePinnedSlot(pinnedSlots[i])
        end
    end)
end

local function CreateRow(parent, labelText, yOffset, guiLib)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, yOffset)
    label:SetText(labelText)
    label:SetTextColor(guiLib:GetThemeColor("TEXT_MUTED"))
    label:SetWidth(118)
    label:SetJustifyH("LEFT")

    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    value:SetPoint("LEFT", label, "RIGHT", 4, 0)
    value:SetText("--")
    value:SetTextColor(guiLib:GetThemeColor("TEXT_PRIMARY"))
    value:SetWidth(150)
    value:SetJustifyH("LEFT")

    return label, value, yOffset - 18
end

function MonitorTab:CreatePinnedPopupFrame(slot, addonTitle)
    local addonName = slot.addonName
    local addonIndex = slot.addonIndex
    local dbEntry = slot.dbEntry
    local useCPU = GetCVar("scriptProfile") == "1"

    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetSize(280, 280)
    popup:SetFrameStrata("HIGH")
    popup:SetToplevel(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetClampedToScreen(true)
        if dbEntry then
            local point, _, relPoint, x, y = self:GetPoint(1)
            dbEntry.position = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    popup:SetClampedToScreen(true)

    popup:SetBackdrop(BACKDROP_SIMPLE)
    popup:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    popup:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local titleBar = CreateFrame("Frame", nil, popup, "BackdropTemplate")
    titleBar:SetHeight(22)
    titleBar:SetPoint("TOPLEFT", popup, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, -1)
    titleBar:SetBackdrop(BACKDROP_SIMPLE)
    titleBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    titleBar:SetBackdropBorderColor(0, 0, 0, 0)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 6, 0)
    titleText:SetText(addonTitle or addonName)
    titleText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeBtn:SetScript("OnClick", function()
        MonitorTab:ClosePinnedPopupByAddon(addonName)
    end)

    local LL = Addon.L or {}
    local yPos = -30
    local memLabel, memValue
    memLabel, memValue, yPos = CreateRow(popup, LL["MON_PIN_MEMORY"], yPos, OneWoW_GUI)
    local memTickLabel, memTickValue
    memTickLabel, memTickValue, yPos = CreateRow(popup, LL["MON_PIN_MEM_TICK"], yPos, OneWoW_GUI)
    local deltaLabel, deltaValue
    deltaLabel, deltaValue, yPos = CreateRow(popup, LL["MON_PIN_DELTA_OPEN"], yPos, OneWoW_GUI)
    local rateLabel, rateValue
    rateLabel, rateValue, yPos = CreateRow(popup, LL["MON_PIN_RATE"], yPos, OneWoW_GUI)
    local peakLabel, peakValue
    peakLabel, peakValue, yPos = CreateRow(popup, LL["MON_PIN_PEAK"], yPos, OneWoW_GUI)
    local minLabel, minValue
    minLabel, minValue, yPos = CreateRow(popup, LL["MON_PIN_MIN"], yPos, OneWoW_GUI)
    local pctLabel, pctValue
    pctLabel, pctValue, yPos = CreateRow(popup, LL["MON_PIN_PCT_MEM"], yPos, OneWoW_GUI)

    local cpuMsValue, cpuSessionValue, cpuRecentValue, cpuPctValue
    if useCPU then
        yPos = yPos - 4
        local memCpuDiv = popup:CreateTexture(nil, "ARTWORK")
        memCpuDiv:SetHeight(1)
        memCpuDiv:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, yPos)
        memCpuDiv:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -12, yPos)
        local dr, dg, db, da = OneWoW_GUI:GetThemeColor("BORDER_DEFAULT")
        memCpuDiv:SetColorTexture(dr, dg, db, (da or 1) * 0.4)
        yPos = yPos - 6
        local cpuMsLabel, cpuSessionLabel, cpuRecentLabel, cpuPctLabel
        cpuMsLabel, cpuMsValue, yPos = CreateRow(popup, LL["MON_PIN_CPU_MS"], yPos, OneWoW_GUI)
        cpuSessionLabel, cpuSessionValue, yPos = CreateRow(popup, LL["MON_PIN_CPU_SESSION"], yPos, OneWoW_GUI)
        cpuRecentLabel, cpuRecentValue, yPos = CreateRow(popup, LL["MON_PIN_CPU_RECENT"], yPos, OneWoW_GUI)
        cpuPctLabel, cpuPctValue, yPos = CreateRow(popup, LL["MON_PIN_PCT_CPU"], yPos, OneWoW_GUI)
    end

    yPos = yPos - 4
    local apDiv = popup:CreateTexture(nil, "ARTWORK")
    apDiv:SetHeight(1)
    apDiv:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, yPos)
    apDiv:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -12, yPos)
    local adr, adg, adb, ada = OneWoW_GUI:GetThemeColor("BORDER_DEFAULT")
    apDiv:SetColorTexture(adr, adg, adb, (ada or 1) * 0.4)
    yPos = yPos - 6
    local apPeakLabel, apPeakValue
    apPeakLabel, apPeakValue, yPos = CreateRow(popup, LL["MON_PIN_AP_PEAK"], yPos, OneWoW_GUI)
    local apSessionLabel, apSessionValue
    apSessionLabel, apSessionValue, yPos = CreateRow(popup, LL["MON_PIN_AP_SESSION"], yPos, OneWoW_GUI)
    local apOver50Label, apOver50Value
    apOver50Label, apOver50Value, yPos = CreateRow(popup, LL["MON_PIN_AP_OVER50"], yPos, OneWoW_GUI)
    local apSpikeLabel, apSpikeValue
    apSpikeLabel, apSpikeValue, yPos = CreateRow(popup, LL["MON_PIN_AP_SPIKE"], yPos, OneWoW_GUI)

    local elapsedLabel, elapsedValue
    elapsedLabel, elapsedValue, yPos = CreateRow(popup, LL["MON_PIN_ELAPSED"], yPos, OneWoW_GUI)
    local samplesLabel, samplesValue
    samplesLabel, samplesValue, yPos = CreateRow(popup, LL["MON_PIN_SAMPLES"], yPos, OneWoW_GUI)

    yPos = yPos - 10
    local reopenCheck = CreateFrame("CheckButton", nil, popup, "UICheckButtonTemplate")
    reopenCheck:SetSize(20, 20)
    reopenCheck:SetPoint("TOPLEFT", popup, "TOPLEFT", 6, yPos)
    local reopenLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reopenLabel:SetPoint("LEFT", reopenCheck, "RIGHT", 2, 0)
    reopenLabel:SetText(LL["MON_PIN_REOPEN"])
    reopenLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local totalHeight = math.abs(yPos) + 32
    popup:SetHeight(totalHeight)

    reopenCheck:SetChecked(dbEntry.reopenOnReload and true or false)
    reopenCheck:SetScript("OnClick", function(self)
        dbEntry.reopenOnReload = self:GetChecked() and true or false
    end)

    popup.memValue = memValue
    popup.memTickValue = memTickValue
    popup.deltaValue = deltaValue
    popup.rateValue = rateValue
    popup.peakValue = peakValue
    popup.minValue = minValue
    popup.pctValue = pctValue
    popup.elapsedValue = elapsedValue
    popup.samplesValue = samplesValue
    popup.addonIndex = addonIndex
    popup.cpuMsValue = cpuMsValue
    popup.cpuSessionValue = cpuSessionValue
    popup.cpuRecentValue = cpuRecentValue
    popup.cpuPctValue = cpuPctValue
    popup.apDiv = apDiv
    popup.apPeakValue = apPeakValue
    popup.apSessionValue = apSessionValue
    popup.apOver50Value = apOver50Value
    popup.apSpikeValue = apSpikeValue

    popup:SetSize(230, totalHeight)

    local savedPos = dbEntry.position
    if type(savedPos) == "table" and savedPos.point then
        popup:ClearAllPoints()
        popup:SetPoint(savedPos.point, UIParent, savedPos.relPoint, savedPos.x, savedPos.y)
    else
        popup:SetPoint("CENTER")
    end

    popup:Show()
    slot.popup = popup
end

function MonitorTab:CreatePinnedPopup(addonName, addonTitle, existingDbEntry)
    local maxPins = getMaxPinnedPopouts()
    local existingSlot = findPinnedSlotByAddon(addonName)
    if existingSlot and existingSlot.popup then
        existingSlot.popup:Show()
        pcall(function()
            if existingSlot.popup.Raise then
                existingSlot.popup:Raise()
            end
        end)
        return
    end

    if #pinnedSlots >= maxPins then
        local L = Addon.L
        local msg = L and L["MON_MSG_PIN_MAX"]
        Addon:Print(msg and string.format(msg, maxPins) or ("You can pin up to " .. tostring(maxPins) .. " addon monitors at once."))
        return
    end

    local addonIndex = FindAddonIndexByName(addonName)
    if not addonIndex then return end

    local db = Addon.db.global.monitor
    ensurePinnedMonitorsArray(db)

    local dbEntry
    if existingDbEntry then
        if existingDbEntry.addon ~= addonName then return end
        dbEntry = existingDbEntry
    else
        dbEntry = findPinnedDbEntry(db.pinnedMonitors, addonName)
        if not dbEntry then
            dbEntry = { addon = addonName, reopenOnReload = false, position = {} }
            tinsert(db.pinnedMonitors, dbEntry)
        end
    end

    if type(dbEntry.position) ~= "table" then
        dbEntry.position = {}
    end

    UpdateAddOnMemoryUsage()
    local ok, mem = pcall(GetAddOnMemoryUsage, addonIndex)
    mem = (ok and mem) or 0

    local slot = {
        addonName = addonName,
        addonIndex = addonIndex,
        dbEntry = dbEntry,
        baselineMemory = mem,
        peakMemory = mem,
        minMemory = mem,
        startTime = GetTime(),
        sampleCount = 0,
        lastMemory = mem,
        growthSamples = {},
        prevCpu = nil,
        lastCpuWallTime = 0,
        popup = nil,
    }

    self:CreatePinnedPopupFrame(slot, addonTitle)
    tinsert(pinnedSlots, slot)
    ensurePinnedMasterTicker()
    self:UpdatePinnedSlot(slot)
end

function MonitorTab:UpdatePinnedSlot(slot)
    local popup = slot.popup
    if not popup or not popup:IsShown() then return end

    local addonIndex = slot.addonIndex
    if not addonIndex then return end

    local profilingNow = GetCVar("scriptProfile") == "1"

    UpdateAddOnMemoryUsage()
    local ok, mem = pcall(GetAddOnMemoryUsage, addonIndex)
    if not ok then return end
    mem = mem or 0

    local tickMemDelta = mem - slot.lastMemory
    slot.sampleCount = slot.sampleCount + 1

    if mem > slot.peakMemory then slot.peakMemory = mem end
    if mem < slot.minMemory then slot.minMemory = mem end

    slot.lastMemory = mem
    tinsert(slot.growthSamples, tickMemDelta)
    if #slot.growthSamples > GROWTH_SAMPLE_MAX then
        tremove(slot.growthSamples, 1)
    end

    local totalMem = 0
    local numAddons = C_AddOns.GetNumAddOns()
    for i = 1, numAddons do
        if C_AddOns.IsAddOnLoaded(i) then
            local mok, m = pcall(GetAddOnMemoryUsage, i)
            if mok and m then totalMem = totalMem + m end
        end
    end

    popup.memValue:SetText(FormatKB(mem))

    popup.memTickValue:SetText(self:FormatMemoryDelta(tickMemDelta))
    do
        local r, g, b = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
        if tickMemDelta > 10 then
            r, g, b = 1, 0.4, 0.4
        elseif tickMemDelta > 2 then
            r, g, b = 1, 0.8, 0.2
        elseif tickMemDelta < -2 then
            r, g, b = 0.4, 1, 0.4
        end
        popup.memTickValue:SetTextColor(r, g, b, 1)
    end

    local delta = mem - slot.baselineMemory
    local deltaStr = FormatKB(math.abs(delta))
    if delta >= 0 then
        deltaStr = "+" .. deltaStr
        if delta > 100 then
            popup.deltaValue:SetTextColor(1, 0.4, 0.4, 1)
        elseif delta > 50 then
            popup.deltaValue:SetTextColor(1, 0.8, 0.2, 1)
        else
            popup.deltaValue:SetTextColor(0.4, 1, 0.4, 1)
        end
    else
        deltaStr = "-" .. deltaStr
        popup.deltaValue:SetTextColor(0.4, 1, 0.4, 1)
    end
    popup.deltaValue:SetText(deltaStr)

    local avgRate = 0
    if #slot.growthSamples > 0 then
        local sum = 0
        for _, v in ipairs(slot.growthSamples) do sum = sum + v end
        avgRate = sum / #slot.growthSamples
    end
    local rateStr = FormatNumber(math.abs(avgRate), 1) .. " k/s"
    if avgRate >= 0 then
        rateStr = "+" .. rateStr
    else
        rateStr = "-" .. rateStr
    end
    if avgRate > 5 then
        popup.rateValue:SetTextColor(1, 0.4, 0.4, 1)
    elseif avgRate > 1 then
        popup.rateValue:SetTextColor(1, 0.8, 0.2, 1)
    else
        popup.rateValue:SetTextColor(0.4, 1, 0.4, 1)
    end
    popup.rateValue:SetText(rateStr)

    popup.peakValue:SetText(FormatKB(slot.peakMemory))
    popup.minValue:SetText(FormatKB(slot.minMemory))

    local pct = totalMem > 0 and (mem / totalMem * 100) or 0
    popup.pctValue:SetText(FormatNumber(pct, 1) .. "%")

    if profilingNow and popup.cpuMsValue then
        UpdateAddOnCPUUsage()
        local cpuOk, cpuVal = pcall(GetAddOnCPUUsage, addonIndex)
        cpuVal = (cpuOk and cpuVal) or 0
        local totalCpu = 0
        for i = 1, numAddons do
            if C_AddOns.IsAddOnLoaded(i) then
                local cok, c = pcall(GetAddOnCPUUsage, i)
                if cok and c then totalCpu = totalCpu + c end
            end
        end
        local sessDur = GetTime() - totals.startTime
        local cpuSess = sessDur > 0 and (cpuVal / sessDur) or 0
        local nowT = GetTime()
        local wall = (slot.lastCpuWallTime > 0) and (nowT - slot.lastCpuWallTime) or 0
        local cpuRec = 0
        if wall > 0 and slot.prevCpu ~= nil then
            cpuRec = (cpuVal - slot.prevCpu) / wall
        end
        popup.cpuMsValue:SetText(self:FormatCPUMs(cpuVal))
        popup.cpuSessionValue:SetText(self:FormatCPU(cpuSess))
        popup.cpuRecentValue:SetText(self:FormatCPU(cpuRec))
        popup.cpuPctValue:SetText(FormatNumber(totalCpu > 0 and (cpuVal / totalCpu * 100) or 0, 1) .. "%")
        slot.prevCpu = cpuVal
        slot.lastCpuWallTime = nowT
    end

    do
        local apm = self:GetProfilerMetricsForAddon(slot.addonName)
        if apm then
            popup.apPeakValue:SetText(self:FormatAPMs(apm.apPeakMs))
            popup.apSessionValue:SetText(self:FormatAPMs(apm.apSessionAvgMs))
            popup.apOver50Value:SetText(self:FormatAPCount(apm.apOver50))
            popup.apSpikeValue:SetText(self:FormatAPCount(apm.apSpikeScore))
        else
            popup.apPeakValue:SetText("--")
            popup.apSessionValue:SetText("--")
            popup.apOver50Value:SetText("--")
            popup.apSpikeValue:SetText("--")
        end
    end

    local elapsed = GetTime() - slot.startTime
    local mins = math.floor(elapsed / 60)
    local secs = math.floor(elapsed % 60)
    popup.elapsedValue:SetText(string.format("%dm %02ds", mins, secs))

    popup.samplesValue:SetText(tostring(slot.sampleCount))
end

function MonitorTab:ClosePinnedPopupByAddon(addonName)
    local _, idx = findPinnedSlotByAddon(addonName)
    if not idx then return end

    local slot = pinnedSlots[idx]
    tremove(pinnedSlots, idx)

    local db = Addon.db.global.monitor
    if slot.dbEntry and not slot.dbEntry.reopenOnReload then
        removePinnedDbEntryByAddon(db, addonName)
    end

    if slot.popup then
        slot.popup:Hide()
        slot.popup:SetParent(nil)
        slot.popup = nil
    end

    cancelPinnedMasterTickerIfEmpty()
end

function MonitorTab:CloseAllPinnedPopouts()
    local names = {}
    for i = 1, #pinnedSlots do
        names[#names + 1] = pinnedSlots[i].addonName
    end
    for i = 1, #names do
        self:ClosePinnedPopupByAddon(names[i])
    end
end

function MonitorTab:GetPinnedPopup()
    local s = pinnedSlots[1]
    return s and s.popup or nil
end

function MonitorTab:GetPinnedAddonName()
    local s = pinnedSlots[1]
    return s and s.addonName or nil
end

function MonitorTab:RestorePinnedMonitorsPending()
    local db = Addon.db.global.monitor
    if type(db.pinnedMonitors) ~= "table" then return end
    local list = Addon.GetPinnedMonitorEntriesInOrder and Addon:GetPinnedMonitorEntriesInOrder(db.pinnedMonitors) or {}
    for _, entry in ipairs(list) do
        if entry.reopenOnReload and type(entry.addon) == "string" and entry.addon ~= "" then
            local existing = select(1, findPinnedSlotByAddon(entry.addon))
            if not (existing and existing.popup) then
                local addonIndex = FindAddonIndexByName(entry.addon)
                if addonIndex and C_AddOns.IsAddOnLoaded(addonIndex) then
                    local _, title = C_AddOns.GetAddOnInfo(addonIndex)
                    local displayTitle = StripColorCodes(title or entry.addon)
                    self:CreatePinnedPopup(entry.addon, displayTitle, entry)
                end
            end
        end
    end
end

function MonitorTab:RestorePinnedMonitors()
    self:RestorePinnedMonitorsPending()
end
