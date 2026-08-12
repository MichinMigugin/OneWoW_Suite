local _, ns = ...

-- ============================================================================
-- Restriction
-- ============================================================================
-- The single funnel for the Midnight secret-value system and combat/instance
-- addon restrictions. Gate secure-frame mutations and combat-sensitive reads
-- behind these instead of raw InCombatLockdown / C_RestrictedActions calls —
-- enforced suite-wide by the `restriction-funnel` pre-commit hook.
--
-- The restriction-type set checked by IsAddonRestricted is listed explicitly
-- (RESTRICTED_ACTION_TYPES below) rather than iterated over
-- Enum.AddOnRestrictionType, so a new type added by a future patch is NOT
-- silently inherited — it must be reviewed and opted in here on purpose.
--
-- Restriction-type state is cached and kept fresh by ADDON_RESTRICTION_STATE_CHANGED
-- (lazy-seeded on first read), so the getters avoid a per-call GetAddOnRestrictionState
-- loop on hot paths. Combat lockdown is intentionally read LIVE via InCombatLockdown()
-- in the getters — it is the gate for secure-frame safety and must never act on a
-- stale value; the PLAYER_REGEN_* listeners only maintain state.lockdown for the
-- snapshot and for transition detection used by a later phase.
-- ============================================================================

local Restriction = {}
ns.Restriction = Restriction

-- The full reviewed restriction-type set behind IsAddonRestricted (the broad
-- gate, including Map). Protected actions / secure-frame mutations use the
-- PROTECTED_ACTION_TYPES subset below (via IsProtectedActionBlocked) instead.
-- Chat (addon comms, not secure-frame related; added 12.0.5) is intentionally
-- excluded — route any future chat-comms gating through a dedicated helper.
local RESTRICTED_ACTION_TYPES = {
    Enum.AddOnRestrictionType.Combat,
    Enum.AddOnRestrictionType.Encounter,
    Enum.AddOnRestrictionType.ChallengeMode,
    Enum.AddOnRestrictionType.PvPMatch,
    Enum.AddOnRestrictionType.Map,
}

-- Subset that gates protected actions (item moves, bindings) WITHOUT Map.
-- An instanced-map restriction (e.g. a Delve) does not block protected
-- inventory/binding actions out of combat — only combat lockdown and the
-- combat/encounter/keystone/PvP restriction types do. Excluding Map here is
-- what lets bag layout cleanup and item handling work normally inside Delves.
local PROTECTED_ACTION_TYPES = {
    Enum.AddOnRestrictionType.Combat,
    Enum.AddOnRestrictionType.Encounter,
    Enum.AddOnRestrictionType.ChallengeMode,
    Enum.AddOnRestrictionType.PvPMatch,
}

local INACTIVE = Enum.AddOnRestrictionState.Inactive

-- Event-driven cache. `types[restrictionType]` is true while that type is Active
-- or Activating. `lockdown` mirrors combat lockdown via PLAYER_REGEN_* and is used
-- by GetSnapshot + (later) transition detection; the getters read lockdown live.
local state = { lockdown = false, types = {} }
local seeded = false

-- Lazy seed: the first getter that needs restriction-type state reads the live
-- values once, then ADDON_RESTRICTION_STATE_CHANGED keeps the cache fresh. This
-- decouples seeding from load order and stays correct across a /reload inside a
-- restricted zone (no event fires on reload, but the first read sees live truth).
local function EnsureSeeded()
    if seeded then return end
    seeded = true
    state.lockdown = InCombatLockdown()
    for _, restrictionType in ipairs(RESTRICTED_ACTION_TYPES) do
        state.types[restrictionType] = C_RestrictedActions.GetAddOnRestrictionState(restrictionType) ~= INACTIVE
    end
end

--- True if `value` is a secret scalar (Midnight secret system). Thin mirror of
--- the `issecretvalue` global so the raw call stays funnelled in one place.
---@param value any
---@return boolean
function Restriction.IsSecretValue(value)
    return issecretvalue(value)
end

--- True if `value` is a secret table — the table reference itself is secret, or
--- its flags make reads produce secrets, so its contents must not be iterated.
--- Thin mirror of the `issecrettable` global (returns false for non-tables).
---@param value any
---@return boolean
function Restriction.IsSecretTable(value)
    return issecrettable(value)
end

--- True if value must not be used in addon logic or persisted (Midnight secret
--- system) — either a secret scalar or a secret table. Secret values may only
--- be passed to display APIs.
---@param value any
---@return boolean
function Restriction.IsSecret(value)
    return Restriction.IsSecretValue(value) or Restriction.IsSecretTable(value)
end

--- True while unit-aura queries will generally produce secrets (Combat /
--- Encounter / ChallengeMode / PvPMatch aura restriction). 12.1+: index, slot,
--- and instance-ID UnitAura / TooltipInfo aura APIs Lua-error when called from
--- tainted code in this state — gate those call sites here (or use spell-ID /
--- spell-name APIs, which return nil for secret auras instead of erroring).
---@return boolean
function Restriction.ShouldAurasBeSecret()
    return C_Secrets.ShouldAurasBeSecret()
