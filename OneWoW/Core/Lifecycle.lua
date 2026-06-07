-- Central lifecycle dispatch for the OneWoW suite. Only OneWoW.lua registers
-- ADDON_LOADED, PLAYER_LOGIN, and PLAYER_ENTERING_WORLD for orchestrated units.
local ADDON_NAME, OneWoW = ...

local C_AddOns = C_AddOns
local ipairs = ipairs
local pairs = pairs
local type = type
local pcall = pcall
local format = string.format
local tostring = tostring
local _G = _G

OneWoW.Lifecycle = OneWoW.Lifecycle or {}
local Lifecycle = OneWoW.Lifecycle

--- Isolated invoke for handler fans: one failure must not abort the fan-out.
--- Failures are forwarded to geterrorhandler() (production sink; not debug-gated).
---@param label string|nil handler id or context label
---@param fn function
local function SafeCall(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        if label then
            geterrorhandler()(format("OneWoW lifecycle handler '%s': %s", tostring(label), tostring(err)))
        else
            geterrorhandler()(err)
        end
    end
end
Lifecycle.SafeCall = SafeCall

local addonLoadedWatchers = {}
local coreLoginHandlers = {}
local coreEnteringWorldHandlers = {}

local function RunUnitHook(unit, method, ...)
    if unit and type(unit[method]) == "function" then
        unit[method](unit, ...)
    end
end

local function WalkManifestUnits(fn)
    local manifest = OneWoW.ModuleManifest
    if not manifest then return end
    for _, m in ipairs(manifest) do
        if not m.addon or m.addon == "" or m.addon == "OneWoW_GUI" then
            -- skip GUI (self-bootstrap) and empty entries
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
function OneWoW:RegisterAddonLoadedWatcher(addonName, fn)
    if not fn then return end
    addonLoadedWatchers[#addonLoadedWatchers + 1] = {
        addonName = addonName,
        fn = fn,
    }
end

---@param id string unique handler id (for debugging; not used for dedup)
---@param fn fun()
function OneWoW:RegisterCoreLoginHandler(id, fn)
    if not fn then return end
    coreLoginHandlers[#coreLoginHandlers + 1] = { id = id, fn = fn }
end

---@param id string unique handler id
---@param fn fun(isLogin: boolean, isReload: boolean, isZoning: boolean)
function OneWoW:RegisterCoreEnteringWorldHandler(id, fn)
    if not fn then return end
    coreEnteringWorldHandlers[#coreEnteringWorldHandlers + 1] = { id = id, fn = fn }
end

function OneWoW:FireCoreLoginHandlers()
    for _, entry in ipairs(coreLoginHandlers) do
        SafeCall(entry.id, entry.fn)
    end
end

function OneWoW:FireCoreEnteringWorldHandlers(isLogin, isReload, isZoning)
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

---@param loadedAddon string addon name from ADDON_LOADED
function OneWoW:DispatchAddonLoaded(loadedAddon)
    if loadedAddon == ADDON_NAME then
        OneWoW:OnAddonLoaded(loadedAddon)
    end
    FireAddonLoadedWatchers(loadedAddon)
    -- Auto-loaded manifest units (e.g. DevTool) receive WoW's own ADDON_LOADED.
    if loadedAddon and loadedAddon ~= ADDON_NAME then
        local unit = _G[loadedAddon]
        if unit and type(unit.OnAddonLoaded) == "function" then
            unit:OnAddonLoaded()
        end
    end
end

-- Login pass over every loaded manifest unit. Login-only by design: it must NOT
-- fire OnPlayerEnteringWorld -- the real PLAYER_ENTERING_WORLD that follows
-- PLAYER_LOGIN at cold start drives PEW with authoritative args (see
-- DispatchEnteringWorld). OnAddonLoaded is a safety net for units whose hook was
-- somehow not driven by the LoadAddOn path; one-shot guards make it idempotent.
function OneWoW:RunManifestLoginPhase()
    WalkManifestUnits(function(addonName)
        local unit = _G[addonName]
        RunUnitHook(unit, "OnAddonLoaded")
        RunUnitHook(unit, "OnPlayerLogin")
    end)
end

---@param isLogin boolean
---@param isReload boolean
function OneWoW:DispatchEnteringWorld(isLogin, isReload)
    local isZoning = not isLogin and not isReload
    OneWoW:FireCoreEnteringWorldHandlers(isLogin, isReload, isZoning)
    WalkManifestUnits(function(addonName)
        RunUnitHook(_G[addonName], "OnPlayerEnteringWorld", isLogin, isReload, isZoning)
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
        OneWoW:RegisterAddonLoadedWatcher(addonName, fn)
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
