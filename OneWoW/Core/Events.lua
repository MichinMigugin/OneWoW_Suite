local _, ns = ...

-- ============================================================================
-- Events
-- ============================================================================
-- The single WoW event frame for the OneWoW core. Two responsibilities:
--
--   1. Lifecycle: ADDON_LOADED / PLAYER_LOGIN / PLAYER_ENTERING_WORLD are routed
--      into the existing ordered dispatch (ns:DispatchAddonLoaded /
--      ns:RunCoreLoginSequence / ns:DispatchEnteringWorld). They deliberately do
--      NOT flow through the generic registry below — that would bypass the
--      phased early/late handlers, the manifest login phase, and the mid-session
--      LoadAddOn catch-up. This is also why this file (not OneWoW.lua) is the
--      lifecycle registrar allowlisted by the `no-suite-lifecycle-events` hook.
--
--   2. Gameplay events: ns.RegisterEvent / ns.UnregisterEvent let core files
--      share this one frame instead of each spawning their own. Core-only by
--      design (ns is private to the OneWoW core); not a public OneWoW.* API.
-- ============================================================================

local LIFECYCLE = {
    ADDON_LOADED = true,
    PLAYER_LOGIN = true,
    PLAYER_ENTERING_WORLD = true,
}

-- handlers[event][ownerID] = fn(event, ...)
local handlers = {}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        ns:DispatchAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        -- After this point, a mid-session LoadAddOn won't deliver the unit's own
        -- one-shot PLAYER_LOGIN, so ns:EnsureLoaded drives its login hooks.
        ns._playerLoginFired = true
        ns:RunCoreLoginSequence()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = ...
        ns:DispatchEnteringWorld(isLogin, isReload)
    end

    -- Fan out to any gameplay-event handlers. Lifecycle buckets stay empty
    -- (ns.RegisterEvent rejects lifecycle events), so this is a no-op for them.
    local bucket = handlers[event]
    if bucket then
        for _, fn in pairs(bucket) do
            fn(event, ...)
        end
    end
end)

--- Register a handler for a NON-lifecycle gameplay event on the shared core frame.
--- Re-registering the same ownerID replaces the prior handler (no stacking).
---@param event string WoW event name (not a lifecycle event)
---@param ownerID string stable id used for replace/unregister
---@param fn fun(event: string, ...): nil
function ns.RegisterEvent(event, ownerID, fn)
    if LIFECYCLE[event] then
        error(("ns.RegisterEvent: '%s' is a lifecycle event; use RegisterCoreLoginHandler / RegisterCoreEnteringWorldHandler / RegisterAddonLoadedWatcher instead"):format(event), 2)
    end
    if type(ownerID) ~= "string" or type(fn) ~= "function" then
        error("ns.RegisterEvent(event, ownerID, fn): ownerID must be a string and fn a function", 2)
    end

    local bucket = handlers[event]
    if not bucket then
        bucket = {}
        handlers[event] = bucket
        frame:RegisterEvent(event)
    end
    bucket[ownerID] = fn
end

--- Remove a previously registered gameplay-event handler. Unregisters the event
--- from the frame once its last handler is gone.
---@param event string
---@param ownerID string
function ns.UnregisterEvent(event, ownerID)
    local bucket = handlers[event]
    if not bucket then return end
    bucket[ownerID] = nil
    if next(bucket) == nil then
        handlers[event] = nil
        if not LIFECYCLE[event] then
            frame:UnregisterEvent(event)
        end
    end
end