end

--- True while in combat lockdown or while any reviewed addon-restriction type
--- (RESTRICTED_ACTION_TYPES, including Map) is active or activating. The
--- `~= Inactive` test covers both Active and the transient Activating state.
--- This is the BROAD gate — use it only for actions that must also stand down
--- inside an instanced/restricted map (e.g. a Delve). For protected actions /
--- secure-frame mutations that stay valid in a Delve out of combat, use
--- IsProtectedActionBlocked instead (Map does not block them).
---@return boolean
function Restriction.IsAddonRestricted()
    if InCombatLockdown() then return true end

    EnsureSeeded()
    for _, restrictionType in ipairs(RESTRICTED_ACTION_TYPES) do
        if state.types[restrictionType] then return true end
    end

    return false
end

--- True while combat lockdown or a combat-tier restriction (Combat, Encounter,
--- ChallengeMode, PvPMatch) is active/activating — but NOT for an instanced-map
--- restriction alone. Gate protected actions that are safe inside a Delve out
--- of combat (item pickup/equip, bank transfers, binding overrides) behind this
--- rather than IsAddonRestricted, so the Map restriction does not block them.
---@return boolean
function Restriction.IsProtectedActionBlocked()
    if InCombatLockdown() then return true end

    EnsureSeeded()
    for _, restrictionType in ipairs(PROTECTED_ACTION_TYPES) do
        if state.types[restrictionType] then return true end
    end

    return false
end

--- True while in combat lockdown only. For combat-only UX/perf gates (fade,
--- deferral, suppression) that are not about secure-frame safety, and for
--- hot paths that want a single cheap check.
---@return boolean
function Restriction.IsInCombat()
    return InCombatLockdown()
end

--- True while the named reviewed restriction type is Active or Activating.
--- Reads the event-driven cache (EnsureSeeded). Use for place/kind detection
--- (ChallengeMode, Map, PvPMatch) — never call C_RestrictedActions from consumers.
---@param restrictionType number Enum.AddOnRestrictionType.*
---@return boolean
function Restriction.IsTypeActive(restrictionType)
    EnsureSeeded()
    return state.types[restrictionType] == true
end

-- ---------------------------------------------------------------------------
-- State-change consumer fan-out
-- ---------------------------------------------------------------------------
-- Feature modules must NOT RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED") —
-- subscribe here instead (enforced by core-event-funnel). Fan-out is deferred
-- one frame so callers never act during Blizzard's dispatch window where the
-- query APIs report false.
-- stateCallbacks[ownerID] = fn(restrictionType, restrictionState)
local stateCallbacks = {}
local pendingStateNotify = {} -- array of { type, state } queued for post-dispatch fan-out
local stateNotifyScheduled = false

local function FlushStateCallbacks()
    local batch = pendingStateNotify
    pendingStateNotify = {}
    stateNotifyScheduled = false
    if #batch == 0 then return end

    for i = 1, #batch do
        local entry = batch[i]
        for ownerID, fn in pairs(stateCallbacks) do
            local ok, err = pcall(fn, entry.type, entry.state)
            if not ok then
                print("|cFFFF0000OneWoW|r Restriction state callback error [" .. tostring(ownerID) .. "]: " .. tostring(err))
            end
        end
    end
end

