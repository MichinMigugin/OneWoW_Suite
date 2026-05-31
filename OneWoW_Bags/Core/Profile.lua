local _, OneWoW_Bags = ...

-- Lightweight profiler for measuring OneWoW_Bags hot paths (especially first
-- bank/warband bank open). Disabled by default so it has zero cost in normal
-- play. Toggle with /owbprof and dump aggregated timings to chat.
--
-- Two APIs:
--   Profile:Start(name) / Profile:Stop(name) for nestable outer sections.
--   Profile:Mark()      / Profile:Add(name, t)  for tight inner loops (no
--                                                table churn per call).
--
-- Usage in code:
--   local P = OneWoW_Bags.Profile
--   P:Start("BankSet:Build"); ...; P:Stop("BankSet:Build")
--   local t = P:Mark(); ...; P:Add("OWB_FullUpdate", t)
--
-- Slash commands:
--   /owbprof on     reset counters and enable
--   /owbprof off    disable (counters preserved for dump)
--   /owbprof reset  clear counters
--   /owbprof dump   print aggregated results sorted by total time

local debugprofilestop = debugprofilestop
local tinsert, tremove, wipe, sort, pairs, ipairs = tinsert, tremove, wipe, sort, pairs, ipairs
local format = string.format

OneWoW_Bags.Profile = {}
local P = OneWoW_Bags.Profile

P.enabled = false
P._sections = {}
P._stack = {}

local function GetOrCreate(name)
    local s = P._sections[name]
    if not s then
        s = { count = 0, total = 0, max = 0 }
        P._sections[name] = s
    end
    return s
end

function P:Reset()
    wipe(self._sections)
    wipe(self._stack)
end

function P:Start(name)
    if not self.enabled then return end
    tinsert(self._stack, { name = name, t = debugprofilestop() })
end

function P:Stop(name)
    if not self.enabled then return end
    local top = self._stack[#self._stack]
    if not top or top.name ~= name then
        return
    end
    tremove(self._stack)
    local elapsed = debugprofilestop() - top.t
    local s = GetOrCreate(name)
    s.count = s.count + 1
    s.total = s.total + elapsed
    if elapsed > s.max then s.max = elapsed end
end

function P:Mark()
    if not self.enabled then return nil end
    return debugprofilestop()
end

function P:Add(name, startedAt)
    if not self.enabled or not startedAt then return end
    local elapsed = debugprofilestop() - startedAt
    local s = GetOrCreate(name)
    s.count = s.count + 1
    s.total = s.total + elapsed
    if elapsed > s.max then s.max = elapsed end
end

function P:Dump()
    local rows = {}
    for name, s in pairs(self._sections) do
        tinsert(rows, { name = name, count = s.count, total = s.total, max = s.max })
    end
    if #rows == 0 then
        print("|cff80c0ffOneWoW_Bags Profile:|r no samples collected.")
        return
    end
    sort(rows, function(a, b) return a.total > b.total end)
    print("|cff80c0ffOneWoW_Bags Profile|r " .. (P.enabled and "(on)" or "(off)"))
    print(format("  %-40s %7s %11s %10s %11s", "section", "n", "total(ms)", "avg(ms)", "max(ms)"))
    for _, r in ipairs(rows) do
        local avg = r.count > 0 and (r.total / r.count) or 0
        print(format("  %-40s %7d %11.2f %10.3f %11.2f", r.name, r.count, r.total, avg, r.max))
    end
end

SLASH_OWBPROF1 = "/owbprof"
SlashCmdList["OWBPROF"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "on" then
        P:Reset()
        P.enabled = true
        print("|cff80c0ffOneWoW_Bags Profile:|r enabled (counters reset). Open the bank, then run /owbprof dump.")
    elseif msg == "off" then
        P.enabled = false
        print("|cff80c0ffOneWoW_Bags Profile:|r disabled. /owbprof dump still works.")
    elseif msg == "reset" then
        P:Reset()
        print("|cff80c0ffOneWoW_Bags Profile:|r counters reset.")
    elseif msg == "dump" then
        P:Dump()
    else
        print("|cff80c0ffOneWoW_Bags Profile:|r usage: /owbprof on | off | reset | dump")
    end
end
