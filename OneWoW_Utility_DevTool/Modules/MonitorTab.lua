local ADDON_NAME, Addon = ...

local MonitorTab = {}
Addon.MonitorTab = MonitorTab

local addonInfo = {}
local displayedList = {}
local totals = { memory = 0, cpu = 0, count = 0, startTime = 0, duration = 0 }
local profilingCPU = false
local updateTimer = 0
local updateFrequency = 1.0
local monitoring = false
local filterText = ""

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

function MonitorTab:Initialize()
    profilingCPU = GetCVar("scriptProfile") == "1"
    totals.startTime = GetTime()
    totals.duration = 0
end

function MonitorTab:GatherUsage()
    local numAddons = C_AddOns.GetNumAddOns()

    addonInfo = {}
    totals.memory = 0
    totals.cpu = 0
    totals.count = 0
    totals.duration = GetTime() - totals.startTime

    UpdateAddOnMemoryUsage()
    if profilingCPU then
        UpdateAddOnCPUUsage()
    end

    for i = 1, numAddons do
        local loaded = C_AddOns.IsAddOnLoaded(i)
        if loaded then
            local name, title = C_AddOns.GetAddOnInfo(i)
            local displayTitle = StripColorCodes(title or name)

            local mem = 0
            local ok, result = pcall(GetAddOnMemoryUsage, i)
            if ok then mem = result or 0 end

            local cpu = 0
            if profilingCPU then
                local cpuOk, cpuResult = pcall(GetAddOnCPUUsage, i)
                if cpuOk then cpu = cpuResult or 0 end
            end

            local cpuPerSec = 0
            if profilingCPU and totals.duration > 0 then
                cpuPerSec = cpu / totals.duration
            end

            tinsert(addonInfo, {
                index = i,
                name = name,
                title = displayTitle,
                memory = mem,
                cpu = cpu,
                cpuPerSec = cpuPerSec,
            })

            totals.memory = totals.memory + mem
            totals.cpu = totals.cpu + cpu
            totals.count = totals.count + 1
        end
    end

    for _, info in ipairs(addonInfo) do
        info.memPercent = totals.memory > 0 and (info.memory / totals.memory * 100) or 0
        info.cpuPercent = totals.cpu > 0 and (info.cpu / totals.cpu * 100) or 0
    end
end

function MonitorTab:GetSortedList()
    local sortOrder = Addon.db and Addon.db.monitor and Addon.db.monitor.sortOrder or 2
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

function MonitorTab:SetFilter(text)
    filterText = text or ""
end

function MonitorTab:GetFilter()
    return filterText
end

function MonitorTab:ToggleSort(column)
    local db = Addon.db and Addon.db.monitor
    if not db then return end

    local current = db.sortOrder or 2
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
        self:UpdateUI()
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

function MonitorTab:UpdateUI()
    local tab = Addon.MonitorTabUI
    if not tab then return end
    tab:RefreshList()
end

local pinnedPopup = nil
local pinnedTicker = nil
local pinnedAddonName = nil
local pinnedBaselineMemory = 0
local pinnedPeakMemory = 0
local pinnedMinMemory = 0
local pinnedStartTime = 0
local pinnedSampleCount = 0
local pinnedLastMemory = 0
local pinnedGrowthSamples = {}
local GROWTH_SAMPLE_MAX = 30

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

local function CreateRow(parent, labelText, prevLabel, yOffset, guiLib)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", prevLabel, "BOTTOMLEFT", 0, yOffset)
    label:SetText(labelText)
    label:SetTextColor(guiLib:GetThemeColor("TEXT_MUTED"))
    label:SetWidth(90)
    label:SetJustifyH("LEFT")

    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    value:SetPoint("LEFT", label, "RIGHT", 4, 0)
    value:SetText("--")
    value:SetTextColor(guiLib:GetThemeColor("TEXT_PRIMARY"))

    return label, value
end

