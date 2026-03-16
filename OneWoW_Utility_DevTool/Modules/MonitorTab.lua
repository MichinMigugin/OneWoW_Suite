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
