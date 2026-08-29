-- Central lifecycle dispatch for the OneWoW suite. Only ns.lua registers
-- ADDON_LOADED, PLAYER_LOGIN, and PLAYER_ENTERING_WORLD for orchestrated units.
local ADDON_NAME, ns = ...

local C_AddOns = C_AddOns
local ipairs = ipairs
local pairs = pairs
local type = type
local pcall = pcall
local format = string.format
local tostring = tostring
local _G = _G
local GetTimePreciseSec = GetTimePreciseSec
local tinsert = tinsert
local tconcat = table.concat
local wipe = wipe
local sort = sort
local print = print

ns.Lifecycle = ns.Lifecycle or {}
local Lifecycle = ns.Lifecycle

--- Isolated invoke for handler fans: one failure must not abort the fan-out.
--- Failures are forwarded to geterrorhandler() (production sink; not debug-gated).
---@param label string|nil handler id or context label
---@param fn function
local function SafeCall(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        ns:TraceRecord("error", label, { err = tostring(err) })
        if label then
            geterrorhandler()(format("OneWoW lifecycle handler '%s': %s", tostring(label), tostring(err)))
        else
            geterrorhandler()(err)
        end
    end
end
Lifecycle.SafeCall = SafeCall

-- ============================================================================
-- Lifecycle Trace
-- ============================================================================
-- Opt-in dispatch/load tracer. Records the lifecycle funnel sequence into an
-- in-memory ring buffer, dumped to chat via /1wtrace. The enable flag persists
-- in OneWoW_DB so a /reload can capture the startup orchestration (which all
-- fires during core's ADDON_LOADED, before any command can run); the ring is
-- session-only and is cleared on each Sync. Record is a cheap no-op when off.
-- Sized for a full-suite + large external-addon-list startup: every addon load
-- emits a watchers.notify (LoD addons add loadAddOn.hook too), so a cold start
-- through PLAYER_ENTERING_WORLD runs into the hundreds of events. Dump only ever
-- prints min(count, RING_SIZE) lines, so a generous cap costs nothing until used.
local RING_SIZE = 1024
local TRACE_PREFIX = "|cFFFFD100OneWoW Trace|r"

local Trace = {
    enabled = false,
    ring = {},
    head = 0,
    count = 0,
}
Lifecycle.Trace = Trace

--- Appends a trace record when recording is enabled; a cheap no-op otherwise.
---@param phase string funnel label (e.g. "OnAddonLoaded", "loadAddOn.hook")
---@param unit string|nil addon/unit name the event concerns
---@param detail table|nil extra key/value fields shown in the dump
function ns:TraceRecord(phase, unit, detail)
    if not Trace.enabled then return end
    Trace.head = (Trace.head % RING_SIZE) + 1
    Trace.count = Trace.count + 1
    Trace.ring[Trace.head] = {
        t = GetTimePreciseSec(),
        phase = phase,
        unit = unit,
        detail = detail,
    }
end

--- One-line "phase unit key=val ..." rendering for a single record.
---@param rec table
---@return string
function Trace:FormatDetail(rec)
    local parts = { rec.phase or "?" }
    if rec.unit then tinsert(parts, rec.unit) end
    local d = rec.detail
    if d then
        local keys = {}
        for k in pairs(d) do keys[#keys + 1] = k end
        sort(keys)
        for _, k in ipairs(keys) do
            tinsert(parts, k .. "=" .. tostring(d[k]))
        end
    end
    return tconcat(parts, " ")
end

--- Prints the buffered trace to chat, oldest-first, with deltas from the first
--- record. Reads as a startup timeline.
function Trace:Dump()
    local stored = (self.count < RING_SIZE) and self.count or RING_SIZE
    print(TRACE_PREFIX .. format(" dump - recording %s, %d event(s)", self.enabled and "ON" or "OFF", stored))
    if stored == 0 then
        print("  (no events - /1wtrace on, then /reload to capture startup)")
        return
    end
    local firstT
    for k = 1, stored do
        local idx = ((self.head - stored + k - 1) % RING_SIZE) + 1
        local rec = self.ring[idx]
        if rec then
            firstT = firstT or rec.t
            print(format("  [+%.3fs] %s", rec.t - firstT, self:FormatDetail(rec)))
        end
    end
end

function Trace:Clear()
    wipe(self.ring)
    self.head = 0
    self.count = 0
end

--- Sets the in-memory recording state and persists it to OneWoW_DB.
---@param on boolean
function Trace:SetEnabled(on)
    self.enabled = on and true or false
    ns.db.global.debugTrace = self.enabled
end

--- Reads the persisted flag into memory and clears the ring for a fresh
--- session. Called from ns:OnAddonLoaded right after InitializeDatabase so
--- a persisted-on flag captures the full startup orchestration.
function Trace:Sync()
    self:Clear()
    self.enabled = ns.db.global.debugTrace and true or false
end

local addonLoadedWatchers = {}
local coreLoginHandlers = {}
local coreEnteringWorldHandlers = {}

-- Data-ready registry: the "data boundary" sibling of the addon-loaded watchers.
-- A provider's data becomes queryable only after its login init runs (Catalog
-- data units finish login init / SignalDataReady; stores finish CollectBags there),
-- which is strictly after ns.FeatureStateChanged ("load boundary"). dataReadySet
-- is monotonic per session; watchers get registration-time catch-up so a consumer
-- built after readiness still fires once.
local dataReadyWatchers = {}
local dataReadySet = {}

local unitRegistry = {}

--- Register a load unit for lifecycle hook dispatch (stores via BootStore; optional for hubs).
---@param addonName string
---@param unit table hook target (thin lifecycle root or store ns)
function Lifecycle.RegisterUnit(addonName, unit)
    if addonName and unit then
        unitRegistry[addonName] = unit
    end
end

--- Resolve a load unit for RunUnitHook. Hub thin roots remain in _G as fallback.
---@param addonName string|nil
---@return table|nil
function Lifecycle.ResolveUnit(addonName)
    if not addonName then return nil end
    return unitRegistry[addonName] or _G[addonName]
end

--- Invokes a one-shot unit lifecycle hook if present; traces only on actual dispatch.
---@param addonName string|nil _G key for the load unit
---@param method string hook name (e.g. "OnPlayerLogin")
local function RunUnitHook(addonName, method, ...)
    local unit = Lifecycle.ResolveUnit(addonName)
    if unit and type(unit[method]) == "function" then
        ns:TraceRecord(method, addonName)
        unit[method](unit, ...)
    end
end
Lifecycle.RunUnitHook = RunUnitHook

local onAddonLoadedDone = {}

--- Dispatch OnAddonLoaded at most once per manifest unit per session.
--- Manifest-gated: a Blizzard or third-party addon whose _G table happens to
--- define OnAddonLoaded is never treated as a suite load unit.
---@param addonName string _G key for the load unit
function ns:DispatchUnitOnAddonLoaded(addonName)
    if not addonName or onAddonLoadedDone[addonName] then return end
    if not ns:IsManifestUnit(addonName) then
        -- Trace only when the gate actually suppressed a would-have-run hook;
        -- a non-manifest addon with no OnAddonLoaded was a no-op before too.
        local unit = Lifecycle.ResolveUnit(addonName)
        if unit and type(unit.OnAddonLoaded) == "function" then
            ns:TraceRecord("dispatch.skip", addonName, { reason = "NOT_MANIFEST" })
        end
        return
    end
    onAddonLoadedDone[addonName] = true
    RunUnitHook(addonName, "OnAddonLoaded")
end

local function WalkManifestUnits(fn)
    local manifest = ns.ModuleManifest
    if not manifest then return end
    for _, m in ipairs(manifest) do
        if not m.addon or m.addon == "" then
            -- skip empty entries
        elseif m.loadPhase == "login" then
            if C_AddOns.IsAddOnLoaded(m.addon) then
                fn(m.addon)
            end
            if m.stores then
                for _, store in ipairs(m.stores) do
                    if C_AddOns.IsAddOnLoaded(store) then
                        fn(store)
                    end
                end
            end
        elseif not m.loadPhase and C_AddOns.IsAddOnLoaded(m.addon) then
            fn(m.addon)
        end
    end
end

---@param addonName string|nil specific addon, or nil/"*" for any addon load
---@param fn fun(loadedAddon: string)
function ns:RegisterAddonLoadedWatcher(addonName, fn)
    if not fn then return end
    addonLoadedWatchers[#addonLoadedWatchers + 1] = {
        addonName = addonName,
        fn = fn,
    }
    -- Registration-time catch-up: a filtered watcher whose addon already loaded
    -- before this registration (e.g. external bag addons that sort before OneWoW)
    -- would otherwise never fire. Per-watcher and deliberately independent of the
    -- NotifyAddonLoadedWatchers dedup set, so a late registrant still runs once.
    -- Wildcard (nil/"*") watchers get no catch-up: there is no single addon to
    -- replay, and they only ever observe loads from this point forward.
    if addonName and addonName ~= "" and addonName ~= "*" and C_AddOns.IsAddOnLoaded(addonName) then
        self:TraceRecord("watcher.catchup", addonName)
        SafeCall(addonName, fn, addonName)
    end
end

local function FireDataReadyWatchers(addonName)
    for _, entry in ipairs(dataReadyWatchers) do
        local filter = entry.addonName
        if not filter or filter == "*" or filter == addonName then
            SafeCall(entry.addonName or "*", entry.fn, addonName)
        end
    end
end

--- Marks a provider's data queryable and fans out its data-ready watchers, at
--- most once per addon per session (monotonic). Auto-fired by BootStore at the
--- end of OnPlayerLogin; hub providers may call it explicitly. nil/duplicate
--- addonName is a no-op (so the call site needs no guard).
---@param addonName string|nil provider addon name
function ns:SignalDataReady(addonName)
    if not addonName or dataReadySet[addonName] then return end
    dataReadySet[addonName] = true
    self:TraceRecord("dataReady.signal", addonName)
    FireDataReadyWatchers(addonName)
end

--- "Wire when provider X's data is queryable" — the data-boundary analogue of
--- RegisterAddonLoadedWatcher. Registration-time catch-up: a filtered watcher
--- whose provider is already ready fires once immediately, so a consumer (or tab)
--- built after readiness is not stranded. Wildcard (nil/"*") gets no catch-up.
--- Setup fns must be idempotent (catch-up + a later signal can both reach a late
--- registrant; scan-callback registration is not dedup-safe).
---@param addonName string|nil specific provider, or nil/"*" for any
---@param fn fun(readyAddon: string)
function ns:RegisterDataReadyWatcher(addonName, fn)
    if not fn then return end
    dataReadyWatchers[#dataReadyWatchers + 1] = {
        addonName = addonName,
        fn = fn,
    }
    if addonName and addonName ~= "" and addonName ~= "*" and dataReadySet[addonName] then
        self:TraceRecord("dataReady.catchup", addonName)
        SafeCall(addonName, fn, addonName)
    end
end

---@param addonName string provider addon name
---@return boolean ready
function ns:IsDataReady(addonName)
    return addonName ~= nil and dataReadySet[addonName] == true
end

--- Handlers within a phase must be order-independent: a handler that needs
--- another subsystem initialized must express that in code (call it, or make
--- the dependency lazy/idempotent), never rely on registration order.
---@param id string unique handler id (for debugging; not used for dedup)
---@param fn fun()
---@param phase "early"|"late"|nil "early" = before the load banner; default "late"
function ns:RegisterCoreLoginHandler(id, fn, phase)
    if not fn then return end
    coreLoginHandlers[#coreLoginHandlers + 1] = { id = id, fn = fn, phase = phase or "late" }
end

---@param id string unique handler id
---@param fn fun(isLogin: boolean, isReload: boolean, isZoning: boolean)
function ns:RegisterCoreEnteringWorldHandler(id, fn)
    if not fn then return end
    coreEnteringWorldHandlers[#coreEnteringWorldHandlers + 1] = { id = id, fn = fn }
end

---@param phase "early"|"late"
function ns:FireCoreLoginHandlers(phase)
    local n = 0
    for _, entry in ipairs(coreLoginHandlers) do
        if entry.phase == phase then n = n + 1 end
    end
    self:TraceRecord("core.loginHandlers", nil, { phase = phase, count = n })
    for _, entry in ipairs(coreLoginHandlers) do
        if entry.phase == phase then
            SafeCall(entry.id, entry.fn)
        end
    end
end

function ns:FireCoreEnteringWorldHandlers(isLogin, isReload, isZoning)
    self:TraceRecord("core.enteringWorldHandlers", nil, { count = #coreEnteringWorldHandlers })
    for _, entry in ipairs(coreEnteringWorldHandlers) do
        SafeCall(entry.id, entry.fn, isLogin, isReload, isZoning)
    end
end

local function FireAddonLoadedWatchers(loadedAddon)
    for _, entry in ipairs(addonLoadedWatchers) do
        local filter = entry.addonName
        if not filter or filter == "*" or filter == loadedAddon then
            SafeCall(entry.addonName or "*", entry.fn, loadedAddon)
        end
    end
end

local addonLoadedNotified = {}

--- Fan out addon-loaded watchers at most once per addon name per session.
--- Both load paths funnel here: WoW ADDON_LOADED (DispatchAddonLoaded) and any
--- C_AddOns.LoadAddOn (RunPostLoadInit). A mid-session LoadAddOn fires both, so
--- the dedup set collapses that double-path to a single fan-out per addon.
---@param loadedAddon string|nil
function ns:NotifyAddonLoadedWatchers(loadedAddon)
    if not loadedAddon or addonLoadedNotified[loadedAddon] then return end
    addonLoadedNotified[loadedAddon] = true
    self:TraceRecord("watchers.notify", loadedAddon)
    FireAddonLoadedWatchers(loadedAddon)
end

---@param loadedAddon string addon name from ADDON_LOADED
function ns:DispatchAddonLoaded(loadedAddon)
    if loadedAddon == ADDON_NAME then
        ns:OnAddonLoaded(loadedAddon)
    elseif loadedAddon then
        -- Auto-loaded manifest units (e.g. DevTool) receive WoW's own ADDON_LOADED.
        self:DispatchUnitOnAddonLoaded(loadedAddon)
    end
    self:NotifyAddonLoadedWatchers(loadedAddon)
end

-- Login pass over every loaded manifest unit. Login-only by design: it must NOT
-- fire OnPlayerEnteringWorld -- the real PLAYER_ENTERING_WORLD that follows
-- PLAYER_LOGIN at cold start drives PEW with authoritative args (see
-- DispatchEnteringWorld). OnAddonLoaded is a safety net for units whose hook was
-- somehow not driven by the LoadAddOn path; DispatchUnitOnAddonLoaded guarantees
-- at-most-once dispatch per unit.
function ns:RunManifestLoginPhase()
    self:TraceRecord("manifest.loginPhase")
    WalkManifestUnits(function(addonName)
        self:DispatchUnitOnAddonLoaded(addonName)
        RunUnitHook(addonName, "OnPlayerLogin")
    end)
end

---@param isLogin boolean
---@param isReload boolean
function ns:DispatchEnteringWorld(isLogin, isReload)
    local isZoning = not isLogin and not isReload
    self:TraceRecord("enteringWorld", nil, { isLogin = isLogin, isReload = isReload, isZoning = isZoning })
    ns:FireCoreEnteringWorldHandlers(isLogin, isReload, isZoning)
    WalkManifestUnits(function(addonName)
        RunUnitHook(addonName, "OnPlayerEnteringWorld", isLogin, isReload, isZoning)
    end)
end

--- Per-manifest-root handler registry for chain-up from sub-modules.
---@param owner table manifest root (ns / addon table)
---@return table registry methods to mix onto owner
function Lifecycle:CreateHandlerRegistry(owner)
    local loginHandlers = {}
    local enteringWorldHandlers = {}

    function owner:RegisterLoginHandler(id, fn)
        if not id or not fn then return end
        loginHandlers[id] = fn
    end

    function owner:UnregisterLoginHandler(id)
        loginHandlers[id] = nil
    end

    function owner:RegisterEnteringWorldHandler(id, fn)
        if not id or not fn then return end
        enteringWorldHandlers[id] = fn
    end

    function owner:UnregisterEnteringWorldHandler(id)
        enteringWorldHandlers[id] = nil
    end

    function owner:RegisterAddonLoadedWatcher(addonName, fn)
        ns:RegisterAddonLoadedWatcher(addonName, fn)
    end

    function owner:FireLoginHandlers()
        for id, fn in pairs(loginHandlers) do
            SafeCall(id, fn)
        end
    end

    function owner:FireEnteringWorldHandlers(isLogin, isReload, isZoning)
        for id, fn in pairs(enteringWorldHandlers) do
            SafeCall(id, fn, isLogin, isReload, isZoning)
        end
    end

    return owner
end

-- Dev-only lifecycle trace command. Hardcoded English, mirroring the Bags
-- /owblayout precedent; this is a developer chat tool, not user-facing UI.
SLASH_ONEWOW_TRACE1 = "/1wtrace"
SlashCmdList["ONEWOW_TRACE"] = function(msg)
    msg = (type(msg) == "string") and msg:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
    if msg == "on" then
        Trace:Clear()
        Trace:SetEnabled(true)
        print(TRACE_PREFIX .. ": |cFF00FF00enabled|r. /reload to capture startup, then /1wtrace dump")
    elseif msg == "off" then
        Trace:SetEnabled(false)
        print(TRACE_PREFIX .. ": disabled. /1wtrace dump still works.")
    elseif msg == "clear" or msg == "reset" then
        Trace:Clear()
        print(TRACE_PREFIX .. ": ring cleared.")
    elseif msg == "dump" then
        Trace:Dump()
    else
        print(TRACE_PREFIX .. ": usage: /1wtrace on | off | clear | dump  (recording " .. (Trace.enabled and "ON" or "OFF") .. ")")
    end
end