function MonitorTab:CreatePinnedPopup(addonName, addonTitle)
    if pinnedPopup then
        self:ClosePinnedPopup()
    end

    local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
    if not OneWoW_GUI then return end

    local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

    local addonIndex = FindAddonIndexByName(addonName)
    if not addonIndex then return end

    pinnedAddonName = addonName
    pinnedStartTime = GetTime()
    pinnedSampleCount = 0
    pinnedGrowthSamples = {}

    UpdateAddOnMemoryUsage()
    local ok, mem = pcall(GetAddOnMemoryUsage, addonIndex)
    pinnedBaselineMemory = (ok and mem) or 0
    pinnedPeakMemory = pinnedBaselineMemory
    pinnedMinMemory = pinnedBaselineMemory
    pinnedLastMemory = pinnedBaselineMemory

    local ROW_SPACING = -4
    local popup = CreateFrame("Frame", "OneWoW_DevTool_PinnedMonitor", UIParent, "BackdropTemplate")
    popup:SetSize(280, 270)
    popup:SetFrameStrata("HIGH")
    popup:SetToplevel(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetClampedToScreen(true)
        local db = Addon.db and Addon.db.monitor
        if db then
            db.pinnedPosition = db.pinnedPosition or {}
            OneWoW_GUI:SaveWindowPosition(self, db.pinnedPosition)
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
        MonitorTab:ClosePinnedPopup()
    end)

    local firstAnchor = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    firstAnchor:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 8, 0)
    firstAnchor:SetText("")
    firstAnchor:SetHeight(1)

    local memLabel, memValue = CreateRow(popup, "Memory:", firstAnchor, ROW_SPACING, OneWoW_GUI)
    local deltaLabel, deltaValue = CreateRow(popup, "Delta:", memLabel, ROW_SPACING, OneWoW_GUI)
    local rateLabel, rateValue = CreateRow(popup, "Rate:", deltaLabel, ROW_SPACING, OneWoW_GUI)
    local peakLabel, peakValue = CreateRow(popup, "Peak:", rateLabel, ROW_SPACING, OneWoW_GUI)
    local minLabel, minValue = CreateRow(popup, "Min:", peakLabel, ROW_SPACING, OneWoW_GUI)
    local pctLabel, pctValue = CreateRow(popup, "% of Total:", minLabel, ROW_SPACING, OneWoW_GUI)
    local elapsedLabel, elapsedValue = CreateRow(popup, "Elapsed:", pctLabel, ROW_SPACING, OneWoW_GUI)
    local samplesLabel, samplesValue = CreateRow(popup, "Samples:", elapsedLabel, ROW_SPACING, OneWoW_GUI)

    local reopenCheck = CreateFrame("CheckButton", nil, popup, "UICheckButtonTemplate")
    reopenCheck:SetSize(20, 20)
    reopenCheck:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 6, 4)
    local reopenLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reopenLabel:SetPoint("LEFT", reopenCheck, "RIGHT", 2, 0)
    reopenLabel:SetText("Reopen on /reload")
    reopenLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local db = Addon.db and Addon.db.monitor
    reopenCheck:SetChecked(db and db.pinnedReopenOnReload or false)
    reopenCheck:SetScript("OnClick", function(self)
        if Addon.db and Addon.db.monitor then
            Addon.db.monitor.pinnedReopenOnReload = self:GetChecked() and true or false
        end
    end)

    popup.memValue = memValue
    popup.deltaValue = deltaValue
    popup.rateValue = rateValue
    popup.peakValue = peakValue
    popup.minValue = minValue
    popup.pctValue = pctValue
    popup.elapsedValue = elapsedValue
    popup.samplesValue = samplesValue
    popup.addonIndex = addonIndex

    local savedPos = db and db.pinnedPosition
    if savedPos and savedPos.point then
        if not OneWoW_GUI:RestoreWindowPosition(popup, savedPos) then
            popup:SetPoint("CENTER")
        end
    else
        popup:SetPoint("CENTER")
    end

    popup:Show()
    pinnedPopup = popup

    if db then
        db.pinnedAddon = addonName
    end

    pinnedTicker = C_Timer.NewTicker(1.0, function()
        MonitorTab:UpdatePinnedPopup()
    end)
end

