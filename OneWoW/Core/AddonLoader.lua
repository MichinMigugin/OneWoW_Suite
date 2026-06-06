-- Centralized on-demand addon loader. One loader serves both the login orchestrator
-- and lazy point-of-use loads, so no addon hand-rolls its own LoadAddOn wrapper.
-- GUI-free on purpose: it loads early, before anything that consumes it.
local _, OneWoW = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local C_AddOns = C_AddOns
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame
local ipairs = ipairs
local tinsert = tinsert
local print = print
local _G = _G
local UnitName = UnitName
local type = type

-- Pending loads deferred until combat ends, and a per-addon "already told the
-- user" guard so a repeated failure isn't reprinted on every attempt.
local pendingCombat = {}
local warned = {}

-- True while OneWoW:BringUp is driving a batch load. The LoadAddOn hook checks
-- this so it only runs OnAddonLoaded during the batch; BringUp drives the login
-- and entering-world passes itself, once, after the whole set is loaded.
local inBringUp = false

local combatFrame = CreateFrame("Frame")
combatFrame:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_REGEN_ENABLED" then return end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if #pendingCombat == 0 then return end
    local queue = pendingCombat
    pendingCombat = {}
    for _, entry in ipairs(queue) do
        OneWoW:WithAddon(entry.name, entry.onReady, entry.onFail, entry.opts)
    end
end)

--- Maps a raw LoadAddOn failure token to a localized, user-facing string.
--- Falls back to Blizzard's ADDON_* constants, then to the raw token.
---@param reason string|nil LoadAddOn failure token (e.g. "DISABLED", "MISSING", "COMBAT")
---@return string text localized failure description
function OneWoW:GetLoadFailureText(reason)
    local L = OneWoW.L
    if reason and L and L["LOAD_FAIL_" .. reason] then
        return L["LOAD_FAIL_" .. reason]
    end
    if reason and _G["ADDON_" .. reason] then
        return _G["ADDON_" .. reason]
    end
    return reason or (L and L["LOAD_FAIL_UNKNOWN"]) or "unknown error"
end

-- Shared addon enable-state API. Both settings surfaces (the Home tab and the
-- Manage Features panel) query and mutate Blizzard's per-addon enable flag the
-- same way; these helpers are the single implementation. `perCharacter` selects
-- the scope: the Home tab passes false (account-wide / all characters) and
-- Manage Features passes true (a current-character override, which can re-enable
-- an addon disabled account-wide). Scope is intentional, not a default.

--- Reads whether an addon is enabled in the requested scope.
---@param name string addon (folder/TOC) name
---@param perCharacter boolean? true = current-character scope; false/nil = account-wide
---@return boolean enabled true when enabled in the requested scope
function OneWoW:IsAddonEnabled(name, perCharacter)
    if not name then return false end
    local state
    if perCharacter then
        state = C_AddOns.GetAddOnEnableState(name, UnitName("player"))
    else
        state = C_AddOns.GetAddOnEnableState(name)
    end
    return state ~= nil and state > 0
end

--- Enables or disables an addon in the requested scope. Takes effect on the next
--- load (reload/relog) — WoW cannot load or unload addon Lua mid-session.
---@param name string addon (folder/TOC) name
---@param enabled boolean desired enabled state
---@param perCharacter boolean? true = current-character scope; false/nil = account-wide
function OneWoW:SetAddonEnabled(name, enabled, perCharacter)
    if not name then return end
    if perCharacter then
        local char = UnitName("player")
        if enabled then
            C_AddOns.EnableAddOn(name, char)
        else
            C_AddOns.DisableAddOn(name, char)
        end
    else
        if enabled then
            C_AddOns.EnableAddOn(name)
        else
            C_AddOns.DisableAddOn(name)
        end
    end
end

local FEATURE_UNIT_STATUS_KEYS = {
    missing    = "FEATURE_UNIT_STATUS_MISSING",
    disabled   = "FEATURE_UNIT_STATUS_DISABLED",
    not_loaded = "FEATURE_UNIT_STATUS_NOT_LOADED",
    pending_disable = "FEATURE_UNIT_STATUS_PENDING_DISABLE",
    all        = "FEATURE_UNIT_STATUS_ALL",
    some       = "FEATURE_UNIT_STATUS_SOME",
}

