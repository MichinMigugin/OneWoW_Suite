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

-- Restriction types that gate protected actions / secure-frame mutations.
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

-- ADDON_RESTRICTION_STATE_CHANGED is synchronous and fires BEFORE a type activates
-- and AFTER it deactivates. Trust the payload state rather than polling, because
-- the query APIs return false during dispatch of this event.
ns.RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED", "Restriction", function(_, restrictionType, restrictionState)
    state.types[restrictionType] = restrictionState ~= INACTIVE
end)

ns.RegisterEvent("PLAYER_REGEN_DISABLED", "Restriction", function()
    state.lockdown = true
end)

ns.RegisterEvent("PLAYER_REGEN_ENABLED", "Restriction", function()
    state.lockdown = false
end)

--- True if value must not be used in addon logic or persisted (Midnight
--- secret system). Secret values may only be passed to display APIs.
---@param value any
---@return boolean
function Restriction.IsSecret(value)
    if issecretvalue(value) then
        return true
    end
    if type(value) == "table" and issecrettable(value) then
        return true
    end
    return false
end

--- True while in combat lockdown or while any reviewed addon-restriction type
--- (RESTRICTED_ACTION_TYPES) is active or activating. The `~= Inactive` test
--- covers both Active and the transient Activating state. Gate secure-frame
--- mutations and other protected actions behind this.
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