function MonitorTab:UpdatePinnedPopup()
    if not pinnedPopup or not pinnedPopup:IsShown() then return end

    local addonIndex = pinnedPopup.addonIndex
    if not addonIndex then return end

    UpdateAddOnMemoryUsage()
    local ok, mem = pcall(GetAddOnMemoryUsage, addonIndex)
    if not ok then return end
    mem = mem or 0

    pinnedSampleCount = pinnedSampleCount + 1

    if mem > pinnedPeakMemory then pinnedPeakMemory = mem end
    if mem < pinnedMinMemory then pinnedMinMemory = mem end

    local perSecondDelta = mem - pinnedLastMemory
    pinnedLastMemory = mem
    tinsert(pinnedGrowthSamples, perSecondDelta)
    if #pinnedGrowthSamples > GROWTH_SAMPLE_MAX then
        tremove(pinnedGrowthSamples, 1)
    end

    local totalMem = 0
    local numAddons = C_AddOns.GetNumAddOns()
    for i = 1, numAddons do
        if C_AddOns.IsAddOnLoaded(i) then
            local mok, m = pcall(GetAddOnMemoryUsage, i)
            if mok and m then totalMem = totalMem + m end
        end
    end

    pinnedPopup.memValue:SetText(FormatKB(mem))

    local delta = mem - pinnedBaselineMemory
    local deltaStr = FormatKB(math.abs(delta))
    if delta >= 0 then
        deltaStr = "+" .. deltaStr
        if delta > 100 then
            pinnedPopup.deltaValue:SetTextColor(1, 0.4, 0.4, 1)
        elseif delta > 50 then
            pinnedPopup.deltaValue:SetTextColor(1, 0.8, 0.2, 1)
        else
            pinnedPopup.deltaValue:SetTextColor(0.4, 1, 0.4, 1)
        end
    else
        deltaStr = "-" .. deltaStr
        pinnedPopup.deltaValue:SetTextColor(0.4, 1, 0.4, 1)
    end
    pinnedPopup.deltaValue:SetText(deltaStr)

    local avgRate = 0
    if #pinnedGrowthSamples > 0 then
        local sum = 0
        for _, v in ipairs(pinnedGrowthSamples) do sum = sum + v end
        avgRate = sum / #pinnedGrowthSamples
    end
    local rateStr = FormatNumber(math.abs(avgRate), 1) .. " k/s"
    if avgRate >= 0 then
        rateStr = "+" .. rateStr
    else
        rateStr = "-" .. rateStr
    end
    if avgRate > 5 then
        pinnedPopup.rateValue:SetTextColor(1, 0.4, 0.4, 1)
    elseif avgRate > 1 then
        pinnedPopup.rateValue:SetTextColor(1, 0.8, 0.2, 1)
    else
        pinnedPopup.rateValue:SetTextColor(0.4, 1, 0.4, 1)
    end
    pinnedPopup.rateValue:SetText(rateStr)

    pinnedPopup.peakValue:SetText(FormatKB(pinnedPeakMemory))
    pinnedPopup.minValue:SetText(FormatKB(pinnedMinMemory))

    local pct = totalMem > 0 and (mem / totalMem * 100) or 0
    pinnedPopup.pctValue:SetText(FormatNumber(pct, 1) .. "%")

    local elapsed = GetTime() - pinnedStartTime
    local mins = math.floor(elapsed / 60)
    local secs = math.floor(elapsed % 60)
    pinnedPopup.elapsedValue:SetText(string.format("%dm %02ds", mins, secs))

    pinnedPopup.samplesValue:SetText(tostring(pinnedSampleCount))
end

function MonitorTab:ClosePinnedPopup()
    if pinnedTicker then
        pinnedTicker:Cancel()
        pinnedTicker = nil
    end
    if pinnedPopup then
        pinnedPopup:Hide()
        pinnedPopup = nil
    end
    pinnedAddonName = nil
    pinnedBaselineMemory = 0
    pinnedPeakMemory = 0
    pinnedMinMemory = 0
    pinnedStartTime = 0
    pinnedSampleCount = 0
    pinnedLastMemory = 0
    pinnedGrowthSamples = {}
    if Addon.db and Addon.db.monitor then
        Addon.db.monitor.pinnedAddon = nil
    end
end

function MonitorTab:GetPinnedPopup()
    return pinnedPopup
end

function MonitorTab:GetPinnedAddonName()
    return pinnedAddonName
end

function MonitorTab:RestorePinnedAddon()
    local db = Addon.db and Addon.db.monitor
    if not db then return end
    if not db.pinnedReopenOnReload then return end
    if not db.pinnedAddon then return end

    local addonName = db.pinnedAddon
    local addonIndex = FindAddonIndexByName(addonName)
    if not addonIndex or not C_AddOns.IsAddOnLoaded(addonIndex) then
        db.pinnedAddon = nil
        return
    end

    local _, title = C_AddOns.GetAddOnInfo(addonIndex)
    local displayTitle = StripColorCodes(title or addonName)
    self:CreatePinnedPopup(addonName, displayTitle)
end