--- Short inline status text for placeholder tabs and similar surfaces.
---@param state string return value from GetFeatureUnitState
---@return string label localized short status
function OneWoW:GetFeatureUnitStatusLabel(state)
    local L = OneWoW.L or {}
    local key = FEATURE_UNIT_STATUS_KEYS[state]
    if key and L[key] then
        return L[key]
    end
    return L["FEATURE_UNIT_STATUS_MISSING"] or "Not detected"
end

--- When a unit is enabled but not in memory, returns a load-failure token if
--- GetAddOnInfo reports something other than DISABLED/DEMAND_LOADED.
---@param name string addon (folder/TOC) name
---@return string? reason raw failure token, or nil when healthy-not-loaded
local function GetFeatureUnitUnloadReason(name)
    if not name or C_AddOns.IsAddOnLoaded(name) then return nil end
    local _, _, _, loadable, reason = C_AddOns.GetAddOnInfo(name)
    if not loadable and reason and reason ~= "DISABLED" and reason ~= "DEMAND_LOADED" then
        return reason
    end
    return nil
end

--- Classifies an addon for status display. A loaded or DEMAND_LOADED unit is
--- "enabled" (healthy): every suite unit is LoadOnDemand: 1 and force-loaded by
--- the orchestrator, so GetAddOnInfo reports loadable=false/reason=DEMAND_LOADED
--- even while the unit is loaded and working — that is not an error.
---@param name string addon (folder/TOC) name
---@param perCharacter boolean? scope of the enable check; false/nil = account-wide
---@return string status "not_found" | "disabled" | "enabled" | "warning"
---@return string? reason raw load-failure token when status is "warning"
function OneWoW:GetAddonStatus(name, perCharacter)
    if not name or not C_AddOns.DoesAddOnExist(name) then
        return "not_found", nil
    end
    if not self:IsAddonEnabled(name, perCharacter) then
        return "disabled", nil
    end
    if C_AddOns.IsAddOnLoaded(name) then
        return "enabled", nil
    end
    local warnReason = GetFeatureUnitUnloadReason(name)
    if warnReason then
        return "warning", warnReason
    end
    return "enabled", nil
end

-- OneWoW "soft disable" (feature opt-out). Layered OVER Blizzard's enable flag,
-- not a replacement: an opted-out unit stays Blizzard-ENABLED (so the built-in
-- addon list shows it enabled with a "Load Addon" button), but the startup
-- orchestrator skips loading it. Because it stays enabled it can be LoadAddOn'd
-- later the same session with no reload. Stored in OneWoW_DB (account-wide SV)
-- with a per-character override map; current-character resolution mirrors
-- Blizzard's char-overrides-account model (char entry: true = out, false = in;
-- nil = inherit account). GUI-free: the char key is built locally so the loader
-- keeps no GUI dependency.
local function OptOutStore(create)
    local db = OneWoW_DB
    if not db then return nil end
    local oo = db.featureOptOut
    if not oo then
        if not create then return nil end
        oo = {}
        db.featureOptOut = oo
    end
    oo.account = oo.account or {}
    oo.char = oo.char or {}
    return oo
end

--- Effective opt-out for the current character (char override wins, else account).
---@param name string addon (folder/TOC) name
---@return boolean optedOut true when OneWoW should not load this unit for this character
function OneWoW:IsFeatureOptedOut(name)
    if not name then return false end
    local oo = OptOutStore(false)
    if not oo then return false end
    local charMap = oo.char[OneWoW_GUI:BuildCharKey()]
    local charVal = charMap and charMap[name]
    if charVal ~= nil then return charVal end
    return oo.account[name] == true
end

--- Opt-out as it applies in a specific scope (drives the Manage Features checkboxes).
---@param name string addon (folder/TOC) name
---@param perCharacter boolean? true = current-character scope (resolved); false/nil = account-wide
---@return boolean optedOut
function OneWoW:IsFeatureOptedOutInScope(name, perCharacter)
    if perCharacter then
        return self:IsFeatureOptedOut(name)
    end
    if not name then return false end
    local oo = OptOutStore(false)
    if not oo then return false end
    return oo.account[name] == true
