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

-- Login-phase orchestrator. Loads every enabled module that must be live before
-- any window opens. Until LoadManagers is added (migration step 3) modules still
-- auto-load, so EnsureLoaded here is a validated no-op via IsAddOnLoaded.
OneWoW.LoadOrchestrator = OneWoW.LoadOrchestrator or {}
local Orchestrator = OneWoW.LoadOrchestrator

--- Loads every enabled `login`-phase module on PLAYER_LOGIN.
function Orchestrator:RunLoginPhase()
    local registry = OneWoW.ModuleRegistry
    if not registry then return end
    for _, mod in ipairs(registry:GetModules()) do
        if mod.loadPhase == "login" and mod.addonName and mod.addonName ~= "" then
            OneWoW:EnsureLoaded(mod.addonName)
        end
    end
end

--- Used by the lazy-tab hook: loads a `lazy` module's addon the first time its
--- tab is opened. Dormant until modules become LoadOnDemand (migration step 3).
---@param moduleName string registered module name whose tab was opened
function Orchestrator:EnsureModuleForTab(moduleName)
    local registry = OneWoW.ModuleRegistry
    if not registry then return end
    local mod = registry:GetModule(moduleName)
    if mod and mod.loadPhase == "lazy" and mod.addonName and mod.addonName ~= "" then
        OneWoW:EnsureLoaded(mod.addonName)
    end
end