local function ScheduleStateNotify(restrictionType, restrictionState)
    pendingStateNotify[#pendingStateNotify + 1] = { type = restrictionType, state = restrictionState }
    if stateNotifyScheduled then return end
    stateNotifyScheduled = true
    C_Timer.After(0, FlushStateCallbacks)
end

--- Subscribe to restriction-type state changes. `fn(restrictionType, restrictionState)`
--- fires one frame after ADDON_RESTRICTION_STATE_CHANGED so IsTypeActive is trustworthy.
--- Re-registering the same ownerID replaces the prior callback.
---@param ownerID string
---@param fn fun(restrictionType: number, restrictionState: number)
function Restriction.RegisterStateCallback(ownerID, fn)
    if type(ownerID) ~= "string" or type(fn) ~= "function" then
        error("RegisterStateCallback(ownerID, fn): ownerID must be a string and fn a function", 2)
    end
    EnsureSeeded()
    stateCallbacks[ownerID] = fn
end

--- Drop a state-change subscription (e.g. on module disable).
---@param ownerID string
function Restriction.UnregisterStateCallback(ownerID)
    stateCallbacks[ownerID] = nil
end

-- ---------------------------------------------------------------------------
-- Deferred-until-unrestricted callbacks
-- ---------------------------------------------------------------------------
-- RunWhenUnrestricted(bucket, ownerID, fn) runs fn as soon as `bucket` is clear:
-- immediately (synchronously) if already clear, otherwise once on the next
-- clearing transition. One-shot; re-registering the same ownerID replaces the
-- prior entry; CancelWhenUnrestricted(ownerID) drops it. Buckets map to the
-- getters so callers express intent rather than naming raw restriction types:
--   "lockdown"   -> IsInCombat               (combat-only UX / perf deferral)
--   "protected"  -> IsProtectedActionBlocked (secure-frame / protected actions)
--   "restricted" -> IsAddonRestricted        (broad gate, includes Map)
local BUCKET_BLOCKED = {
    lockdown = Restriction.IsInCombat,
    protected = Restriction.IsProtectedActionBlocked,
    restricted = Restriction.IsAddonRestricted,
}

-- pending[ownerID] = { bucket = string, fn = function }
local pending = {}

local function IsBucketBlocked(bucket)
    local predicate = BUCKET_BLOCKED[bucket]
    return predicate ~= nil and predicate()
end

local function FlushPending()
    -- Collect ready entries first: a fired callback may re-register itself, and
    -- it must not be re-run within the same pass.
    local ready
    for ownerID, entry in pairs(pending) do
        if not IsBucketBlocked(entry.bucket) then
            ready = ready or {}
            ready[ownerID] = entry
        end
    end
    if not ready then return end

    for ownerID, entry in pairs(ready) do
        pending[ownerID] = nil
        local ok, err = pcall(entry.fn)
        if not ok then
            print("|cFFFF0000OneWoW|r Restriction callback error [" .. tostring(ownerID) .. "]: " .. tostring(err))
        end
    end
end

local flushScheduled = false
-- Flush AFTER event dispatch settles: during ADDON_RESTRICTION_STATE_CHANGED the
-- query APIs report false and an Activating type is not yet enforced, so deferring
-- one frame lets callbacks act on the final state.
local function ScheduleFlush()
    if flushScheduled then return end
    flushScheduled = true
    C_Timer.After(0, function()
        flushScheduled = false
        FlushPending()
    end)
end

--- Run fn once `bucket` is clear: now if already clear, otherwise on the next
--- clearing transition. Re-registering the same ownerID replaces the prior fn.
---@param bucket "lockdown"|"protected"|"restricted"
---@param ownerID string
---@param fn fun(): nil
function Restriction.RunWhenUnrestricted(bucket, ownerID, fn)
    if BUCKET_BLOCKED[bucket] == nil then
        error("RunWhenUnrestricted: unknown bucket '" .. tostring(bucket) .. "'", 2)
    end
    if type(ownerID) ~= "string" or type(fn) ~= "function" then
        error("RunWhenUnrestricted(bucket, ownerID, fn): ownerID must be a string and fn a function", 2)
    end

    if not IsBucketBlocked(bucket) then
        pending[ownerID] = nil
        fn()
        return
    end
    pending[ownerID] = { bucket = bucket, fn = fn }
end

--- Drop a pending callback (e.g. on teardown) so it never fires.
---@param ownerID string
function Restriction.CancelWhenUnrestricted(ownerID)
    pending[ownerID] = nil
end

-- ADDON_RESTRICTION_STATE_CHANGED is synchronous and fires BEFORE a type activates
-- and AFTER it deactivates. Trust the payload state rather than polling, because
-- the query APIs return false during dispatch of this event. A type going Inactive
-- can unblock a pending callback, so schedule a post-dispatch flush.
ns.RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", "Restriction", function(_, restrictionType, restrictionState)
    local active = restrictionState ~= INACTIVE
    state.types[restrictionType] = active
    ScheduleStateNotify(restrictionType, restrictionState)
    if not active then
        ScheduleFlush()
    end
end)

ns.RegisterEvent("PLAYER_REGEN_DISABLED", "Restriction", function()
    state.lockdown = true
end)

ns.RegisterEvent("PLAYER_REGEN_ENABLED", "Restriction", function()
    state.lockdown = false
    ScheduleFlush()
end)

--- Debug view of the restriction cache vs. the live API, for in-game diagnosis
--- (e.g. confirming Map=Active inside a Delve). Not a hot path — builds tables
--- and reads live state on each call.
---@return table
function Restriction.GetSnapshot()
    EnsureSeeded()

    local typeNames, stateNames = {}, {}
    for name, value in pairs(Enum.AddOnRestrictionType) do typeNames[value] = name end
    for name, value in pairs(Enum.AddOnRestrictionState) do stateNames[value] = name end

    local types = {}
    for _, restrictionType in ipairs(RESTRICTED_ACTION_TYPES) do
        local live = C_RestrictedActions.GetAddOnRestrictionState(restrictionType)
        types[typeNames[restrictionType] or restrictionType] = {
            cached = state.types[restrictionType] or false,
            live = stateNames[live] or live,
        }
    end

    return {
        seeded = seeded,
        lockdownLive = InCombatLockdown(),
        lockdownCached = state.lockdown,
        types = types,
    }
end