end

--- Writes the opt-out flag in the requested scope. Char scope stores an explicit
--- boolean so it can re-enable an account-wide opt-out for one character.
---@param name string addon (folder/TOC) name
---@param optedOut boolean desired opt-out state
---@param perCharacter boolean? true = current-character override; false/nil = account-wide
function OneWoW:SetFeatureOptOut(name, optedOut, perCharacter)
    if not name then return end
    local oo = OptOutStore(true)
    if not oo then return end
    if perCharacter then
        local key = OneWoW_GUI:BuildCharKey()
        oo.char[key] = oo.char[key] or {}
        oo.char[key][name] = optedOut and true or false
    else
        oo.account[name] = optedOut and true or nil
    end
    -- Opt-out changes "wanted" state even when nothing loads/unloads this session;
    -- let read-only surfaces (Home) re-query.
    EventRegistry:TriggerEvent("OneWoW.FeatureStateChanged", name)
end

--- Blizzard-enabled in scope AND not soft-opted-out in that scope.
---@param name string addon (folder/TOC) name
---@param perCharacter boolean? true = current-character scope; false/nil = account-wide
---@return boolean wanted
function OneWoW:IsFeatureWanted(name, perCharacter)
    if not name then return false end
    if not self:IsAddonEnabled(name, perCharacter) then return false end
    return not self:IsFeatureOptedOutInScope(name, perCharacter)
end

--- Effective opt-out for a stored character key (char override wins, else account).
---@param name string addon (folder/TOC) name
---@param charKey string canonical or legacy character key
---@return boolean optedOut
function OneWoW:IsFeatureOptedOutForCharKey(name, charKey)
    if not name or not charKey then return false end
    local oo = OptOutStore(false)
    if not oo then return false end
    local key = OneWoW_GUI:CanonicalizeCharacterKey(charKey)
    if not key then return false end
    local charMap = oo.char[key]
    local charVal = charMap and charMap[name]
    if charVal ~= nil then return charVal end
    return oo.account[name] == true
end

--- Wanted for one character: Blizzard-enabled for that toon AND not soft-opted-out.
---@param name string addon (folder/TOC) name
---@param charKey string canonical or legacy character key
---@return boolean wanted
function OneWoW:IsFeatureWantedForCharKey(name, charKey)
    if not name or not charKey then return false end
    local key = OneWoW_GUI:CanonicalizeCharacterKey(charKey)
    if not key then return false end
    local charName = key:match("^(.-)%-")
    if not charName or charName == "" then return false end
    if C_AddOns.GetAddOnEnableState(name, charName) == 0 then return false end
    return not self:IsFeatureOptedOutForCharKey(name, key)
end

