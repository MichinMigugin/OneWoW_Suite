-- Centralized on-demand addon loader. One loader serves both the login orchestrator
-- and lazy point-of-use loads, so no addon hand-rolls its own LoadAddOn wrapper.
-- GUI-free on purpose: it loads early, before anything that consumes it.
local _, OneWoW = ...

local C_AddOns = C_AddOns
local InCombatLockdown = InCombatLockdown
local CreateFrame = CreateFrame
local ipairs = ipairs
local tinsert = tinsert
local print = print
local _G = _G
local UnitName = UnitName

-- Pending loads deferred until combat ends, and a per-addon "already told the
-- user" guard so a repeated failure isn't reprinted on every attempt.
local pendingCombat = {}
local warned = {}

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
    local _, _, _, loadable, reason = C_AddOns.GetAddOnInfo(name)
    if not loadable and reason and reason ~= "DISABLED" and reason ~= "DEMAND_LOADED" then
        return "warning", reason
    end
    return "enabled", nil
end

---@class OneWoW.LoadOpts
---@field deferInCombat boolean? report "COMBAT" instead of loading while in combat (WithAddon queues the retry)

--- Ensures an addon is loaded. Idempotent; LoadAddOn pulls the addon's
--- RequiredDeps chain. Returns the raw failure token so callers can localize
--- via GetLoadFailureText.
---@param name string addon (folder/TOC) name to load
---@param opts OneWoW.LoadOpts? optional behavior flags
---@return boolean ok true if the addon is loaded (or already was)
---@return string? reason raw failure token when ok is false ("DISABLED" | "MISSING" | "DEP_DISABLED" | "COMBAT" | ...)
function OneWoW:EnsureLoaded(name, opts)
    if not name then return false, "MISSING" end
    if C_AddOns.IsAddOnLoaded(name) then
        return true
    end
    if opts and opts.deferInCombat and InCombatLockdown() then
        return false, "COMBAT"
    end
    local ok, reason = C_AddOns.LoadAddOn(name)
    if not ok then
        return false, reason
    end
    -- Core-driven init: invoke the unit's OnAddonLoaded hook right after a fresh
    -- load (when its SavedVariables are present), in core-controlled order. This
    -- replaces the unit's own ADDON_LOADED handler, which WoW does not deliver to
    -- a unit loaded during another addon's ADDON_LOADED dispatch. Only fires on a
    -- fresh load (the IsAddOnLoaded short-circuit above prevents re-firing); the
    -- hooks self-guard too. Units without the hook (Blizzard_*, etc.) are no-ops.
    local unit = _G[name]
    if unit and type(unit.OnAddonLoaded) == "function" then
        unit:OnAddonLoaded()
    end
    return true
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
-- `stores` lists a parent's data-store load units; the orchestrator loads each
-- one right after the parent so its OnAddonLoaded hook fires deterministically
-- (these are LoadOnDemand: 1 now, not LoadWith-auto-loaded).
OneWoW.ModuleManifest = {
    { addon = "OneWoW_GUI",             display = "GUI",           cmd = nil },
    { addon = "OneWoW_Notes",           display = "Notes",         cmd = "/1wn",   module = "notes",      loadPhase = "login" },
    { addon = "OneWoW_AltTracker",      display = "AltTracker",    cmd = "/1wat",  module = "alttracker", loadPhase = "login",
        stores = {
            "OneWoW_AltTracker_Storage",
            "OneWoW_AltTracker_Character",
            "OneWoW_AltTracker_Professions",
            "OneWoW_AltTracker_Collections",
            "OneWoW_AltTracker_Endgame",
            "OneWoW_AltTracker_Accounting",
            "OneWoW_AltTracker_Auctions",
        } },
    { addon = "OneWoW_Catalog",         display = "Catalog",       cmd = "/owcat", module = "catalog",    loadPhase = "login",
        stores = {
            "OneWoW_CatalogData_Tradeskills",
            "OneWoW_CatalogData_Vendors",
            "OneWoW_CatalogData_Quests",
            "OneWoW_CatalogData_Journal",
        } },
    { addon = "OneWoW_Trackers",        display = "Trackers",      cmd = "/1wt",   module = "trackers",   loadPhase = "login" },
    { addon = "OneWoW_QoL",             display = "QoL",           cmd = "/1wqol", module = "qol",        loadPhase = "login" },
    { addon = "OneWoW_DirectDeposit",   display = "DirectDeposit", cmd = "/1wdd",  loadPhase = "login" },
    { addon = "OneWoW_ShoppingList",    display = "ShoppingList",  cmd = "/1wsl",  loadPhase = "login" },
    { addon = "OneWoW_Bags",            display = "Bags",          cmd = "/1wb",   loadPhase = "login" },
    { addon = "OneWoW_Utility_DevTool", display = "DevTools",      cmd = "/1wdt" },
}
local Manifest = OneWoW.ModuleManifest

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
            if OneWoW:EnsureLoaded(m.addon) and m.stores then
                for _, store in ipairs(m.stores) do
                    OneWoW:EnsureLoaded(store)
                end
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