--- Char keys that can affect aggregate wanted state: current toon plus any toon
--- with an explicit opt-out entry for this addon.
---@param name string addon (folder/TOC) name
---@return string[] keys canonical character keys
local function CollectCharKeysForFeature(name)
    local keys = {}
    local seen = {}
    local function add(rawKey)
        if not rawKey then return end
        local key = OneWoW_GUI:CanonicalizeCharacterKey(rawKey)
        if key and not seen[key] then
            seen[key] = true
            keys[#keys + 1] = key
        end
    end
    add(OneWoW_GUI:BuildCharKey())
    local oo = OptOutStore(false)
    if oo and oo.char then
        for charKey, charMap in pairs(oo.char) do
            if charMap[name] ~= nil then
                add(charKey)
            end
        end
    end
    return keys
end

--- Aggregate wanted scope across known characters (Blizzard + soft opt-out).
---@param name string addon (folder/TOC) name
---@return string scope "all"|"some"|"none"
function OneWoW:GetFeatureWantedAggregate(name)
    if not name or not C_AddOns.DoesAddOnExist(name) then
        return "none"
    end
    local keys = CollectCharKeysForFeature(name)
    if #keys == 0 then
        if not self:IsFeatureWanted(name, false) then return "none" end
        if C_AddOns.GetAddOnEnableState(name) == 2 then return "all" end
        return "some"
    end
    local wanted, unwanted = 0, 0
    for _, key in ipairs(keys) do
        if self:IsFeatureWantedForCharKey(name, key) then
            wanted = wanted + 1
        else
            unwanted = unwanted + 1
        end
    end
    if wanted > 0 and unwanted > 0 then return "some" end
    if wanted > 0 then return "all" end
    return "none"
end

--- Canonical lifecycle state for a suite feature unit (TOC/addon folder name).
--- Combines Blizzard enable flags and OneWoW soft opt-out. Used by Home,
--- placeholder tabs, and similar read-only surfaces.
---@param name string addon (folder/TOC) name
---@return string state "missing"|"disabled"|"not_loaded"|"pending_disable"|"all"|"some"
function OneWoW:GetFeatureUnitState(name)
    if not name or not C_AddOns.DoesAddOnExist(name) then
        return "missing"
    end
    if not self:IsAddonEnabled(name, true) then
        return "disabled"
    end
    if not self:IsFeatureWanted(name, true) then
        if C_AddOns.IsAddOnLoaded(name) then
            return "pending_disable"  -- loaded this session; won't load next reload
        end
        return "not_loaded"
    end
    if not C_AddOns.IsAddOnLoaded(name) then
        return "not_loaded"
    end
    if C_AddOns.GetAddOnEnableState(name) == 1 then
        return "some"
    end
    local agg = self:GetFeatureWantedAggregate(name)
    if agg == "some" then return "some" end
    if agg == "all" then return "all" end
    return "some"
end

---@class OneWoW.LoadOpts
---@field deferInCombat boolean? report "COMBAT" instead of loading while in combat (WithAddon queues the retry)

--- Manifest parent for a store load unit (nil when name is a root module).
---@param storeName string
---@return string|nil parentAddon
local function GetManifestParent(storeName)
    local manifest = OneWoW.ModuleManifest
    if not manifest then return nil end
    for _, m in ipairs(manifest) do
        local stores = m.stores
        if stores then
            for _, store in ipairs(stores) do
                if store == storeName then
                    return m.addon
                end
            end
        end
    end
    return nil
end

--- Ensures an addon is loaded. Idempotent; LoadAddOn pulls the addon's
--- RequiredDeps chain. Returns the raw failure token so callers can localize
--- via GetLoadFailureText.
---@param name string addon (folder/TOC) name to load
---@param opts OneWoW.LoadOpts? optional behavior flags
---@return boolean ok true if the addon is loaded (or already was)
---@return string? reason raw failure token when ok is false ("DISABLED" | "MISSING" | "DEP_DISABLED" | "COMBAT" | "OPTED_OUT" | ...)
function OneWoW:EnsureLoaded(name, opts)
    if not name then return false, "MISSING" end
    if C_AddOns.IsAddOnLoaded(name) then
        return true
    end
    if self:IsFeatureOptedOut(name) then
        return false, "OPTED_OUT"
    end
    local parent = GetManifestParent(name)
    if parent and self:IsFeatureOptedOut(parent) then
        return false, "OPTED_OUT"
    end
    if opts and opts.deferInCombat and InCombatLockdown() then
        return false, "COMBAT"
    end
    local ok, reason = C_AddOns.LoadAddOn(name)
    if not ok then
        return false, reason
    end
    -- Core-driven init runs in the C_AddOns.LoadAddOn hook below (single driver
    -- for every load path, including Blizzard's "Load Addon" button), so it has
    -- already fired synchronously by the time LoadAddOn returns here.
    return true
end

-- Calls a one-shot lifecycle hook on a loaded unit, if present. Units without the
-- hook (Blizzard_*, etc.) are a safe no-op.
local function RunUnitHook(name, method, ...)
    local unit = name and _G[name]
    if unit and type(unit[method]) == "function" then
        unit[method](unit, ...)
    end
end

--- Manifest unit set for a feature: { addon, ...stores } in manifest order.
--- Returns nil when name is not a manifest root (caller falls back to { name }).
---@param addonName string
---@return string[]|nil
local function ManifestUnitsFor(addonName)
    local manifest = OneWoW.ModuleManifest
    if not manifest then return nil end
    for _, m in ipairs(manifest) do
        if m.addon == addonName then
            local units = { m.addon }
            if m.stores then
                for _, store in ipairs(m.stores) do
                    units[#units + 1] = store
                end
            end
            return units
        end
    end
    return nil
end

-- Login pass over an already-loaded set. No-ops before PLAYER_LOGIN (cold start
-- defers OnPlayerLogin to RunManifestLoginPhase). The units' one-shot didLogin
-- guards make a repeat call safe.
local function Settle(units)
    if not OneWoW._playerLoginFired then return end
    for _, name in ipairs(units) do
        RunUnitHook(name, "OnPlayerLogin")
    end
end

-- Synthetic entering-world catch-up for units loaded mid-session: they missed the
-- real PLAYER_ENTERING_WORLD, so core delivers one now. isLogin=true mirrors the
-- cold-start OnPlayerLogin -> PEW(isLogin) sequence; isZoning stays false so
-- zone-refresh logic does not spuriously fire (the player did not zone). No-ops
-- before PLAYER_LOGIN: at cold start the real event delivers PEW with true args.
local function CatchUpEnteringWorld(units)
    if not OneWoW._playerLoginFired then return end
    for _, name in ipairs(units) do
        RunUnitHook(name, "OnPlayerEnteringWorld", true, false, false)
    end
end

-- Core-driven post-load init. The unit's own ADDON_LOADED is never delivered when
-- it is LoadAddOn'd inside another addon's dispatch, so core drives init via a
-- standardized one-shot OnAddonLoaded() hook. OnPlayerLogin / OnPlayerEnteringWorld
-- are NOT fired here: Settle / CatchUpEnteringWorld drive them once the whole set
-- is loaded (see OneWoW:BringUp), or the LoadAddOn hook catches up a lone load.
local function RunPostLoadInit(name)
    RunUnitHook(name, "OnAddonLoaded")
end

-- Single post-load init driver: every load path funnels through C_AddOns.LoadAddOn
-- (the orchestrator, EnsureLoaded, on-demand WithAddon, and Blizzard's addon-list
-- "Load Addon" button on a soft-disabled-but-enabled unit). Post-hooking it here
-- means a manual button click runs the unit through its full init for free. A
-- manual load also means the user wants the unit active, so clear any current-
-- character opt-out so the choice sticks.
hooksecurefunc(C_AddOns, "LoadAddOn", function(nameOrIndex)
    local name = nameOrIndex
    if type(name) ~= "string" then
        name = C_AddOns.GetAddOnInfo(nameOrIndex)
    end
    if not name or not C_AddOns.IsAddOnLoaded(name) then return end
    RunPostLoadInit(name)
    -- Single chokepoint for every load path; let read-only surfaces (Home) re-query.
    EventRegistry:TriggerEvent("OneWoW.FeatureStateChanged", name)
    -- A lone load outside a BringUp batch (e.g. Blizzard's addon-list "Load Addon"
    -- button) that happens after login must catch the unit up on the login and
    -- entering-world hooks it missed. BringUp drives these itself for batches, so
    -- skip while inBringUp to avoid firing them before the whole set is loaded.
    if not inBringUp and OneWoW._playerLoginFired then
        local single = { name }
        Settle(single)
        CatchUpEnteringWorld(single)
    end
    if OneWoW:IsFeatureOptedOut(name) then
        OneWoW:SetFeatureOptOut(name, false, true)
    end
end)

--- Brings up a manifest feature and its data stores as one batch: load the whole
--- set (each unit's OnAddonLoaded fires via the LoadAddOn hook), then a single
--- OnPlayerLogin pass, then -- only mid-session -- a synthetic OnPlayerEnteringWorld
--- catch-up. At cold start (before PLAYER_LOGIN) Settle / CatchUpEnteringWorld
--- no-op and the manifest login phase plus the real PLAYER_ENTERING_WORLD drive
--- those hooks with authoritative args. Opted-out / disabled units are skipped by
--- EnsureLoaded and excluded from the settle/catch-up passes.
---@param addonName string manifest feature (or any addon) to bring up
function OneWoW:BringUp(addonName)
    if not addonName then return end
    local units = ManifestUnitsFor(addonName) or { addonName }
    local midSession = OneWoW._playerLoginFired
    inBringUp = true
    for _, name in ipairs(units) do
        self:EnsureLoaded(name)
    end
    inBringUp = false
    local loaded = {}
    for _, name in ipairs(units) do
        if C_AddOns.IsAddOnLoaded(name) then
            loaded[#loaded + 1] = name
        end
    end
    Settle(loaded)
    if midSession then
        CatchUpEnteringWorld(loaded)
    end
end

--- Loads an addon and dispatches a callback, removing the if/else at the call
--- site. On success runs onReady(); on failure runs onFail(reason), or prints the
--- localized reason once if onFail is nil. A "COMBAT" deferral is queued to
--- PLAYER_REGEN_ENABLED rather than failed.
---@param name string addon (folder/TOC) name to load
---@param onReady fun()? called once the addon is loaded
---@param onFail fun(reason: string?)? called on failure; if nil, the reason is printed once
---@param opts OneWoW.LoadOpts? optional behavior flags
---@return boolean ok true if onReady ran this call (false when failed or deferred to combat end)
function OneWoW:WithAddon(name, onReady, onFail, opts)
    local ok, reason = self:EnsureLoaded(name, opts)
    if ok then
        if onReady then onReady() end
        return true
    end
    if reason == "COMBAT" then
        tinsert(pendingCombat, { name = name, onReady = onReady, onFail = onFail, opts = opts })
        combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return false
    end
    if onFail then
        onFail(reason)
    elseif not warned[name] then
        warned[name] = true
        print("|cFFFFD100OneWoW:|r " .. self:GetLoadFailureText(reason))
    end
    return false
end

-- Authoritative list of suite load units the core knows about. Single source of
-- truth for both the startup orchestrator (loads `loadPhase`-tagged entries) and
-- the load banner (reports any that are present). Detect-only entries carry no
-- `loadPhase`, so the orchestrator skips them: OneWoW_GUI is always a RequiredDep,
-- and OneWoW_Utility_DevTool stays a normal opt-in addon until migration step 5.
-- `module` is the RegisterModule name for hub modules (used by the lazy-tab hook).
-- `tabOrder` is the row-1 hub tab sort key (required on hub entries; load order
-- remains array-driven). `stores` lists a parent's data-store load units; the
-- orchestrator loads each one right after the parent so its OnAddonLoaded hook
-- fires deterministically (these are LoadOnDemand: 1 now, not LoadWith-auto-loaded).
OneWoW.ModuleManifest = {
    { addon = "OneWoW_GUI",             display = "GUI",           cmd = nil },
    { addon = "OneWoW_Notes",           display = "Notes",         cmd = "/1wn",   module = "notes",      tabOrder = 1, loadPhase = "login" },
    { addon = "OneWoW_AltTracker",      display = "AltTracker",    cmd = "/1wat",  module = "alttracker", tabOrder = 2, loadPhase = "login",
        stores = {
            "OneWoW_AltTracker_Storage",
            "OneWoW_AltTracker_Character",
            "OneWoW_AltTracker_Professions",
            "OneWoW_AltTracker_Collections",
            "OneWoW_AltTracker_Endgame",
            "OneWoW_AltTracker_Accounting",
            "OneWoW_AltTracker_Auctions",
        } },
    { addon = "OneWoW_Catalog",         display = "Catalog",       cmd = "/owcat", module = "catalog",    tabOrder = 3, loadPhase = "login",
        stores = {
            "OneWoW_CatalogData_Tradeskills",
            "OneWoW_CatalogData_Vendors",
            "OneWoW_CatalogData_Quests",
            "OneWoW_CatalogData_Journal",
        } },
    { addon = "OneWoW_Trackers",        display = "Trackers",      cmd = "/1wt",   module = "trackers",   tabOrder = 4, loadPhase = "login" },
    { addon = "OneWoW_QoL",             display = "QoL",           cmd = "/1wqol", module = "qol",        tabOrder = 5, loadPhase = "login" },
    { addon = "OneWoW_DirectDeposit",   display = "DirectDeposit", cmd = "/1wdd",  loadPhase = "login" },
    { addon = "OneWoW_ShoppingList",    display = "ShoppingList",  cmd = "/1wsl",  loadPhase = "login" },
    { addon = "OneWoW_Bags",            display = "Bags",          cmd = "/1wb",   loadPhase = "login" },
    { addon = "OneWoW_Utility_DevTool", display = "DevTools",      cmd = "/1wdt" },
}
local Manifest = OneWoW.ModuleManifest

-- Row-1 tab order comes from each hub entry's tabOrder; placeholder labels from module.
local MODULE_TAB_LOCALE_KEYS = {
    notes      = "MODULE_NOTES",
    alttracker = "MODULE_ALTTRACKER",
    catalog    = "MODULE_CATALOG",
    trackers   = "MODULE_TRACKERS",
    qol        = "MODULE_QOL",
}

--- Tab sort order for a hub module name (RegisterModule `name` field).
---@param moduleName string e.g. "notes", "alttracker"
---@return number order explicit tabOrder from manifest, or 99 when unknown/missing
function OneWoW:GetModuleTabOrder(moduleName)
    for _, entry in ipairs(OneWoW.ModuleManifest) do
        if entry.module == moduleName then
            return entry.tabOrder or 99
        end
    end
    return 99
end

--- Placeholder row-1 tabs for hub modules not yet registered (not loaded).
--- Order from tabOrder via GetModuleTabOrder; addon names from manifest hub entries.
---@return table[] list of { name, addonName, order, localeKey }
function OneWoW:GetAlwaysShowModules()
    local result = {}
    for _, entry in ipairs(OneWoW.ModuleManifest) do
        if entry.module then
            result[#result + 1] = {
                name      = entry.module,
                addonName = entry.addon,
                order     = self:GetModuleTabOrder(entry.module),
                localeKey = MODULE_TAB_LOCALE_KEYS[entry.module],
            }
        end
    end
    return result
end

-- Startup orchestrator. Tier-2 modules and data stores are `LoadOnDemand: 1`
-- (they no longer auto-load), so core pulls the enabled ones from the manifest.
OneWoW.LoadOrchestrator = OneWoW.LoadOrchestrator or {}
local Orchestrator = OneWoW.LoadOrchestrator

--- Loads every `login`-phase manifest module, then each module's data stores,
--- in dependency order. Called from core's ADDON_LOADED (before PLAYER_LOGIN):
--- EnsureLoaded drives each unit's OnAddonLoaded hook synchronously, so every
--- DB is built in core-controlled order before the one-shot PLAYER_LOGIN fires.
--- A Blizzard-disabled (incl. per-character) module just fails EnsureLoaded with
--- "DISABLED" and is skipped; its stores are skipped too (their RequiredDeps on
--- the parent would fail anyway).
function Orchestrator:RunStartupPhase()
    for _, m in ipairs(Manifest) do
        if m.loadPhase == "login" and m.addon and m.addon ~= "" then
            -- BringUp loads the feature and its stores as one set. A soft opt-out
            -- (OneWoW SavedVariables) skips the unit and its stores via EnsureLoaded
            -- without touching Blizzard's enable flag, so it can be loaded later
            -- this session (Manage Features / the Blizzard "Load Addon" button)
            -- with no reload. Pre-login, BringUp's Settle / catch-up no-op; the
            -- manifest login phase and the real PLAYER_ENTERING_WORLD drive those.
            if not OneWoW:IsFeatureOptedOut(m.addon) then
                OneWoW:BringUp(m.addon)
            end
        end
    end
end

--- Used by the lazy-tab hook: loads a `lazy` module's addon the first time its
--- tab is opened. Dormant today (every manifest module is `login`-phase); ready
--- for when a pure-window module is tagged `lazy`.
---@param moduleName string module name (RegisterModule name) whose tab was opened
function Orchestrator:EnsureModuleForTab(moduleName)
    -- Already-loaded modules self-registered; nothing to pull.
    local registry = OneWoW.ModuleRegistry
    if registry and registry:GetModule(moduleName) then return end
    for _, m in ipairs(Manifest) do
        if m.module == moduleName and m.loadPhase == "lazy" and m.addon and m.addon ~= "" then
            OneWoW:EnsureLoaded(m.addon)
            return
        end
    end
end
